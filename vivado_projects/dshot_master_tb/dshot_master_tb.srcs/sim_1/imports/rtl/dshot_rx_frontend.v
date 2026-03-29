`timescale 1ns / 1ps

module dshot_rx_frontend(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire        pin_i,
    input  wire [15:0] sample_clks,
    input  wire [15:0] timeout_clks,
    output wire [20:0] symbol_word,
    output wire        symbol_valid,
    output wire        timeout
    );

reg [1:0]  pin_sync_reg;
reg        pin_sync_d_reg;
reg        capture_active_reg;
reg        rx_done_reg;
reg [15:0] sample_count_reg;
reg [15:0] timeout_count_reg;
reg [2:0]  sample_idx_reg;
reg [2:0]  ones_count_reg;
reg [4:0]  bits_captured_reg;
reg [20:0] symbol_shift_reg;
reg [20:0] symbol_word_reg;
reg        symbol_valid_reg;
reg        timeout_reg;

wire pin_sample;
wire pin_edge;
wire [2:0] ones_count_next;
wire       bit_majority;

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

function [15:0] half_cycles_to_count;
    input [15:0] cycles;
    reg [15:0] half_cycles;
    begin
        if (cycles <= 16'd2) begin
            half_cycles_to_count = 16'd0;
        end else begin
            half_cycles = cycles >> 1;
            if (half_cycles <= 16'd1) begin
                half_cycles_to_count = 16'd0;
            end else begin
                half_cycles_to_count = half_cycles - 16'd1;
            end
        end
    end
endfunction

assign pin_sample      = pin_sync_reg[1];
assign pin_edge        = (pin_sample ^ pin_sync_d_reg);
assign ones_count_next = ones_count_reg + (pin_sample ? 3'd1 : 3'd0);
assign bit_majority    = (ones_count_next >= 3'd3);
assign symbol_word     = symbol_word_reg;
assign symbol_valid    = symbol_valid_reg;
assign timeout         = timeout_reg;

always @(posedge clk) begin
    pin_sync_reg   <= {pin_sync_reg[0], pin_i};
    pin_sync_d_reg <= pin_sync_reg[1];

    if (rst || !enable) begin
        capture_active_reg <= 1'b0;
        rx_done_reg        <= 1'b0;
        sample_count_reg   <= 16'h0000;
        timeout_count_reg  <= 16'h0000;
        sample_idx_reg     <= 3'd0;
        ones_count_reg     <= 3'd0;
        bits_captured_reg  <= 5'd0;
        symbol_shift_reg   <= 21'h0;
        symbol_word_reg    <= 21'h0;
        symbol_valid_reg   <= 1'b0;
        timeout_reg        <= 1'b0;
    end else begin
        symbol_valid_reg <= 1'b0;
        timeout_reg      <= 1'b0;

        if (!rx_done_reg) begin
            if (timeout_clks != 16'h0000) begin
                if (timeout_count_reg >= (timeout_clks - 16'd1)) begin
                    capture_active_reg <= 1'b0;
                    rx_done_reg        <= 1'b1;
                    timeout_reg        <= 1'b1;
                end else begin
                    timeout_count_reg <= timeout_count_reg + 16'd1;
                end
            end

            if (!capture_active_reg) begin
                if (pin_edge) begin
                    capture_active_reg <= 1'b1;
                    sample_count_reg   <= half_cycles_to_count(sample_clks);
                    sample_idx_reg     <= 3'd0;
                    ones_count_reg     <= 3'd0;
                    bits_captured_reg  <= 5'd0;
                    symbol_shift_reg   <= 21'h0;
                end
            end else if (sample_count_reg == 16'h0000) begin
                if (sample_idx_reg == 3'd4) begin
                    if (bits_captured_reg == 5'd20) begin
                        symbol_word_reg    <= {symbol_shift_reg[19:0], bit_majority};
                        symbol_valid_reg   <= 1'b1;
                        capture_active_reg <= 1'b0;
                        rx_done_reg        <= 1'b1;
                    end else begin
                        symbol_shift_reg  <= {symbol_shift_reg[19:0], bit_majority};
                        bits_captured_reg <= bits_captured_reg + 5'd1;
                    end

                    sample_idx_reg   <= 3'd0;
                    ones_count_reg   <= 3'd0;
                    sample_count_reg <= cycles_to_count(sample_clks);
                end else begin
                    sample_idx_reg   <= sample_idx_reg + 3'd1;
                    ones_count_reg   <= ones_count_next;
                    sample_count_reg <= cycles_to_count(sample_clks);
                end
            end else begin
                sample_count_reg <= sample_count_reg - 16'd1;
            end
        end
    end
end

endmodule
