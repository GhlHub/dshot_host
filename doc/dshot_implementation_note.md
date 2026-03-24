# DSHOT Implementation Note

## Scope

This note summarizes the parts of DSHOT that matter when implementing a hardware transmitter or a bidirectional transmitter/receiver in RTL.

It is based on the protocol description in `dshot_desc.pdf` and is intentionally independent of the current contents of `rtl/`.

## 1. Frame Format

Standard DSHOT sends a 16-bit frame:

```text
[15:5] throttle_or_command
[4]    telemetry_request
[3:0]  crc
```

- `0` means disarmed.
- `1..47` are reserved command values.
- `48..2047` are normal throttle values.
- The telemetry request bit asks for ESC telemetry on the dedicated telemetry path.

The 4-bit CRC is computed from the upper 12 bits:

```c
value12 = {throttle_or_command[10:0], telemetry_request};
crc = (value12 ^ (value12 >> 4) ^ (value12 >> 8)) & 0xF;
frame = {value12, crc};
```

For bidirectional DSHOT, the transmitted command frame keeps the same 16-bit layout but uses the inverted-checksum form:

```c
crc_bidir = (~(value12 ^ (value12 >> 4) ^ (value12 >> 8))) & 0xF;
```

## 2. Bit Encoding

Each bit cell has a fixed duration. The bit value is determined by how long the signal stays high within that bit cell.

- Logic `1`: high for 2/3 of the bit period.
- Logic `0`: high for 1/3 of the bit period.

Nominal timings:

| Mode | Bit rate | Bit time | Frame time |
| --- | ---: | ---: | ---: |
| DSHOT150 | 150 kbit/s | 6.67 us | 106.72 us |
| DSHOT300 | 300 kbit/s | 3.33 us | 53.28 us |
| DSHOT600 | 600 kbit/s | 1.67 us | 26.72 us |
| DSHOT1200 | 1200 kbit/s | 0.83 us | 13.28 us |

Derived pulse widths:

| Mode | `T0H` | `T1H` |
| --- | ---: | ---: |
| DSHOT150 | 2.50 us | 5.00 us |
| DSHOT300 | 1.25 us | 2.50 us |
| DSHOT600 | 0.625 us | 1.25 us |
| DSHOT1200 | 0.313 us | 0.625 us |

Implementation rule:

```text
Tbit = round(clk_hz / dshot_bitrate)
T0H  = round(Tbit / 3)
T1H  = round(2 * Tbit / 3)
T0L  = Tbit - T0H
T1L  = Tbit - T1H
```

Use a single system clock domain and convert all DSHOT timings into integer clock counts before transmission.

## 3. TX Datapath Recommendation

Recommended RTL partition:

1. A frame packer that accepts throttle/command and telemetry request, computes CRC, and emits a 16-bit word.
2. A bit serializer that shifts out the frame MSB first.
3. A pulse generator that converts each serialized bit into `T1H/T1L` or `T0H/T0L`.
4. A frame scheduler that enforces inter-frame spacing and, for bidirectional mode, hands the line over to receive logic.

Transmit sequencing should be:

1. Latch the 16-bit frame.
2. For each bit from bit 15 down to bit 0:
   - Drive active level.
   - Hold it for `T1H` or `T0H`.
   - Drive inactive level.
   - Hold it for `T1L` or `T0L`.
3. Return to idle or switch to receive mode if bidirectional mode is enabled.

The line must be tri-stated or otherwise released before expecting a response from the ESC in bidirectional mode.

## 4. Arming and Commanding

The article notes that many ESC firmwares expect repeated zero-throttle frames before accepting active throttle. A practical implementation should expose:

- A configurable startup arming interval.
- A clean distinction between command frames and throttle frames.
- A way to resend command values multiple times when required by ESC firmware.

Reasonable controller behavior:

1. On reset, transmit `0` continuously for the arming interval.
2. After arming, allow throttle values `48..2047`.
3. Treat `1..47` as explicit command opcodes, not as low throttle.

## 5. Bidirectional DSHOT Behavior

In bidirectional DSHOT:

- The command waveform polarity is inverted relative to normal DSHOT.
- The ESC replies on the same wire after the transmitted frame.
- Effective update rate is reduced because each transmit frame is followed by a receive window.
- The article states a fixed turnaround gap of about `30 us` to switch line direction, DMA, and timers.

Implementation consequences:

- The output-enable handoff must be explicit.
- TX completion and RX start should be separated by a configurable turnaround counter.
- The overall frame period must include:
  - TX frame time
  - line turnaround time
  - ESC reply time
  - optional guard time

For high loop rates, choose the DSHOT mode so the full bidirectional exchange still fits within the control interval.

## 6. eRPM Response Format

The ESC response in bidirectional mode carries a 16-bit payload before line coding:

```text
[15:4] eRPM data
[3:0]  crc
```

The 12-bit eRPM data is split into:

```text
eee mmmmmmmmm
```

- `eee`: left-shift exponent
- `mmmmmmmmm`: 9-bit base period

The period value is reconstructed as:

```text
period = base << exponent
```

The response CRC is checked with the normal, non-inverted DSHOT CRC form over the 12-bit eRPM field.

## 7. eRPM Line Coding

The ESC does not send the raw 16-bit eRPM word directly. It applies two transforms:

1. 4b/5b-style nibble mapping: `16 bits -> 20 bits`
2. Differential-style expansion with a leading `0`: `20 bits -> 21 bits`

Nibble map from the article:

| Nibble | Code | Nibble | Code |
| --- | --- | --- | --- |
| 0 | 19 | 8 | 1A |
| 1 | 1B | 9 | 09 |
| 2 | 12 | A | 0A |
| 3 | 13 | B | 0B |
| 4 | 1D | C | 1E |
| 5 | 15 | D | 0D |
| 6 | 16 | E | 0E |
| 7 | 17 | F | 0F |

The 20-bit value is then converted into a 21-bit transmitted pattern with:

- Start with previous output bit = `0`.
- For each GCR bit:
  - If GCR bit is `1`, invert the previous transmitted bit.
  - If GCR bit is `0`, repeat the previous transmitted bit.

On receive, the article gives a compact decode step:

```c
gcr = value21 ^ (value21 >> 1);
```

Practical RTL implementation:

1. Sample the returned waveform.
2. Recover the 21-bit transmitted symbol stream.
3. Convert it back to the 20-bit GCR data.
4. Reverse the nibble mapping to recover the original 16-bit eRPM frame.
5. Validate CRC.
6. Decode exponent/base into period or eRPM.

## 8. Receive Sampling Recommendation

An FPGA implementation should avoid edge-by-edge asynchronous logic. A safer structure is:

1. Synchronize the input pin into the system clock domain with a multi-flop synchronizer.
2. Optionally apply a short majority-vote filter.
3. Oversample the return data with a programmable sample tick.
4. Detect the start of the return frame after the turnaround gap.
5. Sample each reply bit near the center of the expected bit period.

Recommended configurables:

- System clock frequency
- DSHOT mode
- RX oversample ratio
- Turnaround gap in clocks
- Receive timeout in clocks

## 9. Extended DSHOT Telemetry

The article also describes EDT, which reuses some eRPM encodings to embed telemetry values without a separate wire.

The payload becomes:

```text
pppp mmmmmmmm
```

with telemetry types:

- `0x02`: temperature in C
- `0x04`: voltage in 0.25 V steps
- `0x06`: current in A
- `0x08`: debug 1
- `0x0A`: debug 2
- `0x0C`: debug 3
- `0x0E`: state/event

If EDT support is not required initially, keep it out of the first RTL version. The minimal viable bidirectional implementation is:

- transmit inverted DSHOT frame
- receive 21-bit response
- decode eRPM
- validate CRC

## 10. Suggested Minimal RTL Plan

Phase 1:

1. Implement unidirectional DSHOT TX.
2. Support fixed-rate frame generation.
3. Verify bit timing and CRC with simulation.

Phase 2:

1. Add bidirectional polarity inversion.
2. Add output-enable handoff and turnaround timing.
3. Capture the 21-bit ESC response.
4. Decode GCR and verify eRPM CRC.

Phase 3:

1. Add EDT decode.
2. Add command retries and arming policy.
3. Add status/error counters for bring-up.

## 11. Verification Checklist

At minimum, verify:

- CRC generation for normal and bidirectional command frames
- MSB-first serialization
- Correct `T0H/T1H/T0L/T1L` timing in clocks
- Correct frame length for each DSHOT mode
- Proper line release before bidirectional receive
- Turnaround gap handling
- 21-bit response capture
- GCR decode and reverse nibble mapping
- CRC rejection on malformed eRPM responses
- Proper handling of zero throttle, command range, and active throttle range

## 12. Note on the Source Article

One statement in the source article appears inconsistent: it later says "DSHOT 300" has a frame length of `106.72 us`, but the timing table in the same article correctly shows:

- DSHOT150: `106.72 us`
- DSHOT300: `53.28 us`

Use the timing table values, not that later sentence.
