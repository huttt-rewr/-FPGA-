library verilog;
use verilog.vl_types.all;
entity menu_overlay is
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
        out_rgb         : out    vl_logic_vector(23 downto 0)
    );
end menu_overlay;
