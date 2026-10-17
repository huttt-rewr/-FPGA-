"""Differential mount test: candidate vs saved baseline, including invalid BPBs."""
from pathlib import Path

root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
baseline=(out/'baseline_sd_fat32.v.txt').read_text(encoding='utf-8')
(out/'sd_fat32_reference.v').write_text(baseline.replace('module sd_fat32 #(', 'module sd_fat32_reference #(',1),encoding='utf-8')
fixture=(root/'sim/tb_fat32_mount.v').read_text(encoding='utf-8').split('\nmodule tb_fat32_mount;',1)[0]
fixture=fixture.replace('input br,input [2:0]', 'input integer variant,input br,input [2:0]')
marker='seek_result=$fseek(fd,addr*512,0);got=$fread(sector,fd);'
assert fixture.count(marker)==1
fixture=fixture.replace(marker,marker+'''
    if(addr==(mode==1?2048:0))case(variant)
     1:begin sector[32]=0;sector[33]=0;sector[34]=0;sector[35]=0;end
     2:begin sector[32]=32;sector[33]=0;sector[34]=0;sector[35]=0;end
     3:begin sector[32]=8'h12;sector[33]=8'h04;sector[34]=0;sector[35]=0;end
     4:begin sector[32]=8'h06;sector[33]=8'h04;sector[34]=1;sector[35]=0;end // 65524 data clusters
     5:begin sector[32]=8'h07;sector[33]=8'h04;sector[34]=1;sector[35]=0;end // 65525 data clusters
     6:begin sector[32]=8'hfe;sector[33]=8'hff;sector[34]=8'hff;sector[35]=8'hff;end
     7:begin sector[32]=8'hff;sector[33]=8'h03;sector[34]=0;sector[35]=8'h10;end // high cluster bound
     8:begin sector[36]=0;sector[37]=2;sector[38]=0;sector[39]=0;end // FAT capacity too small
     9:begin sector[32]=1;sector[33]=5;sector[34]=2;sector[35]=0;end // partition shorter than BPB
     default:;
    endcase
''')
a=fixture.replace('module fat32_fixture(', 'module geometry_candidate(')
b=fixture.replace('module fat32_fixture(', 'module geometry_reference(').replace(' sd_fat32 #(', ' sd_fat32_reference #(')
tb='''
module tb_geometry_differential;
 reg clk=0,rst=1;always #5 clk=~clk;
 integer mode=0,variant=0,errors=0,tests=0,m,v;
 wire cm,cf,cw,rm,rf,rw;wire [3:0] cc,rc;wire [2:0] cn,rn;
 wire [127:0] cs,rs;wire [31:0] ca,ra;
 geometry_candidate candidate(.clk(clk),.rst(rst),.mode(mode),.variant(variant),.br(1'b0),.file_idx(3'd0),.baddr(32'd0),
  .ar(1'b0),.aaddr(32'd0),.mounted(cm),.failed(cf),.code(cc),.count(cn),.found(cw),.sizes(cs),.asize(ca),.abort_bmp(1'b0),.init_done(1'b1));
 geometry_reference reference(.clk(clk),.rst(rst),.mode(mode),.variant(variant),.br(1'b0),.file_idx(3'd0),.baddr(32'd0),
  .ar(1'b0),.aaddr(32'd0),.mounted(rm),.failed(rf),.code(rc),.count(rn),.found(rw),.sizes(rs),.asize(ra),.abort_bmp(1'b0),.init_done(1'b1));
 always @(posedge clk)if(!rst)begin
  #1;
  if({cm,cf,cc,cn,cw,cs,ca,candidate.req,candidate.addr} !==
     {rm,rf,rc,rn,rw,rs,ra,reference.req,reference.addr})begin
   $display("FAILED differential mode=%0d variant=%0d",mode,variant);$finish;
  end
 end
 initial begin
  for(m=0;m<2;m=m+1)for(v=0;v<10;v=v+1)begin
   @(negedge clk);rst=1;mode=m;variant=v;repeat(4)@(negedge clk);rst=0;
   wait(cm || cf);repeat(4)@(negedge clk);tests=tests+1;
  end
  $display("ALL PASS geometry_differential: %0d BPB scenarios, identical cycle/requests/addresses/status/sizes",tests);
  $finish;
 end
 initial begin #10000000;$display("FAILED geometry watchdog");$finish;end
endmodule
'''
(out/'tb_geometry_differential.v').write_text(a+'\n'+b+'\n'+tb,encoding='utf-8')
print('Generated 20-case geometry differential test')
