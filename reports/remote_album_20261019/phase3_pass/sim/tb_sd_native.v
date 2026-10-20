`timescale 1ns/1ps
module tb_sd_native;
 reg clk=0,rst=1,request=0,write_request=0,ccs=1;
 reg [31:0] address=0;
 reg [3:0] fault=0;
 wire sclk,init,init_error,transfer_error,valid,done;
 tri1 cmd,d0,d1,d2,d3;
 wire [7:0] data;
 wire [31:0] argument;
 wire [31:0] commands,reads,model_errors;
 integer errors=0,bytes=0,successes=0,failures=0,start_cycles,elapsed,cycles=0;
 integer i,j,read_count;
 reg check_payload=0,recovery_pending=0;
 time previous_edge=0;
 always #5 clk=~clk;
 sd_card_top_native #(.SPI_LOW_SPEED_DIV(0),.WAIT_TIMEOUT_CYCLES(12000),
  .INIT_TIMEOUT_CYCLES(100000),.INIT_PAUSE_CYCLES(200),.INIT_ATTEMPT_LIMIT(3)) dut(
  .clk(clk),.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),
  .SD_DAT0(d0),.SD_DAT1(d1),.SD_DAT2(d2),.SD_DAT3(d3),
  .sd_init_done(init),.sd_init_error(init_error),.sd_transfer_error(transfer_error),
  .sd_sec_read(request),.sd_sec_read_addr(address),.sd_sec_read_data(data),
  .sd_sec_read_data_valid(valid),.sd_sec_read_end(done),
  .sd_sec_write(write_request),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
  .sd_sec_write_data_req(),.sd_sec_write_end());
 sd_native_card_model card(.rst(rst),.SD_CLK(sclk),.SD_CMD(cmd),.SD_DAT({d3,d2,d1,d0}),
  .ccs(ccs),.fault(fault),.last_read_argument(argument),.commands(commands),.reads(reads),.errors(model_errors));
 task fail;input [511:0] message;begin errors=errors+1;$display("FAIL native %0s",message);end endtask
 always @(posedge clk)begin
  cycles=cycles+1;
  if(!rst)begin
   if(valid)begin
    if(check_payload && data!==card.pattern(bytes,argument))fail("payload byte order or lane packing");
    bytes=bytes+1;
   end
   if(done)begin successes=successes+1;if(bytes!=512)fail("success length is not 512");end
   if(transfer_error)failures=failures+1;
   if(valid && done)fail("last data byte and success unexpectedly overlap");
  end
 end
 // At the selected simulation divider both low/high phases must be 20ns.
 always @(sclk or posedge dut.phy_reset)begin
  if(rst || dut.phy_reset)previous_edge=0;
  else begin
   if(previous_edge!=0 && ($time-previous_edge)!=20)fail("SD clock is not 25MHz");
   previous_edge=$time;
  end
 end
 task boot;input mode;begin
  @(negedge clk);rst=1;request=0;write_request=0;fault=0;ccs=mode;previous_edge=0;
  repeat(6)@(negedge clk);rst=0;wait(init);repeat(6)@(negedge clk);
  if(init_error)fail("initialization failed");
 end endtask
 task read_sector;input [31:0] sector;input [3:0] injected;input expected_error;
  integer old_success,old_failure;
  begin
   @(negedge clk);address=sector;fault=injected;bytes=0;check_payload=1;
   recovery_pending=(dut.controller.state!=dut.controller.S_READY);
   old_success=successes;old_failure=failures;start_cycles=cycles;request=1;
   wait(done || transfer_error);elapsed=cycles-start_cycles;
   repeat(2)@(negedge clk);
   if(expected_error)begin
    if(successes!=old_success || failures!=old_failure+1)fail("failed sector reported success");
   end else begin
    if(successes!=old_success+1 || failures!=old_failure || bytes!=512)fail("good sector failed");
    if(argument!==(ccs?sector:(sector<<9)))fail("SDHC/SDSC addressing");
    if(!recovery_pending && elapsed>5120)fail("effective throughput below 10 MB/s");
    if(recovery_pending)$display("NATIVE queued request recovered after %0d host cycles (includes previous fault recovery)",elapsed);
    else $display("NATIVE throughput: 512 bytes / %0d host cycles = %0f MB/s (CMD17 request through CRC/end)",elapsed,51200.0/elapsed);
   end
   // Holding request after completion must not cause a duplicate transaction.
   read_count=reads;repeat(20)@(negedge clk);
   if(reads!=read_count)fail("held request duplicated");
   request=0;check_payload=0;fault=0;repeat(1100)@(negedge clk);
  end
 endtask
 task bad_boot;input [3:0] injected;begin
  @(negedge clk);rst=1;fault=injected;request=0;previous_edge=0;
  repeat(5)@(negedge clk);rst=0;
  wait(init_error);@(negedge clk);
  if(init || dut.phy.cmd_oe)fail("init failure did not release bus");
  fault=0;wait(!init_error);wait(init);repeat(6)@(negedge clk);
 end endtask
 task continuous_reads;
  integer n,begin_cycle,total_cycle;
  begin
   wait(dut.controller.state==dut.controller.S_READY);
   begin_cycle=cycles;
   for(n=0;n<16;n=n+1)begin
    @(negedge clk);address=100+n;fault=0;bytes=0;check_payload=1;request=1;
    wait(done || transfer_error);
    if(transfer_error)fail("continuous stream read failed");
    repeat(2)@(negedge clk);request=0;
    repeat(2)@(negedge clk);
   end
   total_cycle=cycles-begin_cycle;check_payload=0;
   if(total_cycle>81920)fail("continuous effective throughput below 10MB/s");
   $display("NATIVE sustained: 8192 bytes / %0d host cycles = %0f MB/s (16 CMD17 sectors, all handshakes/CRC included)",total_cycle,819200.0/total_cycle);
  end
 endtask
 initial begin
  if(card.reference_crc7(136'h4000000000,40)!=7'h4a)fail("CRC7 CMD0 reference vector");
  if(card.reference_crc7(136'h48000001aa,40)!=7'h43)fail("CRC7 CMD8 reference vector");
  boot(1);
  continuous_reads;
  for(j=0;j<4;j=j+1)read_sector(32'h12340+j,0,0);
  // Individually corrupt all four CRC lanes, then immediately prove recovery.
  for(i=3;i<=6;i=i+1)begin read_sector(7,i,1);read_sector(8,0,0);end
  read_sector(9,2,1);read_sector(10,0,0);
  read_sector(9,7,1);read_sector(10,0,0);
  read_sector(9,8,1);read_sector(10,0,0);
  read_sector(9,9,1);read_sector(10,0,0);
  read_sector(9,13,1);read_sector(10,0,0);
  read_sector(9,10,1);read_sector(10,0,0);
  boot(0);read_sector(123,0,0);
  // Malformed R7, missing response, R1b busy, ACMD41 retry bound, R2/R6.
  bad_boot(1);bad_boot(10);bad_boot(11);bad_boot(12);bad_boot(14);bad_boot(15);
  if(model_errors!=0)fail("card model rejected commands/arguments/CRC");
  if(errors==0)$display("ALL PASS tb_sd_native: SDHC/SDSC init, R2/R3/R6/R7, busy, four CRC lanes, faults/recovery, >=10MB/s logical peer");
  else $display("FAILED tb_sd_native errors=%0d model=%0d",errors,model_errors);
  $finish;
 end
 initial begin #20000000;$display("FAILED watchdog tb_sd_native state=%0d step=%0d cstate=%0d bytes=%0d",dut.controller.state,dut.controller.step,dut.phy.cstate,bytes);$finish;end
endmodule
