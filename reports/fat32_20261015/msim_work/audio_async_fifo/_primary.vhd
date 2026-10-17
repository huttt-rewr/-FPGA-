library verilog;
use verilog.vl_types.all;
entity audio_async_fifo is
    generic(
        ADDRESS_BITS    : integer := 10
    );
    port(
        wr_clk          : in     vl_logic;
        rd_clk          : in     vl_logic;
        rst             : in     vl_logic;
        wr_en           : in     vl_logic;
        wr_data         : in     vl_logic_vector(23 downto 0);
        full            : out    vl_logic;
        rd_en           : in     vl_logic;
        rd_data         : out    vl_logic_vector(23 downto 0);
        empty           : out    vl_logic;
        wr_used         : out    vl_logic_vector;
        rd_used         : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ADDRESS_BITS : constant is 1;
end audio_async_fifo;
