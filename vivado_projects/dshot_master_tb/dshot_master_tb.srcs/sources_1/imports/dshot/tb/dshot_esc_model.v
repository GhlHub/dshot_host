`timescale 1ns / 1ps

module dshot_esc_model(
    input  wire        clk,
    input  wire        rst,
    input  wire        pin_o,
    input  wire        pin_oe,
    output reg         pin_i,
    input  wire        reply_enable,
    input  wire [15:0] pulse_threshold_clks,
    input  wire [15:0] reply_delay_clks,
    input  wire [15:0] reply_bit_clks,
    input  wire [15:0] reply_payload_word,
    output reg         frame_valid,
    output reg         frame_inverted,
    output reg [15:0]  frame_word,
    output reg [31:0]  frame_count
    );

reg        prev_pin_oe_reg;
reg        prev_pin_o_reg;
reg        active_level_reg;
reg [15:0] active_count_reg;
reg [4:0]  bit_count_reg;
reg [15:0] frame_shift_reg;

reg        reply_pending_reg;
reg        reply_arm_reg;
reg        reply_active_reg;
reg [15:0] reply_delay_count_reg;
reg [15:0] reply_bit_count_reg;
reg [4:0]  reply_bits_left_reg;
reg [20:0] reply_shift_reg;

wire       active_to_inactive;
wire       inactive_to_active;
wire       decoded_bit;

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

function [4:0] encode_4b5b;
    input [3:0] nibble;
    begin
        case (nibble)
            4'h0: encode_4b5b = 5'h19;
            4'h1: encode_4b5b = 5'h1B;
            4'h2: encode_4b5b = 5'h12;
            4'h3: encode_4b5b = 5'h13;
            4'h4: encode_4b5b = 5'h1D;
            4'h5: encode_4b5b = 5'h15;
            4'h6: encode_4b5b = 5'h16;
            4'h7: encode_4b5b = 5'h17;
            4'h8: encode_4b5b = 5'h1A;
            4'h9: encode_4b5b = 5'h09;
            4'hA: encode_4b5b = 5'h0A;
            4'hB: encode_4b5b = 5'h0B;
            4'hC: encode_4b5b = 5'h1E;
            4'hD: encode_4b5b = 5'h0D;
            4'hE: encode_4b5b = 5'h0E;
            default: encode_4b5b = 5'h0F;
        endcase
    end
endfunction

function [20:0] encode_reply_symbol;
    input [15:0] payload_word;
    reg   [19:0] gcr_word;
    reg   [20:0] symbol_word;
    integer idx;
    begin
        gcr_word = {
            encode_4b5b(payload_word[15:12]),
            encode_4b5b(payload_word[11:8]),
            encode_4b5b(payload_word[7:4]),
            encode_4b5b(payload_word[3:0])
        };

        symbol_word[20] = 1'b0;
        for (idx = 19; idx >= 0; idx = idx - 1) begin
            if (gcr_word[idx]) begin
                symbol_word[idx] = ~symbol_word[idx + 1];
            end else begin
                symbol_word[idx] = symbol_word[idx + 1];
            end
        end

        encode_reply_symbol = symbol_word;
    end
endfunction

assign active_to_inactive = pin_oe && prev_pin_oe_reg &&
                            (prev_pin_o_reg == active_level_reg) &&
                            (pin_o != active_level_reg);
assign inactive_to_active = pin_oe && prev_pin_oe_reg &&
                            (prev_pin_o_reg != active_level_reg) &&
                            (pin_o == active_level_reg);
assign decoded_bit = (active_count_reg >= pulse_threshold_clks);

always @(posedge clk) begin
    if (rst) begin
        prev_pin_oe_reg       <= 1'b0;
        prev_pin_o_reg        <= 1'b1;
        active_level_reg      <= 1'b1;
        active_count_reg      <= 16'h0000;
        bit_count_reg         <= 5'd0;
        frame_shift_reg       <= 16'h0000;
        frame_valid           <= 1'b0;
        frame_inverted        <= 1'b0;
        frame_word            <= 16'h0000;
        frame_count           <= 32'h0000_0000;
        reply_pending_reg     <= 1'b0;
        reply_arm_reg         <= 1'b0;
        reply_active_reg      <= 1'b0;
        reply_delay_count_reg <= 16'h0000;
        reply_bit_count_reg   <= 16'h0000;
        reply_bits_left_reg   <= 5'd0;
        reply_shift_reg       <= 21'h1F_FFFF;
        pin_i                 <= 1'b1;
    end else begin
        frame_valid <= 1'b0;

        if (!prev_pin_oe_reg && pin_oe) begin
            active_level_reg <= pin_o;
            frame_inverted   <= ~pin_o;
            active_count_reg <= 16'd1;
            bit_count_reg    <= 5'd0;
            frame_shift_reg  <= 16'h0000;
        end else if (pin_oe && prev_pin_oe_reg) begin
            if (active_to_inactive) begin
                if (bit_count_reg == 5'd15) begin
                    frame_word  <= {frame_shift_reg[14:0], decoded_bit};
                    frame_valid <= 1'b1;
                    frame_count <= frame_count + 32'd1;

                    if (frame_inverted && reply_enable) begin
                        reply_arm_reg         <= 1'b1;
                        reply_shift_reg       <= encode_reply_symbol(reply_payload_word);
                    end
                end else begin
                    frame_shift_reg <= {frame_shift_reg[14:0], decoded_bit};
                    bit_count_reg   <= bit_count_reg + 5'd1;
                end
                active_count_reg <= 16'h0000;
            end else if (inactive_to_active) begin
                active_count_reg <= 16'd1;
            end else if (pin_o == active_level_reg) begin
                active_count_reg <= active_count_reg + 16'd1;
            end
        end

        if (prev_pin_oe_reg && !pin_oe && reply_arm_reg) begin
            reply_arm_reg         <= 1'b0;
            reply_pending_reg     <= 1'b1;
            reply_delay_count_reg <= cycles_to_count(reply_delay_clks);
        end

        if (reply_active_reg) begin
            pin_i <= reply_shift_reg[20];
            if (reply_bit_count_reg == 16'h0000) begin
                if (reply_bits_left_reg == 5'd1) begin
                    reply_active_reg    <= 1'b0;
                    reply_bits_left_reg <= 5'd0;
                    pin_i               <= 1'b1;
                end else begin
                    reply_shift_reg     <= {reply_shift_reg[19:0], 1'b1};
                    reply_bits_left_reg <= reply_bits_left_reg - 5'd1;
                    reply_bit_count_reg <= cycles_to_count(reply_bit_clks);
                end
            end else begin
                reply_bit_count_reg <= reply_bit_count_reg - 16'd1;
            end
        end else begin
            pin_i <= 1'b1;
            if (reply_pending_reg) begin
                if (reply_delay_count_reg == 16'h0000) begin
                    reply_pending_reg   <= 1'b0;
                    reply_active_reg    <= 1'b1;
                    reply_bits_left_reg <= 5'd21;
                    reply_bit_count_reg <= cycles_to_count(reply_bit_clks);
                end else begin
                    reply_delay_count_reg <= reply_delay_count_reg - 16'd1;
                end
            end
        end

        prev_pin_oe_reg <= pin_oe;
        prev_pin_o_reg  <= pin_o;
    end
end

endmodule
