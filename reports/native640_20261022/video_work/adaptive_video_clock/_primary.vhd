library verilog;
use verilog.vl_types.all;
entity adaptive_video_clock is
    port(
        refclk          : in     vl_logic;
        reset           : in     vl_logic;
        mode_800        : in     vl_logic;
        locked          : out    vl_logic;
        boot_clk        : out    vl_logic;
        pixel_clk       : out    vl_logic;
        serial_clk      : out    vl_logic
    );
end adaptive_video_clock;
