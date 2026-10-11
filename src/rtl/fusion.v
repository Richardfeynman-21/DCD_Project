`timescale 1ns / 1ps

module fusion #(
    parameter DELAY_CYCLES = 130 // Aligns motion_pixel (latency 1) to Sobel center (latency 131)
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] mode_sel,      // 00: Motion silhouette, 01: Edge AND Motion, 10: Edge OR Motion
    input  wire       edge_pixel,
    input  wire       motion_pixel,
    input  wire       edge_valid,
    input  wire       motion_valid,
    output reg        fused_pixel,
    output reg        fused_valid
);

    // Shift register to align motion_pixel spatially and temporally with Sobel window center
    reg [DELAY_CYCLES-1:0] motion_shift;
    reg [DELAY_CYCLES-1:0] valid_shift;

    wire aligned_motion       = motion_shift[DELAY_CYCLES-1];
    wire aligned_motion_valid = valid_shift[DELAY_CYCLES-1];

    always @(posedge clk) begin
        if (rst) begin
            motion_shift <= {DELAY_CYCLES{1'b0}};
            valid_shift  <= {DELAY_CYCLES{1'b0}};
            fused_pixel  <= 1'b0;
            fused_valid  <= 1'b0;
        end else begin
            motion_shift <= {motion_shift[DELAY_CYCLES-2:0], motion_pixel};
            valid_shift  <= {valid_shift[DELAY_CYCLES-2:0], motion_valid};

            case (mode_sel)
                2'b00:   fused_pixel <= aligned_motion;                    // Motion silhouette
                2'b01:   fused_pixel <= edge_pixel & aligned_motion;       // Strict AND (moving edges)
                2'b10:   fused_pixel <= edge_pixel | aligned_motion;       // OR
                default: fused_pixel <= aligned_motion;
            endcase

            fused_valid <= edge_valid & aligned_motion_valid;
        end
    end

endmodule
