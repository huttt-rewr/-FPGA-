library verilog;
use verilog.vl_types.all;
entity edid_display_mode is
    generic(
        TIMEOUT         : integer := 16777216
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        start           : in     vl_logic;
        valid           : in     vl_logic;
        data            : in     vl_logic_vector(7 downto 0);
        done            : out    vl_logic;
        good            : out    vl_logic;
        mode_800        : out    vl_logic;
        fallback        : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of TIMEOUT : constant is 1;
end edid_display_mode;
