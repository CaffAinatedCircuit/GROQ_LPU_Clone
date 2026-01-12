`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 10:17:47
// Design Name: 
// Module Name: hac_deskew_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//=============================================================================
// HAC Deskew Core for Multi-TSP System - Vivado Implementation
// Dual-Core (Left/Right Links), Configurable Parent/Child, Async C2C
// Professional Verilog with 20+ Years Experience
//=============================================================================

//=============================================================================
// HAC Deskew Core - FIXED VERSION (High-Z Issues Resolved)
//=============================================================================

`timescale 1ns / 1ps
`default_nettype none

module hac_deskew_core #(
    parameter HAC_WIDTH = 32,
    parameter LINK_DATA_WIDTH = HAC_WIDTH + 16  // HAC + type(8) + parity(8)
)(
    input  wire         clk,
    input  wire         rst_n,
    
    input  wire         instr_valid,
    output reg          instr_ready,
    input  wire [31:0]  instr_data,
    
    // Left Link
    output reg  [LINK_DATA_WIDTH-1:0] left_tx_data,
    output reg                       left_tx_valid,
    input  wire                       left_tx_ready,
    input  wire [LINK_DATA_WIDTH-1:0] left_rx_data,
    input  wire                       left_rx_valid,
    output reg                       left_rx_ready,
    
    // Right Link  
    output reg  [LINK_DATA_WIDTH-1:0] right_tx_data,
    output reg                       right_tx_valid,
    input  wire                       right_tx_ready,
    input  wire [LINK_DATA_WIDTH-1:0] right_rx_data,
    input  wire                       right_rx_valid,
    output reg                       right_rx_ready,
    
    output wire [HAC_WIDTH-1:0] hac_current,
    output wire [7:0]           state_left,
    output wire [7:0]           state_right
);

    // Explicit parameters
    localparam [7:0] OPCODE_PARENT_L  = 8'h10;
    localparam [7:0] OPCODE_CHILD_L   = 8'h11;
    localparam [7:0] OPCODE_PARENT_R  = 8'h20;
    localparam [7:0] OPCODE_CHILD_R   = 8'h21;
    
    localparam [7:0] STATE_IDLE       = 8'h00;
    localparam [7:0] STATE_TX_HAC     = 8'h01;
    localparam [7:0] STATE_WAIT_REFLECT = 8'h02;
    
    localparam [7:0] PKT_TYPE_HAC     = 8'hA0;
    
    // HAC Counter - ALWAYS DRIVEN
    reg [HAC_WIDTH-1:0] hac_counter;
    reg [HAC_WIDTH-1:0] hac_offset = 0;
    assign hac_current = hac_counter - hac_offset;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            hac_counter <= 32'h1000;  // Non-zero start
        else
            hac_counter <= hac_counter + 1;
    end

    //=============================================================================
    // LEFT LINK FSM - FIXED
    //=============================================================================
    reg [7:0] left_state = STATE_IDLE;
    reg [HAC_WIDTH-1:0] left_hac_sent;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_state <= STATE_IDLE;
            left_tx_data <= 0;
            left_tx_valid <= 1'b0;
            left_rx_ready <= 1'b1;  // DEFAULT READY HIGH
            left_hac_sent <= 0;
        end else begin
            case (left_state)
                STATE_IDLE: begin
                    left_tx_valid <= 1'b0;
                    left_rx_ready <= 1'b1;
                    
                    if (instr_valid && instr_data[7:0] == OPCODE_PARENT_L) begin
                        left_state <= STATE_TX_HAC;
                        left_hac_sent <= hac_current;
                    end
                end
                
                STATE_TX_HAC: begin
                    left_tx_valid <= 1'b1;
                    left_rx_ready <= 1'b0;
                    
                    // PACKET: {type[7:0], hac[HAC_WIDTH-1:0], parity[7:0]}
                    left_tx_data <= {PKT_TYPE_HAC, hac_current, ^( {PKT_TYPE_HAC, hac_current} )};
                    
                    if (left_tx_ready) begin
                        left_tx_valid <= 1'b0;
                        left_state <= STATE_WAIT_REFLECT;
                        left_rx_ready <= 1'b1;
                    end
                end
                
                STATE_WAIT_REFLECT: begin
                    left_tx_valid <= 1'b0;
                    
                    if (left_rx_valid) begin
                        $display("Core Left RX: %h", left_rx_data);
                        if (left_rx_data[LINK_DATA_WIDTH-1 -: 8] == PKT_TYPE_HAC &&
                            left_rx_data[15:0] == ^left_rx_data[LINK_DATA_WIDTH-1:16]) begin
                            $display("Left: RTT = %d, Latency = %d", 
                                     hac_current - left_hac_sent, (hac_current - left_hac_sent)>>1);
                        end
                        left_state <= STATE_IDLE;
                    end
                end
                
                default: left_state <= STATE_IDLE;
            endcase
        end
    end
    
    assign state_left = left_state;

    //=============================================================================
    // RIGHT LINK FSM - IDENTICAL LOGIC
    //=============================================================================
    reg [7:0] right_state = STATE_IDLE;
    reg [HAC_WIDTH-1:0] right_hac_sent;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            right_state <= STATE_IDLE;
            right_tx_data <= 0;
            right_tx_valid <= 1'b0;
            right_rx_ready <= 1'b1;  // DEFAULT READY HIGH
            right_hac_sent <= 0;
        end else begin
            case (right_state)
                STATE_IDLE: begin
                    right_tx_valid <= 1'b0;
                    right_rx_ready <= 1'b1;
                    
                    if (instr_valid && instr_data[7:0] == OPCODE_PARENT_R) begin
                        right_state <= STATE_TX_HAC;
                        right_hac_sent <= hac_current;
                    end
                end
                
                STATE_TX_HAC: begin
                    right_tx_valid <= 1'b1;
                    right_rx_ready <= 1'b0;
                    
                    right_tx_data <= {PKT_TYPE_HAC, hac_current, ^( {PKT_TYPE_HAC, hac_current} )};
                    
                    if (right_tx_ready) begin
                        right_tx_valid <= 1'b0;
                        right_state <= STATE_WAIT_REFLECT;
                        right_rx_ready <= 1'b1;
                    end
                end
                
                STATE_WAIT_REFLECT: begin
                    right_tx_valid <= 1'b0;
                    
                    if (right_rx_valid) begin
                        $display("Core Right RX: %h", right_rx_data);
                        if (right_rx_data[LINK_DATA_WIDTH-1 -: 8] == PKT_TYPE_HAC &&
                            right_rx_data[15:0] == ^right_rx_data[LINK_DATA_WIDTH-1:16]) begin
                            $display("Right: RTT = %d, Latency = %d", 
                                     hac_current - right_hac_sent, (hac_current - right_hac_sent)>>1);
                        end
                        right_state <= STATE_IDLE;
                    end
                end
                
                default: right_state <= STATE_IDLE;
            endcase
        end
    end
    
    assign state_right = right_state;

    // Instruction Interface - SIMPLIFIED
    always @(*) begin
        instr_ready = (left_state == STATE_IDLE && right_state == STATE_IDLE);
    end

endmodule

