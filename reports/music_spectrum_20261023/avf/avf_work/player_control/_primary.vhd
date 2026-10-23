library verilog;
use verilog.vl_types.all;
entity player_control is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        ir_command      : in     vl_logic_vector(7 downto 0);
        ir_valid        : in     vl_logic;
        next_pulse      : out    vl_logic;
        prev_pulse      : out    vl_logic;
        toggle_pulse    : out    vl_logic;
        vol_up          : out    vl_logic;
        vol_dn          : out    vl_logic;
        mute_toggle     : out    vl_logic;
        bri_up          : out    vl_logic;
        bri_dn          : out    vl_logic;
        con_up          : out    vl_logic;
        con_dn          : out    vl_logic;
        osd_toggle      : out    vl_logic;
        test_toggle     : out    vl_logic;
        transition_toggle: out    vl_logic;
        transition_mode : out    vl_logic_vector(1 downto 0);
        captions_enable : out    vl_logic;
        scroll_enable   : out    vl_logic;
        slogan_select   : out    vl_logic_vector(1 downto 0);
        auto_enh_en     : out    vl_logic;
        slide_enable    : out    vl_logic;
        zh_enable       : out    vl_logic;
        large_clock     : out    vl_logic
    );
end player_control;
