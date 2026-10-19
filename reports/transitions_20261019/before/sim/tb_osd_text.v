`timescale 1ns/1ps
module tb_osd_text;
 reg clk=0,rst=1,vs=0,de=0,auto_play=0,mute=1,busy=0,error=0,edid=0;
 reg [1:0] index=0;
 reg [2:0] count=4;
 reg [4:0] volume=8;
 wire [9:0] px,py;
 wire [23:0] result;
 reg [319:0] expected;
 reg [7:0] ch;
 integer x,y,col,row,errors=0,pass;
 always #5 clk=~clk;
 status_osd dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.rgb(24'h204060),.enable(1'b1),
  .auto_play(auto_play),.image_index(index),.image_count(count),.volume(volume),.mute(mute),
  .busy(busy),.error(error),.edid_ok(edid),.result(result),.pixel_x(px),.pixel_y(py));
 initial begin
  repeat(4) @(negedge clk);rst=0;
  for(pass=0;pass<3;pass=pass+1) begin
   vs=0;de=0;repeat(3) @(negedge clk);vs=1;
   auto_play=(pass!=0);index=(pass!=0)?3:0;volume=(pass!=0)?16:8;
   mute=(pass==0);busy=(pass==1);error=(pass==2);edid=(pass!=0);
   for(y=0;y<80;y=y+1) begin
    de=1;
    for(x=0;x<640;x=x+1) begin
     #1;
     if(px!==x || py!==y) errors=errors+1;
     if(y>=16 && x>=16 && x<336 && (x-16)%8==0) begin
      row=(y-16)/16;col=(x-16)/8;
      case(row)
       0:expected="EG4S20 HDMI PLAYER  640X480             ";
       1:begin
        if(pass==0) expected="PLAY:OFF IMG:1/4 LOAD:- EDID:-          ";
        else if(pass==1) expected="PLAY:ON  IMG:4/4 LOAD:B EDID:Y          ";
        else expected="PLAY:ON  IMG:4/4 LOAD:E EDID:Y          ";
       end
       2:expected=pass==0 ? "VOL:08/16 MUTE:Y TEST AUDIO             " :
                              "VOL:16/16 MUTE:N TEST AUDIO             ";
       3:expected="K1:NEXT K2:PLAY SW:CAP/SCROLL/FX        ";
      endcase
      ch=expected >> ((39-col)*8);
      if(dut.ascii!==ch) begin
       if(errors<8) $display("FAILED OSD row=%0d col=%0d got=%h expected=%h",row,col,dut.ascii,ch);
       errors=errors+1;
      end
     end
     @(negedge clk);
    end
    de=0;repeat(4) @(negedge clk);
   end
  end
  if(errors==0) $display("ALL PASS tb_osd_text: raster positions, all 40 columns, dynamic states");
  else $display("FAILED tb_osd_text %0d",errors);
  $finish;
 end
 initial begin #3000000;$display("FAILED watchdog tb_osd_text");$finish;end
endmodule
