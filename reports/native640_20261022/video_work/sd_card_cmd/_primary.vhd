library verilog;
use verilog.vl_types.all;
entity sd_card_cmd is
    generic(
        WAIT_TIMEOUT_CYCLES: integer := 67108864
    );
    port(
        sys_clk         : in     vl_logic;
        rst             : in     vl_logic;
        spi_clk_div     : in     vl_logic_vector(15 downto 0);
        cmd_req         : in     vl_logic;
        cmd_req_ack     : out    vl_logic;
        cmd_req_error   : out    vl_logic;
        cmd             : in     vl_logic_vector(47 downto 0);
        cmd_r1          : in     vl_logic_vector(7 downto 0);
        response_valid  : out    vl_logic;
        response_data   : out    vl_logic_vector(7 downto 0);
        cmd_data_len    : in     vl_logic_vector(15 downto 0);
        block_read_req  : in     vl_logic;
        block_read_valid: out    vl_logic;
        block_read_data : out    vl_logic_vector(7 downto 0);
        block_read_req_ack: out    vl_logic;
        block_write_req : in     vl_logic;
        block_write_data: in     vl_logic_vector(7 downto 0);
        block_write_data_rd: out    vl_logic;
        block_write_req_ack: out    vl_logic;
        nCS_ctrl        : out    vl_logic;
        clk_div         : out    vl_logic_vector(15 downto 0);
        spi_wr_req      : out    vl_logic;
        spi_wr_ack      : in     vl_logic;
        spi_data_in     : out    vl_logic_vector(7 downto 0);
        spi_data_out    : in     vl_logic_vector(7 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of WAIT_TIMEOUT_CYCLES : constant is 2;
end sd_card_cmd;
