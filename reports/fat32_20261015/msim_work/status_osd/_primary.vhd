library verilog;
use verilog.vl_types.all;
entity status_osd is
    generic(
        ENHANCED_UI     : integer := 0;
        ADAPTIVE        : integer := 0;
        PIPELINED       : integer := 0;
        BOARD_UI        : integer := 0;
        AUDIO_UI        : integer := 0;
        AUDIO_DIAGNOSTICS: integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        rgb             : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        auto_play       : in     vl_logic;
        image_index     : in     vl_logic_vector(1 downto 0);
        image_count     : in     vl_logic_vector(2 downto 0);
        volume          : in     vl_logic_vector(4 downto 0);
        mute            : in     vl_logic;
        busy            : in     vl_logic;
        error           : in     vl_logic;
        edid_ok         : in     vl_logic;
        result          : out    vl_logic_vector(23 downto 0);
        pixel_x         : out    vl_logic_vector(9 downto 0);
        pixel_y         : out    vl_logic_vector(9 downto 0);
        brightness      : in     vl_logic_vector(7 downto 0);
        contrast        : in     vl_logic_vector(3 downto 0);
        edit_mode       : in     vl_logic_vector(1 downto 0);
        source_width    : in     vl_logic_vector(11 downto 0);
        source_height   : in     vl_logic_vector(11 downto 0);
        mode_800        : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        menu_open       : in     vl_logic;
        menu_item       : in     vl_logic_vector(2 downto 0);
        gamma_enable    : in     vl_logic;
        debug_enable    : in     vl_logic;
        debug_page      : in     vl_logic_vector(1 downto 0);
        audio_ready     : in     vl_logic;
        audio_error     : in     vl_logic;
        audio_error_code: in     vl_logic_vector(3 downto 0);
        audio_underflow : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ENHANCED_UI : constant is 1;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
    attribute mti_svvh_generic_type of PIPELINED : constant is 1;
    attribute mti_svvh_generic_type of BOARD_UI : constant is 1;
    attribute mti_svvh_generic_type of AUDIO_UI : constant is 1;
    attribute mti_svvh_generic_type of AUDIO_DIAGNOSTICS : constant is 1;
end status_osd;
