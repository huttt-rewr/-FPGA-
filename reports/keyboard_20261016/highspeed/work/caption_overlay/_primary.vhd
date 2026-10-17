library verilog;
use verilog.vl_types.all;
entity caption_overlay is
    generic(
        CLK_HZ          : integer := 25000000;
        ADAPTIVE        : integer := 0;
        PIPELINED       : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        rgb             : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        scroll_enable   : in     vl_logic;
        slogan_select   : in     vl_logic_vector(1 downto 0);
        transition_mode : in     vl_logic_vector(1 downto 0);
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0);
        mode_800        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HZ : constant is 1;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
    attribute mti_svvh_generic_type of PIPELINED : constant is 1;
end caption_overlay;
