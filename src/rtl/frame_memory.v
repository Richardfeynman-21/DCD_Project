`timescale 1ns / 1ps

module frame_memory #(
    parameter TOTAL_PIXELS = 9216
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        load_en,
    input  wire [7:0]  pixel_in,
    input  wire [13:0] pixel_addr,
    output reg         frame_ready,
    output wire [7:0]  curr_pixel,
    output wire [7:0]  prev_pixel,
    input  wire [13:0] rd_addr
);

    // Two memory banks for zero-copy ping-pong buffering
    (* ram_style = "block" *) reg [7:0] bank0 [0:TOTAL_PIXELS-1];
    (* ram_style = "block" *) reg [7:0] bank1 [0:TOTAL_PIXELS-1];

    reg active_bank;     // Points to bank holding current completed frame
    reg write_bank;      // Points to bank currently receiving incoming pixels
    reg has_prev_frame;  // Becomes 1 after the first full frame is captured

    reg [7:0] rd_data_bank0;
    reg [7:0] rd_data_bank1;

    // Synchronous memory writes
    always @(posedge clk) begin
        if (load_en) begin
            if (write_bank == 1'b0)
                bank0[pixel_addr] <= pixel_in;
            else
                bank1[pixel_addr] <= pixel_in;
        end
    end

    // Synchronous memory reads (standard BRAM inference)
    always @(posedge clk) begin
        rd_data_bank0 <= bank0[rd_addr];
        rd_data_bank1 <= bank1[rd_addr];
    end

    // Output assignments based on active bank
    assign curr_pixel = (active_bank == 1'b0) ? rd_data_bank0 : rd_data_bank1;
    assign prev_pixel = (!has_prev_frame) ? 8'd0 :
                        (active_bank == 1'b0) ? rd_data_bank1 : rd_data_bank0;

    // Buffer management and handshaking
    always @(posedge clk) begin
        if (rst) begin
            active_bank    <= 1'b0;
            write_bank     <= 1'b0;
            frame_ready    <= 1'b0;
            has_prev_frame <= 1'b0;
        end else begin
            frame_ready <= 1'b0;
            if (load_en && (pixel_addr == TOTAL_PIXELS - 1)) begin
                active_bank    <= write_bank;
                write_bank     <= ~write_bank;
                frame_ready    <= 1'b1;
                if (has_prev_frame == 1'b0 && active_bank == write_bank) begin
                    // After first complete frame
                    has_prev_frame <= 1'b1;
                end else begin
                    has_prev_frame <= 1'b1;
                end
            end
        end
    end

endmodule
