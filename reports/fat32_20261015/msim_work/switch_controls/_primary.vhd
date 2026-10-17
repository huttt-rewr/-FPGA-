library verilog;
use verilog.vl_types.all;
entity switch_controls is
    generic(
        DEBOUNCE_CYCLES : integer := 2000000;
        ON_LEVEL        : vl_logic_vector(3 downto 0) := (Hi0, Hi0, Hi0, Hi0)
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        sw              : in     vl_logic_vector(3 downto 0);
        captions_enable : out    vl_logic;
        scroll_enable   : out    vl_logic;
        transition_mode : out    vl_logic_vector(1 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DEBOUNCE_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of ON_LEVEL : constant is 2;
end switch_controls;
