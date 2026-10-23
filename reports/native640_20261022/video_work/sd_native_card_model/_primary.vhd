library verilog;
use verilog.vl_types.all;
entity sd_native_card_model is
    generic(
        IMAGE_MODE      : integer := 0;
        DOUT_DELAY      : integer := 0;
        IMAGE_FILE      : string  := ""
    );
    port(
        rst             : in     vl_logic;
        SD_CLK          : in     vl_logic;
        SD_CMD          : inout  vl_logic;
        SD_DAT          : inout  vl_logic_vector(3 downto 0);
        ccs             : in     vl_logic;
        fault           : in     vl_logic_vector(3 downto 0);
        hs_mode         : in     vl_logic_vector(3 downto 0);
        last_read_argument: out    vl_logic_vector(31 downto 0);
        commands        : out    vl_logic_vector(31 downto 0);
        reads           : out    vl_logic_vector(31 downto 0);
        errors          : out    vl_logic_vector(31 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of IMAGE_MODE : constant is 2;
    attribute mti_svvh_generic_type of DOUT_DELAY : constant is 2;
    attribute mti_svvh_generic_type of IMAGE_FILE : constant is 1;
end sd_native_card_model;
