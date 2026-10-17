library verilog;
use verilog.vl_types.all;
entity sd_read_arbiter is
    generic(
        TIMEOUT_CYCLES  : integer := 67108864
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        sd_ready        : in     vl_logic;
        bmp_req         : in     vl_logic;
        bmp_addr        : in     vl_logic_vector(31 downto 0);
        bmp_data        : out    vl_logic_vector(7 downto 0);
        bmp_valid       : out    vl_logic;
        bmp_end         : out    vl_logic;
        bmp_error       : out    vl_logic;
        bmp_grant       : out    vl_logic;
        aud_req         : in     vl_logic;
        aud_addr        : in     vl_logic_vector(31 downto 0);
        aud_data        : out    vl_logic_vector(7 downto 0);
        aud_valid       : out    vl_logic;
        aud_end         : out    vl_logic;
        aud_error       : out    vl_logic;
        sd_req          : out    vl_logic;
        sd_addr         : out    vl_logic_vector(31 downto 0);
        sd_data         : in     vl_logic_vector(7 downto 0);
        sd_valid        : in     vl_logic;
        sd_end          : in     vl_logic;
        sd_error        : in     vl_logic;
        transport_reset : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of TIMEOUT_CYCLES : constant is 1;
end sd_read_arbiter;
