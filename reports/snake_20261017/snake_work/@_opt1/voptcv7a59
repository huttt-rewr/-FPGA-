library verilog;
use verilog.vl_types.all;
entity snake_frame_control is
    generic(
        FRAMES_PER_TICK : integer := 6
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        controls        : in     vl_logic_vector(4 downto 0);
        game_on         : out    vl_logic;
        dir_req         : out    vl_logic_vector(1 downto 0);
        tick            : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of FRAMES_PER_TICK : constant is 2;
end snake_frame_control;
