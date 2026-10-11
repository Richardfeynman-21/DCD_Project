`timescale 1ns / 1ps

module bbox_centroid (
    input  wire        clk,
    input  wire        rst,
    input  wire        stable_pixel,
    input  wire [6:0]  pixel_x,
    input  wire [6:0]  pixel_y,
    input  wire        pixel_valid,
    input  wire        frame_done,
    output reg  [6:0]  x_min,
    output reg  [6:0]  x_max,
    output reg  [6:0]  y_min,
    output reg  [6:0]  y_max,
    output reg  [6:0]  centroid_x,
    output reg  [6:0]  centroid_y,
    output reg  [13:0] pixel_count,
    output reg         bbox_valid
);

    reg [20:0] sum_x, sum_y;
    reg [13:0] count;
    reg [6:0]  xmin_acc, xmax_acc, ymin_acc, ymax_acc;

    wire [20:0] quot_x, quot_y;
    wire        div_done_x, div_done_y;
    reg         div_start;

    // Divider instances for centroid X and Y
    divider #(.WIDTH_N(21), .WIDTH_D(14)) div_x_inst (
        .clk(clk),
        .rst(rst),
        .start(div_start),
        .dividend(sum_x),
        .divisor(count),
        .quotient(quot_x),
        .done(div_done_x)
    );

    divider #(.WIDTH_N(21), .WIDTH_D(14)) div_y_inst (
        .clk(clk),
        .rst(rst),
        .start(div_start),
        .dividend(sum_y),
        .divisor(count),
        .quotient(quot_y),
        .done(div_done_y)
    );

    localparam S_SCAN = 2'd0;
    localparam S_DIV  = 2'd1;
    localparam S_DONE = 2'd2;
    reg [1:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_SCAN;
            sum_x       <= 21'd0;
            sum_y       <= 21'd0;
            count       <= 14'd0;
            xmin_acc    <= 7'd127;
            xmax_acc    <= 7'd0;
            ymin_acc    <= 7'd71;
            ymax_acc    <= 7'd0;
            x_min       <= 7'd0;
            x_max       <= 7'd0;
            y_min       <= 7'd0;
            y_max       <= 7'd0;
            centroid_x  <= 7'd0;
            centroid_y  <= 7'd0;
            pixel_count <= 14'd0;
            bbox_valid  <= 1'b0;
            div_start   <= 1'b0;
        end else begin
            case (state)
                S_SCAN: begin
                    bbox_valid <= 1'b0;
                    div_start  <= 1'b0;
                    if (pixel_valid && stable_pixel) begin
                        if (pixel_x < xmin_acc) xmin_acc <= pixel_x;
                        if (pixel_x > xmax_acc) xmax_acc <= pixel_x;
                        if (pixel_y < ymin_acc) ymin_acc <= pixel_y;
                        if (pixel_y > ymax_acc) ymax_acc <= pixel_y;
                        sum_x <= sum_x + {14'd0, pixel_x};
                        sum_y <= sum_y + {14'd0, pixel_y};
                        count <= count + 14'd1;
                    end

                    if (frame_done) begin
                        if (count > 14'd0) begin
                            div_start <= 1'b1;
                            state     <= S_DIV;
                        end else begin
                            x_min       <= 7'd0;
                            x_max       <= 7'd0;
                            y_min       <= 7'd0;
                            y_max       <= 7'd0;
                            centroid_x  <= 7'd0;
                            centroid_y  <= 7'd0;
                            pixel_count <= 14'd0;
                            bbox_valid  <= 1'b1;
                            state       <= S_DONE;
                        end
                    end
                end

                S_DIV: begin
                    div_start <= 1'b0;
                    if (div_done_x && div_done_y) begin
                        x_min       <= xmin_acc;
                        x_max       <= xmax_acc;
                        y_min       <= ymin_acc;
                        y_max       <= ymax_acc;
                        centroid_x  <= quot_x[6:0];
                        centroid_y  <= quot_y[6:0];
                        pixel_count <= count;
                        bbox_valid  <= 1'b1;
                        state       <= S_DONE;
                    end
                end

                S_DONE: begin
                    bbox_valid <= 1'b0;
                    sum_x      <= 21'd0;
                    sum_y      <= 21'd0;
                    count      <= 14'd0;
                    xmin_acc   <= 7'd127;
                    xmax_acc   <= 7'd0;
                    ymin_acc   <= 7'd71;
                    ymax_acc   <= 7'd0;
                    state      <= S_SCAN;
                end

                default: state <= S_SCAN;
            endcase
        end
    end

endmodule
