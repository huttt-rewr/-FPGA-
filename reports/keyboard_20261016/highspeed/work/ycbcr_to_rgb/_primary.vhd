library verilog;
use verilog.vl_types.all;
entity ycbcr_to_rgb is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        valid           : in     vl_logic;
        y               : in     vl_logic_vector(7 downto 0);
        cb              : in     vl_logic_vector(7 downto 0);
        cr              : in     vl_logic_vector(7 downto 0);
        out_valid       : out    vl_logic;
        rgb             : out    vl_logic_vector(23 downto 0)
    );
end ycbcr_to_rgb;
