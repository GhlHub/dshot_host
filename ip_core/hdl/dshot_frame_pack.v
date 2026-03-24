`timescale 1ns / 1ps

module dshot_frame_pack(
    input  wire [11:0] value12,
    input  wire        bidir_en,
    output wire [15:0] frame_word,
    output wire [3:0]  crc_nibble
    );

wire [3:0]  crc_base;

assign crc_base   = (value12 ^ (value12 >> 4) ^ (value12 >> 8)) & 4'hF;
assign crc_nibble = bidir_en ? (~crc_base) : crc_base;
assign frame_word = {value12, crc_nibble};

endmodule
