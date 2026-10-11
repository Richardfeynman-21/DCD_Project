`timescale 1ns / 1ps

module sobel_edge_detect (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  pixel_in,
    input  wire        pixel_valid,
    input  wire [7:0]  edge_threshold,
    output reg         edge_pixel,
    output reg         edge_valid,
    output reg  [15:0] edge_magnitude
);

    wire [7:0] lb0_out;
    wire [7:0] lb1_out;

    // Line buffer 1 stores the previous line (128 pixels)
    line_buffer #(.WIDTH(128), .DEPTH(8)) lb1_inst (
        .clk(clk),
        .rst(rst),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .pixel_out(lb1_out)
    );

    // Line buffer 0 stores the line before previous (128 pixels)
    line_buffer #(.WIDTH(128), .DEPTH(8)) lb0_inst (
        .clk(clk),
        .rst(rst),
        .pixel_in(lb1_out),
        .pixel_valid(pixel_valid),
        .pixel_out(lb0_out)
    );

    // 3x3 Window Registers
    reg [7:0] p00, p01, p02;
    reg [7:0] p10, p11, p12;
    reg [7:0] p20, p21, p22;

    // Valid pipeline tracker
    reg [2:0] valid_pipe;

    always @(posedge clk) begin
        if (rst) begin
            p00 <= 8'd0; p01 <= 8'd0; p02 <= 8'd0;
            p10 <= 8'd0; p11 <= 8'd0; p12 <= 8'd0;
            p20 <= 8'd0; p21 <= 8'd0; p22 <= 8'd0;
            valid_pipe <= 3'b000;
        end else if (pixel_valid) begin
            // Shift columns
            p02 <= p01; p01 <= p00; p00 <= lb0_out;
            p12 <= p11; p11 <= p10; p10 <= lb1_out;
            p22 <= p21; p21 <= p20; p20 <= pixel_in;
            valid_pipe <= {valid_pipe[1:0], pixel_valid};
        end else begin
            valid_pipe <= {valid_pipe[1:0], 1'b0};
        end
    end

    // Pipeline Stage 1: Parallel Gx and Gy computation
    reg signed [11:0] gx;
    reg signed [11:0] gy;

    always @(posedge clk) begin
        if (rst) begin
            gx <= 12'sd0;
            gy <= 12'sd0;
        end else begin
            // Gx = (p02 + 2*p12 + p22) - (p00 + 2*p10 + p20)
            gx <= ($signed({4'd0, p02}) + ($signed({4'd0, p12}) <<< 1) + $signed({4'd0, p22})) -
                  ($signed({4'd0, p00}) + ($signed({4'd0, p10}) <<< 1) + $signed({4'd0, p20}));

            // Gy = (p20 + 2*p21 + p22) - (p00 + 2*p01 + p02)
            gy <= ($signed({4'd0, p20}) + ($signed({4'd0, p21}) <<< 1) + $signed({4'd0, p22})) -
                  ($signed({4'd0, p00}) + ($signed({4'd0, p01}) <<< 1) + $signed({4'd0, p02}));
        end
    end

    // Pipeline Stage 2: Manhattan Gradient Magnitude (|Gx| + |Gy|) and Thresholding
    wire [11:0] abs_gx = (gx < 0) ? -gx : gx;
    wire [11:0] abs_gy = (gy < 0) ? -gy : gy;
    wire [12:0] grad_sum = abs_gx + abs_gy;

    always @(posedge clk) begin
        if (rst) begin
            edge_magnitude <= 16'd0;
            edge_pixel     <= 1'b0;
            edge_valid     <= 1'b0;
        end else begin
            edge_magnitude <= {3'd0, grad_sum};
            edge_pixel     <= (grad_sum > {5'd0, edge_threshold}) ? 1'b1 : 1'b0;
            edge_valid     <= valid_pipe[2];
        end
    end

endmodule
