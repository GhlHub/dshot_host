# Agent Notes

## Scope

This project contains a standalone AXI-Lite controlled DSHOT block with optional bidirectional receive support.

Current design assumption:

- Single clock domain at `60 MHz`
- AXI-Lite slave and DSHOT core share the same clock

## Main Files

- `rtl/dshot_axil_top.v`: top-level wrapper with AXI-Lite, DSHOT pins, and `irq`
- `rtl/dshot_axil_regs.v`: AXI-Lite register bank, RX FIFO handling, and IRQ generation
- `rtl/dshot_core.v`: DSHOT TX/RX integration below the register layer
- `rtl/dshot_seq_ctrl.v`: transaction sequencer with repeat handling
- `rtl/dshot_tx_engine.v`: DSHOT waveform generator
- `rtl/dshot_rx_frontend.v`: bidirectional reply capture frontend
- `rtl/dshot_gcr_decode.v`: 21-bit symbol to 16-bit payload decode
- `rtl/dshot_erpm_decode.v`: payload CRC, eRPM period, and EDT decode
- `rtl/dshot_rx_fifo.v`: single-clock FIFO for received words
- `rtl/dshot_module_breakdown.md`: architecture note

## Testbench Files

Testbench sources live in `tb/`:

- `tb/dshot_axil_top_tb.v`: AXI-Lite testbench at `60 MHz`
- `tb/dshot_esc_model.v`: DSHOT receiver / ESC simulation model

## Control/Register Model

Key registers are implemented in `rtl/dshot_axil_regs.v`:

- `0x00` control
  - bit `0`: bidirectional DSHOT enable
  - bits `[4:2]`: speed select
    - `0`: DSHOT150
    - `1`: DSHOT300
    - `2`: DSHOT600
    - `3`: DSHOT1200
- `0x08` TX12
  - bits `[19:16]`: repeat minus 1
  - bits `[11:0]`: 12-bit pre-CRC payload
- `0x0C` TX16
  - bits `[19:16]`: repeat minus 1
  - bits `[15:0]`: raw 16-bit frame
- `0x28` RX FIFO data
  - read pops one entry
- `0x2C` RX FIFO status
- `0x30` IRQ mask
- `0x34` IRQ status / pending
- `0x38` IRQ occupancy threshold
- `0x3C` IRQ age threshold

## Built-In Timing Presets

The control register speed field loads these presets for `60 MHz`:

- DSHOT150: `T0H=150`, `T1H=300`, `BIT=400`
- DSHOT300: `T0H=75`, `T1H=150`, `BIT=200`
- DSHOT600: `T0H=38`, `T1H=75`, `BIT=100`
- DSHOT1200: `T0H=19`, `T1H=38`, `BIT=50`

The speed presets also load `5x` RX oversample intervals for the returned bidirectional eRPM stream:

- DSHOT150: `rx_sample_clks=64`
- DSHOT300: `rx_sample_clks=32`
- DSHOT600: `rx_sample_clks=16`
- DSHOT1200: `rx_sample_clks=8`

Software can still overwrite the timing registers directly after selecting a preset.

## RX FIFO Format

Current FIFO entry format:

```text
{payload_word[15:0], erpm_period[15:0]}
```

`payload_word` is the decoded 16-bit returned DSHOT payload after GCR decode.

## Interrupt Model

IRQ causes:

- bit `0`: RX FIFO non-empty
- bit `1`: RX FIFO occupancy >= configured threshold
- bit `2`: elapsed time since FIFO became non-empty >= configured threshold

Pending IRQ bits are masked by `0x30` and drive `irq`.

## Known Limits

- RX capture now uses fixed `5x` oversampling with 3-of-5 majority voting per returned bit, but it is still edge-started and does not implement adaptive clock/data recovery.
- RX timing registers will likely need hardware tuning.
- The RX FIFO currently stores payload and derived eRPM period, but not extra metadata such as CRC failure history per entry.
- Verification coverage is still needed. Syntax is currently checked with `iverilog -tnull *.v`.

## Safe Editing Guidance

- Keep the design single-clock unless a CDC plan is introduced explicitly.
- If timing presets are changed, update both `dshot_axil_regs.v` and `dshot_module_breakdown.md`.
- If FIFO entry format changes, update the AXI readout documentation and software expectations at the same time.
