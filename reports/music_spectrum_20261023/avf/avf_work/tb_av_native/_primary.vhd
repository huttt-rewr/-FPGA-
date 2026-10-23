library verilog;
use verilog.vl_types.all;
entity tb_av_native is
    generic(
        VIDEO_FORMAT    : integer := 2;
        FAULT           : integer := 0
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of VIDEO_FORMAT : constant is 1;
    attribute mti_svvh_generic_type of FAULT : constant is 1;
end tb_av_native;
