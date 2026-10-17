library verilog;
use verilog.vl_types.all;
entity video_timing_data is
    generic(
        ADAPTIVE        : integer := 0
    );
    port(
        video_clk       : in     vl_logic;
        rst             : in     vl_logic;
        read_req        : out    vl_logic;
        read_req_ack    : in     vl_logic;
        hs              : out    vl_logic;
        vs              : out    vl_logic;
        de              : out    vl_logic;
        vblank          : out    vl_logic;
        mode_800        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
end video_timing_data;
