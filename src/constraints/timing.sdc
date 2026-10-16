# 50 MHz reference, PLL-derived clocks. Pixel and serializer are RELATED.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
# External asynchronous controls only: cut the path to the FIRST synchronizer.
# All later synchronizer stages, held-data buses, FIFO Gray buses and PLL-related
# pixel/serializer and SDRAM clock paths remain timed.
# Each port has exactly one destination: its input synchronizer stage 0.
# Use the port startpoint because TD packs stage 0 into the IREG and removes
# its RTL register name. Paths launching from that IREG are still timed.
set_false_path -from [get_ports {key1 key2 key3 sw[*]}]
# PS/2 clock/data are asynchronous inputs to their own stage-0 synchronizers.
# This exception ends at that first stage; all receiver logic remains timed.
set_false_path -from [get_ports {ps2_clk ps2_data}]
# SDRAM is a device hard macro with TD-generated internal pad timing. Its DQ
# pins are not user top-level GPIO. Never mask the SDRAM hard-macro paths.
# External SD/DDC timing requires actual card/device and PCB propagation data;
# no fabricated input/output delays are inserted. See docs/BOARD_TIMING.md.
# No broad false paths or exclusive pixel/serializer grouping.
# Physical STA/CDC and SD/DDC I/O timing still require board-level validation.
