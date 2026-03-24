# Theory Of Operation

## Overview

This design is a memory-mapped DSHOT host implemented as an AXI-Lite slave. It transmits DSHOT command frames to an ESC and, when bidirectional mode is enabled, receives and decodes the ESC response into an RX FIFO for host software.

The implementation is currently single-clock and assumes a `60 MHz` clock for both the AXI-Lite interface and the DSHOT engine.

## Top-Level Data Flow

At a high level the design is split into two domains of responsibility:

- AXI-Lite control, status, FIFO handling, and interrupt generation
- DSHOT transmit and receive processing

The signal flow is:

```text
AXI-Lite host
  -> dshot_axil_regs
  -> dshot_core
  -> DSHOT pin

Bidirectional return:
DSHOT pin
  -> dshot_core
  -> RX decode
  -> RX FIFO
  -> dshot_axil_regs
  -> AXI-Lite host
```

## AXI-Lite Control Layer

`dshot_axil_regs.v` owns the software-visible programming model.

Its main responsibilities are:

- decode AXI-Lite reads and writes
- hold control and timing registers
- convert writes to transmit registers into a one-shot `start`
- buffer received words in the RX FIFO
- provide sticky status
- generate interrupt pending bits and the top-level `irq`

### Transmit Command Model

There are two transmit write paths:

1. `TX12`
2. `TX16`

`TX12` accepts a 12-bit pre-CRC DSHOT value and computes the CRC in hardware before transmission.

`TX16` accepts a full 16-bit DSHOT frame and transmits it unchanged.

In both cases:

- bits `[19:16]` select repeat count minus one
- `0` means one transmit
- `15` means sixteen transmits

### Speed Selection

The control register includes a DSHOT speed field. When software writes the control register, the AXI block loads preset timing values for:

- `T0H`
- `T1H`
- `BIT`
- `rx_sample_clks`
- `rx_timeout_clks`

Software may still overwrite those timing registers manually afterward.

## DSHOT Transmit Path

The transmit path inside `dshot_core.v` is:

```text
dshot_frame_pack
  -> dshot_seq_ctrl
  -> dshot_tx_engine
```

### Frame Packing

`dshot_frame_pack.v` converts the 12-bit pre-CRC input into a 16-bit frame:

```text
[15:4] value12
[3:0]  crc
```

In normal DSHOT the CRC is:

```text
(value ^ (value >> 4) ^ (value >> 8)) & 0xF
```

In bidirectional DSHOT the CRC form is inverted before transmission.

### Sequencing

`dshot_seq_ctrl.v` handles:

- command start acceptance
- transmit launching
- repeat counting
- turnaround delay for bidirectional mode
- RX window enable
- overall `busy` and `done`

For repeated transmit commands, the sequencer re-enters transmit until the requested repeat count is exhausted.

### Waveform Generation

`dshot_tx_engine.v` serializes the 16-bit frame MSB-first and converts each bit into a timed waveform:

- logic `1`: long active pulse
- logic `0`: short active pulse

The active level depends on mode:

- normal DSHOT: active-high
- bidirectional DSHOT: active-low

The design exports:

- `pin_o`
- `pin_oe`

so an external wrapper can apply an FPGA-specific I/O buffer if desired.

## Bidirectional Receive Path

When bidirectional mode is enabled:

1. the transmit waveform is sent inverted
2. the transmitter releases the line
3. a turnaround counter runs
4. the receive frontend samples the ESC response

The receive chain is:

```text
dshot_rx_frontend
  -> dshot_gcr_decode
  -> dshot_erpm_decode
  -> dshot_rx_fifo
```

### RX Frontend

`dshot_rx_frontend.v` performs:

- input synchronization
- start-edge detection
- fixed `5x` oversampling
- 3-of-5 majority vote per returned bit
- collection of 21 returned bits

If no complete response arrives before `rx_timeout_clks`, the receive window times out.

This implementation is intentionally simple. It is edge-started rather than adaptive, so timing margins should still be validated on hardware.

### GCR Decode

`dshot_gcr_decode.v` reverses the ESC return encoding:

- 21-bit transition-coded symbol stream
- back to 20-bit GCR word
- split into four 5-bit code groups
- reverse-map to four 4-bit nibbles
- reassemble the original 16-bit payload

Invalid 5-bit code groups raise `code_error`.

### eRPM Decode

`dshot_erpm_decode.v` checks payload CRC and interprets the returned data.

The normal eRPM layout is:

```text
eee mmmmmmmmm cccc
```

where:

- `eee` is the exponent
- `mmmmmmmmm` is the base
- `cccc` is the CRC

The decoded period is:

```text
period = base << exponent
```

The same block also flags Extended DShot Telemetry encodings.

## RX FIFO

Valid decoded responses are pushed into `dshot_rx_fifo.v`.

This FIFO is:

- single-clock
- LUTRAM-based
- depth `16`
- width `32`

Current FIFO entry format:

```text
{payload_word[15:0], erpm_period[15:0]}
```

The FIFO allows software to read received responses asynchronously relative to the arrival of ESC replies.

## Interrupt Generation

Interrupt logic lives in `dshot_axil_regs.v`.

Three interrupt causes are supported:

1. RX FIFO non-empty
2. RX FIFO occupancy threshold reached
3. elapsed time since FIFO became non-empty exceeded the programmed threshold

Each cause:

- has a raw condition
- can be enabled or disabled by the interrupt mask register
- sets a pending bit

The top-level `irq` is asserted when any enabled pending bit is set.

### Occupancy Coalescing

Software may choose to interrupt only when the FIFO reaches a minimum occupancy. This reduces interrupt rate when the host wants to process responses in small batches instead of one-by-one.

### Age Coalescing

Software may also interrupt when data has been sitting in the FIFO for a programmed amount of time. This avoids indefinite buffering when traffic is sparse.

## Clocking And Timing Assumptions

The design currently assumes:

- AXI-Lite clock = DSHOT engine clock = `60 MHz`
- timing registers are programmed in `60 MHz` clock counts

This simplifies the design because:

- no clock-domain crossings are required
- the speed presets map directly to integer counts

If a future design uses a separate DSHOT clock, CDC handling will need to be introduced explicitly.

## Expected Integration Style

This core is intended to be integrated under a higher-level FPGA design that:

- connects the AXI-Lite interface to a processor or interconnect
- maps `pin_o`, `pin_oe`, and `pin_i` to an external DSHOT signal
- optionally instantiates a vendor-specific `IOBUF` or equivalent at the top level

The IP itself does not instantiate a Xilinx I/O buffer primitive.

## Practical Notes

- The design is functionally structured and synthesizable.
- A self-checking testbench exists under `tb/`.
- Hardware validation is still required, especially for the bidirectional receive timing.
