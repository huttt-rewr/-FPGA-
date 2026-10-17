library verilog;
use verilog.vl_types.all;
entity audio_wav is
    generic(
        START_SECTOR    : vl_logic_vector(31 downto 0) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0);
        FILESYSTEM      : integer := 0;
        MAX_BYTES       : vl_logic_vector(31 downto 0) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0);
        RETRY_CYCLES    : integer := 100000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        sd_init_done    : in     vl_logic;
        enable          : in     vl_logic;
        sector_room     : in     vl_logic;
        sample_ready    : in     vl_logic;
        req             : out    vl_logic;
        addr            : out    vl_logic_vector(31 downto 0);
        data            : in     vl_logic_vector(7 downto 0);
        data_valid      : in     vl_logic;
        sector_end      : in     vl_logic;
        read_error      : in     vl_logic;
        sample_valid    : out    vl_logic;
        sample          : out    vl_logic_vector(23 downto 0);
        error           : out    vl_logic;
        error_code      : out    vl_logic_vector(3 downto 0);
        ready           : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of START_SECTOR : constant is 2;
    attribute mti_svvh_generic_type of FILESYSTEM : constant is 1;
    attribute mti_svvh_generic_type of MAX_BYTES : constant is 2;
    attribute mti_svvh_generic_type of RETRY_CYCLES : constant is 2;
end audio_wav;
