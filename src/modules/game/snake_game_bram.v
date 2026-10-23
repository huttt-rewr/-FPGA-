// Synchronous block RAM implementation. Reads and input metadata register at
// the same edge; the compositor uses both after that edge (one pixel latency).
// Collision/food probes have explicit wait states; RAM contents have no reset.
module snake_game_bram #(
 parameter integer GW=32, GH=24, CELL=16,
 parameter integer SCREEN_W=640, SCREEN_H=480
)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,
 input game_enable,input [1:0] dir_req,input tick,
 output reg out_vs,out_de,output reg [23:0] out_rgb,
 output reg [7:0] score,output reg game_over
);
 localparam [4:0] INITIAL_Y=GH>>1;
 localparam N=GW*GH, AW=$clog2(N), SHIFT=$clog2(CELL);
 localparam X0=(SCREEN_W-GW*CELL)>>1, Y0=(SCREEN_H-GH*CELL)>>1;
 localparam CLEAR=0,SEED=1,FOOD=2,IDLE=3,ERASE=4,COMMIT=5,FOOD_CHECK=6,MOVE_CHECK=7;
 wire draw_occupied;
 // A ring FIFO of 2-bit steps reconstructs the tail from its coordinates.
 // This uses one fifth of the RAM bits of packed 10-bit coordinates.
 wire [1:0] tail_step;
 reg [2:0] state;
 reg enabled_d,initialized;
 reg [AW-1:0] clear_addr,tail_addr,write_addr;
 reg [AW:0] len;
 reg [1:0] seed_index,dir;
 reg [4:0] head_x,head_y,food_x,food_y,tail_x,tail_y;
 reg [1:0] next_dir;
 reg [4:0] next_x,next_y,search_x,search_y;
 reg [AW-1:0] next_addr;
 reg grow,move_wall;
 reg [15:0] lfsr;
 reg [3:0] hundreds,tens,ones;
 
 wire [AW-1:0] tail_cell=tail_y*GW+tail_x;
 wire [AW-1:0] search_addr=search_y*GW+search_x;
 wire [1:0] accepted_dir=((dir_req ^ dir)==2)?dir:dir_req;
 reg [4:0] candidate_x,candidate_y;
 reg wall;
 always @* begin
  candidate_x=head_x;candidate_y=head_y;wall=0;
  case(accepted_dir)
   0:begin candidate_y=head_y-1'b1;wall=(head_y==0);end
   1:begin candidate_x=head_x+1'b1;wall=(head_x==GW-1);end
   2:begin candidate_y=head_y+1'b1;wall=(head_y==GH-1);end
   3:begin candidate_x=head_x-1'b1;wall=(head_x==0);end
  endcase
 end
 wire [AW-1:0] candidate_addr=candidate_y*GW+candidate_x;
 wire eating=(candidate_x==food_x && candidate_y==food_y);
 wire [AW-1:0] query_addr=(state==FOOD)?search_addr:candidate_addr;
 wire occupied;
 // Entering the tail's old cell is legal when that tail moves this tick.
 wire collision=occupied && (grow || next_addr!=tail_cell);
 wire [4:0] seed_x=(GW>>1)-2+seed_index;
 wire [AW-1:0] seed_cell=(GH>>1)*GW+seed_x;
 wire [4:0] random_x=(lfsr[4:0]<GW)?lfsr[4:0]:0;
 wire [4:0] random_y=(lfsr[9:5]<GH)?lfsr[9:5]:0;
 wire clearing=game_enable && state==CLEAR;
 wire seeding=game_enable && state==SEED;
 wire erasing=game_enable && state==ERASE;
 wire committing=game_enable && state==COMMIT;
 wire inside_board=(x>=X0 && x<X0+GW*CELL && y>=Y0 && y<Y0+GH*CELL);
 wire [9:0] local_x=x-X0,local_y=y-Y0;
 wire [4:0] cell_x=local_x>>SHIFT,cell_y=local_y>>SHIFT;
 wire [AW-1:0] draw_addr=cell_y*GW+cell_x;
 // Banked LUT RAM avoids TD rounding a 768-cell board up to 1024.
 wire board_we=clearing || seeding || erasing || committing;
 wire [AW-1:0] board_wa=clearing?clear_addr:seeding?seed_cell:erasing?tail_cell:next_addr;
 wire board_wd=seeding || committing;
 // The video clock owns both uses. Tick is supplied in vertical blanking;
 // FOOD scans also complete there. One physical read port can serve both.
 wire [AW-1:0] lookup_addr=(state==FOOD || (state==IDLE && tick))?query_addr:draw_addr;
 assign draw_occupied=occupied;
 snake_block_ram #(.WIDTH(1),.DEPTH(N)) board_mem(.clk(clk),.we(board_we),.wa(board_wa),.wd(board_wd),
  .ra(lookup_addr),.q(occupied));
 wire [AW-1:0] body_wa=seeding?{{(AW-2){1'b0}},seed_index}:write_addr;
 snake_block_ram #(.WIDTH(2),.DEPTH(N)) body_mem(.clk(clk),.we(seeding || committing),.wa(body_wa),
  .wd(seeding?2'd1:next_dir),.ra(tail_addr),.q(tail_step));
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=CLEAR;enabled_d<=0;initialized<=0;clear_addr<=0;seed_index<=0;
   tail_x<=(GW>>1)-2;tail_y<=GH>>1;tail_addr<=0;write_addr<=2;len<=3;dir<=1;head_x<=GW>>1;head_y<=GH>>1;
   food_x<=0;food_y<=0;next_x<=0;next_y<=0;next_addr<=0;next_dir<=1;grow<=0;move_wall<=0;
   search_x<=0;search_y<=0;lfsr<=16'h1ace;score<=0;game_over<=0;
   hundreds<=0;tens<=0;ones<=0;
  end else begin
   enabled_d<=game_enable;
   lfsr<={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
   if(!game_enable || !enabled_d)begin
    state<=CLEAR;initialized<=0;clear_addr<=0;seed_index<=0;
    tail_x<=(GW>>1)-2;tail_y<=GH>>1;tail_addr<=0;write_addr<=2;len<=3;dir<=1;head_x<=GW>>1;head_y<=GH>>1;
    score<=0;game_over<=0;hundreds<=0;tens<=0;ones<=0;
   end else case(state)
    CLEAR:if(clear_addr==N-1)begin state<=SEED;seed_index<=0;end
          else clear_addr<=clear_addr+1'b1;
    SEED:if(seed_index==2)begin
     initialized<=1;search_x<=random_x;search_y<=random_y;state<=FOOD;
    end else seed_index<=seed_index+1'b1;
    FOOD:state<=FOOD_CHECK;
    FOOD_CHECK:if(!occupied)begin food_x<=search_x;food_y<=search_y;state<=IDLE;end
         else begin
          if(search_x==GW-1)begin search_x<=0;search_y<=(search_y==GH-1)?0:search_y+1'b1;end
          else search_x<=search_x+1'b1;
          state<=FOOD;
         end
    IDLE:if(tick && !game_over)begin
     dir<=accepted_dir;move_wall<=wall;
     next_dir<=accepted_dir;next_x<=candidate_x;next_y<=candidate_y;next_addr<=candidate_addr;grow<=eating;
     state<=MOVE_CHECK;
    end
    MOVE_CHECK:if(move_wall || collision)begin game_over<=1;state<=IDLE;end
               else state<=grow?COMMIT:ERASE;
    ERASE:begin
     case(tail_step)
      0:tail_y<=tail_y-1'b1;1:tail_x<=tail_x+1'b1;
      2:tail_y<=tail_y+1'b1;3:tail_x<=tail_x-1'b1;
     endcase
     tail_addr<=(tail_addr==N-1)?0:tail_addr+1'b1;state<=COMMIT;end
    COMMIT:begin
     head_x<=next_x;head_y<=next_y;
     write_addr<=(write_addr==N-1)?0:write_addr+1'b1;
     state<=IDLE;
     if(grow)begin
      len<=len+1'b1;
      if(score!=255)begin
       score<=score+1'b1;
       if(ones==9)begin ones<=0;if(tens==9)begin tens<=0;hundreds<=hundreds+1'b1;end else tens<=tens+1'b1;end
       else ones<=ones+1'b1;
      end
      // A completely filled board wins/freezes; never search forever for food.
      if(len==N-1)game_over<=1;
      else begin search_x<=random_x;search_y<=random_y;state<=FOOD;end
     end
    end
    default:state<=CLEAR;
   endcase
  end
 end
 reg [9:0] draw_x,draw_y;
 reg [23:0] draw_rgb;
 reg draw_vs,draw_de,draw_enable;
 always @(posedge clk or posedge rst)begin
  if(rst)begin draw_x<=0;draw_y<=0;draw_rgb<=0;draw_vs<=0;draw_de<=0;draw_enable<=0;end
  else begin draw_x<=x;draw_y<=y;draw_rgb<=rgb;draw_vs<=vs;draw_de<=de;draw_enable<=game_enable;end
 end
 wire [9:0] render_x=draw_x-X0,render_y=draw_y-Y0;
 wire [4:0] render_cell_x=render_x>>SHIFT,render_cell_y=render_y>>SHIFT;
 wire render_inside=(draw_x>=X0 && draw_x<X0+GW*CELL && draw_y>=Y0 && draw_y<Y0+GH*CELL);
 wire border=(render_x<2 || render_x>=GW*CELL-2 || render_y<2 || render_y>=GH*CELL-2);
 localparam TEXT_X=(GW*CELL-9*8)>>1,TEXT_Y=(GH*CELL-16)>>1;
 wire over_text=game_over && render_x>=TEXT_X && render_x<TEXT_X+72 && render_y>=TEXT_Y && render_y<TEXT_Y+14;
 wire score_text=render_x>=8 && render_x<88 && render_y>=4 && render_y<18;
 wire [9:0] tx=over_text?(render_x-TEXT_X):(render_x-8);
 wire [9:0] ty=over_text?(render_y-TEXT_Y):(render_y-4);
 reg [7:0] ascii;
 always @*begin
  ascii=" ";
  if(over_text)case(tx>>3)
   0:ascii="G";1:ascii="A";2:ascii="M";3:ascii="E";
   5:ascii="O";6:ascii="V";7:ascii="E";8:ascii="R";
  endcase
  else case(tx>>3)
   0:ascii="S";1:ascii="C";2:ascii="O";3:ascii="R";4:ascii="E";5:ascii=":";
   7:ascii="0"+hundreds;8:ascii="0"+tens;9:ascii="0"+ones;
  endcase
 end
 wire [7:0] glyph;
 osd_char_rom font(.i_ascii(ascii),.i_row({1'b0,ty[3:1]}),.o_row_data(glyph));
 wire lit=(tx[2:0]<5) && glyph[4-tx[2:0]];
 reg [23:0] composed;
 always @*begin
  composed=draw_rgb;
  if(draw_enable && initialized && render_inside)begin
   composed={1'b0,draw_rgb[23:17],1'b0,draw_rgb[15:9],1'b0,draw_rgb[7:1]};
   if(draw_occupied)composed=24'h20e060;
   else if(render_cell_x==food_x && render_cell_y==food_y)composed=24'hff3030;
   if(border)composed=24'hffffff;
   if((over_text || score_text) && lit)composed=24'hffffff;
  end
 end
 always @*begin
  out_vs=draw_vs;out_de=draw_de;out_rgb=draw_de?composed:24'd0;
 end
endmodule

module snake_block_ram #(parameter WIDTH=1,DEPTH=768,AW=$clog2(DEPTH))(
 input clk,we,input [AW-1:0] wa,ra,input [WIDTH-1:0] wd,
 output reg [WIDTH-1:0] q
);
 (* ram_style="block" *) reg [WIDTH-1:0] ram[0:DEPTH-1];
 always @(posedge clk)begin
  if(we)ram[wa]<=wd;
  q<=ram[ra];
 end
endmodule
