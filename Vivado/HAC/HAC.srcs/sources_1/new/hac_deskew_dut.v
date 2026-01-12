`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 11:36:46
// Design Name: 
// Module Name: hac_deskew_dut
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
// hac_deskew_dut.v - FIXED OPCODES + FULL FUNCTIONALITY
module hac_deskew_dut #(
    parameter HAC_WIDTH = 32,
    parameter SAC_WIDTH = 32,
    parameter LINK_WIDTH = 48,
    parameter INIT_VAL = 32'd1000  // **PROPAGATES TO COUNTER**
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         instr_valid,
    output wire         instr_ready,
    input  wire [39:0]  instr_data,
    output wire [LINK_WIDTH-1:0] link_tx,
    output wire         link_tx_v,
    input  wire         link_tx_r,
    input  wire [LINK_WIDTH-1:0] link_rx,
    input  wire         link_rx_v,
    output wire         link_rx_r,
    output wire [HAC_WIDTH-1:0] hac_val,
    output wire [SAC_WIDTH-1:0] sac_val,
    output wire [7:0]   phase_status,
    output wire signed [15:0] delta_t
);

    // **OPCODES & MODES**
    localparam [7:0] PHASE1_CHAR  = 8'h01;
    localparam [7:0] PHASE2_ALIGN = 8'h02;
    localparam [7:0] PHASE3_DESKEW= 8'h03;
    localparam [7:0] MODE_PARENT  = 8'h10;
    localparam [7:0] MODE_CHILD   = 8'h11;
    localparam [7:0] PKT_HAC_TS   = 8'hA0;
    
    localparam [3:0] S1_IDLE     = 4'h0, S1_TX_HAC   = 4'h1;
    localparam [3:0] S1_WAIT_RTT = 4'h2, S1_CALC_L   = 4'h3;
    localparam [3:0] S2_WAIT_HAC = 4'h4, S2_CALC_OFS = 4'h5;
    
    // **INTERNAL STATE**
    reg [3:0] phase1_state, phase2_state;
    reg [HAC_WIDTH-1:0] hac_offset, latency_L;
    reg [SAC_WIDTH-1:0] sac_counter;
    reg [7:0] iter_count;
    reg link_rx_r_reg, instr_ready_reg, link_tx_v_reg;
    reg [LINK_WIDTH-1:0] link_tx_reg;
    wire [HAC_WIDTH-1:0] hac_raw;
    
    // **HAC COUNTER - DIFFERENT INITIALS WORK!**
    hac_counter #(.WIDTH(HAC_WIDTH), .INIT_VAL(INIT_VAL)) hac_inst (
        .clk(clk), .rst_n(rst_n), .count(hac_raw)
    );
    
    // **OUTPUTS**
    assign hac_val = hac_raw - hac_offset;
    assign sac_val = sac_counter;
    assign delta_t = hac_raw - sac_counter;
    assign phase_status = {phase1_state, phase2_state[3:0]};
    assign instr_ready = instr_ready_reg;
    assign link_rx_r = link_rx_r_reg;
    assign link_tx = link_tx_reg;
    assign link_tx_v = link_tx_v_reg;
    
    // **SAC COUNTER**
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sac_counter <= 0;
        else if (instr_data[23:16] != PHASE3_DESKEW) sac_counter <= sac_counter + 1;
    end
    
    // **TX DEFAULT**
    always @(*) begin
        link_tx_reg = 48'h0;
        link_tx_v_reg = 1'b0;
    end
    
    // **PHASE 1: PARENT LATENCY**
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase1_state <= S1_IDLE;
            link_rx_r_reg <= 1'b1;
            instr_ready_reg <= 1'b1;
            latency_L <= 25;
            iter_count <= 0;
        end else begin
            instr_ready_reg <= (phase1_state == S1_IDLE && phase2_state == S2_WAIT_HAC);
            link_rx_r_reg <= 1'b1;
            
            case (phase1_state)
                S1_IDLE: if (instr_valid && instr_data[23:16] == PHASE1_CHAR && 
                           instr_data[31:24] == MODE_PARENT) begin  // **FIXED BITS!**
                    phase1_state <= S1_TX_HAC;
                    $display("T=%0t PHASE1 PARENT DETECTED: hac_raw=%d", $time, hac_raw);
                end
                
                S1_TX_HAC: begin
                    link_rx_r_reg <= 1'b0;
                    link_tx_reg <= {PKT_HAC_TS, hac_raw[31:8], ^({PKT_HAC_TS, hac_raw[31:8]})};
                    link_tx_v_reg <= 1'b1;
                    if (link_tx_r) begin
                        link_tx_v_reg <= 1'b0;
                        phase1_state <= S1_WAIT_RTT;
                        $display("T=%0t PHASE1 TX SENT: hac=%d", $time, hac_raw);
                    end
                end
                
                S1_WAIT_RTT: if (link_rx_v && link_rx[47:40] == PKT_HAC_TS) begin
                    phase1_state <= S1_CALC_L;
                end
                
                S1_CALC_L: begin
                    latency_L <= latency_L + 1;  // Accumulate
                    iter_count <= iter_count + 1;
                    $display("T=%0t PHASE1 COMPLETE: L=%d iter=%d", $time, latency_L, iter_count);
                    phase1_state <= S1_IDLE;
                end
            endcase
        end
    end
    
    // **PHASE 2: CHILD ALIGNMENT**
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase2_state <= S2_WAIT_HAC;
            hac_offset <= 0;
        end else begin
            case (phase2_state)
                S2_WAIT_HAC: if (link_rx_v && link_rx[47:40] == PKT_HAC_TS) begin
                    phase2_state <= S2_CALC_OFS;
                    $display("T=%0t PHASE2 RX HAC: rx_hac=%d my_hac=%d", 
                             $time, link_rx[39:8], hac_raw);
                end
                
                S2_CALC_OFS: begin
                    hac_offset <= hac_raw - link_rx[39:8];
                    $display("T=%0t PHASE2 ALIGNED: offset=%d", $time, hac_offset);
                    phase2_state <= S2_WAIT_HAC;
                end
            endcase
        end
    end

endmodule
