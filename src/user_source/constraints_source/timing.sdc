# 50 MHz reference, PLL-derived clocks. Pixel and serializer are RELATED.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
# No broad false paths or exclusive pixel/serializer grouping.
# Physical STA/CDC and SD/DDC I/O timing still require board-level validation.
