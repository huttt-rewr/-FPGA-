library verilog;
use verilog.vl_types.all;
entity picture_controls is
    generic(
        DEBOUNCE_CYCLES : integer := 2000000;
        BOARD_MENU      : integer := 0;
        AUDIO_MENU      : integer := 0;
        LONG_PRESS_CYCLES: integer := 100000000;
        KEYBOARD_CONTROLS: integer := 0;
        AUDIO_MUTE_DEFAULT: integer := 1;
        CHINESE_MENU    : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        key1_n          : in     vl_logic;
        key2_n          : in     vl_logic;
        key3_n          : in     vl_logic;
        next_pulse      : out    vl_logic;
        toggle_pulse    : out    vl_logic;
        brightness      : out    vl_logic_vector(7 downto 0);
        contrast        : out    vl_logic_vector(3 downto 0);
        edit_mode       : out    vl_logic_vector(1 downto 0);
        menu_open       : out    vl_logic;
        menu_item       : out    vl_logic_vector(2 downto 0);
        menu_edit       : out    vl_logic;
        gamma_enable    : out    vl_logic;
        debug_enable    : out    vl_logic;
        debug_page      : out    vl_logic_vector(1 downto 0);
        audio_volume    : out    vl_logic_vector(4 downto 0);
        audio_mute      : out    vl_logic;
        kb_vol_up       : in     vl_logic;
        kb_vol_dn       : in     vl_logic;
        kb_mute         : in     vl_logic;
        ir_vol_up       : in     vl_logic;
        ir_vol_dn       : in     vl_logic;
        ir_mute         : in     vl_logic;
        ir_bri_up       : in     vl_logic;
        ir_bri_dn       : in     vl_logic;
        ir_con_up       : in     vl_logic;
        ir_con_dn       : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DEBOUNCE_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of BOARD_MENU : constant is 1;
    attribute mti_svvh_generic_type of AUDIO_MENU : constant is 1;
    attribute mti_svvh_generic_type of LONG_PRESS_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of KEYBOARD_CONTROLS : constant is 1;
    attribute mti_svvh_generic_type of AUDIO_MUTE_DEFAULT : constant is 1;
    attribute mti_svvh_generic_type of CHINESE_MENU : constant is 1;
end picture_controls;
