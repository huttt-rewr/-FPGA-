library verilog;
use verilog.vl_types.all;
entity video_rgb_to_axis_640x480 is
    generic(
        ADAPTIVE        : integer := 0
    );
    port(
        I_clk           : in     vl_logic;
        I_rst           : in     vl_logic;
        I_vs            : in     vl_logic;
        I_de            : in     vl_logic;
        I_rgb           : in     vl_logic_vector(23 downto 0);
        O_video_user    : out    vl_logic;
        O_video_valid   : out    vl_logic;
        O_video_last    : out    vl_logic;
        O_video_data    : out    vl_logic_vector(23 downto 0);
        I_ready         : in     vl_logic;
        O_overflow      : out    vl_logic;
        mode_800        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
end video_rgb_to_axis_640x480;
