library verilog;
use verilog.vl_types.all;
entity ps2_keyboard is
    generic(
        FILTER_CYCLES   : integer := 8;
        TIMEOUT_CYCLES  : integer := 200000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        ps2_clk         : in     vl_logic;
        ps2_data        : in     vl_logic;
        scan_code       : out    vl_logic_vector(7 downto 0);
        key_valid       : out    vl_logic;
        key_release     : out    vl_logic;
        key_extended    : out    vl_logic;
        receive_error   : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of FILTER_CYCLES : constant is 2;
    attribute mti_svvh_generic_type of TIMEOUT_CYCLES : constant is 2;
end ps2_keyboard;
