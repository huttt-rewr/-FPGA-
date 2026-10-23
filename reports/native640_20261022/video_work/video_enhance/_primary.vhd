library verilog;
use verilog.vl_types.all;
entity video_enhance is
    port(
        rgb             : in     vl_logic_vector(23 downto 0);
        brightness      : in     vl_logic_vector(7 downto 0);
        result          : out    vl_logic_vector(23 downto 0)
    );
end video_enhance;
