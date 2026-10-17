library verilog;
use verilog.vl_types.all;
entity video_coordinates is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : out    vl_logic_vector(9 downto 0);
        y               : out    vl_logic_vector(9 downto 0)
    );
end video_coordinates;
