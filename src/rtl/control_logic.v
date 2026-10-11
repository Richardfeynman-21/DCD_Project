`timescale 1ns / 1ps

module control_logic (
    input  wire clk,
    input  wire rst,
    input  wire motion_detected,
    input  wire is_animal,
    input  wire class_valid,
    output reg  motion_alert,
    output reg  animal_alert
);

    always @(posedge clk) begin
        if (rst) begin
            motion_alert <= 1'b0;
            animal_alert <= 1'b0;
        end else if (class_valid) begin
            motion_alert <= motion_detected;
            animal_alert <= is_animal & motion_detected;
        end
    end

endmodule
