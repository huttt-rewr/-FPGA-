library verilog;
use verilog.vl_types.all;
entity audio_playback is
    generic(
        CLK_HZ          : integer := 25000000;
        ADAPTIVE        : integer := 0;
        PREFILL         : integer := 256
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        volume          : in     vl_logic_vector(4 downto 0);
        mute            : in     vl_logic;
        mode_800        : in     vl_logic;
        stream_ok       : in     vl_logic;
        fifo_empty      : in     vl_logic;
        fifo_used       : in     vl_logic_vector(10 downto 0);
        fifo_data       : in     vl_logic_vector(23 downto 0);
        fifo_rd_en      : out    vl_logic;
        valid           : out    vl_logic;
        left_pcm        : out    vl_logic_vector(23 downto 0);
        right_pcm       : out    vl_logic_vector(23 downto 0);
        underflow       : out    vl_logic;
        pcm_valid       : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of CLK_HZ : constant is 1;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
    attribute mti_svvh_generic_type of PREFILL : constant is 1;
end audio_playback;
