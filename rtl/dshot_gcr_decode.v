`timescale 1ns / 1ps

module dshot_gcr_decode(
    input  wire        symbol_valid,
    input  wire [20:0] symbol_word,
    output wire [15:0] payload_word,
    output wire        payload_valid,
    output wire        code_error
    );

wire [19:0] gcr_word;
wire [4:0]  nibble3_decode;
wire [4:0]  nibble2_decode;
wire [4:0]  nibble1_decode;
wire [4:0]  nibble0_decode;
wire        decode_ok;

function [4:0] decode_5b4b;
    input [4:0] code;
    begin
        case (code)
            5'h19: decode_5b4b = {1'b1, 4'h0};
            5'h1B: decode_5b4b = {1'b1, 4'h1};
            5'h12: decode_5b4b = {1'b1, 4'h2};
            5'h13: decode_5b4b = {1'b1, 4'h3};
            5'h1D: decode_5b4b = {1'b1, 4'h4};
            5'h15: decode_5b4b = {1'b1, 4'h5};
            5'h16: decode_5b4b = {1'b1, 4'h6};
            5'h17: decode_5b4b = {1'b1, 4'h7};
            5'h1A: decode_5b4b = {1'b1, 4'h8};
            5'h09: decode_5b4b = {1'b1, 4'h9};
            5'h0A: decode_5b4b = {1'b1, 4'hA};
            5'h0B: decode_5b4b = {1'b1, 4'hB};
            5'h1E: decode_5b4b = {1'b1, 4'hC};
            5'h0D: decode_5b4b = {1'b1, 4'hD};
            5'h0E: decode_5b4b = {1'b1, 4'hE};
            5'h0F: decode_5b4b = {1'b1, 4'hF};
            default: decode_5b4b = 5'h00;
        endcase
    end
endfunction

assign gcr_word      = symbol_word[20:1] ^ symbol_word[19:0];
assign nibble3_decode = decode_5b4b(gcr_word[19:15]);
assign nibble2_decode = decode_5b4b(gcr_word[14:10]);
assign nibble1_decode = decode_5b4b(gcr_word[9:5]);
assign nibble0_decode = decode_5b4b(gcr_word[4:0]);
assign decode_ok      = nibble3_decode[4] & nibble2_decode[4] & nibble1_decode[4] & nibble0_decode[4];

assign payload_word  = {nibble3_decode[3:0], nibble2_decode[3:0], nibble1_decode[3:0], nibble0_decode[3:0]};
assign payload_valid = symbol_valid & decode_ok;
assign code_error    = symbol_valid & ~decode_ok;

endmodule
