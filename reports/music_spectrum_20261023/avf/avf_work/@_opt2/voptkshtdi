library verilog;
use verilog.vl_types.all;
entity bmp_read is
    generic(
        READ_STALL_CYCLES: integer := 67108864;
        ADAPTIVE        : integer := 0;
        ENABLE_SCALING  : integer := 0;
        SHARED_SD       : integer := 0;
        FILESYSTEM      : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        ready           : out    vl_logic;
        scan_start      : in     vl_logic;
        scan_start_sector: in     vl_logic_vector(31 downto 0);
        scan_max_sector : in     vl_logic_vector(31 downto 0);
        scan_target_count: in     vl_logic_vector(2 downto 0);
        fs_mount_done   : in     vl_logic;
        fs_bmp_count    : in     vl_logic_vector(2 downto 0);
        scan_done       : out    vl_logic;
        scan_found_valid: out    vl_logic;
        scan_found_sector: out    vl_logic_vector(31 downto 0);
        scan_found_total: out    vl_logic_vector(2 downto 0);
        load_start      : in     vl_logic;
        load_abort      : in     vl_logic;
        load_sector     : in     vl_logic_vector(31 downto 0);
        sd_init_done    : in     vl_logic;
        read_granted    : in     vl_logic;
        state_code      : out    vl_logic_vector(3 downto 0);
        bmp_width       : in     vl_logic_vector(15 downto 0);
        bmp_height      : in     vl_logic_vector(15 downto 0);
        write_req       : out    vl_logic;
        write_req_ack   : in     vl_logic;
        sd_sec_read     : out    vl_logic;
        sd_sec_read_addr: out    vl_logic_vector(31 downto 0);
        sd_sec_read_data: in     vl_logic_vector(7 downto 0);
        sd_sec_read_data_valid: in     vl_logic;
        sd_sec_read_end : in     vl_logic;
        bmp_data_wr_en  : out    vl_logic;
        bmp_data        : out    vl_logic_vector(23 downto 0);
        read_stall      : out    vl_logic;
        pixel_ready     : in     vl_logic;
        source_width    : out    vl_logic_vector(11 downto 0);
        source_height   : out    vl_logic_vector(11 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of READ_STALL_CYCLES : constant is 2;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
    attribute mti_svvh_generic_type of ENABLE_SCALING : constant is 1;
    attribute mti_svvh_generic_type of SHARED_SD : constant is 1;
    attribute mti_svvh_generic_type of FILESYSTEM : constant is 1;
end bmp_read;
