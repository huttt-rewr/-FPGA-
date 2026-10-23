`timescale 1ns/1ps
module tb_av_faults;
 reg clk=0,rst=1,valid=0,se=0;always #5 clk=~clk;
 reg [7:0] data=0;
 wire read,wr,request,playing,error,ended,we;wire [31:0] address;
 wire [3:0] state;
 integer scenario=0,transport=0,pos=0,limit=512,cycles=0;
 wire ready=scenario!=6;
 sd_av_reader #(.WATCHDOG(1000000)) dut(.clk(clk),.rst(rst),.mode_800(1'b0),.toggle_play(1'b0),
  .sd_ready(1'b1),.sd_error(1'b0),.sector_read(read),.sector_address(address),
  .sector_data(data),.sector_valid(valid),.sector_end(se),.write_req(wr),
  .write_req_ack(wr && scenario!=4),.write_finish_toggle(1'b0),
  .write_en(we),.write_data(),.pixel_ready(ready),.write_bank(),
  .request_toggle(request),.requested_bank(),.ack_toggle(1'b0),
  .audio_we(),.audio_address(),.audio_data(),.playing(playing),.error(error),.ended(ended),.busy(),.state_code(state));
 function [7:0] header_byte;input integer n;begin
  case(n)
   0:header_byte=8'h41;1:header_byte=8'h56;2:header_byte=8'h31;3:header_byte=8'h36;
   4:header_byte=8'h4b;5:header_byte=8'h32;6:header_byte=8'h30;8:header_byte=1;
   12:header_byte=160;14:header_byte=120;16:header_byte=scenario==0?5:20;
   18:header_byte=8'h80;19:header_byte=8'h3e;20:header_byte=117;
   default:header_byte=0;
  endcase
 end endfunction
 always @(negedge clk)begin
  valid=0;se=0;
  if(rst)begin transport=0;cycles=0;end
  else begin
   cycles=cycles+1;
   if(request || ended)$fatal(1,"FAILED malformed/incomplete frame published scenario=%d",scenario);
   if(we && !ready)$fatal(1,"FAILED ignored writer backpressure");
   case(transport)
    0:if(read)begin
     pos=0;limit=512;
     if((scenario==1 && address==1) || (scenario==3 && address==5))limit=100;
     if(scenario==2 && address==1)limit=513;
     transport=1;
    end
    1:if(scenario!=7)begin
     data=address==0?header_byte(pos):8'h55;valid=1;pos=pos+1;
     if(pos==limit)transport=2;
    end
    2:begin se=1;transport=3;end
    3:if(!read)transport=0;
   endcase
  end
 end
 initial begin
  for(scenario=0;scenario<8;scenario=scenario+1)begin
   rst=1;repeat(6)@(posedge clk);#1;rst=0;
   wait(error);@(posedge clk);#1;
   if(playing || ended || read || wr)$fatal(1,"FAILED failure not quarantined scenario=%d",scenario);
   if(scenario<4 && cycles>=1000000)$fatal(1,"FAILED malformed stream detected only by timeout");
   if(scenario>=4 && cycles<1000000)$fatal(1,"FAILED premature watchdog");
   $display("fault scenario %0d rejected after %0d cycles",scenario,cycles);
  end
  $display("ALL PASS tb_av_faults: legacy format, short/oversized audio, short video, missing write ack/finish, pixel stall, SD silence");
  $finish;
 end
 initial begin #50000000;$fatal(1,"FAILED tb_av_faults timeout");end
endmodule
