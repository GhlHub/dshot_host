`timescale 1ns / 1ps

module dshot_seq_ctrl(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [3:0]  tx_repeat_m1,
    input  wire        bidir_en,
    input  wire        tx_done,
    input  wire        turnaround_done,
    input  wire        rx_done,
    output reg         tx_start,
    output reg         turnaround_wait,
    output reg         rx_enable,
    output reg         busy,
    output reg         done
    );

localparam [2:0] ST_IDLE       = 3'd0;
localparam [2:0] ST_LAUNCH     = 3'd1;
localparam [2:0] ST_TX         = 3'd2;
localparam [2:0] ST_TURNAROUND = 3'd3;
localparam [2:0] ST_RX         = 3'd4;
localparam [2:0] ST_DONE       = 3'd5;

reg [2:0] state_reg;
reg [2:0] next_state;
reg [3:0] repeats_left_reg;

always @(*) begin
    tx_start        = 1'b0;
    turnaround_wait = 1'b0;
    rx_enable       = 1'b0;
    busy            = 1'b1;
    done            = 1'b0;
    next_state      = state_reg;

    case (state_reg)
        ST_IDLE: begin
            busy = 1'b0;
            if (start) begin
                next_state = ST_LAUNCH;
            end
        end

        ST_LAUNCH: begin
            tx_start   = 1'b1;
            next_state = ST_TX;
        end

        ST_TX: begin
            if (tx_done) begin
                if (bidir_en) begin
                    next_state = ST_TURNAROUND;
                end else if (repeats_left_reg != 4'h0) begin
                    next_state = ST_LAUNCH;
                end else begin
                    next_state = ST_DONE;
                end
            end
        end

        ST_TURNAROUND: begin
            turnaround_wait = 1'b1;
            if (turnaround_done) begin
                next_state = ST_RX;
            end
        end

        ST_RX: begin
            rx_enable = 1'b1;
            if (rx_done) begin
                if (repeats_left_reg != 4'h0) begin
                    next_state = ST_LAUNCH;
                end else begin
                    next_state = ST_DONE;
                end
            end
        end

        ST_DONE: begin
            busy       = 1'b0;
            done       = 1'b1;
            next_state = ST_IDLE;
        end

        default: begin
            next_state = ST_IDLE;
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg        <= ST_IDLE;
        repeats_left_reg <= 4'h0;
    end else begin
        state_reg <= next_state;

        if (state_reg == ST_IDLE && start) begin
            repeats_left_reg <= tx_repeat_m1;
        end else if ((state_reg == ST_TX && tx_done && !bidir_en && (repeats_left_reg != 4'h0)) ||
                     (state_reg == ST_RX && rx_done && (repeats_left_reg != 4'h0))) begin
            repeats_left_reg <= repeats_left_reg - 4'h1;
        end
    end
end

endmodule
