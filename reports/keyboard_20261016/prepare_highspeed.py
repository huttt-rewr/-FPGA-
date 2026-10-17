"""Prepare CMD6/SDR50 candidate outside formal build inputs."""
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
D=O/'highspeed';D.mkdir(exist_ok=True)
s=(R/'src/modules/sd/native/sd_bus_phy.v').read_text(encoding='utf-8')
s=s.replace('// output, never an internal clock. Launch on falling edges, sample on rising.', '// output, never an internal clock. Launch falling; sample rising at25MHz,\n// one host cycle after rising at50MHz (board I/O signoff remains separate).')
s=s.replace('input clk,rst,high_speed,open_drain,','input clk,rst,high_speed,open_drain,\n input high_speed_50,input [9:0] read_length,')
s=s.replace('high_speed ? 16\'d2 : LOW_HALF_CYCLES', "high_speed_50 ? 16'd1 : (high_speed ? 16'd2 : LOW_HALF_CYCLES)")
needle=' reg cmd_oe,cmd_out;';assert needle in s
s=s.replace(needle,''' // SDR50 samples one host cycle after the nominal rising edge. At 100MHz
 // this places the sample 20ns after the previous card launch, rather than
 // assuming a zero-delay card. External I/O setup/hold still needs signoff.
 reg delayed_rise;
 always @(posedge clk or posedge rst)begin
  if(rst)delayed_rise<=0;else delayed_rise<=rise_tick;
 end
 wire sample_tick=high_speed_50?delayed_rise:rise_tick;
'''+needle)
s=s.replace('C_WAIT:if(rise_tick', 'C_WAIT:if(sample_tick').replace('C_RX:if(rise_tick','C_RX:if(sample_tick').replace('C_BUSY:if(rise_tick','C_BUSY:if(sample_tick')
s=s.replace(' reg [9:0] nibble_count;', ' reg [9:0] nibble_count,last_nibble;')
s=s.replace('dstate<=D_IDLE;nibble_count<=0;', "dstate<=D_IDLE;nibble_count<=0;last_nibble<=1023;",1)
s=s.replace('crc_bad<=0;nibble_count<=0;', "crc_bad<=0;nibble_count<=0;last_nibble<=(read_length==64)?10'd127:10'd1023;",1)
s=s.replace('else if(rise_tick)case(dstate)', 'else if(sample_tick)case(dstate)')
s=s.replace('nibble_count==1023','nibble_count==last_nibble')
s=s.replace('// Candidate only: board DAT1/DAT2 mapping must be verified before integration.', '// Six-wire mapping is documented; physical interface validation remains pending.')
(D/'sd_bus_phy.v').write_text(s,encoding='utf-8')
s=(R/'src/modules/sd/native/sd_native_controller.v').read_text(encoding='utf-8')
s=s.replace('parameter integer INIT_TIMEOUT_CYCLES', 'parameter ENABLE_HIGH_SPEED=0,\n parameter integer INIT_TIMEOUT_CYCLES',1)
s=s.replace('output reg high_speed,open_drain,output reg phy_reset,', 'output reg high_speed,open_drain,output reg phy_reset,\n output reg high_speed_50,output [9:0] read_length,')
s=s.replace('S_ERR=6,S_RECOVER=7;', 'S_ERR=6,S_RECOVER=7,S_SWITCH_READ=8,S_SWITCH_APPLY=9,S_SPEED_WAIT=10;')
s=s.replace('reg [2:0] state;', 'reg [3:0] state;')
needle=' reg [3:0] step;';assert needle in s
s=s.replace(needle,needle+'''
 reg hs_disabled,hs_supported,hs_busy,hs_selected;
 reg [6:0] switch_count;
 reg [3:0] speed_clocks;
 wire switch_step=(step==11 || step==12);
 assign read_length=switch_step?10'd64:10'd512;
 // Capture status independently of response FSM. It is not trusted until
 // read_done confirms all four CRCs and the end bit.
 always @(posedge clk or posedge rst)begin
  if(rst)begin switch_count<=0;hs_supported<=0;hs_busy<=0;hs_selected<=0;end
  else if(read_arm)begin switch_count<=0;hs_supported<=0;hs_busy<=0;hs_selected<=0;end
  else if(switch_step && read_valid)begin
   if(switch_count<65)switch_count<=switch_count+1'b1;
   if(switch_count==13)hs_supported<=read_data[1];
   if(switch_count==16)hs_selected<=read_data[3:0]==1;
   if(switch_count==29)hs_busy<=read_data[1];
  end
 end
''')
s=s.replace('high_speed<=0;open_drain<=1;phy_reset<=0;', 'high_speed<=0;high_speed_50<=0;hs_disabled<=0;speed_clocks<=0;open_drain<=1;phy_reset<=0;',1)
s=s.replace('      default:begin // CMD17', '''      11:begin cmd_index<=6;cmd_argument<=32'h00fffff1;response_type<=1;read_arm<=1;end
      12:begin cmd_index<=6;cmd_argument<=32'h80fffff1;response_type<=1;read_arm<=1;end
      default:begin // CMD17''')
s=s.replace('step==9 || step==10)', 'step==9 || step==10 || switch_step)')
s=s.replace('else begin read_cancel<=1;state<=S_ERR;sd_init_error<=1;phy_reset<=1;pause_timer<=0;end',
'''else begin
       if(switch_step)hs_disabled<=1;
       read_cancel<=1;state<=S_ERR;sd_init_error<=1;phy_reset<=1;pause_timer<=0;
      end''',1)
s=s.replace('else if(step==9)begin sd_init_done<=1;high_speed<=1;state<=S_READY;end', '''else if(step==9)begin
      high_speed<=1;
      if(ENABLE_HIGH_SPEED && !hs_disabled)begin step<=11;state<=S_ISSUE;end
      else begin sd_init_done<=1;state<=S_READY;end
     end
     else if(switch_step)state<=S_SWITCH_READ;''')
needle='    S_READY:if(sd_sec_write)begin';assert needle in s
s=s.replace(needle,'''    S_SWITCH_READ:begin
     if(read_error)begin
      hs_disabled<=1;read_cancel<=1;phy_reset<=1;sd_init_error<=1;pause_timer<=0;state<=S_ERR;
     end else if(read_done)state<=S_SWITCH_APPLY;
    end
    S_SWITCH_APPLY:begin
     if(switch_count!=64 || (step==12 && (!hs_selected || hs_busy)))begin
      // A damaged switch reply may hide a card-side mode change. Reinitialize
      // with this power-cycle's high-speed attempt disabled; never guess.
      hs_disabled<=1;read_cancel<=1;phy_reset<=1;sd_init_error<=1;pause_timer<=0;state<=S_ERR;
     end else if(step==11)begin
      if(hs_supported && !hs_busy)begin step<=12;state<=S_ISSUE;end
      else begin sd_init_done<=1;state<=S_READY;end
     end else begin speed_clocks<=0;state<=S_SPEED_WAIT;end
    end
    S_SPEED_WAIT:if(rise_tick)begin
     if(speed_clocks==7)begin high_speed_50<=1;sd_init_done<=1;state<=S_READY;end
     else speed_clocks<=speed_clocks+1'b1;
    end
'''+needle)
s=s.replace('sd_init_error<=0;high_speed<=0;open_drain<=1;', 'sd_init_error<=0;high_speed<=0;high_speed_50<=0;open_drain<=1;')
# Capture an early status-data error while the CMD6 response is being checked.
needle='   // Capture a bad/missing token';assert needle in s
s=s.replace(needle,'''   if(switch_step && state==S_RESPONSE && read_error)begin
    hs_disabled<=1;read_cancel<=1;phy_reset<=1;sd_init_error<=1;pause_timer<=0;state<=S_ERR;
   end
'''+needle)
(D/'sd_native_controller.v').write_text(s,encoding='utf-8')
s=(R/'src/modules/sd/native/sd_card_top_native.v').read_text(encoding='utf-8')
s=s.replace('// Standalone candidate for sd_card_top replacement. Sector-facing ports retain\n// their original names/widths. NOT instantiated by the board project until the\n// DAT1/DAT2 board wiring and CMD/DAT pull-ups are known.', '// Native read-only sector wrapper, used by the formal six-wire profile.\n// CMD6 optionally negotiates SDR50; unsupported/error fallback remains native25.\n// Logical tests and internal STA do not establish physical card I/O signoff.')
s=s.replace('// Legacy divider parameter spelling retained; operating speed is fixed 25 MHz\n // at a 100 MHz host clock. SPI_HIGH_SPEED_DIV is intentionally not applied.', '// Legacy parameter names retained: identification divider remains configurable.\n // 100MHz host produces native25, or native50 only after CMD6 confirmation.\n // SPI_HIGH_SPEED_DIV does not control the native bus.')
s=s.replace(' parameter SPI_LOW_SPEED_DIV', ' parameter ENABLE_HIGH_SPEED=0,\n parameter SPI_LOW_SPEED_DIV',1)
s=s.replace('wire high_speed,open_drain', 'wire high_speed_50;wire [9:0] read_length;\n wire high_speed,open_drain')
s=s.replace('.open_drain(open_drain),.SD_CLK', '.open_drain(open_drain),.high_speed_50(high_speed_50),.read_length(read_length),.SD_CLK')
s=s.replace('sd_native_controller #(.INIT_TIMEOUT_CYCLES', 'sd_native_controller #(.ENABLE_HIGH_SPEED(ENABLE_HIGH_SPEED),.INIT_TIMEOUT_CYCLES')
s=s.replace('.open_drain(open_drain),.phy_reset', '.open_drain(open_drain),.high_speed_50(high_speed_50),.read_length(read_length),.phy_reset')
(D/'sd_card_top_native.v').write_text(s,encoding='utf-8')
print('Prepared CMD6 check/switch, CRC64 status, fallback/reinit, SDR50 clock candidate; NOT INSTALLED')
