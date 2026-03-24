# Agent Notes

## Scope

This project contains a standalone AXI-Lite controlled DSHOT block with optional bidirectional receive support.

Current design assumption:

- Single clock domain at `60 MHz`
- AXI-Lite slave and DSHOT core share the same clock

## Main Files

- `rtl/dshot_axil_top.v`: top-level wrapper with AXI-Lite, DSHOT pins, and `irq`
- `rtl/dshot_axil_regs.v`: AXI-Lite register bank, TX/RX FIFO handling, control pulses, and IRQ generation
- `rtl/dshot_core.v`: DSHOT TX/RX integration below the register layer
- `rtl/dshot_seq_ctrl.v`: transaction sequencer with repeat handling
- `rtl/dshot_tx_engine.v`: DSHOT waveform generator
- `rtl/dshot_tx_fifo.v`: single-clock FIFO for queued transmit requests
- `rtl/dshot_rx_frontend.v`: bidirectional reply capture frontend
- `rtl/dshot_gcr_decode.v`: 21-bit symbol to 16-bit payload decode
- `rtl/dshot_erpm_decode.v`: payload CRC, eRPM period, and EDT decode
- `rtl/dshot_rx_fifo.v`: single-clock FIFO for received words
- `rtl/dshot_module_breakdown.md`: architecture note

## Testbench Files

Testbench sources live in `tb/`:

- `tb/dshot_axil_top_tb.v`: AXI-Lite testbench at `60 MHz`
- `tb/dshot_esc_model.v`: DSHOT receiver / ESC simulation model

The testbench currently verifies:

- normal `TX12` encoding and decode
- repeated `TX16` encoding and decode
- bidirectional / inverted DSHOT transmit
- exact transmit pulse widths and bit periods on `pin_o/pin_oe`
- bidirectional RX FIFO write/read and tag association
- RX non-empty, occupancy-threshold, and age-threshold IRQs
- TX-complete and TX-empty IRQs
- RX FIFO reset and TX FIFO reset behavior

## Control/Register Model

Key registers are implemented in `rtl/dshot_axil_regs.v`:

- `0x00` control
  - bit `0`: bidirectional DSHOT enable
  - bits `[4:2]`: speed select
    - `0`: DSHOT150
    - `1`: DSHOT300
    - `2`: DSHOT600
    - `3`: DSHOT1200
  - bit `8`: RX FIFO reset pulse
  - bit `9`: TX FIFO reset pulse
- `0x08` TX12
  - write queues one request into the TX FIFO
  - bits `[19:16]`: repeat minus 1
  - bits `[23:20]`: 4-bit tag
  - bits `[11:0]`: 12-bit pre-CRC payload
- `0x0C` TX16
  - write queues one request into the TX FIFO
  - bits `[19:16]`: repeat minus 1
  - bits `[23:20]`: 4-bit tag
  - bits `[15:0]`: raw 16-bit frame
- `0x28` RX FIFO data
  - read pops one entry
- `0x2C` RX FIFO status
- `0x30` IRQ mask
- `0x34` IRQ status / pending
- `0x38` IRQ occupancy threshold
- `0x3C` IRQ age threshold
- `0x40` RX FIFO tag / last-done tag / active tag

`doc/register_map.md` is the detailed software-facing reference.

There is now a software header at:

- `software/dshot_host_regs.h`

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

## FIFO Formats

RX FIFO entry format:

```text
{tx_tag[3:0], payload_word[15:0], erpm_period[15:0]}
```

`payload_word` is the decoded 16-bit returned DSHOT payload after GCR decode.

TX FIFO entry format is internal but conceptually contains:

```text
{use_raw, tx_tag[3:0], repeat_minus_1[3:0], tx_payload_or_frame}
```

## Interrupt Model

IRQ causes:

- bit `0`: RX FIFO non-empty
- bit `1`: RX FIFO occupancy >= configured threshold
- bit `2`: elapsed time since FIFO became non-empty >= configured threshold
- bit `3`: queued request complete
- bit `4`: TX FIFO drained while core is idle

Pending IRQ bits are masked by `0x30` and drive `irq`.

## FIFO Reset Behavior

Software-visible FIFO reset pulses are in `CONTROL`:

- bit `8`: `rx_fifo_reset`
  - flushes the RX FIFO
  - clears RX FIFO overflow
  - clears RX FIFO age tracking
  - clears the latched popped RX tag
  - clears RX-related pending IRQ bits `[2:0]`
- bit `9`: `tx_fifo_reset`
  - flushes queued TX FIFO entries
  - clears TX FIFO overflow
  - does not cancel an already-active transmit
  - clears the TX-empty pending IRQ bit `[4]`

These bits are self-clearing write pulses, not latched mode bits.

## IP Packaging

The packaged IP is under:

- `ip_core/`

Relevant packaging files:

- `ip_core/component.xml`
- `ip_core/xgui/dshot_axil_v1_0.tcl`
- `package_ip_core.tcl`

The packaged IP metadata now points vendor / advertisement URLs to:

- `https://github.com/GhlHub/dshot_host`

The package also includes a Vivado-style `xilinx_productguide` view that points at the GitHub repo page.

## Known Limits

- RX capture now uses fixed `5x` oversampling with 3-of-5 majority voting per returned bit, but it is still edge-started and does not implement adaptive clock/data recovery.
- RX timing registers will likely need hardware tuning.
- The RX FIFO stores the associated TX tag, payload, and derived eRPM period, but not richer per-entry metadata such as CRC failure history.
- TX FIFO overflow and RX FIFO overflow are currently sticky-until-reset / FIFO-reset conditions, not separately clearable software bits.
- `ip_core/hdl/` must be refreshed from `rtl/` when RTL changes; the package is not automatically synchronized.

## Safe Editing Guidance

- Keep the design single-clock unless a CDC plan is introduced explicitly.
- If timing presets are changed, update both `dshot_axil_regs.v` and `dshot_module_breakdown.md`.
- If register semantics change, update all of:
  - `doc/register_map.md`
  - `software/dshot_host_regs.h`
  - `tb/dshot_axil_top_tb.v`
- If FIFO entry format changes, update the AXI readout documentation and software expectations at the same time.
- If packaged IP metadata changes, rerun `package_ip_core.tcl` and check `ip_core/component.xml`.
