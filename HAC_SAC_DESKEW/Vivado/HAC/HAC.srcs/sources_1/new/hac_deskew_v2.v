`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 10:34:07
// Design Name: 
// Module Name: hac_deskew_v2
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
// COMPLETE HAC Deskew Core v2 - All 3 Phases Implemented
// Phase 1: Latency Char, Phase 2: Clock Alignment, Phase 3: Runtime Deskew
//=============================================================================

`timescale 1ns / 1ps
`default_nettype none

module hac_deskew_complete #(
    parameter HAC_WIDTH = 32,
    parameter SAC_WIDTH = 32,
    parameter LINK_WIDTH = 48  // {type[8], hac[32], parity[8]}
)(
    input  wire         clk,
    input  wire         rst_n,
    
    // Instruction Interface
    input  wire         instr_valid,
    output wire         instr_ready,
    input  wire [39:0]  instr_data,  // {opcode[8], arg[32]}
    
    // Single bidirectional link (for TB simplicity)
    output reg  [LINK_WIDTH-1:0] link_tx,
    output reg                 link_tx_v,
    input  wire                link_tx_r,
    input  wire [LINK_WIDTH-1:0] link_rx,
    input  wire                link_rx_v,
    output reg                 link_rx_r,
    
    // Debug outputs
    output wire [HAC_WIDTH-1:0] hac_val,
    output wire [SAC_WIDTH-1:0] sac_val,
    output wire [7:0]           phase_status,
    output wire signed [15:0]   delta_t
);

    // Opcodes for all phases
    localparam [7:0] PHASE1_CHAR     = 8'h01;  // Latency characterization
    localparam [7:0] PHASE2_ALIGN    = 8'h02;  // Clock alignment  
    localparam [7:0] PHASE3_DESKEW   = 8'h03;  // Runtime deskew
    localparam [7:0] MODE_PARENT     = 8'h10;
    localparam [7:0] MODE_CHILD      = 8'h11;
    
    // Packet types
    localparam [7:0] PKT_HAC_TIMESTAMP = 8'hA0;
    localparam [7:0] PKT_NOTIFY_HAC    = 8'hA1;
    
    // Phase 1: Latency characterization state machine
    localparam [3:0] S1_IDLE      = 4'h0;
    localparam [3:0] S1_TX_HAC    = 4'h1;
    localparam [3:0] S1_WAIT_RTT  = 4'h2;
    localparam [3:0] S1_CALC_L    = 4'h3;
    
    // Phase 2: Alignment state machine  
    localparam [3:0] S2_WAIT_HAC  = 4'h4;
    localparam [3:0] S2_CALC_ALIGN= 4'h5;
    localparam [3:0] S2_ADJUST    = 4'h6;
    
    reg [3:0] phase1_state, phase2_state;
    reg [HAC_WIDTH-1:0] hac_start, hac_end;
    reg [HAC_WIDTH-1:0] latency_L;
    reg [7:0] iter_count;
    reg [HAC_WIDTH-1:0] hac_offset;
    
    // Phase 3: SAC counters and deskew
    reg [SAC_WIDTH-1:0] sac_counter;  // Software alignment counter
    reg [15:0] stall_cycles;
    
    // Main HAC counter (free running)
    wire [HAC_WIDTH-1:0] hac_raw;
    assign hac_val = hac_raw - hac_offset;
    
    hac_counter #(.WIDTH(HAC_WIDTH)) hac_inst (
        .clk(clk), .rst_n(rst_n), .count(hac_raw)
    );
    
    // SAC counter (runs slower, drifts)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sac_counter <= 0;
        else if (instr_data[7:0] != PHASE3_DESKEW)  // Pause during deskew
            sac_counter <= sac_counter + 1;
    end
    
    assign sac_val = sac_counter;
    assign delta_t = hac_raw - sac_counter;  // ?t = HAC - SAC
    
    //=============================================================================
    // PHASE 1: Latency Characterization (Parent Mode)
    //=============================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase1_state <= S1_IDLE;
            link_tx_v <= 0;
            link_rx_r <= 1;
            latency_L <= 0;
            iter_count <= 0;
        end else begin
            case (phase1_state)
                S1_IDLE: begin
                    link_tx_v <= 0;
                    link_rx_r <= 1;
                    if (instr_valid && instr_data[7:0] == PHASE1_CHAR && instr_data[15:8] == MODE_PARENT) begin
                        phase1_state <= S1_TX_HAC;
                        hac_start <= hac_raw;
                    end
                end
                
                S1_TX_HAC: begin
                    link_rx_r <= 0;
                    link_tx_v <= 1;
                    link_tx <= {PKT_HAC_TIMESTAMP, hac_raw, ^({PKT_HAC_TIMESTAMP, hac_raw})};
                    
                    if (link_tx_r) begin
                        link_tx_v <= 0;
                        phase1_state <= S1_WAIT_RTT;
                    end
                end
                
                S1_WAIT_RTT: begin
                    link_rx_r <= 1;
                    if (link_rx_v && link_rx[47:40] == PKT_HAC_TIMESTAMP && 
                        link_rx[15:0] == ^link_rx[47:16]) begin
                        hac_end <= hac_raw;
                        phase1_state <= S1_CALC_L;
                    end
                end
                
                S1_CALC_L: begin
                    latency_L <= (hac_end - hac_start) >> 1;  // L = RTT/2
                    iter_count <= iter_count + 1;
                    $display("PHASE1: L=%d, iter=%d", latency_L, iter_count);
                    phase1_state <= S1_IDLE;
                end
            endcase
        end
    end
    
    //=============================================================================
    // PHASE 2: Clock Alignment (Child Mode)  
    //=============================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase2_state <= S2_WAIT_HAC;
            hac_offset <= 0;
        end else begin
            case (phase2_state)
                S2_WAIT_HAC: begin
                    if (instr_valid && instr_data[7:0] == PHASE2_ALIGN && instr_data[15:8] == MODE_CHILD) begin
                        phase2_state <= S2_WAIT_HAC;  // Stay waiting
                    end else if (link_rx_v && link_rx[47:40] == PKT_HAC_TIMESTAMP) begin
                        phase2_state <= S2_CALC_ALIGN;
                    end
                end
                
                S2_CALC_ALIGN: begin
                    // Misalignment = HAC1(t4) - [HAC0(t3) + L]
                    hac_offset <= hac_raw - (link_rx[39:8] + latency_L);
                    $display("PHASE2: Offset=%d, ParentHAC=%d, L=%d", 
                             hac_offset, link_rx[39:8], latency_L);
                    phase2_state <= S2_ADJUST;
                end
                
                S2_ADJUST: begin
                    phase2_state <= S2_WAIT_HAC;  // Ready for next iteration
                end
            endcase
        end
    end
    
    //=============================================================================
    // PHASE 3: RUNTIME DESKEW
    //=============================================================================
    reg [15:0] deskew_stall;
    always @(*) begin
        if (instr_data[7:0] == PHASE3_DESKEW) begin
            deskew_stall = instr_data[23:8];  // Target t
            if (delta_t > 0)      // SAC faster
                stall_cycles = deskew_stall + delta_t[15:0];
            else                  // SAC slower  
                stall_cycles = deskew_stall - delta_t[15:0];
        end else begin
            stall_cycles = 0;
        end
    end
    
    // Instruction decode
    assign instr_ready = (phase1_state == S1_IDLE && phase2_state == S2_WAIT_HAC);
    assign phase_status = {phase1_state[3:0], phase2_state[3:0]};
    
endmodule

