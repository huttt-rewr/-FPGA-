library verilog;
use verilog.vl_types.all;
entity ir_nec_rx is
    generic(
        CLK_FREQ        : integer := 100000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        ir_in           : in     vl_logic;
        o_command       : out    vl_logic_vector(7 downto 0);
        o_command_valid : out    vl_logic;
        o_repeat        : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_FREQ : constant is 1;
end ir_nec_rx;
