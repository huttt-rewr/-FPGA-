library verilog;
use verilog.vl_types.all;
entity av_audio_gain is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        valid           : in     vl_logic;
        pcm             : in     vl_logic_vector(23 downto 0);
        volume          : in     vl_logic_vector(4 downto 0);
        mute            : in     vl_logic;
        out_valid       : out    vl_logic;
        out_pcm         : out    vl_logic_vector(23 downto 0)
    );
end av_audio_gain;
