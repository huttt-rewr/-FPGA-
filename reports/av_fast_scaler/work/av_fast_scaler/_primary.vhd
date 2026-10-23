library verilog;
use verilog.vl_types.all;
entity av_fast_scaler is
    generic(
        FORMAT_SELECT   : integer := 1
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        start           : in     vl_logic;
        base_sector     : in     vl_logic_vector(31 downto 0);
        high_quality    : in     vl_logic;
        sector_read     : out    vl_logic;
        sector_address  : out    vl_logic_vector(31 downto 0);
        sector_data     : in     vl_logic_vector(7 downto 0);
        sector_valid    : in     vl_logic;
        sector_end      : in     vl_logic;
        pixel           : out    vl_logic_vector(23 downto 0);
        pixel_valid     : out    vl_logic;
        pixel_ready     : in     vl_logic;
        done            : out    vl_logic;
        error           : out    vl_logic;
        busy            : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of FORMAT_SELECT : constant is 1;
end av_fast_scaler;
