`timescale 1ns / 1ps

module dshot_axil_top(
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [7:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [7:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    input  wire        pin_i,
    output wire        pin_o,
    output wire        pin_oe,
    output wire        irq
    );

wire        start;
wire        tx_use_raw;
wire [3:0]  tx_repeat_m1;
wire [3:0]  tx_tag;
wire        bidir_en;
wire [11:0] tx_value12;
wire [15:0] tx_frame_raw;
wire [15:0] t0h_clks;
wire [15:0] t1h_clks;
wire [15:0] bit_clks;
wire [15:0] turnaround_clks;
wire [15:0] rx_sample_clks;
wire [15:0] rx_timeout_clks;
wire        busy;
wire        done;
wire        tx_done;
wire        rx_valid;
wire        rx_crc_ok;
wire        code_error;
wire        edt_valid;
wire [3:0]  edt_type;
wire [7:0]  edt_data;
wire [15:0] erpm_period;
wire        rx_fifo_wr_en;
wire [35:0] rx_fifo_wdata;

dshot_axil_regs u_dshot_axil_regs(
    .s_axi_aclk          (s_axi_aclk),
    .s_axi_aresetn       (s_axi_aresetn),
    .s_axi_awaddr        (s_axi_awaddr),
    .s_axi_awvalid       (s_axi_awvalid),
    .s_axi_awready       (s_axi_awready),
    .s_axi_wdata         (s_axi_wdata),
    .s_axi_wstrb         (s_axi_wstrb),
    .s_axi_wvalid        (s_axi_wvalid),
    .s_axi_wready        (s_axi_wready),
    .s_axi_bresp         (s_axi_bresp),
    .s_axi_bvalid        (s_axi_bvalid),
    .s_axi_bready        (s_axi_bready),
    .s_axi_araddr        (s_axi_araddr),
    .s_axi_arvalid       (s_axi_arvalid),
    .s_axi_arready       (s_axi_arready),
    .s_axi_rdata         (s_axi_rdata),
    .s_axi_rresp         (s_axi_rresp),
    .s_axi_rvalid        (s_axi_rvalid),
    .s_axi_rready        (s_axi_rready),
    .start               (start),
    .tx_use_raw          (tx_use_raw),
    .tx_repeat_m1        (tx_repeat_m1),
    .tx_tag              (tx_tag),
    .bidir_en            (bidir_en),
    .tx_value12          (tx_value12),
    .tx_frame_raw        (tx_frame_raw),
    .t0h_clks            (t0h_clks),
    .t1h_clks            (t1h_clks),
    .bit_clks            (bit_clks),
    .turnaround_clks     (turnaround_clks),
    .rx_sample_clks      (rx_sample_clks),
    .rx_timeout_clks     (rx_timeout_clks),
    .busy                (busy),
    .done                (done),
    .tx_done             (tx_done),
    .rx_valid            (rx_valid),
    .rx_crc_ok           (rx_crc_ok),
    .code_error          (code_error),
    .edt_valid           (edt_valid),
    .edt_type            (edt_type),
    .edt_data            (edt_data),
    .erpm_period         (erpm_period),
    .rx_fifo_wr_en       (rx_fifo_wr_en),
    .rx_fifo_wdata       (rx_fifo_wdata),
    .irq                 (irq)
);

dshot_core u_dshot_core(
    .clk                 (s_axi_aclk),
    .rst                 (~s_axi_aresetn),
    .start               (start),
    .tx_use_raw          (tx_use_raw),
    .tx_repeat_m1        (tx_repeat_m1),
    .tx_tag              (tx_tag),
    .bidir_en            (bidir_en),
    .tx_value12          (tx_value12),
    .tx_frame_raw        (tx_frame_raw),
    .t0h_clks            (t0h_clks),
    .t1h_clks            (t1h_clks),
    .bit_clks            (bit_clks),
    .turnaround_clks     (turnaround_clks),
    .rx_sample_clks      (rx_sample_clks),
    .rx_timeout_clks     (rx_timeout_clks),
    .pin_i               (pin_i),
    .pin_o               (pin_o),
    .pin_oe              (pin_oe),
    .busy                (busy),
    .done                (done),
    .tx_done             (tx_done),
    .rx_valid            (rx_valid),
    .rx_crc_ok           (rx_crc_ok),
    .code_error          (code_error),
    .edt_valid           (edt_valid),
    .edt_type            (edt_type),
    .edt_data            (edt_data),
    .erpm_period         (erpm_period),
    .rx_fifo_wr_en       (rx_fifo_wr_en),
    .rx_fifo_wdata       (rx_fifo_wdata)
);

endmodule
