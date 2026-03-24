# DSHOT RTL Module Breakdown

## Top-Level Split

Fresh implementation should be split into these modules:

1. `dshot_axil_top`
2. `dshot_axil_regs`
3. `dshot_core`
4. `dshot_seq_ctrl`
5. `dshot_frame_pack`
6. `dshot_tx_engine`
7. `dshot_rx_frontend`
8. `dshot_gcr_decode`
9. `dshot_erpm_decode`

This keeps the design partitioned into:

- command packing
- transmit waveform generation
- bidirectional sequencing
- receive capture
- eRPM decode

## Signal Flow

Transmit-only path:

```text
dshot_axil_regs
  -> dshot_core
  -> dshot_seq_ctrl
  -> dshot_frame_pack
  -> dshot_tx_engine
  -> output pin
```

Bidirectional path:

```text
dshot_axil_regs
  -> dshot_core
  -> dshot_seq_ctrl
  -> dshot_frame_pack
  -> dshot_tx_engine
  -> turnaround / pin release
  -> dshot_rx_frontend
  -> dshot_gcr_decode
  -> dshot_erpm_decode
  -> decoded eRPM / EDT status
```

## Clocking Assumption

The AXI-Lite slave runs at `60 MHz`.

Recommended first implementation:

- run `dshot_axil_regs` and `dshot_core` from the same `60 MHz` clock
- avoid CDC in revision 1
- keep all timing registers expressed in `60 MHz` clock cycles

At `60 MHz`, one clock is about `16.67 ns`, which gives cleaner DSHOT timing presets than `50 MHz` while keeping the design single-clock. A later revision can still move the DSHOT engine to a separate clock if tighter timing granularity is needed.

## Module Roles

### `dshot_axil_top`

Top-level SoC-facing wrapper.

Responsibilities:

- terminate the AXI-Lite slave interface
- instantiate `dshot_axil_regs`
- instantiate `dshot_core`
- connect register fields to engine controls
- expose the DSHOT pin signals
- expose an `irq` output

### `dshot_axil_regs`

AXI-Lite register bank running at `60 MHz`.

Responsibilities:

- implement the AXI-Lite read/write handshake
- hold control and timing registers
- expose sticky status bits
- expose received data through an RX FIFO
- generate a one-shot `start` pulse into `dshot_core`
- provide two transmit write ports:
  - `TX12`: 12-bit DSHOT payload, checksum auto-generated
  - `TX16`: raw 16-bit DSHOT frame, transmitted unchanged
  - in both registers, bits `[19:16]` are `repeat_minus_1`
  - `0` means send once, `4'hF` means send 16 times
- hold interrupt mask and coalescing registers
- assert `irq` when enabled RX-FIFO conditions become pending

Suggested register map:

- `0x00`: control
  - bit `0`: bi-directional DSHOT enable
  - bits `[4:2]`: DSHOT speed select
    - `0`: DSHOT150
    - `1`: DSHOT300
    - `2`: DSHOT600
    - `3`: DSHOT1200
- `0x04`: status
- `0x08`: `TX12` write / last `TX12` value readback
- `0x0C`: `TX16` write / last `TX16` value readback
- `0x10`: timing `T0H`
- `0x14`: timing `T1H`
- `0x18`: timing `BIT`
- `0x1C`: turnaround
- `0x20`: RX sample period
- `0x24`: RX timeout
- `0x28`: RX FIFO data pop
- `0x2C`: RX FIFO status
- `0x30`: IRQ mask
- `0x34`: IRQ pending / age status
- `0x38`: IRQ occupancy threshold
- `0x3C`: IRQ age threshold

## Module Roles

### `dshot_core`

Engine-domain wrapper below the AXI register layer.

Responsibilities:

- accept register-decoded control inputs
- carry timing configuration inputs
- connect TX and RX pipeline blocks
- interpret `tx_repeat_m1` as transmit count minus one
- emit decoded RX words into a FIFO write interface
- present the physical pin controls as `pin_o`, `pin_oe`, and `pin_i`

### `dshot_seq_ctrl`

Transaction sequencer for one DSHOT exchange.

Responsibilities:

- accept a `start` request
- repeat the transmit transaction `tx_repeat_m1 + 1` times
- pulse `tx_start`
- wait for TX completion
- apply turnaround delay in bidirectional mode
- enable RX window
- terminate on valid receive or timeout
- report `busy` and `done`

This block should not know CRC, GCR, or throttle semantics. It only controls phase ordering.

### `dshot_frame_pack`

Command-frame builder.

Responsibilities:

- accept `value12[11:0]`
- compute standard or bidirectional CRC
- emit the 16-bit outbound frame

This block is pure combinational logic in the simplest implementation.

### `dshot_tx_engine`

Waveform generator for standard or inverted DSHOT.

Responsibilities:

- accept a latched 16-bit frame
- shift bits MSB first
- generate `T1H/T1L` and `T0H/T0L` timing
- drive the pin active/inactive according to polarity
- release the line at end of frame

Suggested internal split during implementation:

- bit shift register
- pulse timer
- bit counter

### `dshot_rx_frontend`

Physical receive capture for the ESC reply.

Responsibilities:

- synchronize `pin_i` into `clk`
- oversample the reply waveform at `5x`
- vote each returned bit with 3-of-5 majority sampling
- detect the reply start
- capture one 21-bit symbol stream
- assert `symbol_valid` or `timeout`

This block should stop at symbol capture. It should not know the GCR table or eRPM fields.

### `dshot_gcr_decode`

Reverse the bidirectional line coding.

Responsibilities:

- convert 21-bit captured symbol stream back to 20-bit GCR data
- reverse nibble mapping
- recover the 16-bit eRPM/EDT payload
- flag invalid codewords

### `dshot_erpm_decode`

Payload decode and integrity checking.

Responsibilities:

- validate 4-bit CRC on received payload
- decode `eee mmmmmmmmm` into `period = base << exponent`
- detect EDT payloads
- report either eRPM data or EDT fields

### `dshot_rx_fifo`

Single-clock FIFO used to buffer received DSHOT response words until software reads them.

Responsibilities:

- accept one decoded RX word per valid response
- provide occupancy, empty, full, and overflow status
- support host-driven pop on AXI-Lite read of the FIFO data register

## External Interface Recommendation

Recommended `dshot_core` host-side inputs:

- `start`
- `tx_use_raw`
- `tx_repeat_m1[3:0]`
- `bidir_en`
- `tx_value12[11:0]`
- `tx_frame_raw[15:0]`
- `t0h_clks`
- `t1h_clks`
- `bit_clks`
- `turnaround_clks`
- `rx_sample_clks`
- `rx_timeout_clks`

Recommended outputs:

- `busy`
- `done`
- `tx_done`
- `rx_valid`
- `rx_crc_ok`
- `code_error`
- `edt_valid`
- `edt_type[3:0]`
- `edt_data[7:0]`
- `erpm_period[15:0]`
- `rx_fifo_wr_en`
- `rx_fifo_wdata[31:0]`

Recommended pin interface from `dshot_core`:

- `pin_o`
- `pin_oe`
- `pin_i`

Use `pin_oe` instead of an `inout` at the module boundary so I/O buffer mapping stays explicit.

## Implementation Order

1. `dshot_axil_regs`
2. `dshot_frame_pack`
3. `dshot_tx_engine`
4. `dshot_seq_ctrl`
5. `dshot_rx_frontend`
6. `dshot_gcr_decode`
7. `dshot_erpm_decode`
8. `dshot_core`
9. `dshot_axil_top`

This order lets TX be verified before adding the bidirectional receive path.
