library verilog;
use verilog.vl_types.all;
entity sd_fat32_reference is
    generic(
        MAX_BMP         : integer := 4;
        ROOT_CLUSTER_LIMIT: integer := 4096
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        sd_init_done    : in     vl_logic;
        mount_done      : out    vl_logic;
        mount_error     : out    vl_logic;
        mount_error_code: out    vl_logic_vector(3 downto 0);
        bmp_count       : out    vl_logic_vector(2 downto 0);
        wav_found       : out    vl_logic;
        bmp_size        : out    vl_logic_vector;
        wav_size        : out    vl_logic_vector(31 downto 0);
        bmp_req         : in     vl_logic;
        bmp_file_idx    : in     vl_logic_vector(2 downto 0);
        bmp_rel_sector  : in     vl_logic_vector(31 downto 0);
        bmp_data        : out    vl_logic_vector(7 downto 0);
        bmp_valid       : out    vl_logic;
        bmp_end         : out    vl_logic;
        bmp_error       : out    vl_logic;
        bmp_grant       : out    vl_logic;
        aud_req         : in     vl_logic;
        aud_rel_sector  : in     vl_logic_vector(31 downto 0);
        aud_data        : out    vl_logic_vector(7 downto 0);
        aud_valid       : out    vl_logic;
        aud_end         : out    vl_logic;
        aud_error       : out    vl_logic;
        arb_bmp_req     : out    vl_logic;
        arb_bmp_addr    : out    vl_logic_vector(31 downto 0);
        arb_bmp_data    : in     vl_logic_vector(7 downto 0);
        arb_bmp_valid   : in     vl_logic;
        arb_bmp_end     : in     vl_logic;
        arb_bmp_error   : in     vl_logic;
        arb_bmp_grant   : in     vl_logic;
        arb_aud_req     : out    vl_logic;
        arb_aud_addr    : out    vl_logic_vector(31 downto 0);
        arb_aud_data    : in     vl_logic_vector(7 downto 0);
        arb_aud_valid   : in     vl_logic;
        arb_aud_end     : in     vl_logic;
        arb_aud_error   : in     vl_logic;
        bmp_abort       : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of MAX_BMP : constant is 2;
    attribute mti_svvh_generic_type of ROOT_CLUSTER_LIMIT : constant is 2;
end sd_fat32_reference;
