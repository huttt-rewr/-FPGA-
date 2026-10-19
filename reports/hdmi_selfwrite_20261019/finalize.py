"""Bind regression logs, timing and documentation to this frozen build."""
from pathlib import Path
import hashlib
import json
import re
import shutil

r=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
out=here/'build1'
manifest=json.loads((out/'build_manifest.json').read_text())
assert manifest['status']=='completed'
raw=(here/'regression1.log').read_bytes()
regression=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
assert 'ALL TESTS PASSED' in regression
assert not re.search(r'FAILED|\[FAIL\]|\*\* (Error|Fatal)',regression)
tests=re.findall(r'^# vsim .*? -c (tb_\w+)\s*$',regression,re.M)
assert len(tests)==len(set(tests))==101,(len(tests),len(set(tests)))
for name in tests:
    src=r/'reports'/f'{name}.log'
    text=src.read_text(encoding='utf-8',errors='replace')
    assert 'ALL PASS' in text and not re.search(r'FAILED|\[FAIL\]|\*\* (Error|Fatal)',text),name
    dest=out/'test_logs'/src.name
    dest.parent.mkdir(exist_ok=True)
    shutil.copy2(src,dest)
shutil.copy2(here/'regression1.log',out/'regression.log')
for name,digest in manifest['sources'].items():
    p=r/name
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,name
    if p.name in ('top.v','tmds_encoder.v','hdmi_tmds_vga.v','edid_i2c.v',
                  'tb_tmds_encoder.v','tb_hdmi_tmds_vga.v','tb_edid_i2c.v',
                  'run_tests.ps1','design_files.txt'):
        shutil.copy2(p,out/p.name)

text=(out/'routed_timing_paths20.txt').read_text()
worst={}
pattern=r'Slack\s*:\s*(-?[\d.]+)ns\s*\nBegin Point\s*:\s*([^\n]+)\nEnd Point\s*:\s*([^\n]+)\nCheck Type\s*:\s*(\w+)'
for slack,begin,end,kind in re.findall(pattern,text):
    value=float(slack)
    if kind not in worst or value<worst[kind]['slack_ns']:
        worst[kind]={'slack_ns':value,'start':begin.split(' (')[0].strip(),
                     'end':end.split(' (')[0].strip()}
assert all(k in worst for k in ('setup','hold','recovery','removal')),worst
assert all(x['slack_ns']>=0 for x in worst.values())
baseline=json.loads((here/'before/build_manifest.json').read_text())
def critical(m):
    return {re.search(r'([A-Z]+-\d+) CRITICAL-WARNING',w)[1] for key,value in m.items()
            if key.endswith('_warnings') for w in value if 'CRITICAL-WARNING' in w}
assert critical(manifest)<=critical(baseline)
for name in ('synthesis.log','implementation.log','hold_finalization.log'):
    assert not re.search(r'Oops!\s*coredump|FATAL|\bERROR\s*:',(out/name).read_text(),re.I),name
def resources(p):
    text=p.read_text()
    return {k:int(re.search(r'^#'+k+r'\s+(\d+)',text,re.M)[1]) for k in ('lut','reg','bram','dsp')}
before=resources(here/'before/physical_area.txt')
after=resources(out/'physical_area.txt')
summary={'timing_ns':manifest['timing_ns'],'physical_before':before,'physical_after':after,
         'worst_by_check':worst,'regression_count':len(tests),'tests':tests,
         'critical_ids':sorted(critical(manifest)),'board_signoff':False,'new_bitstream':False}
(out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
hashes={p.relative_to(out).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in out.rglob('*') if p.is_file() and p.name!='sha256.json'}
(out/'sha256.json').write_text(json.dumps(hashes,indent=2))

result=f'''# 640 明文 TMDS / 独立 EDID 交付结果（2026-10-19）

本轮软件验证通过：80源/40逻辑IO静态检查、101项ModelSim、完整综合/布局布线/独立hold修复与内部STA。640 video-only、800保留原HDMI图声，EDID协商与全部原图像叠加层保留。**没有本轮新bit，没有实板出图/出声完成声明。**

## 实际资源与时序

| 指标 | 修改前（5eb97fa） | 本轮 |
|---|---:|---:|
| 物理 LUT | {before['lut']} | {after['lut']}（80.54%，减少 {before['lut']-after['lut']}） |
| 物理 REG | {before['reg']} | {after['reg']} |
| BRAM9K | {before['bram']} | {after['bram']}（64.06%，减少 {before['bram']-after['bram']}） |
| DSP | {before['dsp']} | {after['dsp']} |
| SWNS | +0.131ns | +0.044ns |
| STNS | 0 | 0 |
| HWNS | +0.022ns | +0.024ns |
| HTNS | 0 | 0 |

LUT减少约{(before['lut']-after['lut'])/before['lut']*100:.2f}%，BRAM减少约{(before['bram']-after['bram'])/before['bram']*100:.2f}%。**资源明显下降；setup裕量比原版减少0.087ns，不能声称时序全面改善。** 两档像素/串行时钟25/125、40/200MHz均仍受约束；100MHz主控不变。没有新增false-path或放宽约束，没有达到整体+0.5ns。

新核综合层次占用：VGA 247 LUT、54 REG、0 BRAM；EDID 123 LUT、67 REG、0 BRAM。物理层次的`lut`列分别为218、91，与另列ripple统计口径不同，不直接与整机合计相加。资源净节省以整机表为准。

## 最差路径（本轮实际报告）

'''
for kind,info in worst.items():
    result+=f"- **{kind} {info['slack_ns']:+.3f}ns**：`{info['start']}` → `{info['end']}`。\n"
result+='''
全局HWNS是工具对保持类检查的汇总，不是HDMI管脚hold。上面单独列出普通hold与内部复位removal；外部SD/DDC/TMDS IO时序仍未签核。Speed仍为NA，STA覆盖99.90%，不能用内部正裕量替代板级电气验收。

## 验证与范围

- 原98项测试与新增3项全部通过，101份逐项日志见 [test_logs](build1/test_logs/)，完整执行记录见 [regression.log](build1/regression.log)。
- 新测试：编码全字节组合/差分界限；延迟23拍的原raster整帧HS/VS/DE、RGB与帧中复位重新锁定；线级EDID从机、ACK/NACK、坏校验/头、不支持800、缺失设备与复位再读。
- `audit.py`验证所有原RTL（除计划内top局部接线）、800参数/实例、PHY、PLL、SDRAM、约束、原98项激励均未改；70位status_source位宽与顺序一致。
- TD两个工程入口、design_files与ModelSim入口已同步登记新增模块，static_check ALL PASS。
- 沿用原构建脚本的独立TD会话reload→incremental route→fix_hold，未修改时钟、引脚或物理策略。
- 没有新增CRITICAL种类、没有coredump。既有PHY-7002 SDRAM宏位置两条、PHY-5079一条local-routed clock仍存在；没有将其归为已解决。

## 用户应注意

640模式不发送HDMI音频；默认上电640无声属于本轮选择。听WAV请用已有键盘R切到**实际800×600**，音量非零并解除静音。EDID回退640时也无声。KEY/SW未新增分辨率功能；OSD的A:R仅表示WAV/PCM状态，不表示640正在发送音频包。详细使用、文件原理与上板验收见 [说明书](../../docs/HDMI_SELFWRITE_640_20261019.md)。

更正附件：`0000011111`=0x01F，非0x03F；TMDS控制期差分清零。保留低有效VGA同步、原PHY位序与最终RGB/DE流；不能凭仿真断言实体显示器已锁定。

DDC继续只在上电触发一次、读取base block。SCL保持原output端口，低/高阻开漏输出，不能采样显示器clock stretching；不新增HPD/热插拔。缺失/NACK后释放总线，由原解析器超时回退。该边界已写入说明书。

## 证据与备份

- [冻结build_manifest](build1/build_manifest.json)：完整输入SHA256、工具警告与四项时序。
- [timing_status](build1/timing_status.txt)、[详细路径](build1/routed_timing_paths20.txt)、[物理资源](build1/physical_area.txt)。
- [summary.json](build1/summary.json)、[sha256.json](build1/sha256.json)：路径、101测试清单及全部冻结文件哈希。
- [baseline.json](baseline.json)与`before/`：包含开始时README用户改动的完整备份；未删除必要官方IP。

不自动下载板卡、不写实体SD卡、不生成新bit。实板仍需验证640图像/颜色/位置、全部叠加层与800图声、异常EDID回退。
'''
(here/'RESULT.md').write_text(result,encoding='utf-8',newline='\n')

notice='''> **2026-10-19 本轮：640 加密实例已替换为明文 TMDS 纯视频核，800 保留原 HDMI 图声；独立 EDID 协商保留。** 静态检查80源/40IO、101项ModelSim及综合/布局布线/内部STA通过。物理LUT 15,785、BRAM 41；SWNS +0.044ns、HWNS +0.024ns，STNS/HTNS均0。资源降低但setup裕量较上一版减少；未达到整体+0.5ns。**默认640不发送HDMI音频，听WAV需R切到实际800×600；EDID回退640也无声。** 未生成本轮bit、未上板，外部IO和既有物理警告仍待核对。详见 [本轮说明](LINK_DOC) 与 [实际报告](LINK_RESULT)。
'''
for name in ('README.md','docs/BUILD_STATUS.md','docs/USER_GUIDE.md'):
    p=r/name;t=p.read_text(encoding='utf-8-sig')
    t=t.replace('2026-10-19 当前时序优化：','历史：2026-10-19 替换640核前的时序优化：')
    doc='docs/HDMI_SELFWRITE_640_20261019.md' if name=='README.md' else 'HDMI_SELFWRITE_640_20261019.md'
    report='reports/hdmi_selfwrite_20261019/RESULT.md' if name=='README.md' else '../reports/hdmi_selfwrite_20261019/RESULT.md'
    first,rest=t.split('\n',1)
    t=first+'\n\n'+notice.replace('LINK_DOC',doc).replace('LINK_RESULT',report)+'\n'+rest.lstrip('\n')
    if name=='README.md':
        t=t.replace('| WAV | 48kHz/16bit/单声道PCM', '| WAV（仅实际800输出声音） | 48kHz/16bit/单声道PCM')
    if name=='docs/USER_GUIDE.md':
        t=t.replace('| 无声 | 合规WAV', '| 无声 | 先确认实际800×600；640不发送HDMI音频，再检查合规WAV')
    p.write_text(t,encoding='utf-8',newline='\n')

short='''> **2026-10-19 输出变化：640×480 为明文 TMDS 纯视频，不发送 HDMI 音频。** 听 WAV 需用已有键盘 R 请求并确认 OSD 实际输出 **800×600**；EDID 回退 640 时也无声。KEY/SW 原操作未改、未新增分辨率切换功能。A:R 只代表内部 WAV/PCM 就绪。见 [640/800使用说明](HDMI_SELFWRITE_640_20261019.md)；尚未完成本轮实板出图出声验收。
'''
for name in ('KEY_SW_OPERATION.md','KEYBOARD_USAGE_20261016.md','CONNECTION_AND_USAGE.md','WAV_AUDIO_20261014.md'):
    p=r/'docs'/name;t=p.read_text(encoding='utf-8-sig');first,rest=t.split('\n',1)
    t=first+'\n\n'+short+'\n'+rest.lstrip('\n')
    if name=='CONNECTION_AND_USAGE.md':
        t=t.replace('声音也走同一根HDMI_B线，','实际800×600时声音也走同一根HDMI_B线；640无声。')
        t=t.replace('听不到时先看错误/音量与显示器音量。','听不到时先确认实际800×600，再看错误/音量与显示器音量。')
        t=t.replace('| 无声 | 默认音量08','| 无声 | 先确认实际800×600，640不发音频；默认音量08')
    if name=='KEYBOARD_USAGE_20261016.md':
        t=t.replace('| 1：VGA，复位默认 | 640×480，25MHz像素，约59.524Hz | 全部合规图片都可缩放显示 |',
                    '| 1：VGA，复位默认 | 640×480，25MHz像素，约59.524Hz | 图片及所有叠加层，无HDMI音频 |')
    p.write_text(t,encoding='utf-8',newline='\n')
p=r/'docs/SOURCE_MAP.md';t=p.read_text(encoding='utf-8-sig')
t=t.replace('必要官方加密HDMI编码、控制包、EDID和内嵌音频IP。',
            '800×600必要官方HDMI视频/内嵌音频IP；640实例已替换，文件仍必须保留。')
newrows='''| [src/modules/hdmi/tmds_encoder.v](../src/modules/hdmi/tmds_encoder.v) | 标准TMDS转换与运行差分平衡；每像素一个10bit码，无BRAM。 |
| [src/modules/hdmi/hdmi_tmds_vga.v](../src/modules/hdmi/hdmi_tmds_vga.v) | 640纯视频，恢复HS相位，直接编码最终game像素流；无HDMI音频。 |
| [src/modules/hdmi/edid_i2c.v](../src/modules/hdmi/edid_i2c.v) | 启动域DDC随机读128字节，ACK/NACK/STOP，接原EDID解析器。 |
'''
needle='| [src/modules/bmp/bmp_read.v]'
t=t.replace(needle,newrows+needle)
p.write_text(t,encoding='utf-8',newline='\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
