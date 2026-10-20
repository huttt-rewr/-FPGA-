`timescale 1ns/1ps
module tb_bram_window;
 reg clk=0,rst=1,vs=0,de=0;reg [9:0] x=0;reg [23:0] rgb=0;reg [1:0] mode=0;
 wire va,da,vb,db,wa,wb,sa,sb;wire [23:0] a,b;
 wire [11:0] suma,sumb;wire [7:0] la,lb;
 integer errors=0,frame,row,col,width,height,i,checked=0;
 always #5 clk=~clk;
 pixel_effects #(.DEPTH(800)) reference(.clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.rgb(rgb),.mode_sel(mode),
  .out_vs(va),.out_de(da),.out_rgb(a),.out_luma_sum(suma),.out_luma(la),.out_window_valid(wa),.out_sobel(sa));
 pixel_effects #(.DEPTH(800),.BRAM_WINDOW(1)) candidate(.clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.rgb(rgb),.mode_sel(mode),
  .out_vs(vb),.out_de(db),.out_rgb(b),.out_luma_sum(sumb),.out_luma(lb),.out_window_valid(wb),.out_sobel(sb));
 always @(posedge clk)begin
  #1;
  if(!rst)begin
   if({va,da,wa,sa}!=={vb,db,wb,sb} || (da && (a!==b || la!==lb || (wa && suma!==sumb))))begin
    errors=errors+1;if(errors<8)$display("FAILED BRAM window frame=%0d row=%0d x=%0d a=%h b=%h sum=%0d/%0d",frame,row,x,a,b,suma,sumb);
   end
   if(da)checked=checked+1;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  // All modes, both widths, consecutive frames; reset/blanking never clear RAM.
  for(frame=0;frame<8;frame=frame+1)begin
   mode=frame%4;width=(frame<4)?640:800;height=(frame<4)?480:600;vs=0;de=0;x=0;
   repeat(8)@(negedge clk);vs=1;
   for(row=0;row<height;row=row+1)begin
    for(col=0;col<width;col=col+1)begin
     de=1;x=col;rgb={$random};@(negedge clk);
    end
    de=0;x=0;repeat(3+(row%5))@(negedge clk);
   end
  end
  repeat(8)@(negedge clk);
  if(errors==0)$display("ALL PASS tb_bram_window: %0d exact pixels, four modes VGA/SVGA, unchanged three-cycle latency and shared luma",checked);
  else $display("FAILED BRAM window errors=%0d",errors);
  $finish;
 end
 initial begin #40000000;$display("FAILED BRAM window watchdog");$finish;end
endmodule
