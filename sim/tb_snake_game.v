`timescale 1ns/1ps
module tb_snake_game;
 reg clk=0,rst=1,vs=1,de=0,en=0,tick=0;
 reg [9:0] x=0,y=0;reg [23:0] rgb=24'hc08040;
 reg [1:0] dir=1;
 wire ov,od,over;wire [23:0] pixel;wire [7:0] score;
 integer errors=0,i,j,green=0,red=0,white=0;
 integer hx,hy,old_len,old_score,old_tail,old_write;
 reg [23:0] expected;
 always #5 clk=~clk;
 snake_game dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.y(y),.rgb(rgb),
  .game_enable(en),.dir_req(dir),.tick(tick),.out_vs(ov),.out_de(od),.out_rgb(pixel),.score(score),.game_over(over));
 function board_at;
  input integer address;
  begin case(address>>8)
   0:board_at=dut.board_mem.bank[0].ram[address&255];
   1:board_at=dut.board_mem.bank[1].ram[address&255];
   2:board_at=dut.board_mem.bank[2].ram[address&255];
   default:board_at=1'bx;
  endcase end
 endfunction
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;if(errors<12)$display("FAIL snake %0s",msg);end
 end endtask
 task ready;integer n;begin
  n=0;while(dut.state!=3 && n<2000)begin @(negedge clk);n=n+1;end
  check(dut.state==3,"initialization/food search completes");
 end endtask
 task restart;begin
  @(negedge clk);en=0;repeat(3)@(negedge clk);en=1;dir=1;
  repeat(3)@(negedge clk);ready;
 end endtask
 task move;input [1:0] d;begin
  @(negedge clk);dir=d;tick=1;@(negedge clk);tick=0;
  repeat(4)@(negedge clk);ready;
 end endtask
 task pixel_check;input [9:0] px,py;input [23:0] wanted;begin
  @(negedge clk);de=1;x=px;y=py;vs=1;
  @(posedge clk);#1;check(od && ov && pixel===wanted,"one-cycle pixel RGB/DE/VS alignment");
 end endtask
 // Directed food placement is a legal empty-cell state fixture. Generated
 // food is separately checked for bounds/occupancy after every growth.
 task put_food;input integer fx,fy;begin
  @(negedge clk);check(!board_at(fy*32+fx),"fixture is an empty cell");
  dut.food_x=fx;dut.food_y=fy;
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  pixel_check(200,200,rgb); // bypass while disabled
  restart;
  check(dut.len==3 && score==0 && dut.head_x==16 && dut.head_y==12,"initial length/head/score");
  check(dut.food_x<32 && dut.food_y<24 && !board_at(dut.food_y*32+dut.food_x),"generated food legal");
  pixel_check(0,0,rgb);pixel_check(63,48,rgb);pixel_check(576,100,rgb);
  pixel_check(65,100,24'hffffff);
  pixel_check(72,88,24'h604020);
  pixel_check(64+16*16+8,48+12*16+8,24'h20e060);
  pixel_check(64+dut.food_x*16+8,48+dut.food_y*16+8,24'hff3030);
  // Independently scan the complete viewport, including both sides of all
  // rectangle boundaries. Text is checked through its visible white pixels.
  for(j=0;j<480;j=j+1)for(i=0;i<640;i=i+1)begin
   @(negedge clk);x=i;y=j;de=1;vs=(i!=0);
   #1;expected=dut.composed;
   @(posedge clk);#1;
   check(od && ov==vs && pixel===expected,"scan timing");
   if(i<64 || i>=576 || j<48 || j>=432)check(pixel===rgb,"outside rectangle transparent");
   if(pixel==24'h20e060)green=green+1;
   if(pixel==24'hff3030)red=red+1;
   if(pixel==24'hffffff)white=white+1;
  end
  check(green>0 && red>0 && white>0,"snake food border and score visible");
  @(negedge clk);de=0;vs=0;@(posedge clk);#1;check(!od && !ov && pixel==0,"blank is black, VS aligned");
  put_food(0,0);move(3);check(dut.head_x==17 && dut.dir==1 && !over,"180-degree reversal rejected");
  hx=dut.head_x;hy=dut.head_y;old_tail={dut.tail_y,dut.tail_x};
  move(1);check(!board_at((old_tail>>5)*32+(old_tail&31)) && dut.head_x==hx+1,"straight move clears old tail");
  hx=dut.head_x;hy=dut.head_y;put_food(hx+1,hy);old_len=dut.len;old_tail=dut.tail_addr;
  move(1);check(score==1 && dut.len==old_len+1 && dut.tail_addr==old_tail,"food grows and retains tail");
  check(!board_at(dut.food_y*32+dut.food_x),"new food excludes occupied cells");
  // Grow into a U, then the next turn intersects the middle of the body.
  hx=dut.head_x;hy=dut.head_y;put_food(hx,hy-1);move(0);
  put_food(hx-1,hy-1);move(3);put_food(0,0);move(2);
  check(over,"self collision detected");
  pixel_check(285,232,24'hffffff); // G row zero, column one in GAME OVER
  pixel_check(284,232,24'h604020); // G's unlit first column
  @(negedge clk);de=0;
  hx=dut.head_x;hy=dut.head_y;old_score=score;old_write=dut.write_addr;
  repeat(3)move(1);
  check(dut.head_x==hx && dut.head_y==hy && score==old_score && dut.write_addr==old_write,"game-over freezes state");
  restart;put_food(0,0);repeat(16)move(1);check(over && dut.head_x==31,"wall collision");
  restart;put_food(0,0);
  // Long rectangle route exercises both ring pointer wrap-around and legal
  // repeated visits to cells without growing or touching the food.
  for(i=0;i<30;i=i+1)begin
   repeat(4)move(1);repeat(4)move(2);repeat(4)move(3);repeat(4)move(0);
  end
  check(!over && score==0 && dut.head_x==16 && dut.head_y==12,"cyclic play without false collision");
  check(dut.write_addr==482 && dut.tail_addr==480,"ring pointers advance");
  for(i=0;i<20;i=i+1)begin
   repeat(4)move(1);repeat(4)move(2);repeat(4)move(3);repeat(4)move(0);
  end
  check(!over && dut.write_addr==34 && dut.tail_addr==32,"ring pointers wrap at board size");
  // Four-segment square: next head enters the currently vacating tail cell.
  restart;put_food(17,12);move(1);put_food(0,0);move(2);move(3);move(0);
  check(!over && dut.head_x==16 && dut.head_y==12,"moving into vacating tail is legal");
  @(negedge clk);rst=1;@(posedge clk);#1;
  check(!od && !ov && pixel==0 && !over && score==0,"active-high reset");
  if(errors==0)$display("ALL PASS tb_snake_game: rendering, latency, reverse, grow, food, walls, self/tail collision, ring wrap, reset");
  else $display("FAILED tb_snake_game errors=%0d",errors);
  $finish;
 end
 initial begin #20000000;$display("FAILED snake watchdog");$finish;end
endmodule
