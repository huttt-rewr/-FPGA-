library verilog;
use verilog.vl_types.all;
entity video_scaler is
    generic(
        SRC_W           : integer := 320;
        SRC_H           : integer := 240;
        DST_W           : integer := 640;
        DST_H           : integer := 480;
        DATA_W          : integer := 24;
        FP              : integer := 16
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        i_start         : in     vl_logic;
        o_src_req       : out    vl_logic;
        i_src_pix       : in     vl_logic_vector;
        i_src_vld       : in     vl_logic;
        o_pix           : out    vl_logic_vector;
        o_pix_vld       : out    vl_logic;
        o_sof           : out    vl_logic;
        o_eol           : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of SRC_W : constant is 1;
    attribute mti_svvh_generic_type of SRC_H : constant is 1;
    attribute mti_svvh_generic_type of DST_W : constant is 1;
    attribute mti_svvh_generic_type of DST_H : constant is 1;
    attribute mti_svvh_generic_type of DATA_W : constant is 1;
    attribute mti_svvh_generic_type of FP : constant is 1;
end video_scaler;
