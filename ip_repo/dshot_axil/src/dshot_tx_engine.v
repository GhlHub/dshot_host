`timescale 1ns / 1ps

module dshot_tx_engine(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        bidir_en,
    input  wire [15:0] frame_word,
    input  wire [15:0] t0h_clks,
    input  wire [15:0] t1h_clks,
    input  wire [15:0] bit_clks,
    output wire        pin_o,
    output wire        pin_oe,
    output wire        busy,
    output wire        done
    );

localparam [1:0] ST_IDLE = 2'd0;
localparam [1:0] ST_HIGH = 2'd1;
localparam [1:0] ST_LOW  = 2'd2;

reg [1:0]  state_reg;
reg [15:0] shift_reg;
reg [15:0] phase_count_reg;
reg [4:0]  bits_left_reg;
reg        done_reg;

wire current_bit;
wire active_level;
wire inactive_level;
wire [15:0] high_cycles;
wire [15:0] low_cycles;

function [15:0] cycles_to_count;
    input [15:0] cycles;
    begin
        if (cycles <= 16'd1) begin
            cycles_to_count = 16'd0;
        end else begin
            cycles_to_count = cycles - 16'd1;
        end
    end
endfunction

assign current_bit    = shift_reg[15];
assign active_level   = bidir_en ? 1'b0 : 1'b1;
assign inactive_level = ~active_level;
assign high_cycles    = current_bit ? t1h_clks : t0h_clks;
assign low_cycles     = (bit_clks > high_cycles) ? (bit_clks - high_cycles) : 16'd1;

assign pin_o  = (state_reg == ST_HIGH) ? active_level : inactive_level;
assign pin_oe = (state_reg != ST_IDLE);
assign busy   = (state_reg != ST_IDLE);
assign done   = done_reg;

always @(posedge clk) begin
    if (rst) begin
        state_reg       <= ST_IDLE;
        shift_reg       <= 16'h0000;
        phase_count_reg <= 16'h0000;
        bits_left_reg   <= 5'd0;
        done_reg        <= 1'b0;
    end else begin
        done_reg <= 1'b0;

        case (state_reg)
            ST_IDLE: begin
                if (start) begin
                    shift_reg       <= frame_word;
                    phase_count_reg <= cycles_to_count(frame_word[15] ? t1h_clks : t0h_clks);
                    bits_left_reg   <= 5'd16;
                    state_reg       <= ST_HIGH;
                end
            end

            ST_HIGH: begin
                if (phase_count_reg == 16'h0000) begin
                    phase_count_reg <= cycles_to_count(low_cycles);
                    state_reg       <= ST_LOW;
                end else begin
                    phase_count_reg <= phase_count_reg - 16'h0001;
                end
            end

            ST_LOW: begin
                if (phase_count_reg == 16'h0000) begin
                    if (bits_left_reg == 5'd1) begin
                        state_reg <= ST_IDLE;
                        done_reg  <= 1'b1;
                    end else begin
                        shift_reg       <= {shift_reg[14:0], 1'b0};
                        bits_left_reg   <= bits_left_reg - 5'd1;
                        phase_count_reg <= cycles_to_count(shift_reg[14] ? t1h_clks : t0h_clks);
                        state_reg       <= ST_HIGH;
                    end
                end else begin
                    phase_count_reg <= phase_count_reg - 16'h0001;
                end
            end

            default: begin
                state_reg <= ST_IDLE;
            end
        endcase
    end
end

endmodule
