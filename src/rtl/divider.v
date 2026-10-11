`timescale 1ns / 1ps

module divider #(
    parameter WIDTH_N = 21,
    parameter WIDTH_D = 14
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    input  wire [WIDTH_N-1:0]   dividend,
    input  wire [WIDTH_D-1:0]   divisor,
    output reg  [WIDTH_N-1:0]   quotient,
    output reg                  done
);

    reg [WIDTH_N-1:0] rem;
    reg [WIDTH_N-1:0] div;
    reg [WIDTH_D-1:0] dvsr;
    reg [4:0]         step;
    reg               busy;

    wire [WIDTH_N-1:0] next_rem = {rem[WIDTH_N-2:0], div[WIDTH_N-1]};

    always @(posedge clk) begin
        if (rst) begin
            quotient <= {WIDTH_N{1'b0}};
            rem      <= {WIDTH_N{1'b0}};
            div      <= {WIDTH_N{1'b0}};
            dvsr     <= {WIDTH_D{1'b0}};
            step     <= 5'd0;
            busy     <= 1'b0;
            done     <= 1'b0;
        end else if (start && !busy) begin
            if (divisor == {WIDTH_D{1'b0}}) begin
                // Division by zero safeguard
                quotient <= {WIDTH_N{1'b0}};
                done     <= 1'b1;
                busy     <= 1'b0;
            end else begin
                rem      <= {WIDTH_N{1'b0}};
                div      <= dividend;
                dvsr     <= divisor;
                quotient <= {WIDTH_N{1'b0}};
                step     <= WIDTH_N;
                busy     <= 1'b1;
                done     <= 1'b0;
            end
        end else if (busy) begin
            if (step == 5'd0) begin
                done <= 1'b1;
                busy <= 1'b0;
            end else begin
                div <= {div[WIDTH_N-2:0], 1'b0};

                if (next_rem >= {{(WIDTH_N-WIDTH_D){1'b0}}, dvsr}) begin
                    rem <= next_rem - {{(WIDTH_N-WIDTH_D){1'b0}}, dvsr};
                    quotient <= {quotient[WIDTH_N-2:0], 1'b1};
                end else begin
                    rem <= next_rem;
                    quotient <= {quotient[WIDTH_N-2:0], 1'b0};
                end
                step <= step - 5'd1;
            end
        end else begin
            done <= 1'b0;
        end
    end

endmodule
