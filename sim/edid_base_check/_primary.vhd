library verilog;
use verilog.vl_types.all;
entity edid_base_check is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        start           : in     vl_logic;
        valid           : in     vl_logic;
        data            : in     vl_logic_vector(7 downto 0);
        done            : out    vl_logic;
        good            : out    vl_logic
    );
end edid_base_check;
