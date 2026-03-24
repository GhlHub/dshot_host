# Register Map

## Overview

This document describes the AXI-Lite register map implemented by `rtl/dshot_axil_regs.v`.

The design runs in a single `60 MHz` clock domain. Timing and age-related fields are expressed in `60 MHz` clock cycles.

## Register Summary

| Addr | Name | Access | Description |
|---|---|---:|---|
| `0x00` | `CONTROL` | `RW` | mode and DSHOT speed select |
| `0x04` | `STATUS` | `RW1C/R` | sticky status plus RX/TX FIFO state |
| `0x08` | `TX12` | `W/R` | queue 12-bit payload with auto-generated CRC |
| `0x0C` | `TX16` | `W/R` | queue raw 16-bit DSHOT frame |
| `0x10` | `T0H` | `RW` | active time for transmitted `0` bit |
| `0x14` | `T1H` | `RW` | active time for transmitted `1` bit |
| `0x18` | `BIT` | `RW` | total bit period |
| `0x1C` | `TURNAROUND` | `RW` | bidirectional turnaround delay |
| `0x20` | `RX_SAMPLE` | `RW` | RX oversample interval |
| `0x24` | `RX_TIMEOUT` | `RW` | RX timeout |
| `0x28` | `RX_FIFO_DATA` | `R(pop)` | pop RX payload/period word |
| `0x2C` | `RX_FIFO_STATUS` | `R` | RX FIFO occupancy and flags |
| `0x30` | `IRQ_MASK` | `RW` | interrupt enable mask |
| `0x34` | `IRQ_STATUS` | `RW1C/R` | pending bits, source bits, FIFO age |
| `0x38` | `IRQ_OCC` | `RW` | RX FIFO occupancy threshold |
| `0x3C` | `IRQ_AGE` | `RW` | RX FIFO age threshold |
| `0x40` | `RX_FIFO_TAG` | `R` | tag/meta register for popped RX data |

## `0x00` `CONTROL`

| Bits | Name | Description |
|---|---|---|
| `[0]` | `bidir_en` | `0`: normal DSHOT, `1`: bidirectional DSHOT |
| `[1]` | reserved | write `0` |
| `[4:2]` | `speed` | DSHOT speed select |
| `[7:5]` | reserved | write `0` |
| `[8]` | `rx_fifo_reset` | self-clearing RX FIFO flush/reset pulse |
| `[9]` | `tx_fifo_reset` | self-clearing TX FIFO flush/reset pulse |
| `[31:10]` | reserved | write `0` |

`speed` encoding:

| Value | Meaning |
|---|---|
| `0` | `DSHOT150` |
| `1` | `DSHOT300` |
| `2` | `DSHOT600` |
| `3` | `DSHOT1200` |

Writing `CONTROL` reloads the built-in timing presets for the selected speed.

`bidir_en` and `speed` are normal mode bits. `rx_fifo_reset` and `tx_fifo_reset` are write pulses in the same register and are not latched.

`rx_fifo_reset`:

- flushes the RX FIFO
- clears RX FIFO overflow state
- clears the latched popped RX tag
- clears RX FIFO age tracking
- clears RX-related pending IRQ bits `[2:0]`

`tx_fifo_reset`:

- flushes the queued TX FIFO entries
- clears TX FIFO overflow state
- does not cancel an already-active transmit
- clears the TX-empty pending IRQ bit `[4]`
- does not change `bidir_en` or `speed` beyond whatever values were written in the same `CONTROL` word

## `0x04` `STATUS`

| Bits | Name | Description |
|---|---|---|
| `[0]` | `busy` | core busy processing a queued request |
| `[1]` | `done` | sticky request-complete flag |
| `[2]` | `tx_done` | sticky transmit-engine-done flag |
| `[3]` | `rx_valid` | sticky receive-valid flag |
| `[4]` | `code_error` | sticky receive code/CRC error flag |
| `[9:5]` | `rx_fifo_occupancy` | RX FIFO occupancy |
| `[10]` | `rx_fifo_empty` | RX FIFO empty |
| `[11]` | `rx_fifo_full` | RX FIFO full |
| `[12]` | `rx_fifo_overflow` | RX FIFO overflow sticky flag |
| `[17:13]` | `tx_fifo_occupancy` | TX FIFO occupancy |
| `[18]` | `tx_fifo_empty` | TX FIFO empty |
| `[19]` | `tx_fifo_full` | TX FIFO full |
| `[20]` | `tx_fifo_overflow` | TX FIFO overflow sticky flag |
| `[31:21]` | reserved | read as `0` |

Bits `[4:1]` clear on write-one.

FIFO overflow bits in `STATUS` are cleared by the corresponding FIFO reset pulse or global reset, not by writing `STATUS`.

## `0x08` `TX12`

Writing this register pushes one request into the TX FIFO.

| Bits | Name | Description |
|---|---|---|
| `[11:0]` | `value12` | 12-bit pre-CRC DSHOT payload |
| `[15:12]` | reserved | write `0` |
| `[19:16]` | `repeat_minus_1` | transmit count minus one |
| `[23:20]` | `tag` | 4-bit request tag |
| `[31:24]` | reserved | write `0` |

CRC is generated in hardware when the request is launched from the TX FIFO.

If the TX FIFO is full when this register is written, the incoming request is dropped and the TX FIFO overflow flag is set.

## `0x0C` `TX16`

Writing this register pushes one raw-frame request into the TX FIFO.

| Bits | Name | Description |
|---|---|---|
| `[15:0]` | `frame16` | raw 16-bit DSHOT frame |
| `[19:16]` | `repeat_minus_1` | transmit count minus one |
| `[23:20]` | `tag` | 4-bit request tag |
| `[31:24]` | reserved | write `0` |

Repeat encoding for both `TX12` and `TX16`:

| Value | Transmit Count |
|---|---|
| `0x0` | 1 |
| `0x1` | 2 |
| `...` | ... |
| `0xF` | 16 |

If the TX FIFO is full when this register is written, the incoming request is dropped and the TX FIFO overflow flag is set.

## Timing Registers

`0x10` `T0H`, `0x14` `T1H`, `0x18` `BIT`, `0x1C` `TURNAROUND`, `0x20` `RX_SAMPLE`, and `0x24` `RX_TIMEOUT` all use bits `[15:0]` as clock counts in the `60 MHz` domain.

`RX_SAMPLE` is the oversample interval used by the fixed `5x` / 3-of-5-vote receive frontend.

## `0x28` `RX_FIFO_DATA`

Reading this register pops one RX FIFO entry and returns:

```text
{payload_word[15:0], erpm_period[15:0]}
```

The corresponding 4-bit request tag is latched into `RX_FIFO_TAG`.

If the RX FIFO is empty, the read returns `0`.

## `0x2C` `RX_FIFO_STATUS`

| Bits | Name | Description |
|---|---|---|
| `[15:0]` | `last_erpm_period` | most recently decoded eRPM period |
| `[20:16]` | `rx_fifo_occupancy` | RX FIFO occupancy |
| `[21]` | `rx_fifo_empty` | RX FIFO empty |
| `[22]` | `rx_fifo_full` | RX FIFO full |
| `[23]` | `rx_fifo_overflow` | RX FIFO overflow |
| `[31:24]` | reserved | read as `0` |

RX FIFO overflow indicates a received response was dropped because the RX FIFO was full.

## `0x30` `IRQ_MASK`

| Bits | Name | Description |
|---|---|---|
| `[0]` | `rx_nonempty_en` | RX FIFO non-empty interrupt enable |
| `[1]` | `rx_occ_en` | RX FIFO occupancy-threshold interrupt enable |
| `[2]` | `rx_age_en` | RX FIFO age-threshold interrupt enable |
| `[3]` | `tx_complete_en` | request-complete interrupt enable |
| `[4]` | `tx_empty_en` | TX FIFO drained interrupt enable |
| `[31:5]` | reserved | write `0` |

## `0x34` `IRQ_STATUS`

| Bits | Name | Description |
|---|---|---|
| `[15:0]` | `fifo_age` | age of the current RX FIFO non-empty interval |
| `[20:16]` | `irq_pending` | pending interrupt bits |
| `[25:21]` | `irq_source` | current source bits |
| `[31:26]` | reserved | read as `0` |

Interrupt bit encoding:

| Bit | Meaning |
|---|---|
| `0` | RX FIFO non-empty |
| `1` | RX FIFO occupancy >= `IRQ_OCC` |
| `2` | RX FIFO age >= `IRQ_AGE` |
| `3` | queued request completed |
| `4` | TX FIFO drained and core idle |

Writing `1` to bits `[4:0]` clears the corresponding pending bits. For TX-complete and TX-empty, the associated sticky source bit is also cleared.

Interrupt summary:

- bits `[2:0]` are RX-side causes
- bit `[3]` is a sticky request-complete event
- bit `[4]` is a sticky TX-queue-drained event

## `0x38` `IRQ_OCC`

| Bits | Name | Description |
|---|---|---|
| `[7:0]` | `occupancy_threshold` | threshold for IRQ bit `1` |
| `[31:8]` | reserved | write `0` |

`0` disables the occupancy-threshold cause.

## `0x3C` `IRQ_AGE`

| Bits | Name | Description |
|---|---|---|
| `[15:0]` | `age_threshold` | threshold for IRQ bit `2`, in `60 MHz` clocks |
| `[31:16]` | reserved | write `0` |

`0` disables the age-threshold cause.

## `0x40` `RX_FIFO_TAG`

| Bits | Name | Description |
|---|---|---|
| `[3:0]` | `rx_tag` | tag associated with the most recently popped `RX_FIFO_DATA` word |
| `[7:4]` | `last_tx_done_tag` | tag of the most recently completed request |
| `[11:8]` | `active_tx_tag` | tag of the request currently being executed |
| `[31:12]` | reserved | read as `0` |

`rx_tag` updates when `RX_FIFO_DATA` is popped. `last_tx_done_tag` updates when a queued request completes.

## Reset Defaults

| Register | Reset Value | Notes |
|---|---|---|
| `CONTROL` | `0x0000_0008` | `DSHOT600`, bidirectional disabled |
| `T0H` | `38` | DSHOT600 preset |
| `T1H` | `75` | DSHOT600 preset |
| `BIT` | `100` | DSHOT600 preset |
| `TURNAROUND` | `1800` | default turnaround delay |
| `RX_SAMPLE` | `16` | DSHOT600 5x oversample interval |
| `RX_TIMEOUT` | `2000` | default RX timeout |
| `IRQ_MASK` | `0` | all interrupts masked |
| `IRQ_OCC` | `0` | occupancy threshold disabled |
| `IRQ_AGE` | `0` | age threshold disabled |

At reset both FIFOs are empty, both overflow flags are clear, and no request tag is active.

## Built-In Speed Presets

| Speed | `T0H` | `T1H` | `BIT` | `RX_SAMPLE` | `RX_TIMEOUT` |
|---|---:|---:|---:|---:|---:|
| `DSHOT150` | `150` | `300` | `400` | `64` | `8000` |
| `DSHOT300` | `75` | `150` | `200` | `32` | `4000` |
| `DSHOT600` | `38` | `75` | `100` | `16` | `2000` |
| `DSHOT1200` | `19` | `38` | `50` | `8` | `1000` |
