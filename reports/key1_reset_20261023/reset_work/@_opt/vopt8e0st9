library verilog;
use verilog.vl_types.all;
entity boot_media_select is
    generic(
        SETTLE_CYCLES   : integer := 1024;
        DEFAULT_MOVIE   : integer := 0;
        RUNTIME_SELECT  : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        key1_n          : in     vl_logic;
        movie_mode      : out    vl_logic;
        select_valid    : in     vl_logic;
        select_movie    : in     vl_logic;
        restart_request : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of SETTLE_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of DEFAULT_MOVIE : constant is 1;
    attribute mti_svvh_generic_type of RUNTIME_SELECT : constant is 1;
end boot_media_select;
