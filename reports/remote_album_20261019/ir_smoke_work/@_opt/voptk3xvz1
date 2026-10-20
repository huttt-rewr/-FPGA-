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
        ir_rx           : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HZ : constant is 1;
    attribute mti_svvh_generic_type of BAUD : constant is 1;
    attribute mti_svvh_generic_type of TIMEOUT_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of IR_ENABLED : constant is 1;
end remote_controls;
