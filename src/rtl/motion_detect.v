`timescale 1ns / 1ps

module motion_detect (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  curr_pixel,
    input  wire [7:0]  prev_pixel,
    input  wire        pixel_valid,
    input  wire [7:0]  motion_threshold,
    input  wire        frame_done,
    output reg         motion_pixel,
    output reg         motion_valid,
    output reg  [13:0] motion_count
);

    reg [13:0] count_acc;
    wire [7:0] diff = (curr_pixel >= prev_pixel) ?
                      (curr_pixel - prev_pixel) :
                      (prev_pixel - curr_pixel);

    always @(posedge clk) begin
        if (rst) begin
            motion_pixel <= 1'b0;
            motion_valid <= 1'b0;
            motion_count <= 14'd0;
            count_acc    <= 14'd0;
        end else begin
            if (pixel_valid) begin
                if (diff > motion_threshold) begin
                    motion_pixel <= 1'b1;
                    count_acc    <= count_acc + 14'd1;
                end else begin
                    motion_pixel <= 1'b0;
                end
                motion_valid <= 1'b1;
            end else begin
                motion_pixel <= 1'b0;
                motion_valid <= 1'b0;
            end

            if (frame_done) begin
                motion_count <= count_acc;
                count_acc    <= 14'd0;
            end
        end
    end

endmodule
