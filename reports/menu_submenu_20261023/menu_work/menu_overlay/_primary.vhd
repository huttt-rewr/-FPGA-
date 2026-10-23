library verilog;
use verilog.vl_types.all;
entity menu_overlay is
    generic(
        VGA_CLOCK_HZ    : integer := 25000000;
        SVGA_CLOCK_HZ   : integer := 40000000;
        POPUP_SECONDS   : integer := 2
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        menu_open       : in     vl_logic;
        menu_item       : in     vl_logic_vector(2 downto 0);
        edit_mode       : in     vl_logic;
        auto_play       : in     vl_logic;
        brightness      : in     vl_logic_vector(7 downto 0);
        contrast        : in     vl_logic_vector(3 downto 0);
        volume          : in     vl_logic_vector(4 downto 0);
        mute            : in     vl_logic;
        gamma_enable    : in     vl_logic;
        debug_enable    : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0);
        mode_800        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of VGA_CLOCK_HZ : constant is 1;
    attribute mti_svvh_generic_type of SVGA_CLOCK_HZ : constant is 1;
    attribute mti_svvh_generic_type of POPUP_SECONDS : constant is 1;
end menu_overlay;
