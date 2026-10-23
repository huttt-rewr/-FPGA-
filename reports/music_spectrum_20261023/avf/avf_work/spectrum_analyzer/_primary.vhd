library verilog;
use verilog.vl_types.all;
entity spectrum_analyzer is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        frame_start     : in     vl_logic;
        audio_valid     : in     vl_logic;
        audio_left      : in     vl_logic_vector(23 downto 0);
        display_band    : in     vl_logic_vector(4 downto 0);
        display_height  : out    vl_logic_vector(6 downto 0);
        display_peak    : out    vl_logic_vector(6 downto 0)
    );
end spectrum_analyzer;
