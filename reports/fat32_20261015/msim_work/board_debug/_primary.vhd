library verilog;
use verilog.vl_types.all;
entity board_debug is
    generic(
        UPDATE_CYCLES   : integer := 10000000
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        video_clk       : in     vl_logic;
        video_rst       : in     vl_logic;
        mem_clk         : in     vl_logic;
        mem_rst         : in     vl_logic;
        vs              : in     vl_logic;
        hs              : in     vl_logic;
        de              : in     vl_logic;
        video_flags     : in     vl_logic_vector(7 downto 0);
        memory_status   : in     vl_logic_vector(19 downto 0);
        read_status     : in     vl_logic_vector(10 downto 0);
        reset_count     : in     vl_logic_vector(7 downto 0);
        sd_status       : in     vl_logic_vector(3 downto 0);
        player_state    : in     vl_logic_vector(3 downto 0);
        page            : in     vl_logic_vector(1 downto 0);
        display_word    : out    vl_logic_vector(23 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of UPDATE_CYCLES : constant is 1;
end board_debug;
