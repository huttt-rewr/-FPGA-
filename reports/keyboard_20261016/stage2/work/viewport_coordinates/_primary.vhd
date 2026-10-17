library verilog;
use verilog.vl_types.all;
entity viewport_coordinates is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        expanded        : in     vl_logic;
        x               : out    vl_logic_vector(9 downto 0);
        y               : out    vl_logic_vector(9 downto 0);
        raw_x           : out    vl_logic_vector(9 downto 0);
        raw_y           : out    vl_logic_vector(9 downto 0)
    );
end viewport_coordinates;
