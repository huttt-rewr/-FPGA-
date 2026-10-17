"""Prepare six-wire integration outside active build inputs; install separately."""
from pathlib import Path
import re
R=Path(__file__).resolve().parents[2]; O=Path(__file__).resolve().parent
D=O/'native_integration'; D.mkdir(exist_ok=True)
s=(R/'src/modules/sd/sd_card_top.v').read_text(encoding='utf-8')
s=s.replace('parameter  SPI_LOW_SPEED_DIV', 'parameter NATIVE_4BIT=0,\n\tparameter  SPI_LOW_SPEED_DIV',1)
s=s.replace('\toutput           sd_sec_write_end           //SD card sector write end',
'''\toutput           sd_sec_write_end,          //SD card sector write end
    output SD_CLK,inout SD_CMD,SD_DAT0,SD_DAT1,SD_DAT2,SD_DAT3''')
marker='wire response_valid;'; assert marker in s
ports=['clk','rst','sd_init_done','sd_init_error','sd_transfer_error','sd_sec_read',
 'sd_sec_read_addr','sd_sec_read_data','sd_sec_read_data_valid','sd_sec_read_end',
 'sd_sec_write','sd_sec_write_addr','sd_sec_write_data','sd_sec_write_data_req','sd_sec_write_end',
 'SD_CLK','SD_CMD','SD_DAT0','SD_DAT1','SD_DAT2','SD_DAT3']
connections=',\n  '.join('.'+p+'('+p+')' for p in ports)
block='''generate if(NATIVE_4BIT)begin:native_bus
 assign SD_nCS=1'b1;assign SD_DCLK=1'b0;assign SD_MOSI=1'b1;
 sd_card_top_native #(.SPI_LOW_SPEED_DIV(SPI_LOW_SPEED_DIV),
  .INIT_TIMEOUT_CYCLES(INIT_TIMEOUT_CYCLES),.INIT_PAUSE_CYCLES(INIT_PAUSE_CYCLES),
  .WAIT_TIMEOUT_CYCLES(WAIT_TIMEOUT_CYCLES)) transport(
  '''+connections+''');
end else begin:legacy_spi
 assign SD_CLK=1'b0;
 assign SD_CMD=1'bz;assign SD_DAT0=1'bz;assign SD_DAT1=1'bz;assign SD_DAT2=1'bz;assign SD_DAT3=1'bz;
'''
s=s.replace(marker,block+marker,1).replace('endmodule','end endgenerate\nendmodule')
(D/'sd_card_top.v').write_text(s,encoding='utf-8')
s=(R/'src/modules/bmp/sd_card_bmp.v').read_text(encoding='utf-8')
s=s.replace('module sd_card_bmp #(', 'module sd_card_bmp #(\n    parameter NATIVE_4BIT=0,',1)
s=s.replace('    output media_truncated', '    output SD_CLK,inout SD_CMD,SD_DAT0,SD_DAT1,SD_DAT2,SD_DAT3,\n    output media_truncated',1)
s=s.replace('sd_card_top sd_card_top_m0(', 'sd_card_top #(.NATIVE_4BIT(NATIVE_4BIT)) sd_card_top_m0(',1)
needle='    .SD_nCS                 (SD_nCS),'; assert needle in s
s=s.replace(needle,'''    .SD_CLK(SD_CLK),.SD_CMD(SD_CMD),.SD_DAT0(SD_DAT0),
    .SD_DAT1(SD_DAT1),.SD_DAT2(SD_DAT2),.SD_DAT3(SD_DAT3),
'''+needle,1)
(D/'sd_card_bmp.v').write_text(s,encoding='utf-8')
s=(R/'src/top.v').read_text(encoding='utf-8')
a=s.index('    // TF card SPI'); b=s.index('\n);',a)
s=s[:a]+'''    // TF native four-bit SDR, no SPI fallback in this profile.
    output SD_CLK,
    inout SD_CMD,SD_DAT0,SD_DAT1,SD_DAT2,SD_DAT3'''+s[b:]
s=s.replace('.INDEXED(1),', '.NATIVE_4BIT(1),.INDEXED(1),',1)
s=re.sub(r'    \.SD_nCS\s*\(sd_ncs\),\s*\.SD_DCLK\s*\(sd_dclk\),\s*\.SD_MOSI\s*\(sd_mosi\),\s*\.SD_MISO\s*\(sd_miso\),',
'''    .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
    .SD_CLK(SD_CLK),.SD_CMD(SD_CMD),.SD_DAT0(SD_DAT0),
    .SD_DAT1(SD_DAT1),.SD_DAT2(SD_DAT2),.SD_DAT3(SD_DAT3),''',s)
assert 'sd_ncs' not in s and '.SD_CLK(SD_CLK)' in s
(D/'top.v').write_text(s,encoding='utf-8')
s=(R/'src/constraints/pin.adc').read_text(encoding='utf-8')
s=re.sub(r'^.*set_pin_assignment\s*\{\s*sd_(?:ncs|dclk|mosi|miso)\s*\}[^\n]*\n?', '',s,flags=re.M)
for signal,pin in [('SD_CLK','A14'),('SD_CMD','A13'),('SD_DAT0','B14'),('SD_DAT1','B15'),('SD_DAT2','A11'),('SD_DAT3','A12')]:
 s+=f'\nset_pin_assignment {{ {signal} }} {{ LOCATION = {pin}; IOSTANDARD = LVCMOS33; PULLTYPE = '+('NONE' if signal=='SD_CLK' else 'PULLUP')+'; }'
(D/'pin.adc').write_text(s+'\n',encoding='utf-8')
print('Prepared native four-bit wiring only; no active source/project changed')
