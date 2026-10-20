library verilog;
use verilog.vl_types.all;
entity uart_rx is
    generic(
        CLK_FREQ        : integer := 100000000;
        BAUD            : integer := 115200
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        rx              : in     vl_logic;
        o_data          : out    vl_logic_vector(7 downto 0);
        o_valid         : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_FREQ : constant is 1;
    attribute mti_svvh_generic_type of BAUD : constant is 1;
end uart_rx;
