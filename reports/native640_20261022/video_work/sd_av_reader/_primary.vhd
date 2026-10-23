library verilog;
use verilog.vl_types.all;
entity sd_av_reader is
    generic(
        WATCHDOG        : integer := 100000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        mode_800        : in     vl_logic;
        toggle_play     : in     vl_logic;
        sd_ready        : in     vl_logic;
        sd_error        : in     vl_logic;
        sector_read     : out    vl_logic;
        sector_address  : out    vl_logic_vector(31 downto 0);
        sector_data     : in     vl_logic_vector(7 downto 0);
        sector_valid    : in     vl_logic;
        sector_end      : in     vl_logic;
        write_req       : out    vl_logic;
        write_req_ack   : in     vl_logic;
        write_finish_toggle: in     vl_logic;
        write_en        : out    vl_logic;
        write_data      : out    vl_logic_vector(31 downto 0);
        pixel_ready     : in     vl_logic;
        write_bank      : out    vl_logic_vector(1 downto 0);
        request_toggle  : out    vl_logic;
        requested_bank  : out    vl_logic;
        ack_toggle      : in     vl_logic;
        audio_we        : out    vl_logic;
        audio_address   : out    vl_logic_vector(10 downto 0);
        audio_data      : out    vl_logic_vector(15 downto 0);
        playing         : out    vl_logic;
        error           : out    vl_logic;
        ended           : out    vl_logic;
        busy            : out    vl_logic;
        state_code      : out    vl_logic_vector(3 downto 0);
        video_format    : out    vl_logic_vector(1 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WATCHDOG : constant is 1;
end sd_av_reader;
