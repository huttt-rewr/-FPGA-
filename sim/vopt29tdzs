library verilog;
use verilog.vl_types.all;
entity video_rgb_to_axis_640x480 is
    port(
        I_clk           : in     vl_logic;
        I_rst           : in     vl_logic;
        I_vs            : in     vl_logic;
        I_de            : in     vl_logic;
        I_rgb           : in     vl_logic_vector(23 downto 0);
        O_video_user    : out    vl_logic;
        O_video_valid   : out    vl_logic;
        O_video_last    : out    vl_logic;
        O_video_data    : out    vl_logic_vector(23 downto 0)
    );
end video_rgb_to_axis_640x480;
