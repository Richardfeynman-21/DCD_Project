`timescale 1ns / 1ps

module line_buffer #(
    parameter WIDTH = 128,
    parameter DEPTH = 8
)(
    input  wire             clk,
    input  wire             rst,
    input  wire [DEPTH-1:0] pixel_in,
    input  wire             pixel_valid,
    output wire [DEPTH-1:0] pixel_out
);
    reg [DEPTH-1:0] buffer [0:WIDTH-1];
    integer i;

    assign pixel_out = buffer[WIDTH-1];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < WIDTH; i = i + 1)
                buffer[i] <= {DEPTH{1'b0}};
        end else if (pixel_valid) begin
            buffer[0] <= pixel_in;
            for (i = 1; i < WIDTH; i = i + 1)
                buffer[i] <= buffer[i-1];
        end
    end
endmodule
