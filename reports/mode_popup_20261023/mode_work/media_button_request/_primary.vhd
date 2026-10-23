library verilog;
use verilog.vl_types.all;
entity media_button_request is
    generic(
        DEBOUNCE_CYCLES : integer := 500000;
        HOLD_CYCLES     : integer := 25000000
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        key1_n          : in     vl_logic;
        key2_n          : in     vl_logic;
        movie_mode      : in     vl_logic;
        select_valid    : out    vl_logic;
        select_movie    : out    vl_logic;
        select_toggle   : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DEBOUNCE_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of HOLD_CYCLES : constant is 1;
end media_button_request;
