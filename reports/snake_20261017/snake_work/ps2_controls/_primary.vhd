library verilog;
use verilog.vl_types.all;
entity ps2_controls is
    generic(
        PENDING_TIMEOUT_CYCLES: integer := 200000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        scan_code       : in     vl_logic_vector(7 downto 0);
        key_valid       : in     vl_logic;
        key_release     : in     vl_logic;
        key_extended    : in     vl_logic;
        receive_error   : in     vl_logic;
        ev_next         : out    vl_logic;
        ev_prev         : out    vl_logic;
        ev_toggle_auto  : out    vl_logic;
        ev_vol_up       : out    vl_logic;
        ev_vol_dn       : out    vl_logic;
        ev_mute         : out    vl_logic;
        ev_osd          : out    vl_logic;
        ev_res          : out    vl_logic;
        ev_fps          : out    vl_logic;
        ev_digit        : out    vl_logic_vector(3 downto 0);
        ev_image_select : out    vl_logic;
        ev_audio_select : out    vl_logic;
        game_enable     : out    vl_logic;
        held_up         : out    vl_logic;
        held_down       : out    vl_logic;
        held_left       : out    vl_logic;
        held_right      : out    vl_logic;
        audio_pending   : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of PENDING_TIMEOUT_CYCLES : constant is 2;
end ps2_controls;
