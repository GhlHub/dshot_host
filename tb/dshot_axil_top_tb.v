`timescale 1ns / 1ps

module dshot_axil_top_tb;

localparam [7:0] ADDR_CONTROL      = 8'h00;
localparam [7:0] ADDR_STATUS       = 8'h04;
localparam [7:0] ADDR_TX12         = 8'h08;
localparam [7:0] ADDR_TX16         = 8'h0C;
localparam [7:0] ADDR_RX_FIFO_DATA = 8'h28;
localparam [7:0] ADDR_IRQ_MASK     = 8'h30;
localparam [7:0] ADDR_IRQ_STATUS   = 8'h34;
localparam [7:0] ADDR_IRQ_OCC      = 8'h38;
localparam [7:0] ADDR_IRQ_AGE      = 8'h3C;
localparam [7:0] ADDR_RX_FIFO_TAG  = 8'h40;

localparam [2:0] DSHOT_SPEED_600 = 3'd2;
localparam integer CONTROL_RX_FIFO_RST_BIT = 8;
localparam integer CONTROL_TX_FIFO_RST_BIT = 9;
localparam [3:0] TAG_BIDIR_RX    = 4'hA;
localparam [3:0] TAG_TX_DONE     = 4'h3;
localparam [3:0] TAG_TX_QUEUE0   = 4'h4;
localparam [3:0] TAG_TX_QUEUE1   = 4'h5;

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
reg        waveform_check_done;

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

task ensure_no_irq_cycles;
    input integer cycle_count;
    integer idx;
    begin
        for (idx = 0; idx < cycle_count; idx = idx + 1) begin
            @(posedge clk);
            if (irq) begin
                $display("ERROR: unexpected IRQ assertion during quiet window at cycle %0d", idx);
                $fatal;
            end
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

task check_tx_frame_waveform;
    input [15:0] expected_frame;
    input integer repeat_count;
    input integer expected_bidir;
    integer repeat_idx;
    integer bit_idx;
    integer watchdog;
    integer active_cycles;
    integer inactive_cycles;
    integer expected_active_cycles;
    integer expected_inactive_cycles;
    reg active_level;
    reg inactive_level;
    begin
        active_level   = expected_bidir ? 1'b0 : 1'b1;
        inactive_level = ~active_level;

        for (repeat_idx = 0; repeat_idx < repeat_count; repeat_idx = repeat_idx + 1) begin
            watchdog = 0;
            while (!pin_oe && (watchdog < 200000)) begin
                @(posedge clk);
                watchdog = watchdog + 1;
            end
            if (!pin_oe) begin
                $display("ERROR: timed out waiting for TX waveform start, repeat %0d", repeat_idx);
                $fatal;
            end

            for (bit_idx = 15; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                if (pin_o !== active_level) begin
                    $display("ERROR: TX waveform polarity mismatch at repeat %0d bit %0d. exp active=%0d got=%0d",
                             repeat_idx, bit_idx, active_level, pin_o);
                    $fatal;
                end

                active_cycles = 0;
                while (pin_oe && (pin_o === active_level)) begin
                    active_cycles = active_cycles + 1;
                    @(posedge clk);
                end

                inactive_cycles = 0;
                while (pin_oe && (pin_o === inactive_level)) begin
                    inactive_cycles = inactive_cycles + 1;
                    @(posedge clk);
                end

                expected_active_cycles = expected_frame[bit_idx] ?
                                         dut.u_dshot_axil_regs.t1h_clks_reg :
                                         dut.u_dshot_axil_regs.t0h_clks_reg;
                expected_inactive_cycles = dut.u_dshot_axil_regs.bit_clks_reg - expected_active_cycles;

                if (active_cycles !== expected_active_cycles) begin
                    $display("ERROR: active pulse width mismatch at repeat %0d bit %0d. exp=%0d got=%0d",
                             repeat_idx, bit_idx, expected_active_cycles, active_cycles);
                    $fatal;
                end
                if (inactive_cycles !== expected_inactive_cycles) begin
                    $display("ERROR: inactive pulse width mismatch at repeat %0d bit %0d. exp=%0d got=%0d",
                             repeat_idx, bit_idx, expected_inactive_cycles, inactive_cycles);
                    $fatal;
                end
                if ((active_cycles + inactive_cycles) !== dut.u_dshot_axil_regs.bit_clks_reg) begin
                    $display("ERROR: bit period mismatch at repeat %0d bit %0d. exp=%0d got=%0d",
                             repeat_idx, bit_idx, dut.u_dshot_axil_regs.bit_clks_reg,
                             active_cycles + inactive_cycles);
                    $fatal;
                end
            end
        end
    end
endtask

task start_tx_waveform_check;
    input [15:0] expected_frame;
    input integer repeat_count;
    input integer expected_bidir;
    begin
        waveform_check_done = 1'b0;
        fork
            begin
                check_tx_frame_waveform(expected_frame, repeat_count, expected_bidir);
                waveform_check_done = 1'b1;
            end
        join_none
    end
endtask

task wait_tx_waveform_check_done;
    integer watchdog;
    begin
        watchdog = 0;
        while (!waveform_check_done && (watchdog < 200000)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        if (!waveform_check_done) begin
            $display("ERROR: timed out waiting for waveform checker completion");
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
    waveform_check_done    = 1'b1;

    $dumpfile("dshot_axil_top_tb.vcd");
    $dumpvars(0, dshot_axil_top_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b0});

    expected_frame_count = 1;
    start_tx_waveform_check({tx12_value, dshot_crc12(tx12_value)}, 1, 0);
    axil_write(ADDR_TX12, {8'h00, 4'h0, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    wait_tx_waveform_check_done;
    if (esc_frame_word !== {tx12_value, dshot_crc12(tx12_value)}) begin
        $display("ERROR: TX12 normal frame mismatch. exp=%h got=%h", {tx12_value, dshot_crc12(tx12_value)}, esc_frame_word);
        $fatal;
    end
    if (esc_frame_inverted !== 1'b0) begin
        $display("ERROR: expected normal DSHOT frame");
        $fatal;
    end

    expected_frame_count = expected_frame_count + 3;
    start_tx_waveform_check(tx16_frame, 3, 0);
    axil_write(ADDR_TX16, {8'h00, 4'h0, 4'h2, tx16_frame});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    wait_tx_waveform_check_done;
    if (esc_frame_word !== tx16_frame) begin
        $display("ERROR: TX16 frame mismatch. exp=%h got=%h", tx16_frame, esc_frame_word);
        $fatal;
    end

    esc_reply_enable       = 1'b1;
    esc_reply_payload_word = expected_reply_payload;

    axil_write(ADDR_IRQ_MASK, 32'h0000_0001);
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b1});

    expected_frame_count = expected_frame_count + 1;
    start_tx_waveform_check(expected_bidir_frame, 1, 1);
    axil_write(ADDR_TX12, {8'h00, TAG_BIDIR_RX, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    wait_tx_waveform_check_done;

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

    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[3:0] !== TAG_BIDIR_RX) begin
        $display("ERROR: RX FIFO tag mismatch. exp=%h got=%h", TAG_BIDIR_RX, read_data_reg[3:0]);
        $fatal;
    end

    axil_read(ADDR_IRQ_STATUS, read_data_reg);
    if (read_data_reg[20:16] !== 5'b00001) begin
        $display("ERROR: expected non-empty IRQ pending bit set, got %h", read_data_reg[20:16]);
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

    axil_write(ADDR_IRQ_MASK, 32'h0000_0002);
    axil_write(ADDR_IRQ_OCC, 32'h0000_0002);
    axil_write(ADDR_IRQ_AGE, 32'h0000_0000);

    expected_frame_count = expected_frame_count + 1;
    axil_write(ADDR_TX12, {8'h00, 4'h1, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    ensure_no_irq_cycles(32);

    expected_frame_count = expected_frame_count + 1;
    axil_write(ADDR_TX12, {8'h00, 4'h2, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    wait_for_irq_assert;

    axil_read(ADDR_IRQ_STATUS, read_data_reg);
    if (read_data_reg[20:16] !== 5'b00010) begin
        $display("ERROR: expected occupancy IRQ pending bit set, got %h", read_data_reg[20:16]);
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg !== {expected_reply_payload, expected_reply_period}) begin
        $display("ERROR: occupancy test FIFO word 0 mismatch. exp=%h got=%h",
                 {expected_reply_payload, expected_reply_period}, read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[3:0] !== 4'h1) begin
        $display("ERROR: occupancy test tag 0 mismatch. exp=1 got=%h", read_data_reg[3:0]);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg !== {expected_reply_payload, expected_reply_period}) begin
        $display("ERROR: occupancy test FIFO word 1 mismatch. exp=%h got=%h",
                 {expected_reply_payload, expected_reply_period}, read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[3:0] !== 4'h2) begin
        $display("ERROR: occupancy test tag 1 mismatch. exp=2 got=%h", read_data_reg[3:0]);
        $fatal;
    end

    axil_write(ADDR_IRQ_STATUS, 32'h0000_0002);
    repeat (5) @(posedge clk);
    if (irq !== 1'b0) begin
        $display("ERROR: occupancy IRQ did not clear");
        $fatal;
    end

    axil_write(ADDR_IRQ_MASK, 32'h0000_0004);
    axil_write(ADDR_IRQ_OCC, 32'h0000_0000);
    axil_write(ADDR_IRQ_AGE, 32'h0000_0010);

    expected_frame_count = expected_frame_count + 1;
    axil_write(ADDR_TX12, {8'h00, 4'h6, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    ensure_no_irq_cycles(8);
    wait_for_irq_assert;

    axil_read(ADDR_IRQ_STATUS, read_data_reg);
    if (read_data_reg[20:16] !== 5'b00100) begin
        $display("ERROR: expected age IRQ pending bit set, got %h", read_data_reg[20:16]);
        $fatal;
    end

    axil_read(ADDR_RX_FIFO_DATA, read_data_reg);
    if (read_data_reg !== {expected_reply_payload, expected_reply_period}) begin
        $display("ERROR: age test FIFO word mismatch. exp=%h got=%h",
                 {expected_reply_payload, expected_reply_period}, read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[3:0] !== 4'h6) begin
        $display("ERROR: age test tag mismatch. exp=6 got=%h", read_data_reg[3:0]);
        $fatal;
    end

    axil_write(ADDR_IRQ_STATUS, 32'h0000_0004);
    repeat (5) @(posedge clk);
    if (irq !== 1'b0) begin
        $display("ERROR: age IRQ did not clear");
        $fatal;
    end

    esc_reply_enable = 1'b0;
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b0});
    axil_write(ADDR_IRQ_STATUS, 32'h0000_001F);

    axil_write(ADDR_IRQ_MASK, 32'h0000_0008);
    expected_frame_count = expected_frame_count + 1;
    axil_write(ADDR_TX16, {8'h00, TAG_TX_DONE, 4'h0, 16'h5AA5});
    wait_for_irq_assert;
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;

    axil_read(ADDR_IRQ_STATUS, read_data_reg);
    if (read_data_reg[20:16] !== 5'b01000) begin
        $display("ERROR: expected TX complete IRQ pending bit set, got %h", read_data_reg[20:16]);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[7:4] !== TAG_TX_DONE) begin
        $display("ERROR: last TX done tag mismatch. exp=%h got=%h", TAG_TX_DONE, read_data_reg[7:4]);
        $fatal;
    end

    axil_write(ADDR_IRQ_STATUS, 32'h0000_0008);
    repeat (5) @(posedge clk);
    if (irq !== 1'b0) begin
        $display("ERROR: TX complete IRQ did not clear");
        $fatal;
    end

    axil_write(ADDR_IRQ_STATUS, 32'h0000_001F);
    axil_write(ADDR_IRQ_MASK, 32'h0000_0010);
    expected_frame_count = expected_frame_count + 2;
    axil_write(ADDR_TX16, {8'h00, TAG_TX_QUEUE0, 4'h0, 16'h1111});
    axil_write(ADDR_TX16, {8'h00, TAG_TX_QUEUE1, 4'h0, 16'h2222});
    ensure_no_irq_cycles(16);
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    if (esc_frame_word !== 16'h2222) begin
        $display("ERROR: queued TX final frame mismatch. exp=2222 got=%h", esc_frame_word);
        $fatal;
    end
    wait_for_irq_assert;

    axil_read(ADDR_IRQ_STATUS, read_data_reg);
    if (read_data_reg[20:16] !== 5'b10000) begin
        $display("ERROR: expected TX empty IRQ pending bit set, got %h", read_data_reg[20:16]);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[7:4] !== TAG_TX_QUEUE1) begin
        $display("ERROR: queued TX last done tag mismatch. exp=%h got=%h", TAG_TX_QUEUE1, read_data_reg[7:4]);
        $fatal;
    end

    axil_write(ADDR_IRQ_STATUS, 32'h0000_0010);
    repeat (5) @(posedge clk);
    if (irq !== 1'b0) begin
        $display("ERROR: TX empty IRQ did not clear");
        $fatal;
    end

    axil_write(ADDR_IRQ_MASK, 32'h0000_0000);
    esc_reply_enable = 1'b1;
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b1});
    expected_frame_count = expected_frame_count + 1;
    axil_write(ADDR_TX12, {8'h00, 4'h7, 4'h0, 4'h0, tx12_value});
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[10] !== 1'b0) begin
        $display("ERROR: expected RX FIFO non-empty before RX reset");
        $fatal;
    end

    axil_write(ADDR_CONTROL, ((32'h1 << CONTROL_RX_FIFO_RST_BIT) | (DSHOT_SPEED_600 << 2) | 32'h1));
    repeat (3) @(posedge clk);
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[10] !== 1'b1 || read_data_reg[9:5] !== 5'd0) begin
        $display("ERROR: RX FIFO reset did not empty FIFO. status=%h", read_data_reg);
        $fatal;
    end
    axil_read(ADDR_RX_FIFO_TAG, read_data_reg);
    if (read_data_reg[3:0] !== 4'h0) begin
        $display("ERROR: RX FIFO tag latch not cleared by RX reset. got=%h", read_data_reg[3:0]);
        $fatal;
    end

    esc_reply_enable = 1'b0;
    axil_write(ADDR_CONTROL, {27'h0, DSHOT_SPEED_600, 1'b0, 1'b0});
    axil_write(ADDR_IRQ_STATUS, 32'h0000_001F);
    axil_write(ADDR_TX16, {8'h00, 4'h8, 4'h0, 16'h3333});
    axil_write(ADDR_TX16, {8'h00, 4'h9, 4'h0, 16'h4444});
    axil_write(ADDR_CONTROL, ((32'h1 << CONTROL_TX_FIFO_RST_BIT) | (DSHOT_SPEED_600 << 2)));
    expected_frame_count = expected_frame_count + 1;
    wait_for_frame_count(expected_frame_count);
    wait_core_idle;
    ensure_no_irq_cycles(64);
    if (esc_frame_count !== expected_frame_count) begin
        $display("ERROR: TX FIFO reset allowed extra frame. exp=%0d got=%0d",
                 expected_frame_count, esc_frame_count);
        $fatal;
    end
    axil_read(ADDR_STATUS, read_data_reg);
    if (read_data_reg[18] !== 1'b1 || read_data_reg[17:13] !== 5'd0) begin
        $display("ERROR: TX FIFO reset did not empty FIFO. status=%h", read_data_reg);
        $fatal;
    end

    $display("PASS: queued TX, tagged RX FIFO, IRQ paths, and FIFO reset controls");
    $finish;
end

endmodule
