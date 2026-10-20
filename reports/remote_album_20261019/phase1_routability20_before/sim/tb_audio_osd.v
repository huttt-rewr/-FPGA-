`timescale 1ns/1ps
module tb_audio_osd;
 reg clk=0,rst=1,vs=1,de=0,mode=0,mute=1,menu=1,uf=0;
 reg [3:0] code=0;reg [2:0] item=4;always #5 clk=~clk;
 wire [23:0] rgb;integer m,i,x,y,c,row,errors=0;reg [319:0] expected;reg [7:0] ch;
 status_osd #(.ENHANCED_UI(1),.ADAPTIVE(1),.BOARD_UI(1),.AUDIO_UI(1),.AUDIO_DIAGNOSTICS(1)) dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.rgb(24'h204060),.enable(1'b1),.auto_play(1'b0),.image_index(2'd0),.image_count(3'd4),.volume(5'd31),.mute(mute),.busy(1'b0),.error(1'b0),.edid_ok(1'b1),.result(rgb),.brightness(8'sd0),.contrast(4'd4),.edit_mode(2'd0),.source_width(12'd640),.source_height(12'd480),.mode_800(mode),.menu_open(menu),.menu_item(item),.gamma_enable(1'b0),.debug_enable(1'b0),.debug_page(2'd0),.audio_ready(1'b1),.audio_error(|code),.audio_error_code(code),.audio_underflow(uf));
 initial begin
 for(m=0;m<2;m=m+1)for(i=0;i<4;i=i+1)begin
  mode=m;item=i<2?4:i+3;mute=i==0;
  case(i)
  0:expected="MENU >AUDIO MUTE:ON                     ";
  1:expected="MENU >AUDIO MUTE:OFF                    ";
  2:expected="MENU >VOLUME DOWN:31                    ";
  3:expected="MENU >VOLUME UP:31                      ";
  endcase
  rst=1;repeat(4)@(negedge clk);rst=0;vs=0;repeat(3)@(negedge clk);vs=1;
  for(y=0;y<(mode?100:80);y=y+1)begin de=1;
   for(x=0;x<(mode?800:640);x=x+1)begin #1;
    if(mode?(x>=20 && x<420 && (x-20)%10==0 && y>=60 && y<80):(x>=16 && x<336 && (x-16)%8==0 && y>=48 && y<64))begin
     c=mode?(x-20)/10:(x-16)/8;ch=expected>>((39-c)*8);
     if(dut.board_ascii!==ch)begin if(errors<5)$display("FAILED audio OSD mode %d item %d col %d actual %h expected %h",m,item,c,dut.board_ascii,ch);errors=errors+1;end
    end
    @(negedge clk);
   end de=0;repeat(4)@(negedge clk);
  end
 end
 // Both viewports: all four error codes, ready/muted and sticky underflow glyphs.
 menu=0;
 for(m=0;m<2;m=m+1)for(i=0;i<6;i=i+1)begin
  mode=m;code=i<4?i+1:0;mute=i==4;uf=i%2;
  expected="                            A:E1 V:31 U0";
  expected[(39-30)*8+:8]=code?"E":(mute?"M":"R");
  expected[(39-31)*8+:8]=code?("0"+code):"-";
  expected[(39-39)*8+:8]=uf?"1":"0";
  rst=1;repeat(4)@(negedge clk);rst=0;vs=0;repeat(3)@(negedge clk);vs=1;
  for(y=0;y<(mode?100:80);y=y+1)begin de=1;
   for(x=0;x<(mode?800:640);x=x+1)begin #1;
    if(mode?(x>=300 && x<420 && (x-20)%10==0 && y>=80 && y<100):(x>=240 && x<336 && (x-16)%8==0 && y>=64 && y<80))begin
     c=mode?(x-20)/10:(x-16)/8;ch=expected>>((39-c)*8);
     if(dut.board_ascii!==ch)begin
      if(errors<5)$display("FAILED audio diagnostic OSD code %d col %d actual %h expected %h",code,c,dut.board_ascii,ch);
      errors=errors+1;
     end
    end
    @(negedge clk);
   end de=0;repeat(4)@(negedge clk);
  end
 end
 if(errors==0)$display("ALL PASS tb_audio_osd");else $display("FAILED audio OSD %0d",errors);$finish;
 end
endmodule
