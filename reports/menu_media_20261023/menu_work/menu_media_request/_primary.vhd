library verilog;
use verilog.vl_types.all;
entity menu_media_request is
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        controls_reset  : in     vl_logic;
        movie_mode      : in     vl_logic;
        keyboard_event  : in     vl_logic;
        keyboard_movie  : in     vl_logic;
        button_valid    : in     vl_logic;
        button_movie    : in     vl_logic;
        button_toggle   : in     vl_logic;
        image_next      : in     vl_logic;
        movie_next      : in     vl_logic;
        wav_next        : in     vl_logic;
        select_valid    : out    vl_logic;
        select_movie    : out    vl_logic;
        next_picture    : out    vl_logic;
        next_movie      : out    vl_logic;
        next_wav        : out    vl_logic
    );
end menu_media_request;
