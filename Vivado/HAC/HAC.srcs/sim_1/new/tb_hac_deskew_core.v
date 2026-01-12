`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 10:19:25
// Design Name: 
// Module Name: tb_hac_deskew_core
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
// HAC Deskew Core Testbench - Vivado Simulation
// Tests Dual-Core Parent/Child Latency Characterization & Alignment
//=============================================================================

`timescale 1ns / 1ps

module tb_hac_deskew_core;

    // Testbench Parameters
    parameter HAC_WIDTH = 32;
    parameter LINK_DATA_WIDTH = HAC_WIDTH + 8;
    parameter CLK_PERIOD = 10.0;  // 100MHz
    
    // DUT Signals
    logic clk, rst_n;
    logic instr_valid, instr_ready;
    logic [31:0] instr_data;
    
    // Core 0 (Left/Right Links)
    logic [LINK_DATA_WIDTH-1:0] c0_left_tx_data, c0_left_rx_data;
    logic c0_left_tx_valid, c0_left_tx_ready;
    logic c0_left_rx_valid, c0_left_rx_ready;
    
    logic [LINK_DATA_WIDTH-1:0] c0_right_tx_data, c0_right_rx_data;
    logic c0_right_tx_valid, c0_right_tx_ready;
    logic c0_right_rx_valid, c0_right_rx_ready;
    
    logic [HAC_WIDTH-1:0] c0_hac_current;
    logic [7:0] c0_state_left, c0_state_right;
    
    // Core 1 Signals (Symmetric)
    logic [LINK_DATA_WIDTH-1:0] c1_right_tx_data, c1_right_rx_data;
    logic c1_right_tx_valid, c1_right_tx_ready;
    logic c1_right_rx_valid, c1_right_rx_ready;
    
    logic [HAC_WIDTH-1:0] c1_hac_current;
    logic [7:0] c1_state_right;
    
    // Wire connections between cores (Core0 Right <-> Core1 Right)
    assign c0_right_rx_data   = c1_right_tx_data;
    assign c0_right_rx_valid  = c1_right_tx_valid;
    assign c1_right_tx_ready  = c0_right_tx_ready;
    
    assign c1_right_rx_data   = c0_right_tx_data;
    assign c1_right_rx_valid  = c0_right_tx_valid;
    assign c0_right_tx_ready  = c1_right_tx_ready;
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT Instantiations
    hac_deskew_core #(
        .HAC_WIDTH(HAC_WIDTH),
        .LINK_DATA_WIDTH(LINK_DATA_WIDTH)
    ) core0 (
        .clk(clk),
        .rst_n(rst_n),
        .instr_valid(instr_valid),
        .instr_ready(instr_ready),
        .instr_data(instr_data),
        // Left link (open for future multi-link testing)
        .left_tx_data(c0_left_tx_data),
        .left_tx_valid(c0_left_tx_valid),
        .left_tx_ready(c0_left_tx_ready),
        .left_rx_data(c0_left_rx_data),
        .left_rx_valid(c0_left_rx_valid),
        .left_rx_ready(c0_left_rx_ready),
        // Right link (connected to Core1)
        .right_tx_data(c0_right_tx_data),
        .right_tx_valid(c0_right_tx_valid),
        .right_tx_ready(c0_right_tx_ready),
        .right_rx_data(c0_right_rx_data),
        .right_rx_valid(c0_right_rx_valid),
        .right_rx_ready(c0_right_rx_ready),
        .hac_current(c0_hac_current),
        .state_left(c0_state_left),
        .state_right(c0_state_right)
    );
    
    hac_deskew_core #(
        .HAC_WIDTH(HAC_WIDTH),
        .LINK_DATA_WIDTH(LINK_DATA_WIDTH)
    ) core1 (
        .clk(clk),
        .rst_n(rst_n),
        .instr_valid(1'b0),  // Core1 only responds (child mode auto)
        .instr_ready(),
        .instr_data(32'h0),
        // Left link unused
        .left_tx_data(),
        .left_tx_valid(),
        .left_tx_ready(1'b1),
        .left_rx_data(1'b0),
        .left_rx_valid(1'b0),
        .left_rx_ready(),
        // Right link (connected to Core0)
        .right_tx_data(c1_right_tx_data),
        .right_tx_valid(c1_right_tx_valid),
        .right_tx_ready(c1_right_tx_ready),
        .right_rx_data(c1_right_rx_data),
        .right_rx_valid(c1_right_rx_valid),
        .right_rx_ready(c1_right_rx_ready),
        .hac_current(c1_hac_current),
        .state_left(),
        .state_right(c1_state_right)
    );
    
    //=============================================================================
    // Test Sequence
    //=============================================================================
    initial begin
        // Initialize
        rst_n = 0;
        instr_valid = 0;
        instr_data = 0;
        
        c0_left_tx_ready = 1'b1;  // Accept all for now
        c0_left_rx_valid = 1'b0;
        c0_left_rx_data = 0;
        
        $display("HAC Deskew Testbench Starting...");
        $display("Core0 (Parent) <--> Core1 (Child) via Right Links");
        $display("============================================");
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(20) @(posedge clk);
        
        // TEST 1: Core0 as Parent (Right link)
        $display("\n=== TEST 1: Core0 PARENT MODE (Right Link) ===");
        issue_instruction(8'h20);  // OPCODE_PARENT_R
        repeat(100) @(posedge clk);
        
        // TEST 2: Verify Latency Calculation (should see ~10 cycles RTT)
        $display("\n=== TEST 2: Latency Check ===");
        repeat(50) @(posedge clk);
        
        // TEST 3: Core0 Init (triggers full characterization)
        $display("\n=== TEST 3: INIT Characterization ===");
        issue_instruction(8'h01);  // OPCODE_INIT
        repeat(200) @(posedge clk);
        
        // Monitor Results
        $display("\n=== FINAL STATES ===");
        $display("Core0 HAC: %0d, StateL: 0x%02h, StateR: 0x%02h", c0_hac_current, c0_state_left, c0_state_right);
        $display("Core1 HAC: %0d, StateR: 0x%02h", c1_hac_current, c1_state_right);
        $display("HAC Delta: %0d cycles", $signed(c1_hac_current - c0_hac_current));
        
        repeat(50) @(posedge clk);
        $finish;
    end
    
    // Instruction Helper Task
    task issue_instruction(input [7:0] opcode);
        begin
            @(posedge clk);
            instr_data = {24'h0, opcode};
            instr_valid = 1'b1;
            @(posedge clk);
            while (!instr_ready) @(posedge clk);
            instr_valid = 1'b0;
            $display("Issued instr: 0x%08h", instr_data);
        end
    endtask
    
    //=============================================================================
    // Monitoring and Waveform Dumps
    //=============================================================================
    initial begin
        $dumpfile("hac_deskew_tb.vcd");
        $dumpvars(0, tb_hac_deskew_core);
        
        // Continuous monitoring
        forever begin
            @(posedge clk);
            if (c0_right_tx_valid || c1_right_tx_valid) begin
                if (c0_right_tx_valid && c0_right_tx_ready)
                    $display("T+%0t Core0 TX: %h (valid=%b)", $time, c0_right_tx_data, c0_right_tx_valid);
                if (c1_right_tx_valid && c1_right_tx_ready)
                    $display("T+%0t Core1 TX: %h (valid=%b)", $time, c1_right_tx_data, c1_right_tx_valid);
            end
            
            // Detect alignment completion
            if (c0_state_right == 8'h00 && c1_state_right == 8'h00 && c0_hac_current > 100) begin
                $display("*** ALIGNMENT COMPLETE ***");
                $display("Core0: %0d, Core1: %0d, Error: %0d cycles", 
                         c0_hac_current, c1_hac_current, c1_hac_current - c0_hac_current);
            end
        end
    end
    
    // Timeout safety
    initial begin
        #10000;
        $display("*** TESTBENCH TIMEOUT ***");
        $finish;
    end

endmodule
