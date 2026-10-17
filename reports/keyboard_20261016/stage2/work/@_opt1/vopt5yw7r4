library verilog;
use verilog.vl_types.all;
entity audio_effects is
    generic(
        N_TAP           : integer := 15;
        BASS_GAIN       : vl_logic_vector(15 downto 0) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0);
        TREBLE_GAIN     : vl_logic_vector(15 downto 0) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0);
        ECHO_DELAY      : integer := 2400;
        ECHO_FEEDBACK   : vl_logic_vector(15 downto 0) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0)
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        src_valid       : in     vl_logic;
        src_left        : in     vl_logic_vector(23 downto 0);
        src_right       : in     vl_logic_vector(23 downto 0);
        out_valid       : out    vl_logic;
        out_left        : out    vl_logic_vector(23 downto 0);
        out_right       : out    vl_logic_vector(23 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of N_TAP : constant is 2;
    attribute mti_svvh_generic_type of BASS_GAIN : constant is 2;
    attribute mti_svvh_generic_type of TREBLE_GAIN : constant is 2;
    attribute mti_svvh_generic_type of ECHO_DELAY : constant is 2;
    attribute mti_svvh_generic_type of ECHO_FEEDBACK : constant is 2;
end audio_effects;
