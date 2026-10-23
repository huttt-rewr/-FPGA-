library verilog;
use verilog.vl_types.all;
entity startup_pulse is
    generic(
        CNT_MAX         : vl_logic_vector(19 downto 0) := (Hi0, Hi0, Hi0, Hi1, Hi1, Hi0, Hi0, Hi0, Hi0, Hi1, Hi1, Hi0, Hi1, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0)
    );
    port(
        I_clk           : in     vl_logic;
        I_rst           : in     vl_logic;
        O_pulse         : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CNT_MAX : constant is 2;
end startup_pulse;
