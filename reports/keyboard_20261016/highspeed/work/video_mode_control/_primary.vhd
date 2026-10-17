library verilog;
use verilog.vl_types.all;
entity video_mode_control is
    generic(
        QUIET_CYCLES    : integer := 16;
        SETTLE_CYCLES   : integer := 4096
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        edid_done       : in     vl_logic;
        supports_800    : in     vl_logic;
        requested_mode  : in     vl_logic_vector(1 downto 0);
        ready           : out    vl_logic;
        mode_800        : out    vl_logic;
        active_mode     : out    vl_logic_vector(1 downto 0);
        fallback        : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of QUIET_CYCLES : constant is 2;
    attribute mti_svvh_generic_type of SETTLE_CYCLES : constant is 2;
end video_mode_control;
