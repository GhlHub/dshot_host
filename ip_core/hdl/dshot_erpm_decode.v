`timescale 1ns / 1ps

module dshot_erpm_decode(
    input  wire [15:0] payload_word,
    output wire        crc_ok,
    output wire        edt_valid,
    output wire [3:0]  edt_type,
    output wire [7:0]  edt_data,
    output wire [2:0]  erpm_exp,
    output wire [8:0]  erpm_base,
    output wire [15:0] erpm_period
    );

wire [11:0] value12;
wire [3:0]  crc_calc;
wire        edt_detect;

assign value12     = payload_word[15:4];
assign crc_calc    = (value12 ^ (value12 >> 4) ^ (value12 >> 8)) & 4'hF;
assign crc_ok      = (crc_calc == payload_word[3:0]);
assign edt_detect  = (value12[8] == 1'b0) && (value12[11:8] != 4'h0) && (value12[11:8] != 4'h1);
assign edt_valid   = crc_ok & edt_detect;
assign edt_type    = edt_detect ? value12[11:8] : 4'h0;
assign edt_data    = edt_detect ? value12[7:0] : 8'h00;
assign erpm_exp    = value12[11:9];
assign erpm_base   = value12[8:0];
assign erpm_period = {7'h00, value12[8:0]} << value12[11:9];

endmodule
