library verilog;
use verilog.vl_types.all;
entity player_control is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        uart_data       : in     vl_logic_vector(7 downto 0);
        uart_valid      : in     vl_logic;
        ir_command      : in     vl_logic_vector(7 downto 0);
        ir_valid        : in     vl_logic;
        next_pulse      : out    vl_logic;
        prev_pulse      : out    vl_logic;
        toggle_pulse    : out    vl_logic;
        volume          : out    vl_logic_vector(4 downto 0);
        mute            : out    vl_logic;
        osd_enable      : out    vl_logic;
        brightness      : out    vl_logic_vector(7 downto 0);
        test_pattern    : out    vl_logic;
        reply_valid     : out    vl_logic;
        reply           : out    vl_logic_vector(7 downto 0)
    );
end player_control;
