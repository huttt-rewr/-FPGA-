library verilog;
use verilog.vl_types.all;
entity av_sync_player is
    generic(
        VGA_HZ          : integer := 25000000;
        SAMPLES         : integer := 800
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        mode_800        : in     vl_logic;
        vblank          : in     vl_logic;
        request_toggle  : in     vl_logic;
        requested_bank  : in     vl_logic;
        play            : in     vl_logic;
        failed          : in     vl_logic;
        ended           : in     vl_logic;
        ack_toggle      : out    vl_logic;
        active_buffer   : out    vl_logic_vector(1 downto 0);
        visible         : out    vl_logic;
        buffering       : out    vl_logic;
        write_clk       : in     vl_logic;
        audio_we        : in     vl_logic;
        audio_address   : in     vl_logic_vector(10 downto 0);
        audio_data      : in     vl_logic_vector(15 downto 0);
        audio_valid     : out    vl_logic;
        left_pcm        : out    vl_logic_vector(23 downto 0);
        right_pcm       : out    vl_logic_vector(23 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of VGA_HZ : constant is 1;
    attribute mti_svvh_generic_type of SAMPLES : constant is 1;
end av_sync_player;
