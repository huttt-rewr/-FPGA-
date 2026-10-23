library verilog;
use verilog.vl_types.all;
entity music_wave_capture is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        frame_start     : in     vl_logic;
        audio_valid     : in     vl_logic;
        audio_left      : in     vl_logic_vector(23 downto 0);
        display_index   : in     vl_logic_vector(7 downto 0);
        wave_a          : out    vl_logic_vector(5 downto 0);
        wave_b          : out    vl_logic_vector(5 downto 0);
        known           : out    vl_logic
    );
end music_wave_capture;
