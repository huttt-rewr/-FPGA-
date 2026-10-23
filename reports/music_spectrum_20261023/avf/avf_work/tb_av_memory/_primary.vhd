library verilog;
use verilog.vl_types.all;
entity tb_av_memory is
    generic(
        HQ              : integer := 0
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of HQ : constant is 1;
end tb_av_memory;
