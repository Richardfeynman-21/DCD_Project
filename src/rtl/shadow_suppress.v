`timescale 1ns / 1ps

module shadow_suppress #(
    parameter TOTAL_PIXELS = 9216
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        fused_pixel,
    input  wire [13:0] pixel_addr,
    input  wire        pixel_valid,
    input  wire        frame_done,
    input  wire [2:0]  persist_thresh,
    output reg         stable_pixel,
    output reg         stable_valid
);

    // 9216 x 3-bit memory for pixel persistence history (synthesizes into 1 BRAM)
    (* ram_style = "block" *) reg [2:0] history_mem [0:TOTAL_PIXELS-1];

    integer init_i;
    initial begin
        for (init_i = 0; init_i < TOTAL_PIXELS; init_i = init_i + 1) begin
            history_mem[init_i] = 3'd0;
        end
    end

    reg [13:0] addr_pipe1;
    reg        fused_pipe1;
    reg        valid_pipe1;
    reg [2:0]  cnt_read;

    // Pipeline Stage 1: Read previous count
    always @(posedge clk) begin
        if (pixel_valid) begin
            cnt_read <= history_mem[pixel_addr];
        end
        addr_pipe1  <= pixel_addr;
        fused_pipe1 <= fused_pixel;
        valid_pipe1 <= pixel_valid;
    end

    // Pipeline Stage 2: Update counter and output stability decision
    wire [2:0] next_cnt = fused_pipe1 ?
                          ((cnt_read == 3'd7) ? 3'd7 : (cnt_read + 3'd1)) :
                          3'd0;

    always @(posedge clk) begin
        if (rst) begin
            stable_pixel <= 1'b0;
            stable_valid <= 1'b0;
        end else if (valid_pipe1) begin
            history_mem[addr_pipe1] <= next_cnt;
            stable_pixel <= (next_cnt >= persist_thresh) ? 1'b1 : 1'b0;
            stable_valid <= 1'b1;
        end else begin
            stable_valid <= 1'b0;
        end
    end

endmodule
