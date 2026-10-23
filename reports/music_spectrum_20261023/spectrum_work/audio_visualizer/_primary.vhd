library verilog;
use verilog.vl_types.all;
entity audio_visualizer is
    generic(
        WIN_X           : vl_logic_vector(9 downto 0) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi1, Hi0, Hi0, Hi0);
        WIN_Y           : vl_logic_vector(9 downto 0) := (Hi0, Hi1, Hi0, Hi1, Hi0, Hi1, Hi1, Hi0, Hi0, Hi0);
        WIN_W           : vl_logic_vector(9 downto 0) := (Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0);
        WIN_H           : vl_logic_vector(9 downto 0) := (Hi0, Hi0, Hi0, Hi1, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0);
        N               : integer := 128;
        BRAM_HISTORY    : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        audio_valid     : in     vl_logic;
        audio_left      : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WIN_X : constant is 2;
    attribute mti_svvh_generic_type of WIN_Y : constant is 2;
    attribute mti_svvh_generic_type of WIN_W : constant is 2;
    attribute mti_svvh_generic_type of WIN_H : constant is 2;
    attribute mti_svvh_generic_type of N : constant is 1;
    attribute mti_svvh_generic_type of BRAM_HISTORY : constant is 1;
end audio_visualizer;
