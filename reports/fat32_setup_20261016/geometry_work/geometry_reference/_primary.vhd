library verilog;
use verilog.vl_types.all;
entity geometry_reference is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        mode            : in     integer;
        variant         : in     integer;
        br              : in     vl_logic;
        file_idx        : in     vl_logic_vector(2 downto 0);
        baddr           : in     vl_logic_vector(31 downto 0);
        bd              : out    vl_logic_vector(7 downto 0);
        bv              : out    vl_logic;
        be              : out    vl_logic;
        berr            : out    vl_logic;
        bg              : out    vl_logic;
        ar              : in     vl_logic;
        aaddr           : in     vl_logic_vector(31 downto 0);
        ad              : out    vl_logic_vector(7 downto 0);
        av              : out    vl_logic;
        ae              : out    vl_logic;
        aerr            : out    vl_logic;
        mounted         : out    vl_logic;
        failed          : out    vl_logic;
        code            : out    vl_logic_vector(3 downto 0);
        count           : out    vl_logic_vector(2 downto 0);
        found           : out    vl_logic;
        sizes           : out    vl_logic_vector(127 downto 0);
        asize           : out    vl_logic_vector(31 downto 0);
        abort_bmp       : in     vl_logic;
        init_done       : in     vl_logic
    );
end geometry_reference;
