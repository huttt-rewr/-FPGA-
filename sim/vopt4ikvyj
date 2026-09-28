library verilog;
use verilog.vl_types.all;
entity status_osd is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        rgb             : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        auto_play       : in     vl_logic;
        image_index     : in     vl_logic_vector(1 downto 0);
        image_count     : in     vl_logic_vector(2 downto 0);
        volume          : in     vl_logic_vector(4 downto 0);
        mute            : in     vl_logic;
        busy            : in     vl_logic;
        error           : in     vl_logic;
        edid_ok         : in     vl_logic;
        result          : out    vl_logic_vector(23 downto 0);
        pixel_x         : out    vl_logic_vector(9 downto 0);
        pixel_y         : out    vl_logic_vector(9 downto 0)
    );
end status_osd;
