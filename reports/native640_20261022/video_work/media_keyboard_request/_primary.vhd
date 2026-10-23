library verilog;
use verilog.vl_types.all;
entity media_keyboard_request is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        controls_reset  : in     vl_logic;
        scan_code       : in     vl_logic_vector(7 downto 0);
        key_valid       : in     vl_logic;
        key_release     : in     vl_logic;
        key_extended    : in     vl_logic;
        receive_error   : in     vl_logic;
        select_valid    : out    vl_logic;
        select_movie    : out    vl_logic
    );
end media_keyboard_request;
