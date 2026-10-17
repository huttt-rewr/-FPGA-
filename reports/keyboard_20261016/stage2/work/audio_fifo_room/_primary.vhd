library verilog;
use verilog.vl_types.all;
entity audio_fifo_room is
    generic(
        ADDRESS_BITS    : integer := 10
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        full            : in     vl_logic;
        used            : in     vl_logic_vector;
        sample_ready    : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of ADDRESS_BITS : constant is 2;
end audio_fifo_room;
