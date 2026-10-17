library verilog;
use verilog.vl_types.all;
entity glass_osd is
    generic(
        DEPTH           : integer := 1024;
        \SHARED_LUMA\   : integer := 0;
        WIN_X           : vl_logic_vector(9 downto 0) := (Hi0, Hi0, Hi0, Hi1, Hi1, Hi1, Hi1, Hi0, Hi0, Hi0);
        WIN_Y           : vl_logic_vector(9 downto 0) := (Hi0, Hi0, Hi0, Hi1, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0);
        WIN_W           : vl_logic_vector(9 downto 0) := (Hi0, Hi1, Hi1, Hi0, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0);
        WIN_H           : vl_logic_vector(9 downto 0) := (Hi0, Hi1, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0)
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        ascii_char      : in     vl_logic_vector(7 downto 0);
        osd_enable      : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0);
        shared_sum      : in     vl_logic_vector(11 downto 0);
        shared_luma     : in     vl_logic_vector(7 downto 0);
        shared_valid    : in     vl_logic;
        shared_sobel    : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DEPTH : constant is 1;
    attribute mti_svvh_generic_type of \SHARED_LUMA\ : constant is 1;
    attribute mti_svvh_generic_type of WIN_X : constant is 2;
    attribute mti_svvh_generic_type of WIN_Y : constant is 2;
    attribute mti_svvh_generic_type of WIN_W : constant is 2;
    attribute mti_svvh_generic_type of WIN_H : constant is 2;
end glass_osd;
