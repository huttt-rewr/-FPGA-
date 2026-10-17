from pathlib import Path
import json,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
stage=sys.argv[1];v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==78
t=v['timing_ns']
note=f'''## 当前：原生四位SD 25MHz已接入

阶段1～4完成以后，正式TF通路切换为六线原生SDR四位25MHz，主控制时钟100MHz。没有SPI运行时回退。扇区侧请求/地址/字节valid/成功end/错误语义保留，FAT32、仲裁、BMP、WAV及缩放器相对阶段四零改动。旧SPI仅保留作兼容测试profile。

静态72源/40IO、78项ModelSim回归、综合/P&R/STA通过：SWNS **{t['SWNS']:+.3f}ns**、HWNS **{t['HWNS']:+.3f}ns**，TNS均0。新激励直接使用正式原生profile和物理引脚，不force替换扇区通道。[冻结验收](../reports/keyboard_20261016/{stage}_validation.json)、[报告](../reports/keyboard_20261016/RESULT_{stage}.md)。70位状态布局保留；没有降频、屏蔽功能路径或整体+0.5ns声明。

CMD6高速代码已在隔离候选完成逻辑仿真，尚未接入本阶段正式profile；当前仍25MHz。四位25MHz理想模型11.20MB/s不是实体卡实测。没有下载、写实体卡或实板出图/出声/吞吐验收。以下较早“当前SPI”记录属于历史阶段。
'''
def prepend(name,text):
 p=R/name;s=p.read_text(encoding='utf-8');head,_,body=s.partition('\n')
 p.write_text(head+'\n\n'+text+'\n\n'+body.lstrip(),encoding='utf-8')
prepend('docs/BUILD_STATUS.md',note)
sd='> 2026-10-17当前：正式SD已切为原生四位25MHz，CLK=A14、CMD=A13、DAT0=B14、DAT1=B15、DAT2=A11、DAT3=A12，仍使用原TF卡槽；CMD/DAT外部10kΩ上拉依据已确认。KEY/SW/键盘操作不变。50MHz尚为隔离候选，未实板。准确验收见[构建状态](BUILD_STATUS.md)。下文SPI与未接入描述为历史记录。'
for name in ('docs/SD_NATIVE_4BIT_20261016.md','docs/USER_GUIDE.md','docs/KEYBOARD_USAGE_20261016.md',
 'docs/KEYBOARD_REMAINING_20261016.md','docs/CONNECTION_AND_USAGE.md','docs/ROADMAP_KEYBOARD_MEDIA.md','docs/BOARD_TIMING.md'):
 prepend(name,sd)
p=R/'README.md';s=p.read_text(encoding='utf-8')
a=s.index('SD正式接口仍为');b=s.index('\n',a)
s=s[:a]+'SD正式接口为 **原生四位25MHz**，主控制100MHz；同一TF卡槽，六线映射及10kΩ上拉已核对。阶段1～4和原生25MHz整机回归/STA通过；50MHz CMD6目前为隔离候选，尚未正式安装或实板验收。'+s[b:]
s=s.replace('`sd/native/` | 独立四位SD候选，未接正式顶层/TD源清单', '`sd/native/` | 已接正式顶层与TD源清单的原生四位SD25MHz协议、PHY和封装')
s=s.replace('发送接收SPI字节，默认工作SCK25MHz','旧兼容profile的SPI字节收发；正式native profile不使用')
s=s.replace('初始化、寻址类型、重试、扇区读写握手和SPI封装','扇区封装选择原生/旧SPI兼容profile；正式选择原生四位')
p.write_text(s,encoding='utf-8')
p=R/'docs/SOURCE_MAP.md';s=p.read_text(encoding='utf-8')
s=s.replace('`src/modules/sd/native/`是未接入正式板级工程的四位SD候选','`src/modules/sd/native/`已接正式板级工程，使用原生四位25MHz')
s=s.replace('正式SPI控制层与PHY连接，对上提供扇区字节流。','正式原生/旧SPI兼容profile封装，对上保留扇区字节流握手。')
s+='''
## 新增正式原生SD源

| 文件 | 功能 |
|---|---|
| src/modules/sd/native/sd_bus_phy.v | 100MHz域产生识别/25MHz线时钟，CMD三态、命令/响应CRC7、四路数据CRC16与字节拼接。 |
| src/modules/sd/native/sd_native_controller.v | CMD0/8/55/41/2/3/7/ACMD6/16初始化、SDHC/SDSC寻址、CMD17和超时恢复。 |
| src/modules/sd/native/sd_card_top_native.v | 原生扇区封装，保留请求和数据握手；只读，写请求报错。 |

正式源数为72；sd_card_top按常量NATIVE_4BIT选择，正式top为1，旧SPI分支在正式综合中剪除。sim/tb_sd_native_integrated.v直接验证正式通路，原有SPI激励仍运行兼容profile。没有改官方IP或上层解析算法。
'''
p.write_text(s,encoding='utf-8')
print('Published native25 evidence and current six-wire status')
