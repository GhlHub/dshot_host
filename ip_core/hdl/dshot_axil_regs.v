`timescale 1ns / 1ps

module dshot_axil_regs(
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
    output wire        start,
    output wire        tx_use_raw,
    output wire [3:0]  tx_repeat_m1,
    output wire        bidir_en,
    output wire [11:0] tx_value12,
    output wire [15:0] tx_frame_raw,
    output wire [15:0] t0h_clks,
    output wire [15:0] t1h_clks,
    output wire [15:0] bit_clks,
    output wire [15:0] turnaround_clks,
    output wire [15:0] rx_sample_clks,
    output wire [15:0] rx_timeout_clks,
    input  wire        busy,
    input  wire        done,
    input  wire        tx_done,
    input  wire        rx_valid,
    input  wire        rx_crc_ok,
    input  wire        code_error,
    input  wire        edt_valid,
    input  wire [3:0]  edt_type,
    input  wire [7:0]  edt_data,
    input  wire [15:0] erpm_period,
    input  wire        rx_fifo_wr_en,
    input  wire [31:0] rx_fifo_wdata,
    output wire        irq
    );

localparam [7:0] ADDR_CONTROL        = 8'h00;
localparam [7:0] ADDR_STATUS         = 8'h04;
localparam [7:0] ADDR_TX12           = 8'h08;
localparam [7:0] ADDR_TX16           = 8'h0C;
localparam [7:0] ADDR_T0H            = 8'h10;
localparam [7:0] ADDR_T1H            = 8'h14;
localparam [7:0] ADDR_BIT            = 8'h18;
localparam [7:0] ADDR_TURNAROUND     = 8'h1C;
localparam [7:0] ADDR_RX_SAMPLE      = 8'h20;
localparam [7:0] ADDR_RX_TIMEOUT     = 8'h24;
localparam [7:0] ADDR_RX_FIFO_DATA   = 8'h28;
localparam [7:0] ADDR_RX_FIFO_STATUS = 8'h2C;
localparam [7:0] ADDR_IRQ_MASK       = 8'h30;
localparam [7:0] ADDR_IRQ_STATUS     = 8'h34;
localparam [7:0] ADDR_IRQ_OCC        = 8'h38;
localparam [7:0] ADDR_IRQ_AGE        = 8'h3C;

localparam integer CONTROL_BIDIR_EN_BIT = 0;
localparam integer CONTROL_SPEED_LSB    = 2;
localparam integer CONTROL_SPEED_MSB    = 4;

localparam [2:0] DSHOT_SPEED_150  = 3'd0;
localparam [2:0] DSHOT_SPEED_300  = 3'd1;
localparam [2:0] DSHOT_SPEED_600  = 3'd2;
localparam [2:0] DSHOT_SPEED_1200 = 3'd3;
localparam [2:0] IRQ_CAUSE_NONEMPTY = 3'b001;
localparam [2:0] IRQ_CAUSE_OCC      = 3'b010;
localparam [2:0] IRQ_CAUSE_AGE      = 3'b100;

reg        awaddr_valid_reg;
reg [7:0]  awaddr_reg;
reg        wdata_valid_reg;
reg [31:0] wdata_reg;
reg [3:0]  wstrb_reg;
reg        bvalid_reg;
reg        araddr_valid_reg;
reg [7:0]  araddr_reg;
reg        rvalid_reg;
reg [31:0] rdata_reg;

reg        start_reg;
reg        tx_use_raw_reg;
reg [3:0]  tx_repeat_m1_reg;
reg [3:0]  tx12_repeat_m1_reg;
reg [3:0]  tx16_repeat_m1_reg;
reg        bidir_en_reg;
reg [2:0]  dshot_speed_reg;
reg [11:0] tx_value12_reg;
reg [15:0] tx_frame_raw_reg;
reg [15:0] t0h_clks_reg;
reg [15:0] t1h_clks_reg;
reg [15:0] bit_clks_reg;
reg [15:0] turnaround_clks_reg;
reg [15:0] rx_sample_clks_reg;
reg [15:0] rx_timeout_clks_reg;

reg [2:0]  irq_mask_reg;
reg [2:0]  irq_pending_reg;
reg [7:0]  irq_occ_threshold_reg;
reg [15:0] irq_age_threshold_reg;
reg [15:0] fifo_age_reg;
reg        sticky_done_reg;
reg        sticky_tx_done_reg;
reg        sticky_rx_valid_reg;
reg        sticky_code_error_reg;
reg [31:0] last_rx_word_reg;
reg        last_edt_valid_reg;
reg [3:0]  last_edt_type_reg;
reg [7:0]  last_edt_data_reg;
reg [15:0] last_erpm_period_reg;

wire write_fire;
wire read_fire;
wire [31:0] control_wdata;
wire [31:0] tx12_wdata;
wire [31:0] tx16_wdata;
wire [31:0] t0h_wdata;
wire [31:0] t1h_wdata;
wire [31:0] bit_wdata;
wire [31:0] turnaround_wdata;
wire [31:0] rx_sample_wdata;
wire [31:0] rx_timeout_wdata;
wire [31:0] irq_mask_wdata;
wire [31:0] irq_occ_wdata;
wire [31:0] irq_age_wdata;
wire [31:0] status_wdata;
wire [2:0]  irq_clear_mask;
wire [4:0]  fifo_occupancy;
wire [31:0] fifo_rd_data;
wire        fifo_empty;
wire        fifo_full;
wire        fifo_overflow;
wire        fifo_pop;
wire        fifo_do_read;
wire        fifo_do_write;
wire [4:0]  fifo_occupancy_next;
wire        fifo_nonempty_next;
wire [2:0]  irq_raw_status;
wire [31:0] control_readback;

assign s_axi_awready = ~awaddr_valid_reg;
assign s_axi_wready  = ~wdata_valid_reg;
assign s_axi_bresp   = 2'b00;
assign s_axi_bvalid  = bvalid_reg;
assign s_axi_arready = ~araddr_valid_reg & ~rvalid_reg;
assign s_axi_rdata   = rdata_reg;
assign s_axi_rresp   = 2'b00;
assign s_axi_rvalid  = rvalid_reg;

assign write_fire = awaddr_valid_reg & wdata_valid_reg & ~bvalid_reg;
assign read_fire  = araddr_valid_reg & ~rvalid_reg;

assign start           = start_reg;
assign tx_use_raw      = tx_use_raw_reg;
assign tx_repeat_m1    = tx_repeat_m1_reg;
assign bidir_en        = bidir_en_reg;
assign tx_value12      = tx_value12_reg;
assign tx_frame_raw    = tx_frame_raw_reg;
assign t0h_clks        = t0h_clks_reg;
assign t1h_clks        = t1h_clks_reg;
assign bit_clks        = bit_clks_reg;
assign turnaround_clks = turnaround_clks_reg;
assign rx_sample_clks  = rx_sample_clks_reg;
assign rx_timeout_clks = rx_timeout_clks_reg;
assign irq             = |(irq_pending_reg & irq_mask_reg);
assign control_readback = {24'h0, dshot_speed_reg, 1'b0, bidir_en_reg};

function [31:0] apply_wstrb32;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0]  strobe;
    begin
        apply_wstrb32 = old_value;
        if (strobe[0]) apply_wstrb32[7:0]   = new_value[7:0];
        if (strobe[1]) apply_wstrb32[15:8]  = new_value[15:8];
        if (strobe[2]) apply_wstrb32[23:16] = new_value[23:16];
        if (strobe[3]) apply_wstrb32[31:24] = new_value[31:24];
    end
endfunction

assign control_wdata    = apply_wstrb32(control_readback, wdata_reg, wstrb_reg);
assign tx12_wdata       = apply_wstrb32({12'h000, tx12_repeat_m1_reg, 4'h0, tx_value12_reg}, wdata_reg, wstrb_reg);
assign tx16_wdata       = apply_wstrb32({12'h000, tx16_repeat_m1_reg, tx_frame_raw_reg}, wdata_reg, wstrb_reg);
assign t0h_wdata        = apply_wstrb32({16'h0000, t0h_clks_reg}, wdata_reg, wstrb_reg);
assign t1h_wdata        = apply_wstrb32({16'h0000, t1h_clks_reg}, wdata_reg, wstrb_reg);
assign bit_wdata        = apply_wstrb32({16'h0000, bit_clks_reg}, wdata_reg, wstrb_reg);
assign turnaround_wdata = apply_wstrb32({16'h0000, turnaround_clks_reg}, wdata_reg, wstrb_reg);
assign rx_sample_wdata  = apply_wstrb32({16'h0000, rx_sample_clks_reg}, wdata_reg, wstrb_reg);
assign rx_timeout_wdata = apply_wstrb32({16'h0000, rx_timeout_clks_reg}, wdata_reg, wstrb_reg);
assign irq_mask_wdata   = apply_wstrb32({29'h0, irq_mask_reg}, wdata_reg, wstrb_reg);
assign irq_occ_wdata    = apply_wstrb32({24'h0, irq_occ_threshold_reg}, wdata_reg, wstrb_reg);
assign irq_age_wdata    = apply_wstrb32({16'h0, irq_age_threshold_reg}, wdata_reg, wstrb_reg);
assign status_wdata     = apply_wstrb32(32'h0, wdata_reg, wstrb_reg);
assign irq_clear_mask   = (write_fire && (awaddr_reg == ADDR_IRQ_STATUS) && wstrb_reg[0]) ? wdata_reg[2:0] : 3'b000;

assign fifo_pop         = read_fire && (araddr_reg == ADDR_RX_FIFO_DATA) && !fifo_empty;
assign fifo_do_read     = fifo_pop;
assign fifo_do_write    = rx_fifo_wr_en && (!fifo_full || fifo_do_read);
assign fifo_occupancy_next = fifo_occupancy +
                             (fifo_do_write ? 5'd1 : 5'd0) -
                             (fifo_do_read ? 5'd1 : 5'd0);
assign fifo_nonempty_next = (fifo_occupancy_next != 5'd0);

assign irq_raw_status[0] = !fifo_empty;
assign irq_raw_status[1] = (irq_occ_threshold_reg != 8'h00) && (fifo_occupancy >= irq_occ_threshold_reg[4:0]);
assign irq_raw_status[2] = (irq_age_threshold_reg != 16'h0000) && !fifo_empty &&
                           (fifo_age_reg >= irq_age_threshold_reg);

dshot_rx_fifo #(
    .DATA_W(32),
    .DEPTH (16),
    .ADDR_W(4)
) u_dshot_rx_fifo (
    .clk      (s_axi_aclk),
    .rst      (~s_axi_aresetn),
    .wr_en    (rx_fifo_wr_en),
    .wr_data  (rx_fifo_wdata),
    .rd_en    (fifo_pop),
    .rd_data  (fifo_rd_data),
    .empty    (fifo_empty),
    .full     (fifo_full),
    .occupancy(fifo_occupancy),
    .overflow (fifo_overflow)
);

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        awaddr_valid_reg    <= 1'b0;
        awaddr_reg          <= 8'h00;
        wdata_valid_reg     <= 1'b0;
        wdata_reg           <= 32'h0000_0000;
        wstrb_reg           <= 4'h0;
        bvalid_reg          <= 1'b0;
        araddr_valid_reg    <= 1'b0;
        araddr_reg          <= 8'h00;
        rvalid_reg          <= 1'b0;
        rdata_reg           <= 32'h0000_0000;
        start_reg           <= 1'b0;
        tx_use_raw_reg      <= 1'b0;
        tx_repeat_m1_reg    <= 4'h0;
        tx12_repeat_m1_reg  <= 4'h0;
        tx16_repeat_m1_reg  <= 4'h0;
        bidir_en_reg        <= 1'b0;
        dshot_speed_reg     <= DSHOT_SPEED_600;
        tx_value12_reg      <= 12'h000;
        tx_frame_raw_reg    <= 16'h0000;
        t0h_clks_reg        <= 16'd38;
        t1h_clks_reg        <= 16'd75;
        bit_clks_reg        <= 16'd100;
        turnaround_clks_reg <= 16'd1800;
        rx_sample_clks_reg  <= 16'd16;
        rx_timeout_clks_reg <= 16'd2000;
        irq_mask_reg        <= 3'b000;
        irq_pending_reg     <= 3'b000;
        irq_occ_threshold_reg <= 8'd0;
        irq_age_threshold_reg <= 16'd0;
        fifo_age_reg        <= 16'd0;
        sticky_done_reg     <= 1'b0;
        sticky_tx_done_reg  <= 1'b0;
        sticky_rx_valid_reg <= 1'b0;
        sticky_code_error_reg <= 1'b0;
        last_rx_word_reg    <= 32'h0000_0000;
        last_edt_valid_reg  <= 1'b0;
        last_edt_type_reg   <= 4'h0;
        last_edt_data_reg   <= 8'h00;
        last_erpm_period_reg<= 16'h0000;
    end else begin
        start_reg <= 1'b0;

        if (s_axi_awvalid && s_axi_awready) begin
            awaddr_valid_reg <= 1'b1;
            awaddr_reg       <= s_axi_awaddr;
        end

        if (s_axi_wvalid && s_axi_wready) begin
            wdata_valid_reg <= 1'b1;
            wdata_reg       <= s_axi_wdata;
            wstrb_reg       <= s_axi_wstrb;
        end

        if (write_fire) begin
            case (awaddr_reg)
                ADDR_CONTROL: begin
                    bidir_en_reg <= control_wdata[CONTROL_BIDIR_EN_BIT];
                    dshot_speed_reg <= control_wdata[CONTROL_SPEED_MSB:CONTROL_SPEED_LSB];
                    case (control_wdata[CONTROL_SPEED_MSB:CONTROL_SPEED_LSB])
                        DSHOT_SPEED_150: begin
                            t0h_clks_reg <= 16'd150;
                            t1h_clks_reg <= 16'd300;
                            bit_clks_reg <= 16'd400;
                            rx_sample_clks_reg <= 16'd64;
                            rx_timeout_clks_reg <= 16'd8000;
                        end
                        DSHOT_SPEED_300: begin
                            t0h_clks_reg <= 16'd75;
                            t1h_clks_reg <= 16'd150;
                            bit_clks_reg <= 16'd200;
                            rx_sample_clks_reg <= 16'd32;
                            rx_timeout_clks_reg <= 16'd4000;
                        end
                        DSHOT_SPEED_600: begin
                            t0h_clks_reg <= 16'd38;
                            t1h_clks_reg <= 16'd75;
                            bit_clks_reg <= 16'd100;
                            rx_sample_clks_reg <= 16'd16;
                            rx_timeout_clks_reg <= 16'd2000;
                        end
                        DSHOT_SPEED_1200: begin
                            t0h_clks_reg <= 16'd19;
                            t1h_clks_reg <= 16'd38;
                            bit_clks_reg <= 16'd50;
                            rx_sample_clks_reg <= 16'd8;
                            rx_timeout_clks_reg <= 16'd1000;
                        end
                        default: begin
                            t0h_clks_reg <= 16'd38;
                            t1h_clks_reg <= 16'd75;
                            bit_clks_reg <= 16'd100;
                            rx_sample_clks_reg <= 16'd16;
                            rx_timeout_clks_reg <= 16'd2000;
                        end
                    endcase
                end
                ADDR_STATUS: begin
                    sticky_done_reg       <= sticky_done_reg & ~status_wdata[1];
                    sticky_tx_done_reg    <= sticky_tx_done_reg & ~status_wdata[2];
                    sticky_rx_valid_reg   <= sticky_rx_valid_reg & ~status_wdata[3];
                    sticky_code_error_reg <= sticky_code_error_reg & ~status_wdata[4];
                end
                ADDR_TX12: begin
                    tx_value12_reg     <= tx12_wdata[11:0];
                    tx12_repeat_m1_reg <= tx12_wdata[19:16];
                    tx_use_raw_reg     <= 1'b0;
                    tx_repeat_m1_reg   <= tx12_wdata[19:16];
                    start_reg          <= 1'b1;
                end
                ADDR_TX16: begin
                    tx_frame_raw_reg   <= tx16_wdata[15:0];
                    tx16_repeat_m1_reg <= tx16_wdata[19:16];
                    tx_use_raw_reg     <= 1'b1;
                    tx_repeat_m1_reg   <= tx16_wdata[19:16];
                    start_reg          <= 1'b1;
                end
                ADDR_T0H: begin
                    t0h_clks_reg <= t0h_wdata[15:0];
                end
                ADDR_T1H: begin
                    t1h_clks_reg <= t1h_wdata[15:0];
                end
                ADDR_BIT: begin
                    bit_clks_reg <= bit_wdata[15:0];
                end
                ADDR_TURNAROUND: begin
                    turnaround_clks_reg <= turnaround_wdata[15:0];
                end
                ADDR_RX_SAMPLE: begin
                    rx_sample_clks_reg <= rx_sample_wdata[15:0];
                end
                ADDR_RX_TIMEOUT: begin
                    rx_timeout_clks_reg <= rx_timeout_wdata[15:0];
                end
                ADDR_IRQ_MASK: begin
                    irq_mask_reg <= irq_mask_wdata[2:0];
                end
                ADDR_IRQ_OCC: begin
                    irq_occ_threshold_reg <= irq_occ_wdata[7:0];
                end
                ADDR_IRQ_AGE: begin
                    irq_age_threshold_reg <= irq_age_wdata[15:0];
                end
                default: begin
                end
            endcase

            awaddr_valid_reg <= 1'b0;
            wdata_valid_reg  <= 1'b0;
            bvalid_reg       <= 1'b1;
        end

        if (bvalid_reg && s_axi_bready) begin
            bvalid_reg <= 1'b0;
        end

        if (s_axi_arvalid && s_axi_arready) begin
            araddr_valid_reg <= 1'b1;
            araddr_reg       <= s_axi_araddr;
        end

        if (read_fire) begin
            case (araddr_reg)
                ADDR_CONTROL: begin
                    rdata_reg <= control_readback;
                end
                ADDR_STATUS: begin
                    rdata_reg <= {19'h0, fifo_overflow, fifo_full, fifo_empty, fifo_occupancy,
                                  sticky_code_error_reg, sticky_rx_valid_reg, sticky_tx_done_reg,
                                  sticky_done_reg, busy};
                end
                ADDR_TX12: begin
                    rdata_reg <= {12'h000, tx12_repeat_m1_reg, 4'h0, tx_value12_reg};
                end
                ADDR_TX16: begin
                    rdata_reg <= {12'h000, tx16_repeat_m1_reg, tx_frame_raw_reg};
                end
                ADDR_T0H: begin
                    rdata_reg <= {16'h0000, t0h_clks_reg};
                end
                ADDR_T1H: begin
                    rdata_reg <= {16'h0000, t1h_clks_reg};
                end
                ADDR_BIT: begin
                    rdata_reg <= {16'h0000, bit_clks_reg};
                end
                ADDR_TURNAROUND: begin
                    rdata_reg <= {16'h0000, turnaround_clks_reg};
                end
                ADDR_RX_SAMPLE: begin
                    rdata_reg <= {16'h0000, rx_sample_clks_reg};
                end
                ADDR_RX_TIMEOUT: begin
                    rdata_reg <= {16'h0000, rx_timeout_clks_reg};
                end
                ADDR_RX_FIFO_DATA: begin
                    rdata_reg <= fifo_empty ? 32'h0000_0000 : fifo_rd_data;
                end
                ADDR_RX_FIFO_STATUS: begin
                    rdata_reg <= {fifo_overflow, fifo_full, fifo_empty, irq, irq_pending_reg,
                                  4'h0, fifo_occupancy, last_erpm_period_reg};
                end
                ADDR_IRQ_MASK: begin
                    rdata_reg <= {29'h0, irq_mask_reg};
                end
                ADDR_IRQ_STATUS: begin
                    rdata_reg <= {10'h0, irq_raw_status, irq_pending_reg, fifo_age_reg};
                end
                ADDR_IRQ_OCC: begin
                    rdata_reg <= {24'h0, irq_occ_threshold_reg};
                end
                ADDR_IRQ_AGE: begin
                    rdata_reg <= {16'h0, irq_age_threshold_reg};
                end
                default: begin
                    rdata_reg <= 32'h0000_0000;
                end
            endcase

            araddr_valid_reg <= 1'b0;
            rvalid_reg       <= 1'b1;
        end

        if (rvalid_reg && s_axi_rready) begin
            rvalid_reg <= 1'b0;
        end

        if (done) begin
            sticky_done_reg <= 1'b1;
        end
        if (tx_done) begin
            sticky_tx_done_reg <= 1'b1;
        end
        if (rx_valid) begin
            sticky_rx_valid_reg  <= 1'b1;
            last_rx_word_reg     <= rx_fifo_wdata;
            last_edt_valid_reg   <= edt_valid;
            last_edt_type_reg    <= edt_type;
            last_edt_data_reg    <= edt_data;
            last_erpm_period_reg <= erpm_period;
        end
        if (code_error || (rx_valid && !rx_crc_ok)) begin
            sticky_code_error_reg <= 1'b1;
        end

        irq_pending_reg <= (irq_pending_reg & ~irq_clear_mask) | (irq_raw_status & irq_mask_reg);

        case ({(fifo_occupancy != 5'd0), fifo_nonempty_next})
            2'b01: fifo_age_reg <= 16'd0;
            2'b11: begin
                if (fifo_age_reg != 16'hFFFF) begin
                    fifo_age_reg <= fifo_age_reg + 16'd1;
                end
            end
            default: fifo_age_reg <= 16'd0;
        endcase
    end
end

endmodule
