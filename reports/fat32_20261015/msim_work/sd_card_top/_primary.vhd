library verilog;
use verilog.vl_types.all;
entity sd_card_top is
    generic(
        SPI_LOW_SPEED_DIV: integer := 248;
        SPI_HIGH_SPEED_DIV: integer := 0;
        INIT_TIMEOUT_CYCLES: integer := 800000000;
        INIT_PAUSE_CYCLES: integer := 100000000;
        WAIT_TIMEOUT_CYCLES: integer := 67108864
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        SD_nCS          : out    vl_logic;
        SD_DCLK         : out    vl_logic;
        SD_MOSI         : out    vl_logic;
        SD_MISO         : in     vl_logic;
        sd_init_done    : out    vl_logic;
        sd_init_error   : out    vl_logic;
        sd_transfer_error: out    vl_logic;
        sd_sec_read     : in     vl_logic;
        sd_sec_read_addr: in     vl_logic_vector(31 downto 0);
        sd_sec_read_data: out    vl_logic_vector(7 downto 0);
        sd_sec_read_data_valid: out    vl_logic;
        sd_sec_read_end : out    vl_logic;
        sd_sec_write    : in     vl_logic;
        sd_sec_write_addr: in     vl_logic_vector(31 downto 0);
        sd_sec_write_data: in     vl_logic_vector(7 downto 0);
        sd_sec_write_data_req: out    vl_logic;
        sd_sec_write_end: out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of SPI_LOW_SPEED_DIV : constant is 1;
    attribute mti_svvh_generic_type of SPI_HIGH_SPEED_DIV : constant is 1;
    attribute mti_svvh_generic_type of INIT_TIMEOUT_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of INIT_PAUSE_CYCLES : constant is 1;
    attribute mti_svvh_generic_type of WAIT_TIMEOUT_CYCLES : constant is 1;
end sd_card_top;
