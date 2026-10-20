`timescale 1ns/1ps
module tb_board_osd;
 reg clk=0,rst=1,vs=1,de=0,mode=0,opened=1;always #5 clk=~clk;
 wire [23:0] rgb;wire [9:0] px,py;
 integer m,x,y,col,row,errors=0;
 reg [319:0] expected;reg [7:0] ch;
 status_osd #(.ENHANCED_UI(1),.ADAPTIVE(1),.BOARD_UI(1)) dut(
  .clk(clk),.rst(rst),.vs(vs),.de(de),.rgb(24'h204060),.enable(1'b1),
  .auto_play(1'b0),.image_index(2'd0),.image_count(3'd4),.volume(5'd8),
  .mute(1'b1),.busy(1'b0),.error(1'b0),.edid_ok(1'b1),.result(rgb),
  .pixel_x(px),.pixel_y(py),.brightness(8'sd0),.contrast(4'd4),.edit_mode(2'd0),
  .source_width(12'd640),.source_height(12'd480),.mode_800(mode),.out_vs(),.out_de(),
  .menu_open(opened),.menu_item(3'd1),.gamma_enable(1'b1),.debug_enable(1'b1),.debug_page(2'd2));
 initial begin
  for(m=0;m<2;m=m+1)begin
   mode=m;rst=1;repeat(4)@(negedge clk);rst=0;vs=0;repeat(3)@(negedge clk);vs=1;
   for(y=0;y<(mode?100:80);y=y+1)begin
    de=1;
    for(x=0;x<(mode?800:640);x=x+1)begin
     #1;
     if((mode?(x>=20 && x<420 && (x-20)%10==0 && y>=60):(x>=16 && x<336 && (x-16)%8==0 && y>=48)))begin
      col=mode?(x-20)/10:(x-16)/8;row=mode?(y-20)/20:(y-16)/16;
      expected=(row==2)?"MENU >GAMMA:ON  (SHADOW LIFT)           ":"K1:UP K2:DOWN K3:OK HOLD3:EXIT          ";
      ch=expected>>((39-col)*8);
      if(dut.board_ascii!==ch)begin
       if(errors<5)$display("FAILED board OSD mode=%d row=%d col=%d actual=%h expected=%h",mode,row,col,dut.board_ascii,ch);
       errors=errors+1;
      end
     end
     @(negedge clk);
    end
    de=0;repeat(4)@(negedge clk);
   end
  end
  if(errors==0)$display("ALL PASS tb_board_osd: board-only menu text and control hints in both adaptive viewports");
  else $display("FAILED tb_board_osd %0d",errors);
  $finish;
 end
endmodule
