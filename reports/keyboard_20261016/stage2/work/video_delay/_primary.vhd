library verilog;
use verilog.vl_types.all;
entity video_delay is
    generic(
        DATA_WIDTH      : integer := 24;
        SYNC_STAGES     : integer := 21;
        FIFO_CAPTURE_LATENCY: integer := 2
    );
    port(
        video_clk       : in     vl_logic;
        rst             : in     vl_logic;
        read_en         : out    vl_logic;
        read_data       : in     vl_logic_vector;
        hs              : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        hs_r            : out    vl_logic;
        vs_r            : out    vl_logic;
        de_r            : out    vl_logic;
        vout_data       : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DATA_WIDTH : constant is 1;
    attribute mti_svvh_generic_type of SYNC_STAGES : constant is 1;
    attribute mti_svvh_generic_type of FIFO_CAPTURE_LATENCY : constant is 1;
end video_delay;
