library verilog;
use verilog.vl_types.all;
entity sd_native_controller is
    generic(
        ENABLE_HIGH_SPEED: integer := 0;
        INIT_TIMEOUT_CYCLES: integer := 800000000;
        INIT_PAUSE_CYCLES: integer := 100000000;
        INIT_ATTEMPT_LIMIT: integer := 4096
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        rise_tick       : in     vl_logic;
        high_speed      : out    vl_logic;
        open_drain      : out    vl_logic;
        phy_reset       : out    vl_logic;
        high_speed_50   : out    vl_logic;
        read_length     : out    vl_logic_vector(9 downto 0);
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
        sd_sec_write_end: out    vl_logic;
        cmd_start       : out    vl_logic;
        cmd_index       : out    vl_logic_vector(5 downto 0);
        cmd_argument    : out    vl_logic_vector(31 downto 0);
        response_type   : out    vl_logic_vector(2 downto 0);
        cmd_ready       : in     vl_logic;
        cmd_done        : in     vl_logic;
        cmd_error       : in     vl_logic;
        response        : in     vl_logic_vector(135 downto 0);
        read_arm        : out    vl_logic;
        read_cancel     : out    vl_logic;
        read_data       : in     vl_logic_vector(7 downto 0);
        read_valid      : in     vl_logic;
        read_done       : in     vl_logic;
        read_error      : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ENABLE_HIGH_SPEED : constant is 1;
    attribute mti_svvh_generic_type of INIT_TIMEOUT_CYCLES : constant is 2;
    attribute mti_svvh_generic_type of INIT_PAUSE_CYCLES : constant is 2;
    attribute mti_svvh_generic_type of INIT_ATTEMPT_LIMIT : constant is 2;
end sd_native_controller;
