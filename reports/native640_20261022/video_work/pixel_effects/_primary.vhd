library verilog;
use verilog.vl_types.all;
entity pixel_effects is
    generic(
        DEPTH           : integer := 1024;
        EDGE_TH         : vl_logic_vector(7 downto 0) := (Hi0, Hi1, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0);
        BRAM_WINDOW     : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        mode_sel        : in     vl_logic_vector(1 downto 0);
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0);
        out_luma_sum    : out    vl_logic_vector(11 downto 0);
        out_luma        : out    vl_logic_vector(7 downto 0);
        out_window_valid: out    vl_logic;
        out_sobel       : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DEPTH : constant is 1;
    attribute mti_svvh_generic_type of EDGE_TH : constant is 2;
    attribute mti_svvh_generic_type of BRAM_WINDOW : constant is 1;
end pixel_effects;
