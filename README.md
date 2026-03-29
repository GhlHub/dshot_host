# DSHOT Host

AXI-Lite controlled DSHOT host IP with optional bidirectional eRPM receive support.

## Contents

- `rtl/`: synthesizable RTL source
- `tb/`: simulation testbench and DSHOT ESC model
- `doc/`: protocol notes and theory-of-operation documents
- `ip_repo/dshot_axil/`: Vivado-style packaged IP core for automatic Vivado repository discovery

## Features

- AXI-Lite slave control interface
- Normal and bidirectional DSHOT transmit
- `TX12` register for auto-CRC frame generation
- `TX16` register for raw 16-bit frame transmit
- Repeat-count field on transmit commands
- Built-in speed presets for DSHOT150/300/600/1200
- Bidirectional eRPM receive path
- `5x` oversampling with 3-of-5 majority vote in the RX frontend
- RX FIFO for host-side data retrieval
- Interrupt output with mask, FIFO occupancy coalescing, and age-based coalescing

## Clocking

Current design assumption:

- single clock domain
- AXI-Lite and DSHOT core both run at `60 MHz`

The built-in DSHOT presets are derived for `60 MHz`.

## Top-Level RTL

The main top-level module is:

- `rtl/dshot_axil_top.v`

Primary external interfaces:

- AXI-Lite slave
- DSHOT pin triplet: `pin_o`, `pin_oe`, `pin_i`
- interrupt output: `irq`

The design intentionally exposes `pin_o`, `pin_oe`, and `pin_i` instead of instantiating a Xilinx `IOBUF` primitive inside the core.

## Register Highlights

Implemented in `rtl/dshot_axil_regs.v`.

- `0x00`: control
  - bit `0`: bidirectional DSHOT enable
  - bits `[4:2]`: DSHOT speed select
- `0x08`: `TX12`
  - bits `[19:16]`: repeat minus one
  - bits `[11:0]`: 12-bit pre-CRC payload
- `0x0C`: `TX16`
  - bits `[19:16]`: repeat minus one
  - bits `[15:0]`: raw frame
- `0x28`: RX FIFO data pop
- `0x2C`: RX FIFO status
- `0x30`: IRQ mask
- `0x34`: IRQ pending / age status
- `0x38`: IRQ occupancy threshold
- `0x3C`: IRQ age threshold

## Receive Path

The bidirectional receive path is:

```text
pin_i
  -> dshot_rx_frontend
  -> dshot_gcr_decode
  -> dshot_erpm_decode
  -> dshot_rx_fifo
  -> AXI-Lite host readout
```

The current RX FIFO entry format is:

```text
{payload_word[15:0], erpm_period[15:0]}
```

## Simulation

Main testbench files:

- `tb/dshot_axil_top_tb.v`
- `tb/dshot_esc_model.v`

Example simulation flow:

```sh
cd rtl
iverilog -g2005-sv -o dshot_axil_top_tb.out *.v ../tb/*.v
vvp ./dshot_axil_top_tb.out
```

The current self-checking testbench covers:

- AXI-Lite control writes and reads
- normal DSHOT transmit
- inverted DSHOT transmit
- raw and auto-CRC transmit paths
- bidirectional receive
- RX FIFO readout
- IRQ assertion and clear behavior

## Vivado IP Packaging

Packaged IP contents are under:

- `ip_repo/dshot_axil/`

The packaging helper script is:

- `package_ip_core.tcl`

## Documentation

- `doc/dshot_implementation_note.md`
- `doc/theory_of_operation.md`
- `rtl/dshot_module_breakdown.md`

## Current Limits

- RX capture uses fixed `5x` oversampling and majority vote, but not adaptive clock recovery
- hardware tuning of RX timing is still expected
- FIFO entries do not currently carry extended per-entry metadata beyond payload and decoded period
