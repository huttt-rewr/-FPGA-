`timescale 1ns/1ps
// Physical raster -> adaptive viewport -> game -> one-cycle stream scoreboard.
module tb_snake_pipeline;
 reg clk=0,rst=1,vs=1,de=0,mode=0,en=0;reg [23:0] rgb=0;
 wire [9:0] x,y;wire ov,od,over;wire [23:0] result;wire [7:0] score;
 integer errors=0,i,j,w,h,pass,m,count;
 reg previous_vs,previous_de;reg [23:0] expected;
 always #5 clk=~clk;
 viewport_coordinates coords(clk,rst,vs,de,mode,x,y,,);
 snake_game dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.y(y),.rgb(rgb),
  .game_enable(en),.dir_req(2'd1),.tick(1'b0),.out_vs(ov),.out_de(od),.out_rgb(result),.score(score),.game_over(over));
 task cycle;begin
  #1;previous_vs=vs;previous_de=de;
  expected=de?dut.composed:24'd0;
  @(posedge clk);#1;
  if(ov!==previous_vs || od!==previous_de || result!==expected)begin
   errors=errors+1;if(errors<5)$display("FAIL snake pipeline x=%0d y=%0d",x,y);
  end
  if(od)count=count+1;
  @(negedge clk);
 end endtask
 initial begin
  count=0;repeat(4)@(negedge clk);rst=0;
  for(m=0;m<2;m=m+1)begin
   mode=m;w=m?800:640;h=m?600:480;
   for(pass=0;pass<2;pass=pass+1)begin
    en=pass;vs=0;de=0;repeat(1000)cycle;vs=1;
    for(j=0;j<h;j=j+1)begin
     for(i=0;i<w;i=i+1)begin
      de=1;rgb={i[7:0],j[7:0],8'ha5};
      if(x!==((m==0)?i:((i*4)/5)) || y!==((m==0)?j:((j*4)/5)))begin
       errors=errors+1;if(errors<5)$display("FAIL viewport physical=%0d,%0d logical=%0d,%0d",i,j,x,y);
      end
      cycle;
      // Check spatial selection independently of the RTL compositor.
      if(!pass || i<(m?80:64) || i>=(m?720:576) || j<(m?60:48) || j>=(m?540:432))
       if(result!==rgb)begin errors=errors+1;if(errors<5)$display("FAIL game bypass/viewport boundary");end
     end
     de=0;repeat(8)cycle;
    end
   end
  end
  if(count!=1574400)begin errors=errors+1;$display("FAIL pixel count %0d",count);end
  if(errors==0)$display("ALL PASS tb_snake_pipeline: VGA/SVGA enabled+bypass 1574400 active pixels, centered viewport, fixed latency");
  else $display("FAILED tb_snake_pipeline errors=%0d",errors);
  $finish;
 end
 initial begin #40000000;$display("FAILED pipeline watchdog");$finish;end
endmodule
