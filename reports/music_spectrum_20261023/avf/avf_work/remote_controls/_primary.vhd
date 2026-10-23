library verilog;
use verilog.vl_types.all;
entity remote_controls is
    generic(
        CLK_HZ          : integer := 100000000;
        BAUD            : integer := 115200;
        TIMEOUT_CYCLES  : integer := 50000000;
        IR_ENABLED      : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        rx              : in     vl_logic;
        tx              : out    vl_logic;
        overflow        : out    vl_logic;
        next_pulse      : out    vl_logic;
        prev_pulse      : out    vl_logic;
        toggle_pulse    : out    vl_logic;
        time_bcd        : out    vl_logic_vector(23 downto 0);
        time_seq        : out    vl_logic_vector(7 downto 0);
        time_set        : out    vl_logic;
        ir_rx           : in     vl_logic;
        auto_enh_en     : out    vl_logic;
        slide_enable    : out    vl_logic;
        zh_enable       : out    vl_logic;
        large_clock     : out    vl_logic;
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
        slogan_select   : out    vl_logic_vector(1 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HZ : constant is 1;
    attribute mti_svvh_generic_type of BAUD : constant is 1;
    attribute mti_svvh_generic_type of TIMEOUT_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of IR_ENABLED : constant is 1;
end remote_controls;
