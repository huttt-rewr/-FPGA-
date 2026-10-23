library verilog;
use verilog.vl_types.all;
entity video_luma_window_bram is
    generic(
        DEPTH           : integer := 800
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        external_luma   : in     vl_logic_vector(7 downto 0);
        gray            : out    vl_logic_vector(7 downto 0);
        t0              : out    vl_logic_vector(7 downto 0);
        t1              : out    vl_logic_vector(7 downto 0);
        t2              : out    vl_logic_vector(7 downto 0);
        m0              : out    vl_logic_vector(7 downto 0);
        m1              : out    vl_logic_vector(7 downto 0);
        m2              : out    vl_logic_vector(7 downto 0);
        b0              : out    vl_logic_vector(7 downto 0);
        b1              : out    vl_logic_vector(7 downto 0);
        b2              : out    vl_logic_vector(7 downto 0);
        valid           : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DEPTH : constant is 1;
end video_luma_window_bram;
