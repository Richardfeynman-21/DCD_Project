`timescale 1ns / 1ps

module line_buffer #(
    parameter WIDTH = 128,
    parameter DEPTH = 8
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [DEPTH-1:0] pixel_in,
    input  wire             pixel_valid,
    output reg  [DEPTH-1:0] pixel_out
);
    reg [DEPTH-1:0] buffer [0:WIDTH-2];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            pixel_out <= {DEPTH{1'b0}};
            for (i = 0; i < WIDTH-1; i = i + 1)
                buffer[i] <= {DEPTH{1'b0}};
        end else if (pixel_valid) begin
            buffer[0] <= pixel_in;
            for (i = 1; i < WIDTH-1; i = i + 1)
                buffer[i] <= buffer[i-1];
            pixel_out <= buffer[WIDTH-2];
        end
    end
endmodule
