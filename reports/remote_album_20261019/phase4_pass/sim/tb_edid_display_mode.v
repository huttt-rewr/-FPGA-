`timescale 1ns/1ps
module tb_edid_display_mode;
 reg clk=0,rst=1,start=0,valid=0;reg [7:0] data=0;
 always #5 clk=~clk;
 wire done,good,mode_800,fallback;
 reg [7:0] edid[0:127];integer i,k,sum,errors=0;
 edid_display_mode #(.TIMEOUT(30)) dut(clk,rst,start,valid,data,done,good,mode_800,fallback);
 task base;begin
  for(i=0;i<128;i=i+1)edid[i]=0;
  for(i=1;i<7;i=i+1)edid[i]=255;
  edid[18]=1;edid[19]=4;edid[20]=128;
 end endtask
 task checksum;begin sum=0;for(i=0;i<127;i=i+1)sum=sum+edid[i];edid[127]=-sum;end endtask
 task send;begin
  @(negedge clk);start=1;@(negedge clk);start=0;
  for(i=0;i<128;i=i+1)begin
   data=edid[i];valid=1;@(negedge clk);valid=0;@(negedge clk);
   if(i<127 && (done || mode_800))begin errors=errors+1;$display("FAILED promoted unchecked block");end
  end
 end endtask
 task check;input g,m;begin
  if(done!==1 || good!==g || mode_800!==m || fallback!==!m)begin
   errors=errors+1;$display("FAILED EDID case %d good=%b mode=%b",k,good,mode_800);
  end
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(k=0;k<9;k=k+1)begin
   base;
   case(k)
    0:edid[35]=1;
    1:edid[35]=2; // 800x600@56 is not 60Hz
    2:begin edid[38]=69;edid[39]=8'h40;end
    3:begin edid[38]=69;edid[39]=8'h4b;end // 75Hz
    4,5:begin
     edid[54]=8'ha0;edid[55]=8'h0f;edid[56]=8'h20;edid[57]=0;edid[58]=8'h31;
     edid[59]=8'h58;edid[60]=28;edid[61]=8'h20;edid[62]=40;edid[63]=128;
     edid[64]=8'h14;edid[71]=(k==4)?8'h1e:8'h9e;
    end
    6:begin edid[35]=1;edid[0]=1;end
    7:begin edid[35]=1;edid[20]=0;end // analog display is not promoted
    8:edid[35]=1;
   endcase
   checksum;if(k==8)edid[127]=edid[127]+1;
   send;check(k!=6 && k!=8,k==0 || k==2 || k==4);
  end
  @(negedge clk);start=1;@(negedge clk);start=0;
  repeat(35)@(negedge clk);k=9;check(0,0);
  // A reset may interrupt a partial EDID; old capabilities must not leak.
  base;edid[35]=1;checksum;
  start=1;@(negedge clk);start=0;
  for(i=0;i<40;i=i+1)begin valid=1;data=edid[i];@(negedge clk);end
  valid=0;rst=1;@(negedge clk);rst=0;
  base;checksum;send;k=10;check(1,0);
  if(errors==0)$display("ALL PASS tb_edid_display_mode: established/standard/DTD, 56/75Hz rejection, checksum/header, analog, timeout, reset");
  else $display("FAILED tb_edid_display_mode %d",errors);
  $finish;
 end
endmodule
