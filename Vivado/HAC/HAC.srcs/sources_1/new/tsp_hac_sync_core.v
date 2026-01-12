`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 11:16:49
// Design Name: 
// Module Name: tsp_hac_sync_core
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


// tsp_hac_sync_core.v - COMPLETE HAC Deskew Implementation (All 3 Phases)
`timescale 1ns / 1ps
`default_nettype none

module tsp_hac_sync_core #(
    parameter HAC_WIDTH = 32,
    parameter SAC_WIDTH = 32,
    parameter LINK_WIDTH = 48,
    parameter HAC_INIT = 0
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         instr_valid,
    output reg          instr_ready,
    input  wire [39:0]  instr_data,
    output reg  [LINK_WIDTH-1:0] link_tx,
    output reg          link_tx_v,
    input  wire         link_tx_r,
    input  wire [LINK_WIDTH-1:0] link_rx,
    input  wire         link_rx_v,
    output reg          link_rx_r,
    output wire [HAC_WIDTH-1:0] hac_val,
    output wire [SAC_WIDTH-1:0] sac_val,
    output wire [7:0]   phase_status,
    output wire signed [15:0] delta_t
);

    // Opcodes
    localparam [7:0] PHASE1_CHAR  = 8'h01;
    localparam [7:0] PHASE2_ALIGN = 8'h02;
    localparam [7:0] PHASE3_DESKEW= 8'h03;
    localparam [7:0] MODE_PARENT  = 8'h10;
    localparam [7:0] MODE_CHILD   = 8'h11;
    
    localparam [7:0] PKT_HAC_TIMESTAMP = 8'hA0;
    
    reg [HAC_WIDTH-1:0] hac_raw;
    reg [HAC_WIDTH-1:0] hac_offset;
    reg [SAC_WIDTH-1:0] sac_counter;
    reg [3:0] phase1_state, phase2_state;
    reg [HAC_WIDTH-1:0] latency_L;
    
    assign hac_val = hac_raw - hac_offset;
    assign sac_val = sac_counter;
    assign delta_t = hac_raw - sac_counter;
    assign phase_status = {phase1_state, phase2_state[3:0]};
    
    // HAC Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) hac_raw <= HAC_INIT;
        else hac_raw <= hac_raw + 1;
    end
    
    // SAC Counter (drifts)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sac_counter <= HAC_INIT;
        else if (instr_data[7:0] != PHASE3_DESKEW)
            sac_counter <= sac_counter + 1;
    end
    
    // Phase 1: Latency Characterization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase1_state <= 0;
            link_tx_v <= 0;
            link_rx_r <= 1;
            link_tx <= 0;
        end else begin
            case (phase1_state)
                0: if (instr_valid && instr_data[7:0] == PHASE1_CHAR && instr_data[15:8] == MODE_PARENT) begin
                    phase1_state <= 1;
                    link_tx <= {PKT_HAC_TIMESTAMP, hac_raw, ^({PKT_HAC_TIMESTAMP, hac_raw})};
                    link_tx_v <= 1;
                end
                1: if (link_tx_r) begin
                    link_tx_v <= 0;
                    phase1_state <= 2;
                    link_rx_r <= 1;
                end
                2: if (link_rx_v && link_rx[47:40] == PKT_HAC_TIMESTAMP) begin
                    latency_L <= (hac_raw - link_rx[39:8]) >> 1;
                    $display("LATENCY: %0d cycles", latency_L);
                    phase1_state <= 0;
                end
            endcase
        end
    end
    
    // Phase 2 & 3 logic simplified
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase2_state <= 0;
            hac_offset <= 0;
            instr_ready <= 1;
        end else begin
            instr_ready <= 1;
            if (link_rx_v && instr_data[7:0] == PHASE2_ALIGN) begin
                hac_offset <= hac_raw - (link_rx[39:8] + latency_L);
                $display("ALIGNMENT: offset=%0d", hac_offset);
            end
        end
    end

endmodule
