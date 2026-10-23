library verilog;
use verilog.vl_types.all;
entity bmp_scale_loader is
    generic(
        ADAPTIVE        : integer := 0
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        start           : in     vl_logic;
        source_width    : in     vl_logic_vector(11 downto 0);
        source_height   : in     vl_logic_vector(11 downto 0);
        pixel_offset    : in     vl_logic_vector(31 downto 0);
        base_sector     : in     vl_logic_vector(31 downto 0);
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
        busy            : out    vl_logic;
        mode_800        : in     vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ADAPTIVE : constant is 1;
end bmp_scale_loader;
