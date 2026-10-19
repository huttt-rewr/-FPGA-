from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
task=Path(__file__).resolve().parent
validation=json.loads((task/'validation.json').read_text())
timing=validation['timing_ns']
for rel in ('README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','docs/BUILD_STATUS.md'):
    p=root/rel
    s=p.read_text(encoding='utf-8-sig')
    link=('docs/' if rel=='README.md' else '')+'TRANSITIONS_ZOOM_FFT_20261019.md'
    banner=(f"> **2026-10-19 转场扩充：仅第一阶段已通过软件/内部时序门禁，尚未实板验收。** "
            f"80源/40IO静态检查、{validation['unique_tests']}项ModelSim通过；"
            f"SWNS +{timing['SWNS']:.3f}ns、HWNS +{timing['HWNS']:.3f}ns，STNS/HTNS均0。"
            "SW第3、4路同时ON后，每次换图依次轮播淡入淡出、滑动、擦除、圆形、棋盘。"
            "二维Ken-Burns受两行缓存与禁止修改SDRAM的约束冲突而未实现，FFT按指定顺序尚未启动；"
            f"本轮无新bit，旧bit不含这些修改。见[操作、原理与未完成项]({link})。\n\n")
    # Keep historical evidence but stop presenting its old bit as today's build.
    s=s.replace('> **2026-10-19 上板验收准备：已生成匹配当前源码的候选 bit',
                '> **历史：2026-10-19 旧上板验收包（不匹配当前源码）：已生成当时版本的候选 bit',1)
    s=s.replace('**按本次任务书，四项实板通过前不进入新转场/变焦、FFT、raw视频。**',
                '**该前置规则属于旧任务；本轮按新版统一附件执行转场，实板仍待验。**',1)
    s=s.replace('> **2026-10-19 本轮：640 加密实例已替换',
                '> **历史：2026-10-19 640 加密实例替换记录：640 加密实例已替换',1)
    pos=s.index('\n')+1
    s=s[:pos]+'\n'+banner+s[pos:].lstrip('\n')
    if rel=='docs/KEY_SW_OPERATION.md':
        s=s.replace('淡出淡入、滑动交替 | 紫色','五效果轮播（淡入淡出、滑动、擦除、圆形、棋盘） | 紫色')
        s=s.replace('交替模式：复位后的第一次实际动画为淡出淡入，下一次为滑动，再下一次淡出淡入。首图不消耗轮次；暂时退出交替模式再回来会保留轮次。',
                    '五效果轮播：复位后依次为淡出淡入、滑动、擦除、圆形开合、棋盘展开，然后循环。首图不消耗轮次；暂时退出轮播档再回来会保留轮次。')
        s=s.replace('滚动字幕加交替转场','滚动字幕加五效果转场')
        s=s.replace('连续换两次图，观察两种效果','连续完成五次换图，观察五种效果')
        s=s.replace('连续完成两次换图，演示交替转场','连续完成五次换图，演示五效果轮播')
    p.write_text(s,encoding='utf-8')
doc=root/'docs/TRANSITIONS_ZOOM_FFT_20261019.md'
s=doc.read_text(encoding='utf-8')
s=s.replace('圆形计算预计增加两个 DSP，以最终物理报告为准。',
            '圆形坐标按有效画面范围收窄为 9 位，两路 9×9 平方经 TD 映射后合计增加一个 DSP（物理总计 24/29）；BRAM 仍为 41/64。')
s=s.replace('完整验证结果、基线备份和作用域审计位于',
 f"最终静态检查 80源/40IO、{validation['unique_tests']} 项 ModelSim 全部通过；SWNS +{timing['SWNS']:.3f}ns、HWNS +{timing['HWNS']:.3f}ns、STNS/HTNS 均为 0，setup 不低于 +0.105ns 基线。无新增 CRITICAL、无 coredump；保留既有 SDRAM 位置及局部时钟告警，外部 IO 尚未签核。\n\n第一轮候选曾出现 PHY-8023 布线资源争用并失败，已单独归档，未算作验收通过；收窄圆形计算后重新完成全流程与全部回归。\n\n完整验证结果、基线备份和作用域审计位于")
doc.write_text(s,encoding='utf-8')
print('Updated README, user guide, KEY/SW guide, build status and transition notes')
