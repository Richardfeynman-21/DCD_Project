`timescale 1ns / 1ps

module top #(
    parameter FRAME_WIDTH   = 128,
    parameter FRAME_HEIGHT  = 72,
    parameter TOTAL_PIXELS  = 9216,
    parameter PIPE_DEPTH    = 136 // 133 to fusion + 2 to shadow output + 1 buffer
)(
    input  wire        clk,
    input  wire        rst,

    // Video stream input interface
    input  wire        load_en,
    input  wire [7:0]  pixel_in,
    input  wire [13:0] pixel_addr,

    // Runtime configuration thresholds
    input  wire [1:0]  fusion_mode,       // 00: Motion silhouette, 01: Edge AND Motion, 10: OR
    input  wire [7:0]  motion_threshold,
    input  wire [7:0]  edge_threshold,
    input  wire [2:0]  persist_thresh,
    input  wire [6:0]  min_width,
    input  wire [6:0]  max_width,
    input  wire [6:0]  min_height,
    input  wire [6:0]  max_height,
    input  wire [13:0] min_area,
    input  wire [7:0]  max_aspect_ratio,

    // Status and detection outputs
    output wire        frame_ready,
    output reg         process_busy,
    output wire        motion_alert,
    output wire        animal_alert,
    output wire [6:0]  x_min,
    output wire [6:0]  x_max,
    output wire [6:0]  y_min,
    output wire [6:0]  y_max,
    output wire [6:0]  centroid_x,
    output wire [6:0]  centroid_y,
    output wire [13:0] pixel_count,
    output wire        bbox_valid
);

    // =========================================================================
    // 1. Frame Memory Instance (Dual Ping-Pong BRAM Buffer)
    // =========================================================================
    reg  [13:0] rd_addr;
    wire [7:0]  curr_pixel;
    wire [7:0]  prev_pixel;

    frame_memory #(.TOTAL_PIXELS(TOTAL_PIXELS)) mem_inst (
        .clk(clk),
        .rst(rst),
        .load_en(load_en),
        .pixel_in(pixel_in),
        .pixel_addr(pixel_addr),
        .frame_ready(frame_ready),
        .curr_pixel(curr_pixel),
        .prev_pixel(prev_pixel),
        .rd_addr(rd_addr)
    );

    // =========================================================================
    // 2. Raster Scan Generator and Address Pipeline
    // =========================================================================
    localparam S_IDLE       = 2'd0;
    localparam S_SCAN       = 2'd1;
    localparam S_DRAIN      = 2'd2;
    localparam S_WAIT_CLASS = 2'd3;

    reg [1:0]  scan_state;
    reg [6:0]  scan_x;
    reg [6:0]  scan_y;
    reg [8:0]  drain_count;
    reg        scan_valid;
    reg        frame_done_pulse;

    // Delayed scan signals to match BRAM 1-cycle latency
    reg        rd_valid_d1;
    reg [13:0] rd_addr_d1;
    reg [6:0]  scan_x_d1;
    reg [6:0]  scan_y_d1;

    wire class_valid; // Forward declaration from classifier

    always @(posedge clk) begin
        if (rst) begin
            scan_state       <= S_IDLE;
            rd_addr          <= 14'd0;
            scan_x           <= 7'd0;
            scan_y           <= 7'd0;
            drain_count      <= 9'd0;
            scan_valid       <= 1'b0;
            process_busy     <= 1'b0;
            frame_done_pulse <= 1'b0;
            rd_valid_d1      <= 1'b0;
            rd_addr_d1       <= 14'd0;
            scan_x_d1        <= 7'd0;
            scan_y_d1        <= 7'd0;
        end else begin
            rd_valid_d1      <= scan_valid;
            rd_addr_d1       <= rd_addr;
            scan_x_d1        <= scan_x;
            scan_y_d1        <= scan_y;
            frame_done_pulse <= 1'b0;

            case (scan_state)
                S_IDLE: begin
                    if (frame_ready) begin
                        scan_state   <= S_SCAN;
                        rd_addr      <= 14'd0;
                        scan_x       <= 7'd0;
                        scan_y       <= 7'd0;
                        scan_valid   <= 1'b1;
                        process_busy <= 1'b1;
                    end
                end

                S_SCAN: begin
                    if (rd_addr == TOTAL_PIXELS - 1) begin
                        scan_valid  <= 1'b0;
                        scan_state  <= S_DRAIN;
                        drain_count <= PIPE_DEPTH;
                    end else begin
                        rd_addr <= rd_addr + 14'd1;
                        if (scan_x == FRAME_WIDTH - 1) begin
                            scan_x <= 7'd0;
                            scan_y <= scan_y + 7'd1;
                        end else begin
                            scan_x <= scan_x + 7'd1;
                        end
                    end
                end

                S_DRAIN: begin
                    if (drain_count == 9'd0) begin
                        frame_done_pulse <= 1'b1;
                        scan_state       <= S_WAIT_CLASS;
                    end else begin
                        drain_count <= drain_count - 9'd1;
                    end
                end

                S_WAIT_CLASS: begin
                    if (class_valid) begin
                        process_busy <= 1'b0;
                        scan_state   <= S_IDLE;
                    end
                end

                default: scan_state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // 3. Multi-Tap Coordinate Pipeline Shift Register
    // =========================================================================
    reg [13:0] addr_shift [0:PIPE_DEPTH-1];
    reg [6:0]  x_shift    [0:PIPE_DEPTH-1];
    reg [6:0]  y_shift    [0:PIPE_DEPTH-1];
    integer p;

    reg [13:0] shadow_addr;
    reg [6:0]  bbox_x;
    reg [6:0]  bbox_y;

    always @(posedge clk) begin
        if (rst) begin
            shadow_addr <= 14'd0;
            bbox_x      <= 7'd0;
            bbox_y      <= 7'd0;
            for (p = 0; p < PIPE_DEPTH; p = p + 1) begin
                addr_shift[p] <= 14'd0;
                x_shift[p]    <= 7'd0;
                y_shift[p]    <= 7'd0;
            end
        end else begin
            addr_shift[0] <= rd_addr_d1;
            x_shift[0]    <= scan_x_d1;
            y_shift[0]    <= scan_y_d1;
            for (p = 1; p < PIPE_DEPTH; p = p + 1) begin
                addr_shift[p] <= addr_shift[p-1];
                x_shift[p]    <= x_shift[p-1];
                y_shift[p]    <= y_shift[p-1];
            end
            // Synchronous taps: 132-cycle latency for shadow_suppress, 133-cycle for bbox_centroid
            shadow_addr <= addr_shift[131];
            bbox_x      <= x_shift[132];
            bbox_y      <= y_shift[132];
        end
    end

    // =========================================================================
    // 4. Sobel Edge Detection (Novelty #1: Parallel Pipelined 3x3 Filter)
    // =========================================================================
    wire        edge_pixel;
    wire        edge_valid;
    wire [15:0] edge_magnitude;

    sobel_edge_detect sobel_inst (
        .clk(clk),
        .rst(rst),
        .pixel_in(curr_pixel),
        .pixel_valid(rd_valid_d1),
        .edge_threshold(edge_threshold),
        .edge_pixel(edge_pixel),
        .edge_valid(edge_valid),
        .edge_magnitude(edge_magnitude)
    );

    // =========================================================================
    // 5. Motion Detection (Frame Differencing Engine)
    // =========================================================================
    wire        motion_pixel;
    wire        motion_valid;
    wire [13:0] motion_count;

    motion_detect motion_inst (
        .clk(clk),
        .rst(rst),
        .curr_pixel(curr_pixel),
        .prev_pixel(prev_pixel),
        .pixel_valid(rd_valid_d1),
        .motion_threshold(motion_threshold),
        .frame_done(frame_done_pulse),
        .motion_pixel(motion_pixel),
        .motion_valid(motion_valid),
        .motion_count(motion_count)
    );

    // =========================================================================
    // 6. Fusion Module (Edge + Motion Merge with Delay Compensation)
    // =========================================================================
    wire fused_pixel;
    wire fused_valid;

    fusion #(.DELAY_CYCLES(130)) fusion_inst (
        .clk(clk),
        .rst(rst),
        .mode_sel(fusion_mode),
        .edge_pixel(edge_pixel),
        .motion_pixel(motion_pixel),
        .edge_valid(edge_valid),
        .motion_valid(motion_valid),
        .fused_pixel(fused_pixel),
        .fused_valid(fused_valid)
    );

    // =========================================================================
    // 7. Shadow and Noise Suppression (Novelty #2: BRAM Persistence Filter)
    // =========================================================================
    wire stable_pixel;
    wire stable_valid;

    shadow_suppress #(.TOTAL_PIXELS(TOTAL_PIXELS)) shadow_inst (
        .clk(clk),
        .rst(rst),
        .fused_pixel(fused_pixel),
        .pixel_addr(shadow_addr),
        .pixel_valid(fused_valid),
        .frame_done(frame_done_pulse),
        .persist_thresh(persist_thresh),
        .stable_pixel(stable_pixel),
        .stable_valid(stable_valid)
    );

    // =========================================================================
    // 8. Bounding Box and Centroid Extraction (Novelty #3: Localization)
    // =========================================================================
    bbox_centroid bbox_inst (
        .clk(clk),
        .rst(rst),
        .stable_pixel(stable_pixel),
        .pixel_x(bbox_x),
        .pixel_y(bbox_y),
        .pixel_valid(stable_valid),
        .frame_done(frame_done_pulse),
        .x_min(x_min),
        .x_max(x_max),
        .y_min(y_min),
        .y_max(y_max),
        .centroid_x(centroid_x),
        .centroid_y(centroid_y),
        .pixel_count(pixel_count),
        .bbox_valid(bbox_valid)
    );

    // =========================================================================
    // 9. Lightweight Rule-Based Classifier (Novelty #4: Multi-Feature Decision)
    // =========================================================================
    wire [6:0] bbox_w = (pixel_count > 14'd0 && x_max >= x_min) ? (x_max - x_min + 7'd1) : 7'd0;
    wire [6:0] bbox_h = (pixel_count > 14'd0 && y_max >= y_min) ? (y_max - y_min + 7'd1) : 7'd0;
    wire       is_animal;

    classifier classifier_inst (
        .clk(clk),
        .rst(rst),
        .bbox_valid(bbox_valid),
        .width(bbox_w),
        .height(bbox_h),
        .pixel_count(pixel_count),
        .motion_count(motion_count),
        .min_width(min_width),
        .max_width(max_width),
        .min_height(min_height),
        .max_height(max_height),
        .min_area(min_area),
        .max_aspect_ratio(max_aspect_ratio),
        .is_animal(is_animal),
        .class_valid(class_valid)
    );

    // =========================================================================
    // 10. Control Logic / Alert Generation
    // =========================================================================
    wire motion_detected = (motion_count > 14'd0);

    control_logic control_inst (
        .clk(clk),
        .rst(rst),
        .motion_detected(motion_detected),
        .is_animal(is_animal),
        .class_valid(class_valid),
        .motion_alert(motion_alert),
        .animal_alert(animal_alert)
    );

endmodule
