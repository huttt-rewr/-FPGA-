library verilog;
use verilog.vl_types.all;
entity spectrum_fft256 is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        sample_valid    : in     vl_logic;
        sample          : in     vl_logic_vector(15 downto 0);
        bin_valid       : out    vl_logic;
        bin_index       : out    vl_logic_vector(7 downto 0);
        bin_real        : out    vl_logic_vector(15 downto 0);
        bin_imag        : out    vl_logic_vector(15 downto 0);
        block_done      : out    vl_logic;
        busy            : out    vl_logic
    );
end spectrum_fft256;
