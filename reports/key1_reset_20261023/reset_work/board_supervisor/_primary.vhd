library verilog;
use verilog.vl_types.all;
entity board_supervisor is
    generic(
        POWER_CYCLES    : integer := 250000;
        TIMEOUT_CYCLES  : integer := 50000000
    );
    port(
        clk             : in     vl_logic;
        arst            : in     vl_logic;
        enable          : in     vl_logic;
        heartbeat_toggle: in     vl_logic;
        reset_request   : out    vl_logic;
        watchdog_resets : out    vl_logic_vector(7 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of POWER_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of TIMEOUT_CYCLES : constant is 1;
end board_supervisor;
