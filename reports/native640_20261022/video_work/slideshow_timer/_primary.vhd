library verilog;
use verilog.vl_types.all;
entity slideshow_timer is
    generic(
        PERIOD          : integer := 500000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        enable          : in     vl_logic;
        busy            : in     vl_logic;
        next_pulse      : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of PERIOD : constant is 1;
end slideshow_timer;
