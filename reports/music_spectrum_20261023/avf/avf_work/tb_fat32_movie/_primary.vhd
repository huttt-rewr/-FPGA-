library verilog;
use verilog.vl_types.all;
entity tb_fat32_movie is
    generic(
        SCENARIO        : integer := 0;
        HQ              : integer := 0
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of SCENARIO : constant is 1;
    attribute mti_svvh_generic_type of HQ : constant is 1;
end tb_fat32_movie;
