# TF/SD 50MHz verification - 2026-10-22

## Scope and result

The existing top-level design already enables native 4-bit SD and optional
50MHz High Speed operation. This verification did not change RTL, pins,
constraints, or existing testbench assertions. ModelSim 10.1c compiled the
current sources into the isolated `sim/sd_50mhz_verify_work` library.

This is SD High Speed at 3.3V, not UHS-I SDR50. Existing testbench messages
use the label `SDR50`; that label is not evidence of a UHS-I interface.

## Implementation evidence

- `src/top.v:480`: `NATIVE_4BIT(1)` and `NATIVE_HIGH_SPEED(1)`.
- `src/modules/sd/native/sd_native_controller.v:110-111`: CMD6 check
  (`0x00fffff1`) and switch (`0x80fffff1`).
- `src/modules/sd/native/sd_native_controller.v:150-160`: verify the
  64-byte switch status, selected function and busy status, then wait
  eight clocks before requesting 50MHz operation.
- `src/modules/sd/native/sd_bus_phy.v:31`: at a 100MHz host clock,
  a half-period of one cycle produces a 50MHz SD clock. Divider updates
  occur at falling edges. Four DAT lanes retain CRC16 checking.
- Unsupported or failed negotiation retains or reinitializes at 25MHz;
  initialization errors are not handled by forcing an unconfirmed 50MHz mode.

## Fresh simulation results

All commands ran from `E:\fpga\sim`, using `J:\win64\vlog.exe` and
`J:\win64\vsim.exe`, with `-do 'run -all; quit -f'`.

| Test | Configuration | Result |
|---|---|---|
| tb_sd_highspeed | CARD_DELAY=0ns | ALL PASS |
| tb_sd_highspeed | CARD_DELAY=6ns | ALL PASS |
| tb_sd_highspeed | CARD_DELAY=14ns | ALL PASS |
| tb_sd_native | initialization, CRC lanes, fault recovery, 25MHz | ALL PASS |
| tb_sd_native_clock | 200kHz initialization, open drain, switch to 25MHz | ALL PASS |
| tb_sd_highspeed_player | 14ns card delay, scaled BMP and WAV integration | ALL PASS |

Each high-speed configuration exercised ten negotiation scenarios, including
unsupported, busy, rejected, corrupt, and missing switch responses/data.
For each delay, the high-speed successful case read 8192 bytes in 36672
100MHz host cycles: **22.338569 MB/s** including CMD17, CRC and handshakes.
The 25MHz baseline read 8192 bytes in 73113 cycles: **11.204574 MB/s**.
The raw 50MHz four-bit bandwidth is 25 MB/s; it is not 50 MB/s.
Detailed transcripts are the six adjacent `.log` files.

## Limits and current build state

No physical card, oscilloscope, or board throughput measurement was available.
Logical pin-delay simulation does not establish board I/O timing closure.
This verification did not run a new full synthesis/implementation build.
The previously running build finished with SWNS +0.136ns, STNS 0,
HWNS -0.020ns and HTNS -0.020ns (`reports/timing_status.txt`).
Consequently, whole-design timing has **not** converged and board signoff
is still false. No +0.5ns timing-margin claim is made.

## Source SHA256

- sd_native_controller.v: `5F625747628225228F1712D31C4973B7195B4C12ABB0065139C2CDB30418D6EE`
- sd_bus_phy.v: `A94846880AE6EC3F89EE9BEAA6CC19EE4E49228AD733D3C41702A9A540C7FD42`
- sd_card_top_native.v: `5582617564736CC5C87462DDE21A67A4FB7EF2BFAE914DFF2A8F6E793B90743D`
