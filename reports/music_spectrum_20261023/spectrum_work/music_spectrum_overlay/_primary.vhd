library verilog;
use verilog.vl_types.all;
entity music_spectrum_overlay is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        vs              : in     vl_logic;
        de              : in     vl_logic;
        x               : in     vl_logic_vector(9 downto 0);
        y               : in     vl_logic_vector(9 downto 0);
        rgb             : in     vl_logic_vector(23 downto 0);
        audio_valid     : in     vl_logic;
        audio_left      : in     vl_logic_vector(23 downto 0);
        enable          : in     vl_logic;
        out_vs          : out    vl_logic;
        out_de          : out    vl_logic;
        out_rgb         : out    vl_logic_vector(23 downto 0)
    );
end music_spectrum_overlay;
