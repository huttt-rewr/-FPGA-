library verilog;
use verilog.vl_types.all;
entity cdc_snapshot is
    generic(
        WIDTH           : integer := 8
    );
    port(
        src_clk         : in     vl_logic;
        src_rst         : in     vl_logic;
        src_data        : in     vl_logic_vector;
        dst_clk         : in     vl_logic;
        dst_rst         : in     vl_logic;
        dst_data        : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WIDTH : constant is 1;
end cdc_snapshot;
