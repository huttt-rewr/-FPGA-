library verilog;
use verilog.vl_types.all;
entity audio_test_source is
    generic(
        CLK_HZ          : integer := 25000000;
        SAMPLE_HZ       : integer := 48000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        volume          : in     vl_logic_vector(4 downto 0);
        mute            : in     vl_logic;
        valid           : out    vl_logic;
        left_pcm        : out    vl_logic_vector(23 downto 0);
        right_pcm       : out    vl_logic_vector(23 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HZ : constant is 1;
    attribute mti_svvh_generic_type of SAMPLE_HZ : constant is 1;
end audio_test_source;
