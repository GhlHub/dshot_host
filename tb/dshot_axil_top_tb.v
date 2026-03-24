`timescale 1ns / 1ps

module dshot_axil_top_tb;

localparam [7:0] ADDR_CONTROL      = 8'h00;
localparam [7:0] ADDR_STATUS       = 8'h04;
localparam [7:0] ADDR_TX12         = 8'h08;
localparam [7:0] ADDR_TX16         = 8'h0C;
localparam [7:0] ADDR_RX_FIFO_DATA = 8'h28;
localparam [7:0] ADDR_IRQ_MASK     = 8'h30;
localparam [7:0] ADDR_IRQ_STATUS   = 8'h34;

localparam [2:0] DSHOT_SPEED_600 = 3'd2;

reg         clk;
reg         rst_n;
reg  [7:0]  s_axi_awaddr;
reg         s_axi_awvalid;
wire        s_axi_awready;
reg  [31:0] s_axi_wdata;
reg  [3:0]  s_axi_wstrb;
reg         s_axi_wvalid;
wire        s_axi_wready;
wire [1:0]  s_axi_bresp;
wire        s_axi_bvalid;
reg         s_axi_bready;
reg  [7:0]  s_axi_araddr;
reg         s_axi_arvalid;
wire        s_axi_arready;
wire [31:0] s_axi_rdata;
wire [1:0]  s_axi_rresp;
wire        s_axi_rvalid;
reg         s_axi_rready;
wire        pin_o;
wire        pin_oe;
wire        irq;
wire        pin_i;

reg         esc_reply_enable;
reg  [15:0] esc_pulse_threshold_clks;
reg  [15:0] esc_reply_delay_clks;
reg  [15:0] esc_reply_bit_clks;
reg  [15:0] esc_reply_payload_word;
wire        esc_frame_valid;
wire        esc_frame_inverted;
wire [15:0] esc_frame_word;
wire [31:0] esc_frame_count;

integer expected_frame_count;
reg [31:0] read_data_reg;
reg [11:0] tx12_value;
reg [15:0] tx16_frame;
reg [15:0] expected_reply_period;
reg [11:0] expected_reply_value12;
reg [15:0] expected_reply_payload;
reg [15:0] expected_bidir_frame;

dshot_axil_top dut(
    .s_axi_aclk   (clk),
    .s_axi_aresetn(rst_n),
    .s_axi_awaddr (s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata  (s_axi_wdata),
    .s_axi_wstrb  (s_axi_wstrb),
    .s_axi_wvalid (s_axi_wvalid),
    .s_axi_wready (s_axi_wready),
    .s_axi_bresp  (s_axi_bresp),
    .s_axi_bvalid (s_axi_bvalid),
    .s_axi_bready (s_axi_bready),
    .s_axi_araddr (s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata  (s_axi_rdata),
    .s_axi_rresp  (s_axi_rresp),
    .s_axi_rvalid (s_axi_rvalid),
    .s_axi_rready (s_axi_rready),
    .pin_i        (pin_i),
    .pin_o        (pin_o),
    .pin_oe       (pin_oe),
    .irq          (irq)
);

dshot_esc_model esc_model(
    .clk                 (clk),
    .rst                 (~rst_n),
    .pin_o               (pin_o),
    .pin_oe              (pin_oe),
    .pin_i               (pin_i),
    .reply_enable        (esc_reply_enable),
    .pulse_threshold_clks(esc_pulse_threshold_clks),
    .reply_delay_clks    (esc_reply_delay_clks),
    .reply_bit_clks      (esc_reply_bit_clks),
    .reply_payload_word  (esc_reply_payload_word),
    .frame_valid         (esc_frame_valid),
    .frame_inverted      (esc_frame_inverted),
    .frame_word          (esc_frame_word),
    .frame_count         (esc_frame_count)
);

function [3:0] dshot_crc12;
    input [11:0] value12;
    begin
        dshot_crc12 = (value12 ^ (value12 >> 4) ^ (value12 >> 8)) & 4'hF;
    end
endfunction

function [3:0] dshot_crc12_inv;
    input [11:0] value12;
    begin
        dshot_crc12_inv = (~(value12 ^ (value12 >> 4) ^ (value12 >> 8))) & 4'hF;
    end
endfunction

task axil_write;
    input [7:0] addr;
    input [31:0] data;
    reg aw_done;
    reg w_done;
    begin
        aw_done = 1'b0;
        w_done  = 1'b0;

        @(posedge clk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'hF;
        s_axi_wvalid  <= 1'b1;

        while (!(aw_done && w_done)) begin
            @(posedge clk);
            if (s_axi_awvalid && s_axi_awready) begin
                s_axi_awvalid <= 1'b0;
                aw_done = 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                s_axi_wvalid <= 1'b0;
                w_done = 1'b1;
            end
        end

        s_axi_bready <= 1'b1;
        while (!s_axi_bvalid) begin
            @(posedge clk);
        end
        @(posedge clk);
        s_axi_bready <= 1'b0;
    end
endtask

task axil_read;
    input [7:0] addr;
    output [31:0] data;
    reg ar_done;
    begin
        ar_done = 1'b0;

        @(posedge clk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;

        while (!ar_done) begin
            @(posedge clk);
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arvalid <= 1'b0;
                ar_done = 1'b1;
            end
        end

        s_axi_rready <= 1'b1;
        while (!s_axi_rvalid) begin
            @(posedge clk);
        end
        data = s_axi_rdata;
        @(posedge clk);
        s_axi_rready <= 1'b0;
    end
endtask

task wait_for_frame_count;
    input integer target_count;
    integer watchdog;
    begin
        watchdog = 0;
        while ((esc_frame_count < target_count) && (watchdog < 200000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        if (esc_frame_count < target_count) begin
            $display("ERROR: timed out waiting for frame count %0d, saw %0d", target_count, esc_frame_count);
            $fatal;
        end
    end
endtask

task wait_for_irq_assert;
    integer watchdog;
    begin
        watchdog = 0;
        while (!irq && (watchdog < 200000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        if (!irq) begin
            $display("ERROR: timed out waiting for IRQ assertion");
            $fatal;
        end
    end
endtask

task wait_core_idle;
    integer watchdog;
    begin
        watchdog = 0;
        while (dut.busy && (watchdog < 200000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        if (dut.busy) begin
            $display("ERROR: timed out waiting for DUT idle");
            $fatal;
        end
    end
endtask

initial begin
    clk = 1'b0;
    forever #8.333 clk = ~clk;
end

initial begin
    s_axi_awaddr  = 8'h00;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'h0000_0000;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 8'h00;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;
    rst_n         = 1'b0;

    esc_reply_enable         = 1'b0;
    esc_pulse_threshold_clks = 16'd56;
    esc_reply_delay_clks     = 16'd1816;
    esc_reply_bit_clks       = 16'd80;
    esc_reply_payload_word   = 16'h0000;

    tx12_value             = 12'h345;
    tx16_frame             = 16'hA55A;
    expected_reply_value12 = 12'h205;
    expected_reply_payload = {expected_reply_value12, dshot_crc12(expected_reply_value12)};
    expected_reply_period  = 16'd10;
    expected_bidir_frame   = {tx12_value, dshot_crc12_inv(tx12_value)};

    $dumpfile("dshot_axil_top_tb.vcd");
    $dumpvars(0, dshot_axil_top_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b0});

    expected_frame_count = 1;
    axil_write(ADDR_TX12, {12'h0, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    if (esc_frame_word !== {tx12_value, dshot_crc12(tx12_value)}) begin
        $display("ERROR: TX12 normal frame mismatch. exp=%h got=%h", {tx12_value, dshot_crc12(tx12_value)}, esc_frame_word);
        $fatal;
    end
    if (esc_frame_inverted !== 1'b0) begin
        $display("ERROR: expected normal DSHOT frame");
        $fatal;
    end

    expected_frame_count = expected_frame_count + 3;
    axil_write(ADDR_TX16, {12'h0, 4'h2, tx16_frame});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    if (esc_frame_word !== tx16_frame) begin
        $display("ERROR: TX16 frame mismatch. exp=%h got=%h", tx16_frame, esc_frame_word);
        $fatal;
    end

    esc_reply_enable       = 1'b1;
    esc_reply_payload_word = expected_reply_payload;

    axil_write(ADDR_IRQ_MASK, 32'h0000_0001);
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b1});

    expected_frame_count = expected_frame_count + 1;
    axil_write(ADDR_TX12, {12'h0, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;

    if (esc_frame_word !== expected_bidir_frame) begin
        $display("ERROR: bidirectional TX12 frame mismatch. exp=%h got=%h", expected_bidir_frame, esc_frame_word);
        $fatal;
    end
    if (esc_frame_inverted !== 1'b1) begin
        $display("ERROR: expected inverted DSHOT frame");
        $fatal;
    end

    wait_for_irq_assert;

    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg !== {expected_reply_payload, expected_reply_period}) begin
        $display("ERROR: RX FIFO word mismatch. exp=%h got=%h", {expected_reply_payload, expected_reply_period}, read_data_reg);
        $fatal;
    end

    axil_read(ADDR_IRQ_STATUS, read_data_reg);
    if (read_data_reg[18:16] !== 3'b001) begin
        $display("ERROR: expected non-empty IRQ pending bit set, got %h", read_data_reg[18:16]);
        $fatal;
    end

    axil_write(ADDR_IRQ_STATUS, 32'h0000_0001);
    repeat (5) @(posedge clk);
    if (irq !== 1'b0) begin
        $display("ERROR: IRQ did not clear");
        $fatal;
    end

    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[4] !== 1'b0) begin
        $display("ERROR: sticky code error set unexpectedly");
        $fatal;
    end

    $display("PASS: normal DSHOT, inverted DSHOT, AXI-Lite master, RX FIFO, and IRQ path");
    $finish;
end

endmodule
