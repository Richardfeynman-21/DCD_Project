`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/09/2026
// Design Name: DCD_Project
// Module Name: top
// Project Name: DCD_Project
// Target Devices: Artix-7 (xc7a35tcpg236-1)
// Tool Versions: Vivado 2026.1
// Description: Top-level module for DCD Project
// 
//////////////////////////////////////////////////////////////////////////////////

module top (
    input  wire clk,
    input  wire rst,
    input  wire [3:0] sw,
    output wire [3:0] led
);

    // Simple pass-through / example logic
    assign led = rst ? 4'b0000 : sw;

endmodule
