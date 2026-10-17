library verilog;
use verilog.vl_types.all;
entity adaptive_raster is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        mode_800        : in     vl_logic;
        hs              : out    vl_logic;
        vs              : out    vl_logic;
        de              : out    vl_logic
    );
end adaptive_raster;
