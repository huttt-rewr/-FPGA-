library verilog;
use verilog.vl_types.all;
entity auto_enhance_scale is
    port(
        range_value     : in     vl_logic_vector(7 downto 0);
        scale           : out    vl_logic_vector(15 downto 0)
    );
end auto_enhance_scale;
