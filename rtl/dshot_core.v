`timescale 1ns / 1ps

module dshot_core(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        tx_use_raw,
    input  wire [3:0]  tx_repeat_m1,
    input  wire        bidir_en,
    input  wire [11:0] tx_value12,
    input  wire [15:0] tx_frame_raw,
    input  wire [15:0] t0h_clks,
    input  wire [15:0] t1h_clks,
    input  wire [15:0] bit_clks,
    input  wire [15:0] turnaround_clks,
    input  wire [15:0] rx_sample_clks,
    input  wire [15:0] rx_timeout_clks,
    input  wire        pin_i,
    output wire        pin_o,
    output wire        pin_oe,
    output wire        busy,
    output wire        done,
    output wire        tx_done,
    output wire        rx_valid,
    output wire        rx_crc_ok,
    output wire        code_error,
    output wire        edt_valid,
    output wire [3:0]  edt_type,
    output wire [7:0]  edt_data,
    output wire [15:0] erpm_period,
    output wire        rx_fifo_wr_en,
    output wire [31:0] rx_fifo_wdata
    );

wire [15:0] tx_frame_word_auto;
wire [15:0] tx_frame_word;
wire [3:0]  tx_crc_nibble;
wire        seq_tx_start;
wire        seq_turnaround_wait;
wire        seq_rx_enable;
wire        seq_busy_wire;
wire        seq_done_wire;
wire        tx_done_int;
wire        rx_symbol_valid;
wire        rx_timeout_int;
wire        rx_done_int;
wire        turnaround_done;
wire [20:0] rx_symbol_word;
wire [15:0] rx_payload_word;
wire        rx_payload_valid;
wire        rx_code_error_int;
wire        rx_crc_ok_int;
wire        rx_crc_error_int;
wire        edt_valid_int;
wire [3:0]  edt_type_int;
wire [7:0]  edt_data_int;
wire [2:0]  erpm_exp_int;
wire [8:0]  erpm_base_int;
wire [15:0] erpm_period_int;
reg  [15:0] turnaround_count_reg;

assign tx_frame_word    = tx_use_raw ? tx_frame_raw : tx_frame_word_auto;
assign turnaround_done  = seq_turnaround_wait &&
                          ((turnaround_clks <= 16'd1) || (turnaround_count_reg >= (turnaround_clks - 16'd1)));
assign rx_done_int      = rx_symbol_valid | rx_timeout_int;
assign rx_crc_error_int = rx_payload_valid & ~rx_crc_ok_int;

assign busy         = seq_busy_wire;
assign done         = seq_done_wire;
assign tx_done      = tx_done_int;
assign rx_valid     = rx_fifo_wr_en;
assign rx_crc_ok    = rx_payload_valid & rx_crc_ok_int;
assign code_error   = rx_code_error_int | rx_crc_error_int;
assign edt_valid    = rx_fifo_wr_en & edt_valid_int;
assign edt_type     = edt_type_int;
assign edt_data     = edt_data_int;
assign erpm_period  = erpm_period_int;
assign rx_fifo_wr_en = rx_payload_valid & rx_crc_ok_int;
assign rx_fifo_wdata = {rx_payload_word, erpm_period_int};

dshot_frame_pack u_dshot_frame_pack(
    .value12    (tx_value12),
    .bidir_en   (bidir_en),
    .frame_word (tx_frame_word_auto),
    .crc_nibble (tx_crc_nibble)
);

dshot_seq_ctrl u_dshot_seq_ctrl(
    .clk            (clk),
    .rst            (rst),
    .start          (start),
    .tx_repeat_m1   (tx_repeat_m1),
    .bidir_en       (bidir_en),
    .tx_done        (tx_done_int),
    .turnaround_done(turnaround_done),
    .rx_done        (rx_done_int),
    .tx_start       (seq_tx_start),
    .turnaround_wait(seq_turnaround_wait),
    .rx_enable      (seq_rx_enable),
    .busy           (seq_busy_wire),
    .done           (seq_done_wire)
);

dshot_tx_engine u_dshot_tx_engine(
    .clk       (clk),
    .rst       (rst),
    .start     (seq_tx_start),
    .bidir_en  (bidir_en),
    .frame_word(tx_frame_word),
    .t0h_clks  (t0h_clks),
    .t1h_clks  (t1h_clks),
    .bit_clks  (bit_clks),
    .pin_o     (pin_o),
    .pin_oe    (pin_oe),
    .busy      (),
    .done      (tx_done_int)
);

dshot_rx_frontend u_dshot_rx_frontend(
    .clk         (clk),
    .rst         (rst),
    .enable      (seq_rx_enable),
    .pin_i       (pin_i),
    .sample_clks (rx_sample_clks),
    .timeout_clks(rx_timeout_clks),
    .symbol_word (rx_symbol_word),
    .symbol_valid(rx_symbol_valid),
    .timeout     (rx_timeout_int)
);

dshot_gcr_decode u_dshot_gcr_decode(
    .symbol_valid (rx_symbol_valid),
    .symbol_word  (rx_symbol_word),
    .payload_word (rx_payload_word),
    .payload_valid(rx_payload_valid),
    .code_error   (rx_code_error_int)
);

dshot_erpm_decode u_dshot_erpm_decode(
    .payload_word(rx_payload_word),
    .crc_ok      (rx_crc_ok_int),
    .edt_valid   (edt_valid_int),
    .edt_type    (edt_type_int),
    .edt_data    (edt_data_int),
    .erpm_exp    (erpm_exp_int),
    .erpm_base   (erpm_base_int),
    .erpm_period (erpm_period_int)
);

always @(posedge clk) begin
    if (rst || !seq_turnaround_wait) begin
        turnaround_count_reg <= 16'h0000;
    end else if (!turnaround_done) begin
        turnaround_count_reg <= turnaround_count_reg + 16'd1;
    end
end

endmodule
