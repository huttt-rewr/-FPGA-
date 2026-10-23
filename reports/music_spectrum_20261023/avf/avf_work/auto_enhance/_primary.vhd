library verilog;
use verilog.vl_types.all;
entity auto_enhance is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_x           : out    vl_logic_vector(9 downto 0);
        out_y           : out    vl_logic_vector(9 downto 0);
        out_rgb         : out    vl_logic_vector(23 downto 0)
    );
end auto_enhance;
