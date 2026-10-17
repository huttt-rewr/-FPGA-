library verilog;
use verilog.vl_types.all;
entity video_mode_table is
    port(
        i_mode          : in     vl_logic_vector(2 downto 0);
        o_htotal        : out    vl_logic_vector(15 downto 0);
        o_hactive       : out    vl_logic_vector(15 downto 0);
        o_hfp           : out    vl_logic_vector(15 downto 0);
        o_hsa           : out    vl_logic_vector(15 downto 0);
        o_hbp           : out    vl_logic_vector(15 downto 0);
        o_vtotal        : out    vl_logic_vector(15 downto 0);
        o_vactive       : out    vl_logic_vector(15 downto 0);
        o_vfp           : out    vl_logic_vector(15 downto 0);
        o_vsa           : out    vl_logic_vector(15 downto 0);
        o_vbp           : out    vl_logic_vector(15 downto 0);
        o_clk_sel       : out    vl_logic_vector(1 downto 0);
        o_hs_pol        : out    vl_logic;
        o_vs_pol        : out    vl_logic;
        o_pixel_clk     : out    vl_logic_vector(31 downto 0)
    );
end video_mode_table;
