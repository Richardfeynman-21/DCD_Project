`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for top module
//////////////////////////////////////////////////////////////////////////////////

module top_tb;

    reg clk;
    reg rst;
    reg [3:0] sw;
    wire [3:0] led;

    // Instantiate unit under test (UUT)
    top uut (
        .clk(clk),
        .rst(rst),
        .sw(sw),
        .led(led)
    );

    // Clock generator
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        sw = 4'b0000;

        #20;
        rst = 0;
        sw = 4'b1010;

        #20;
        sw = 4'b0101;

        #20;
        rst = 1;

        #20;
        rst = 0;
        sw = 4'b1111;

        #20;
        $finish;
    end

endmodule
