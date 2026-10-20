`timescale 1ns/1ps
module tb_picture_osd;
 reg clk=0,rst=1,vs=0,de=0;always #5 clk=~clk;
 reg signed [7:0] b=0;reg [3:0] c=4;reg [1:0] mode=0;
 wire [23:0] rgb;wire [9:0] px,py;
 reg [319:0] expected;reg [7:0] ch;
 integer pass,x,y,col,errors=0;
 status_osd #(.ENHANCED_UI(1)) dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.rgb(24'h204060),
  .enable(1'b1),.auto_play(1'b0),.image_index(2'd0),.image_count(3'd4),.volume(5'd8),
  .mute(1'b1),.busy(1'b0),.error(1'b0),.edid_ok(1'b1),.result(rgb),.pixel_x(px),.pixel_y(py),
  .brightness(b),.contrast(c),.edit_mode(mode),.source_width(12'd1920),.source_height(12'd1080));
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(pass=0;pass<3;pass=pass+1)begin
   mode=pass;b=(pass==0)?0:((pass==1)?-64:64);c=(pass==0)?4:((pass==1)?2:7);
   vs=0;repeat(3)@(negedge clk);vs=1;
   for(y=0;y<80;y=y+1)begin
    de=1;
    for(x=0;x<640;x=x+1)begin
     #1;
     if(x>=16 && x<336 && (x-16)%8==0 && y>=16)begin
      col=(x-16)/8;
      case((y-16)/16)
       0:expected="SRC:1920X1080 ->640X480 FIT BILINEAR    ";
       1:expected="PLAY:OFF IMG:1/4 LOAD:- EDID:Y          ";
       2:case(pass)
        0:expected="BRI:+00 CON:1.00 MODE:PLAY              ";
        1:expected="BRI:-64 CON:0.50 MODE:BRIG              ";
        2:expected="BRI:+64 CON:1.75 MODE:CONT              ";
       endcase
       3:expected=(pass==0)?"K3:MODE K1:NEXT K2:AUTO                 ":"K3:MODE K1:MINUS K2:PLUS                ";
      endcase
      ch=expected>>((39-col)*8);
      if(dut.ascii!==ch)begin
       if(errors<8)$display("FAILED OSD y=%0d col=%0d actual=%h expected=%h",y,col,dut.ascii,ch);
       errors=errors+1;
      end
     end
     @(negedge clk);
    end
    de=0;repeat(4)@(negedge clk);
   end
  end
  if(errors==0)$display("ALL PASS tb_picture_osd: 40 columns, resolution, signed brightness, fractional contrast, mode hints");
  else $display("FAILED tb_picture_osd %0d",errors);
  $finish;
 end
endmodule
