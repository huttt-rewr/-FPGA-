library verilog;
use verilog.vl_types.all;
entity frame_swap is
    generic(
        ENABLE_EFFECTS  : integer := 0;
        ADAPTIVE        : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vblank          : in     vl_logic;
        request_toggle  : in     vl_logic;
        requested_buffer: in     vl_logic_vector(1 downto 0);
        ack_toggle      : out    vl_logic;
        active_buffer   : out    vl_logic_vector(1 downto 0);
        display_valid   : out    vl_logic;
        transition_mode : in     vl_logic_vector(1 downto 0);
        effect_mode     : out    vl_logic_vector(2 downto 0);
        fade_level      : out    vl_logic_vector(5 downto 0);
        slide_offset    : out    vl_logic_vector(9 downto 0);
        transition_busy : out    vl_logic;
        mode_800        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ENABLE_EFFECTS : constant is 1;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
end frame_swap;
