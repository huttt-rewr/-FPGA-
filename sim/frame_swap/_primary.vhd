library verilog;
use verilog.vl_types.all;
entity frame_swap is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vblank          : in     vl_logic;
        request_toggle  : in     vl_logic;
        requested_buffer: in     vl_logic_vector(1 downto 0);
        ack_toggle      : out    vl_logic;
        active_buffer   : out    vl_logic_vector(1 downto 0);
        display_valid   : out    vl_logic
    );
end frame_swap;
