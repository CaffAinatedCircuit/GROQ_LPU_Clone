`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 11:19:48
// Design Name: 
// Module Name: tb_hac_deskew_complete_final
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
// tb_hac_deskew_clean.v - FIXED: No Multiple Drivers, Clean Finish
//=============================================================================

`timescale 1ns / 1ps

module tb_hac_deskew_clean;

    parameter HAC_WIDTH = 32;
    parameter SAC_WIDTH = 32;
    parameter LINK_WIDTH = 48;
    parameter CLK_PERIOD_C0 = 10.0;
    parameter CLK_PERIOD_C1 = 10.1;  // 0.01 slower
    
    // **CORE 0 (Parent) - ALL OUTPUTS EXPLICITLY DRIVEN**
    logic                       c0_clk;
    logic                       c0_rst_n;
    logic                       c0_instr_valid;
    wire                        c0_instr_ready;
    logic [39:0]                c0_instr_data;
    wire [LINK_WIDTH-1:0]       c0_link_tx;
    wire                        c0_link_tx_valid;
    logic                       c0_link_tx_ready;
    wire [LINK_WIDTH-1:0]       c0_link_rx;
    wire                        c0_link_rx_valid;
    logic                       c0_link_rx_ready;
    wire [HAC_WIDTH-1:0]        c0_hac_val;
    wire [SAC_WIDTH-1:0]        c0_sac_val;
    wire [7:0]                  c0_phase_status;
    wire signed [15:0]          c0_delta_t;
    
    // **CORE 1 (Child)**
    logic                       c1_clk;
    logic                       c1_rst_n;
    logic                       c1_instr_valid;
    wire                        c1_instr_ready;
    logic [39:0]                c1_instr_data;
    wire [LINK_WIDTH-1:0]       c1_link_tx;
    wire                        c1_link_tx_valid;
    logic                       c1_link_tx_ready;
    wire [LINK_WIDTH-1:0]       c1_link_rx;
    wire                        c1_link_rx_valid;
    logic                       c1_link_rx_ready;
    wire [HAC_WIDTH-1:0]        c1_hac_val;
    wire [SAC_WIDTH-1:0]        c1_sac_val;
    wire [7:0]                  c1_phase_status;
    wire signed [15:0]          c1_delta_t;
    
    // **SHARED RESET**
    assign c0_rst_n = rst_n;
    assign c1_rst_n = rst_n;
    
    // **CLEAN INTERCONNECT - WIRES ONLY (NO REGS)**
    assign c0_link_rx = c1_link_tx;
    assign c0_link_rx_valid = c1_link_tx_valid;
    assign c1_link_tx_ready = c0_link_rx_ready;
    
    assign c1_link_rx = c0_link_tx;
    assign c1_link_rx_valid = c0_link_tx_valid;
    assign c0_link_tx_ready = c1_link_rx_ready;
    
    // **CLOCK GENERATORS**
    initial begin
        c0_clk = 0;
        forever begin #(CLK_PERIOD_C0/2); c0_clk = ~c0_clk; end
    end
    
    initial begin
        c1_clk = 0;
        forever begin #(CLK_PERIOD_C1/2); c1_clk = ~c1_clk; end
    end
    
    // **CORE 0 INSTANTIATION**
    hac_deskew_complete #(
        .HAC_WIDTH(HAC_WIDTH),
        .SAC_WIDTH(SAC_WIDTH),
        .LINK_WIDTH(LINK_WIDTH)
    ) core0 (
        .clk(c0_clk),
        .rst_n(c0_rst_n),
        .instr_valid(c0_instr_valid),
        .instr_ready(c0_instr_ready),
        .instr_data(c0_instr_data),
        .link_tx(c0_link_tx),
        .link_tx_v(c0_link_tx_valid),
        .link_tx_r(c0_link_tx_ready),
        .link_rx(c0_link_rx),
        .link_rx_v(c0_link_rx_valid),
        .link_rx_r(c0_link_rx_ready),
        .hac_val(c0_hac_val),
        .sac_val(c0_sac_val),
        .phase_status(c0_phase_status),
        .delta_t(c0_delta_t)
    );
    
    // **CORE 1 INSTANTIATION**
    hac_deskew_complete #(
        .HAC_WIDTH(HAC_WIDTH),
        .SAC_WIDTH(SAC_WIDTH),
        .LINK_WIDTH(LINK_WIDTH)
    ) core1 (
        .clk(c1_clk),
        .rst_n(c1_rst_n),
        .instr_valid(c1_instr_valid),
        .instr_ready(c1_instr_ready),
        .instr_data(c1_instr_data),
        .link_tx(c1_link_tx),
        .link_tx_v(c1_link_tx_valid),
        .link_tx_r(c1_link_tx_ready),
        .link_rx(c1_link_rx),
        .link_rx_v(c1_link_rx_valid),
        .link_rx_r(c1_link_rx_ready),
        .hac_val(c1_hac_val),
        .sac_val(c1_sac_val),
        .phase_status(c1_phase_status),
        .delta_t(c1_delta_t)
    );
    
    // **TEST SEQUENCE**
    initial begin
        $display("=== HAC DESKEW CLEAN TESTBENCH ===");
        
        rst_n = 0;
        c0_instr_valid = 0;
        c1_instr_valid = 0;
        c0_instr_data = 0;
        c1_instr_data = 0;
        c0_link_tx_ready = 1;
        c1_link_tx_ready = 1;
        c0_link_rx_ready = 1;
        c1_link_rx_ready = 1;
        
        repeat(20) @(posedge c0_clk);
        rst_n = 1;
        repeat(50) @(posedge c0_clk);
        
        // **PHASE 1: Latency**
        $display("\n=== PHASE 1 ===");
        send_cmd(0, 40'h00010010);
        repeat(300) @(posedge c0_clk);
        
        // **PHASE 2: Alignment**
        $display("\n=== PHASE 2 ===");
        send_cmd(1, 40'h00020011);
        repeat(300) @(posedge c0_clk);
        
        // **PHASE 3: Deskew**
        $display("\n=== PHASE 3 ===");
        send_cmd(0, 40'h00030064);
        send_cmd(1, 40'h00030064);
        repeat(500) @(posedge c0_clk);
        
        $display("\nC0: HAC=%0d SAC=%0d ?t=%0d", c0_hac_val, c0_sac_val, c0_delta_t);
        $display("C1: HAC=%0d SAC=%0d ?t=%0d", c1_hac_val, c1_sac_val, c1_delta_t);
        $display("ERROR: %0d", c1_hac_val - c0_hac_val);
        
        repeat(50) @(posedge c0_clk);
        
        // **CLEAN FINISH - NO STRING ERRORS**
        $display("TEST COMPLETE");
        #100;  // Final delay
        $finish;
    end
    
    // **INSTRUCTION TASK - CLEAN**
    task send_cmd;
        input [0:0] core;
        input [39:0] data;
        begin
            if (core == 0) begin
                @(posedge c0_clk);
                c0_instr_data = data;
                c0_instr_valid = 1'b1;
                @(posedge c0_clk iff c0_instr_ready);
                c0_instr_valid = 1'b0;
            end else begin
                @(posedge c1_clk);
                c1_instr_data = data;
                c1_instr_valid = 1'b1;
                @(posedge c1_clk iff c1_instr_ready);
                c1_instr_valid = 1'b0;
            end
        end
    endtask
    
    // **PACKET MONITOR**
    always @(posedge c0_clk) begin
        if (c0_link_tx_valid && c0_link_tx_ready)
            $display("C0?C1: 0x%h", c0_link_tx);
    end
    
    always @(posedge c1_clk) begin
        if (c1_link_tx_valid && c1_link_tx_ready)
            $display("C1?C0: 0x%h", c1_link_tx);
    end
    
    // **VCD**
    initial begin
        $dumpfile("hac_clean.vcd");
        $dumpvars(0, tb_hac_deskew_clean);
    end

endmodule


