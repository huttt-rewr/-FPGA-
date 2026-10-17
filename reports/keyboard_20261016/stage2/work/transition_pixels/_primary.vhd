library verilog;
use verilog.vl_types.all;
entity transition_pixels is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        effect_mode     : in     vl_logic_vector(1 downto 0);
        fade_level      : in     vl_logic_vector(5 downto 0);
        slide_offset    : in     vl_logic_vector(9 downto 0);
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0)
    );
end transition_pixels;
