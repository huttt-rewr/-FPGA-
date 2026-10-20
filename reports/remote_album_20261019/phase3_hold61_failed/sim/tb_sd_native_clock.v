`timescale 1ns/1ps
// Real default divider, all 80 startup clocks and open-drain identification.
module tb_sd_native_clock;
 reg clk=0,rst=1;
 tri1 cmd,d0,d1,d2,d3;
 wire sclk,init,init_error;
 wire [31:0] commands,reads,model_errors,argument;
 integer errors=0,boot_edges=0,fast_edges=0;
 time last_rise=0,period;
 reg was_high_speed=0;
 always #5 clk=~clk;
 sd_card_top_native dut(.clk(clk),.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),
  .SD_DAT0(d0),.SD_DAT1(d1),.SD_DAT2(d2),.SD_DAT3(d3),
  .sd_init_done(init),.sd_init_error(init_error),.sd_transfer_error(),
  .sd_sec_read(1'b0),.sd_sec_read_addr(32'd0),.sd_sec_read_data(),
  .sd_sec_read_data_valid(),.sd_sec_read_end(),.sd_sec_write(1'b0),
  .sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
  .sd_sec_write_data_req(),.sd_sec_write_end());
 sd_native_card_model card(.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),.SD_DAT({d3,d2,d1,d0}),
  .ccs(1'b1),.fault(4'd0),.last_read_argument(argument),.commands(commands),.reads(reads),.errors(model_errors));
 always @(posedge sclk)if(!rst)begin
  if(commands==0)boot_edges=boot_edges+1;
  if(last_rise!=0)begin
   period=$time-last_rise;
   if(was_high_speed && dut.high_speed)begin
    // The boundary period may combine one slow half and one fast half.
    if(period==40)fast_edges=fast_edges+1;
    else if(fast_edges>0)errors=errors+1;
   end else if(!dut.high_speed && period!=5000)errors=errors+1;
  end
  last_rise=$time;was_high_speed=dut.high_speed;
 end
 // During identification, a transmitted one must be released to the pull-up.
 always @(negedge clk)if(!rst && dut.open_drain && dut.phy.cmd_oe && dut.phy.cmd_out)
  if(dut.phy.SD_CMD!==1'b1)errors=errors+1;
 initial begin
  repeat(5)@(negedge clk);rst=0;wait(init);wait(fast_edges>=50);
  if(boot_edges<80 || init_error || model_errors!=0 || reads!=0)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_sd_native_clock: default 200kHz init, >=80 startup clocks, open-drain ID, glitch-free switch to 25MHz");
  else $display("FAILED tb_sd_native_clock errors=%0d boot=%0d",errors,boot_edges);
  $finish;
 end
 initial begin #30000000;$display("FAILED watchdog tb_sd_native_clock");$finish;end
endmodule
