library verilog;
use verilog.vl_types.all;
entity zh_overlay is
    generic(
        WIN_X           : integer := 32;
        WIN_Y           : integer := 384;
        CHARS           : integer := 17
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_x           : out    vl_logic_vector(9 downto 0);
        out_y           : out    vl_logic_vector(9 downto 0);
        out_rgb         : out    vl_logic_vector(23 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WIN_X : constant is 1;
    attribute mti_svvh_generic_type of WIN_Y : constant is 1;
    attribute mti_svvh_generic_type of CHARS : constant is 1;
end zh_overlay;
