library verilog;
use verilog.vl_types.all;
entity time_cmd is
    generic(
        TIMEOUT_CYCLES  : integer := 50000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        uart_data       : in     vl_logic_vector(7 downto 0);
        uart_valid      : in     vl_logic;
        time_bcd        : out    vl_logic_vector(23 downto 0);
        time_seq        : out    vl_logic_vector(7 downto 0);
        time_set        : out    vl_logic;
        busy            : out    vl_logic;
        reply_valid     : out    vl_logic;
        reply_ok        : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of TIMEOUT_CYCLES : constant is 1;
end time_cmd;
