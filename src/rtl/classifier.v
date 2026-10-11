`timescale 1ns / 1ps

module classifier (
    input  wire        clk,
    input  wire        rst,
    input  wire        bbox_valid,
    input  wire [6:0]  width,
    input  wire [6:0]  height,
    input  wire [13:0] pixel_count,
    input  wire [13:0] motion_count,
    input  wire [6:0]  min_width,
    input  wire [6:0]  max_width,
    input  wire [6:0]  min_height,
    input  wire [6:0]  max_height,
    input  wire [13:0] min_area,
    input  wire [7:0]  max_aspect_ratio, // Q4.4 format, e.g., 8'd48 = 3.0
    output reg         is_animal,
    output reg         class_valid
);

    // Rule 1 & 2: Dimension bounds
    wire width_ok  = (width >= min_width) && (width <= max_width);
    wire height_ok = (height >= min_height) && (height <= max_height);

    // Rule 3: Minimum foreground area
    wire area_ok   = (pixel_count >= min_area);

    // Rule 4: Aspect ratio check (both horizontal and vertical elongation bounds)
    // width*16 <= max_aspect_ratio * height  AND  height*16 <= max_aspect_ratio * width
    wire [14:0] aspect_w_lhs = {8'd0, width} * 15'd16;
    wire [14:0] aspect_w_rhs = {7'd0, max_aspect_ratio} * {8'd0, height};
    wire [14:0] aspect_h_lhs = {8'd0, height} * 15'd16;
    wire [14:0] aspect_h_rhs = {7'd0, max_aspect_ratio} * {8'd0, width};

    wire aspect_ok = (width > 7'd0) && (height > 7'd0) &&
                     (aspect_w_lhs <= aspect_w_rhs) &&
                     (aspect_h_lhs <= aspect_h_rhs);

    // Rule 5: Fill ratio check: pixel_count * 4 >= width * height (at least 25% box occupancy)
    wire [15:0] count_x4  = {2'd0, pixel_count} << 2;
    wire [13:0] bbox_area = {7'd0, width} * {7'd0, height};
    wire fill_ok   = (bbox_area > 14'd0) && (count_x4 >= {2'd0, bbox_area});

    always @(posedge clk) begin
        if (rst) begin
            is_animal   <= 1'b0;
            class_valid <= 1'b0;
        end else if (bbox_valid) begin
            is_animal   <= width_ok & height_ok & area_ok & aspect_ok & fill_ok;
            class_valid <= 1'b1;
        end else begin
            class_valid <= 1'b0;
        end
    end

endmodule
