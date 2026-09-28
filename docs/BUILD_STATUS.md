# Build Status

Target: `EG4S20BG256`, 50 MHz reference clock, direct HDMI TMDS, external
2M x 32 SDRAM, SPI TF card.

The generated reports are retained under `reports/`:

- `synthesis.log`: TD RTL/gate synthesis log.
- `gate_area.txt`: post-gate resource report.
- `implementation.log`: place/route log.
- `timing_status.txt` and `timing_summary.txt`: final routed timing reports.
- `video_improve_gate.db` and `video_improve_routed.db`: TD checkpoints.

The routed design was produced to expose board-level timing risks before a
bitstream is generated. Current setup worst slack is negative. Check the HDMI
serializer, SDRAM clocking, pin constraints, and clock constraints on the exact
board revision, then rerun `scripts/implement.tcl` and add a separate bitgen
step after timing is positive.
