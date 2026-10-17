library verilog;
use verilog.vl_types.all;
entity sd_bus_phy is
    generic(
        LOW_HALF_CYCLES : integer := 250;
        WAIT_TIMEOUT_CYCLES: integer := 67108864
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        high_speed      : in     vl_logic;
        open_drain      : in     vl_logic;
        high_speed_50   : in     vl_logic;
        read_length     : in     vl_logic_vector(9 downto 0);
        SD_CLK          : out    vl_logic;
        SD_CMD          : inout  vl_logic;
        SD_DAT          : inout  vl_logic_vector(3 downto 0);
        rise_tick       : out    vl_logic;
        fall_tick       : out    vl_logic;
        cmd_start       : in     vl_logic;
        cmd_index       : in     vl_logic_vector(5 downto 0);
        cmd_argument    : in     vl_logic_vector(31 downto 0);
        response_type   : in     vl_logic_vector(2 downto 0);
        cmd_ready       : out    vl_logic;
        cmd_done        : out    vl_logic;
        cmd_error       : out    vl_logic;
        response        : out    vl_logic_vector(135 downto 0);
        read_arm        : in     vl_logic;
        read_cancel     : in     vl_logic;
        read_data       : out    vl_logic_vector(7 downto 0);
        read_valid      : out    vl_logic;
        read_done       : out    vl_logic;
        read_error      : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of LOW_HALF_CYCLES : constant is 2;
    attribute mti_svvh_generic_type of WAIT_TIMEOUT_CYCLES : constant is 2;
end sd_bus_phy;
