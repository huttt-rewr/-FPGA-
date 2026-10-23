library verilog;
use verilog.vl_types.all;
entity audio_error_history is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        current_code    : in     vl_logic_vector(3 downto 0);
        pcm_valid       : in     vl_logic;
        last_code       : out    vl_logic_vector(3 downto 0)
    );
end audio_error_history;
