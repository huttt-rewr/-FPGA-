library verilog;
use verilog.vl_types.all;
entity sdram is
    port(
        Clk             : in     vl_logic;
        Clk_sft         : in     vl_logic;
        Rst             : in     vl_logic;
        Sdr_init_done   : out    vl_logic;
        Sdr_init_ref_vld: out    vl_logic;
        Sdr_busy        : out    vl_logic;
        App_wr_en       : in     vl_logic;
        App_wr_addr     : in     vl_logic_vector(20 downto 0);
        App_wr_dm       : in     vl_logic_vector(3 downto 0);
        App_wr_din      : in     vl_logic_vector(31 downto 0);
        App_rd_en       : in     vl_logic;
        App_rd_addr     : in     vl_logic_vector(20 downto 0);
        Sdr_rd_en       : out    vl_logic;
        Sdr_rd_dout     : out    vl_logic_vector(31 downto 0)
    );
end sdram;
