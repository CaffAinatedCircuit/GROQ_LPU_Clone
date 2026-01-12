`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.01.2026 10:38:02
// Design Name: 
// Module Name: hac_counter
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
// COMPLETE HAC Deskew Testbench v2 - Tests ALL 3 Phases
// Dual-Core Setup: Core0(Parent) <-> Core1(Child)
//=============================================================================
module hac_counter #(
    parameter WIDTH = 32,
    parameter INIT_VAL = 32'd1000
)(
    input  wire        clk,
    input  wire        rst_n,
    output wire [WIDTH-1:0] count
);
    reg [WIDTH-1:0] count_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) count_reg <= INIT_VAL;
        else count_reg <= count_reg + 1;
    end
    assign count = count_reg;
endmodule