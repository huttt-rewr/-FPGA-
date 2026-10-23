library verilog;
use verilog.vl_types.all;
entity spectrum_coefficients is
    port(
        clk             : in     vl_logic;
        tw_address      : in     vl_logic_vector(6 downto 0);
        window_address  : in     vl_logic_vector(7 downto 0);
        tw_real         : out    vl_logic_vector(15 downto 0);
        tw_imag         : out    vl_logic_vector(15 downto 0);
        window          : out    vl_logic_vector(15 downto 0)
    );
end spectrum_coefficients;
