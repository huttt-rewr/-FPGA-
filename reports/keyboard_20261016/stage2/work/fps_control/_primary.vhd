library verilog;
use verilog.vl_types.all;
entity fps_control is
    generic(
        CLK_FREQ_HZ     : integer := 100000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        enable          : in     vl_logic;
        busy            : in     vl_logic;
        mode            : in     vl_logic_vector(3 downto 0);
        tick            : out    vl_logic;
        limited         : out    vl_logic;
        requested_fps   : out    vl_logic_vector(5 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_FREQ_HZ : constant is 2;
end fps_control;
