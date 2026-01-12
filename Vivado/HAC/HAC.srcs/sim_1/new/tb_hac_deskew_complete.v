// tb_hac_deskew_complete.v - COMPLETE TESTBENCH WITH DIFFERENT INITIALS
`timescale 1ns / 1ps

module tb_hac_deskew_complete;

    parameter HAC_WIDTH = 32, SAC_WIDTH = 32, LINK_WIDTH = 48;
    parameter CLK_PERIOD_C0 = 10.000;  // 100MHz
    parameter CLK_PERIOD_C1 = 10.001;  // 99.99MHz drift
    
    // **TB OPCODES**
    localparam [7:0] PHASE1_CHAR  = 8'h01;
    localparam [7:0] PHASE2_ALIGN = 8'h02;
    localparam [7:0] PHASE3_DESKEW= 8'h03;
    localparam [7:0] MODE_PARENT  = 8'h10;
    localparam [7:0] MODE_CHILD   = 8'h11;
    
    logic rst_n, c0_clk, c1_clk;
    
    // **CORE 0 (PARENT) - STARTS AT 1000**
    logic c0_instr_valid; wire c0_instr_ready;
    logic [39:0] c0_instr_data;
    wire [LINK_WIDTH-1:0] c0_link_tx; wire c0_link_tx_v;
    wire [LINK_WIDTH-1:0] c0_link_rx; wire c0_link_rx_v;
    logic c0_link_tx_r = 1'b1, c0_link_rx_r = 1'b1;
    wire [HAC_WIDTH-1:0] c0_hac_val, c0_sac_val;
    
    // **CORE 1 (CHILD) - STARTS AT 1750**
    logic c1_instr_valid; wire c1_instr_ready;
    logic [39:0] c1_instr_data;
    wire [LINK_WIDTH-1:0] c1_link_tx; wire c1_link_tx_v;
    wire [LINK_WIDTH-1:0] c1_link_rx; wire c1_link_rx_v;
    logic c1_link_tx_r = 1'b1, c1_link_rx_r = 1'b1;
    wire [HAC_WIDTH-1:0] c1_hac_val, c1_sac_val;
    
    // **INTERCONNECT**
    assign c0_link_rx = c1_link_tx;
    assign c0_link_rx_v = c1_link_tx_v;
    assign c1_link_rx = c0_link_tx;
    assign c1_link_rx_v = c0_link_tx_v;
    
    // **CLOCKS**
    initial begin c0_clk = 0; forever #(CLK_PERIOD_C0/2) c0_clk = ~c0_clk; end
    initial begin c1_clk = 0; forever #(CLK_PERIOD_C1/2) c1_clk = ~c1_clk; end
    
    // **CORE INSTANCES - DIFFERENT INITIAL VALUES!**
    hac_deskew_dut #(.INIT_VAL(32'd1000)) core0 (  // C0 starts at 1000
        .clk(c0_clk), .rst_n(rst_n),
        .instr_valid(c0_instr_valid), .instr_ready(c0_instr_ready),
        .instr_data(c0_instr_data),
        .link_tx(c0_link_tx), .link_tx_v(c0_link_tx_v),
        .link_tx_r(c0_link_tx_r), .link_rx(c0_link_rx),
        .link_rx_v(c0_link_rx_v), .link_rx_r(c0_link_rx_r),
        .hac_val(c0_hac_val), .sac_val(c0_sac_val)
    );
    
    hac_deskew_dut #(.INIT_VAL(32'd1750)) core1 (  // C1 starts at 1750 ?
        .clk(c1_clk), .rst_n(rst_n),
        .instr_valid(c1_instr_valid), .instr_ready(c1_instr_ready),
        .instr_data(c1_instr_data),
        .link_tx(c1_link_tx), .link_tx_v(c1_link_tx_v),
        .link_tx_r(c1_link_tx_r), .link_rx(c1_link_rx),
        .link_rx_v(c1_link_rx_v), .link_rx_r(c1_link_rx_r),
        .hac_val(c1_hac_val), .sac_val(c1_sac_val)
    );
    
    // **LIVE MONITORING**
    always @(posedge c0_clk) begin
        if ($time/1000 % 320 == 0)
            $display("[T=%0t] C0=%6d C1=%6d ?=%4d", 
                     $time/1ns, c0_hac_val, c1_hac_val, c1_hac_val-c0_hac_val);
    end
    
    // **TEST SEQUENCE**
    initial begin
        $display("=== HAC DESKEW - C0=1000 C1=1750 (?750) + 0.01%% DRIFT ===");
        
        // **RESET**
        rst_n = 0; c0_instr_valid = 0; c1_instr_valid = 0;
        repeat(20) @(posedge c0_clk);
        rst_n = 1; repeat(50) @(posedge c0_clk);
        
        // **PHASE 1: PARENT LATENCY (5x)**
        $display("\n=== PHASE 1: C0 PARENT LATENCY x5 ===");
        repeat(5) begin
            // **FORMAT: {pad[39:32], mode[31:24], opc[23:16], arg[15:0]}**
            send_instr(0, {8'h00, MODE_PARENT, PHASE1_CHAR, 16'h0000});
            repeat(250) @(posedge c0_clk);
        end
        
        // **PHASE 2: CHILD ALIGNMENT**
        $display("\n=== PHASE 2: C1 CHILD ALIGNMENT ===");
        repeat(100) @(posedge c0_clk);
        send_instr(0, {8'h00, MODE_PARENT, PHASE1_CHAR, 16'h0000});  // Trigger HAC
        repeat(50) @(posedge c0_clk);
        send_instr(1, {8'h00, MODE_CHILD, PHASE2_ALIGN, 16'h0000});
        repeat(400) @(posedge c0_clk);
        
        // **PHASE 3: RUNTIME DESKEW**
        $display("\n=== PHASE 3: DESKEW t=100 ===");
        send_instr(0, {16'h0064, PHASE3_DESKEW, 16'h0000});
        send_instr(1, {16'h0064, PHASE3_DESKEW, 16'h0000});
        repeat(800) @(posedge c0_clk);
        
        $display("\n=== FINAL RESULTS ===");
        $display("C0: HAC=%0d SAC=%0d", c0_hac_val, c0_sac_val);
        $display("C1: HAC=%0d SAC=%0d", c1_hac_val, c1_sac_val);
        $display("ALIGNMENT ERROR: %0d cycles", c1_hac_val - c0_hac_val);
        repeat(50) @(posedge c0_clk);
        $finish;
    end
    
    // **SEND INSTRUCTION**
    task send_instr(input [0:0] core, input [39:0] instr);
        if (core == 0) begin
            @(posedge c0_clk);
            c0_instr_data = instr; c0_instr_valid = 1'b1;
            wait(c0_instr_ready === 1'b1);
            @(posedge c0_clk); c0_instr_valid = 1'b0;
            $display("T=%0t C0 INSTR=0x%h [opc=0x%02h,mode=0x%02h]", 
                     $time/1ns, instr, instr[23:16], instr[31:24]);
        end else begin
            @(posedge c1_clk);
            c1_instr_data = instr; c1_instr_valid = 1'b1;
            wait(c1_instr_ready === 1'b1);
            @(posedge c1_clk); c1_instr_valid = 1'b0;
            $display("T=%0t C1 INSTR=0x%h [opc=0x%02h,mode=0x%02h]", 
                     $time/1ns, instr, instr[23:16], instr[31:24]);
        end
    endtask
    
    // **PACKET MONITORING**
    always @(posedge c0_clk) if (c0_link_tx_v)
        $display("*** C0?C1 TX *** Type=0x%02h HAC=%0d", c0_link_tx[47:40], c0_link_tx[39:8]);
    
    always @(posedge c1_clk) if (c1_link_tx_v)
        $display("*** C1?C0 TX *** Type=0x%02h HAC=%0d", c1_link_tx[47:40], c1_link_tx[39:8]);
    
    initial begin
        $dumpfile("hac_complete.vcd");
        $dumpvars(0, tb_hac_deskew_complete);
    end

endmodule
