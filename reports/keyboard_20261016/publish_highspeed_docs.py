from pathlib import Path
import json,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text());assert v['build_status']=='completed' and v['regression_passed']==80
t=v['timing_ns']
note=f'''## 当前：CMD6自动协商原生四位50MHz

阶段1～4、原生四位25MHz检查点及CMD6高速增量完成。正式顶层开启高速查询：卡支持High Speed、未busy、64字节切换状态四线CRC通过且选中功能1后，保留八个SD时钟再在完整周期边界切50MHz；不支持/busy留在原生四位25MHz，切换结果损坏则重新初始化并禁用本轮高速尝试。ACMD6设置四位宽度，与普通CMD6高速协商不同。

静态72源/40IO、80项ModelSim、综合/P&R/内部STA通过：SWNS **{t['SWNS']:+.3f}ns**、HWNS **{t['HWNS']:+.3f}ns**，TNS0。[精确源码绑定](../reports/keyboard_20261016/{stage}_validation.json)、[报告](../reports/keyboard_20261016/RESULT_{stage}.md)。FAT32/仲裁/BMP/WAV/缩放相对阶段四不变；原70位状态位序不变。未降100MHz，未新增功能路径false path，未宣称整体+0.5ns或HDMI管脚hold通过。

理想引脚模型50MHz连续16扇区22.338569MB/s，包含CMD17、响应、CRC与握手，卡输出延迟0/6/14ns测试通过；真实播放器夹具逐像素/PCM测试亦通过。这些是逻辑模型数据，**不是实体卡吞吐或SD外部IO签核**。板卡显示/出声、25MHz实板稳定性、50MHz波形/卡延迟/PCB往返与输入输出时序仍未验收；没有自动下载或写实体卡。

以下25MHz/SPI与候选描述属于之前检查点。最终候选bit是否导出以对应清单为准。
'''
def prepend(name,text):
 p=R/name;s=p.read_text(encoding='utf-8');head,_,body=s.partition('\n')
 p.write_text(head+'\n\n'+text+'\n\n'+body.lstrip(),encoding='utf-8')
prepend('docs/BUILD_STATUS.md',note)
short='> 当前版本：六线原生四位SD自动协商25/50MHz。支持CMD6且完整确认后才升50；不支持时保留四位25，不回SPI。100MHz主控制不变。80项逻辑回归与内部STA结果见[构建状态](BUILD_STATUS.md)，实体卡和板级IO尚未验收。下文较早“仅25MHz/未实现CMD6”属于旧检查点。'
for name in ('docs/SD_NATIVE_4BIT_20261016.md','docs/USER_GUIDE.md','docs/KEYBOARD_USAGE_20261016.md',
 'docs/KEYBOARD_REMAINING_20261016.md','docs/ROADMAP_KEYBOARD_MEDIA.md','docs/BOARD_TIMING.md','docs/CONNECTION_AND_USAGE.md'):
 prepend(name,short)
p=R/'README.md';s=p.read_text(encoding='utf-8')
a=s.index('SD正式接口为');b=s.index('\n',a)
s=s[:a]+'SD正式接口为 **原生四位SDR，CMD6自动协商25/50MHz**，主控制100MHz。支持并确认切换成功才升50MHz；不支持/busy留在四位25MHz。80项逻辑回归及内部STA通过；卡模型吞吐22.34MB/s不是实体卡实测。仍使用原TF卡槽，六线映射和10kΩ上拉已核对。'+s[b:]
s=s.replace('原生四位SD25MHz协议、PHY和封装','原生四位SD25/50MHz、CMD6协议、PHY和封装')
p.write_text(s,encoding='utf-8')
p=R/'docs/SOURCE_MAP.md';s=p.read_text(encoding='utf-8')
s+='''
## CMD6高速增量

sd_native_controller在25MHz查询/切换CMD6，锁存64字节状态中的支持、选中与busy；CRC成功后才采用结果。sd_bus_phy按read_length接收64或512字节、四路CRC16；50MHz使用100MHz域延后一拍的采样许可，不照搬SDRAM相位。sd_card_top_native的ENABLE_HIGH_SPEED及上层NATIVE_HIGH_SPEED仅为构建profile，正式top开启；旧25MHz协议测试默认关闭，仍回归。

新增sim/tb_sd_highspeed.v覆盖协商和错误重初始化；sim/tb_sd_highspeed_player.v用14ns延迟卡模型经过正式profile读取FAT/BMP/WAV。模型延迟测试不能替代板级STA/示波器。
''';p.write_text(s,encoding='utf-8')
print('Published precise native25/50 negotiation status, model-only throughput and physical limitations')
