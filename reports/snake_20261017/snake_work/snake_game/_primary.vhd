library verilog;
use verilog.vl_types.all;
entity snake_game is
    generic(
        GW              : integer := 32;
        GH              : integer := 24;
        CELL            : integer := 16;
        SCREEN_W        : integer := 640;
        SCREEN_H        : integer := 480
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        game_enable     : in     vl_logic;
        dir_req         : in     vl_logic_vector(1 downto 0);
        tick            : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0);
        score           : out    vl_logic_vector(7 downto 0);
        game_over       : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of GW : constant is 2;
    attribute mti_svvh_generic_type of GH : constant is 2;
    attribute mti_svvh_generic_type of CELL : constant is 2;
    attribute mti_svvh_generic_type of SCREEN_W : constant is 2;
    attribute mti_svvh_generic_type of SCREEN_H : constant is 2;
end snake_game;
