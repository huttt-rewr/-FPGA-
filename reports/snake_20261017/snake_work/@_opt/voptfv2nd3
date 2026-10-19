library verilog;
use verilog.vl_types.all;
entity snake_lut_ram is
    generic(
        WIDTH           : integer := 1;
        DEPTH           : integer := 768;
        AW              : vl_notype
    );
    port(
        clk             : in     vl_logic;
        we              : in     vl_logic;
        wa              : in     vl_logic_vector;
        ra              : in     vl_logic_vector;
        rb              : in     vl_logic_vector;
        wd              : in     vl_logic_vector;
        qa              : out    vl_logic_vector;
        qb              : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WIDTH : constant is 1;
    attribute mti_svvh_generic_type of DEPTH : constant is 1;
    attribute mti_svvh_generic_type of AW : constant is 3;
end snake_lut_ram;
