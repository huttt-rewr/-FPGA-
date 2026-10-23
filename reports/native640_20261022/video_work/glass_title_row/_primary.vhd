library verilog;
use verilog.vl_types.all;
entity glass_title_row is
    port(
        column          : in     vl_logic_vector(6 downto 0);
        row             : in     vl_logic_vector(3 downto 0);
        bits            : out    vl_logic_vector(7 downto 0)
    );
end glass_title_row;
