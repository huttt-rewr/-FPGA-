"""Publish the PC-only candidate package and point docs at the pending gate."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile

root=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
subprocess.run([sys.executable,str(here/'prepare.py'),'verify'],cwd=root,check=True)
bit=json.loads((here/'candidate/manifest.json').read_text())
assert bit['bytes']==635444

result=f'''# 上板验收准备结果（2026-10-19）

**完成了电脑端候选与素材准备；Part 1四项实板检查待测，Part 2未开始。** 本次没有改RTL、工程清单、时钟、复位、引脚约束或70位status_source。

任务书明确规定先上板；当前会话没有连接板卡、显示器/下载器的可用硬件操作接口或人工实板观察，因此没有将任何一项记为通过，也没有进入转场/变焦、FFT和raw视频实现。

## 已完成

- 校验当前源码与上一轮冻结输入哈希一致：80源/40IO静态ALL PASS，原101项回归及冻结报告完整。无RTL变更，不重跑同样的101项。
- 原布线数据库SHA-256=`{bit['database_sha256']}`，与已通过构建绑定。
- 独立TD会话导入同一个DB，不重新布局/布线、不改时钟；bit生成前后分别报告内部STA，均为SWNS +0.044ns / STNS0 / HWNS +0.024ns / HTNS0，四种模式时钟均存在。
- 生成 [hdmi_640_plain_800_audio.bit](candidate/hdmi_640_plain_800_audio.bit)，{bit['bytes']}字节，SHA-256=`{bit['sha256']}`。
- 生成并用既有严格校验器检查7份BMP和1份48kHz/16bit/单声道WAV；只生成工程内普通文件，未写卡。
- 生成 [验收教程](../../docs/BOARD_ACCEPTANCE_640_20261019.md)、[实板记录表](BOARD_RESULTS.md)、[状态表](STATUS.json)与便携文件包。

## 当前基线与待测项

源码提交`f32e7c9`（RTL提交`ffc8584`）；LUT15785 / BRAM41 / DSP23 / REG10158。blue通道同步`{{vs,hs}}`低有效，复位h=0，VS下降沿之后的下一拍h=1，时钟图案0x01F；这些是代码设置，最终实板采用值仍待确认。

| 实板项目 | 状态 |
|---|---|
| 640静态图/OSD/原叠加，RGB颜色/无噪点/无偏移 | 待测 |
| 800图像与WAV出声、无爆音 | 待测 |
| 支持800设备协商 + 仅640设备回退 | 两类设备均待测 |
| R切换与复位，重新锁定、不卡死 | 待测 |

按照本次附件Part 1“上板未通过前，禁止进入Part 2”，等这四项的真实结果齐全后再进入新转场→变焦→FFT→raw视频。未对物理观测作推断。只有1920×1080面板型号，不能推断其EDID是否仅支持640；没有第二类设备时应保留未测。

640仍无HDMI音频；800图声与原连接保持。KEY/SW未加新功能，R仍由现有PS/2键盘控制。默认640，听WAV必须确认实际800，R:2但回退640仍无声。

既有PHY-7002/PHY-5079仍未解决，Speed=NA及外部IO未签核；内部removal不是HDMI管脚hold，未达到整体+0.5ns。降目标FPS不等于修复固定100MHz的setup违例。

## 文件与核验

- [候选清单](candidate/manifest.json)、[生成日志](candidate/bitgen.log)。
- [生成前STA](candidate/before_bit_timing_status.txt)、[生成后STA](candidate/after_bit_timing_status.txt)。
- [素材清单](media_manifest.json)、[预览](media_preview.png)、[素材目录](sd_files/)。
- [便携验收包](board_acceptance_640.zip)及[文件包哈希](package_manifest.json)。

```powershell
python reports/board_accept_20261019/prepare.py verify
```

修改前的README/用户手册/构建状态已备份到本目录`before/`。没有改写上一轮冻结报告中的历史“未生成bit”记录；当前候选状态在主文档顶部单独说明。
'''
(here/'RESULT.md').write_text(result,encoding='utf-8',newline='\n')

notice='''> **2026-10-19 上板验收准备：已生成匹配当前源码的候选 bit，尚未下载或完成实板验收。** 635,444字节；生成前后SWNS +0.044ns、HWNS +0.024ns、STNS/HTNS均0，原80源/101项回归基线不变。已准备7份BMP、1份WAV和四项实板记录；**按本次任务书，四项实板通过前不进入新转场/变焦、FFT、raw视频。** 见 [逐步验收教程](GUIDE)、[本次准备结果](RESULT)、[候选bit](BIT)。默认640无HDMI音频，实际800保留图声。
'''
for name in ('README.md','docs/BUILD_STATUS.md','docs/USER_GUIDE.md'):
    p=root/name;t=p.read_text(encoding='utf-8-sig')
    assert '2026-10-19 上板验收准备：' not in t,'Do not duplicate the published notice'
    if name=='README.md':
        links=('docs/BOARD_ACCEPTANCE_640_20261019.md','reports/board_accept_20261019/RESULT.md',
               'reports/board_accept_20261019/candidate/hdmi_640_plain_800_audio.bit')
    else:
        links=('BOARD_ACCEPTANCE_640_20261019.md','../reports/board_accept_20261019/RESULT.md',
               '../reports/board_accept_20261019/candidate/hdmi_640_plain_800_audio.bit')
    new=notice.replace('GUIDE',links[0]).replace('RESULT',links[1]).replace('BIT',links[2])
    first,rest=t.split('\n',1)
    p.write_text(first+'\n\n'+new+'\n'+rest.lstrip('\n'),encoding='utf-8',newline='\n')

quick=f'''# 640明文核 / 800图声 · 实板待验包

候选bit：candidate/hdmi_640_plain_800_audio.bit
635444字节，SHA-256：{bit['sha256']}
源码提交f32e7c9，EG4S20BG256；内部SWNS +0.044ns / HWNS +0.024ns / STNS0 / HTNS0。

## 怎么用

1. 解压到普通电脑目录；用TD配套下载工具识别已有EG4S20BG256下载链，选择candidate里的bit做JTAG临时配置。本包没有执行下载或写Flash。
2. 只将sd_files内7份BMP和1份WAV复制到FAT32卡根目录，安全弹出后插回板卡。不是烧写裸镜像；文件序号按FAT目录项顺序，不按文件名。
3. 显示器接HDMI_B，默认640。用KEY1（MODE:PLAY）或键盘左右选图。RGB纯色检查颜色，GRID640检查边框，SMALL/PORTRAIT检查缩放；开启OSD/字幕/特效/游戏检查原功能。
4. 用已有PS/2键盘R请求800，看实际尺寸是800x600后检查GRID800和TONE.wav。A松开后两秒内按0选第一份音频，音量非零、解除静音。640无HDMI音频；A:R不表示640发声。
5. TONE是440Hz两秒、静音一秒、880Hz两秒、静音一秒；先调低显示器音量。
6. 换显示器后全局复位再测EDID：支持800的设备R后实际800，仅640设备R后回退640。没有第二类设备就记未测，不能用仿真替代。
7. 支持800的设备上R循环640→800→640→640，记录10轮及全局复位结果。每次等屏幕重新锁定，切模式暂停轮播需再开。
8. 填BOARD_RESULTS.md。所有四项真实通过后才继续新转场/变焦、FFT、raw视频；当前都未开始。

## 当前边界

尚未实板出图出声；低有效{{vs,hs}}、frame_start之后h=1是代码基线，待实物确认。不要同时改极性、位序、相位。既有SDRAM物理警告、Speed=NA与外部IO仍未签核，未达到整体+0.5ns。

详细步骤在工程E:/fpga/docs/BOARD_ACCEPTANCE_640_20261019.md。manifest.json记录bit/数据库/源构建关联；media_manifest.json记录素材哈希。STATUS.json各项pending，不能视为通过。
'''
(here/'PACKAGE_README.md').write_text(quick,encoding='utf-8',newline='\n')
paths=[here/'PACKAGE_README.md',here/'BOARD_RESULTS.md',here/'STATUS.json',
       here/'media_manifest.json',here/'media_preview.png']
paths+=list((here/'sd_files').glob('*'))+list((here/'candidate').glob('*'))
archive=here/'board_acceptance_640.zip'
assert not archive.exists(),'Do not overwrite a delivered package'
with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in sorted(paths):
        arcname='README.md' if p.name=='PACKAGE_README.md' else p.relative_to(here).as_posix()
        z.write(p,arcname)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for p in paths:
        arcname='README.md' if p.name=='PACKAGE_README.md' else p.relative_to(here).as_posix()
        assert z.read(arcname)==p.read_bytes(),arcname
manifest={'archive':archive.name,'bytes':archive.stat().st_size,
          'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
          'board_test':'pending','part2_started':False,
          'files':{p.relative_to(here).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
(here/'package_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(f'Prepared {archive.name}, {archive.stat().st_size} bytes, all entries verified')
