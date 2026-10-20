from pathlib import Path
root=Path(__file__).resolve().parents[2]
for name in ('README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','docs/BUILD_STATUS.md','docs/README.md'):
 p=root/name;s=p.read_text(encoding='utf-8-sig')
 s=s.replace('UART/对时增量仍在物理验证，尚未交付新 bit。','UART/对时阶段已通过内部时序，红外阶段验证中，尚未交付新 bit。')
 s=s.replace('103 项 ModelSim 已通过；完整物理门禁尚未通过，红外、画质增强、相册候选尚未接入。',
             '103 项 ModelSim、综合布局布线通过，SWNS +0.243ns、HWNS +0.021ns、TNS均0；红外已接入待完整验证，画质增强与相册尚未接入。')
 p.write_text(s,encoding='utf-8')
p=root/'docs/UART_IR_ALBUM_20261020.md';s=p.read_text(encoding='utf-8-sig')
s=s.replace('当前为分阶段开发记录，**尚未通过本轮完整物理门禁，不能用旧 bit 验收这些功能**。',
            '当前为分阶段开发记录，**UART阶段已通过软件与内部物理门禁，红外阶段正在验证，尚无本轮新 bit**。')
s=s.replace('已接入源码，103 项 ModelSim 回归通过，布局布线正在修复。',
            '已接入源码，103 项 ModelSim、综合布局布线通过；SWNS +0.243ns、HWNS +0.021ns、TNS均0。')
s=s.replace('尚未接入；候选实现等待阶段一全部通过。',
            '已接入源码，独立真实NEC波形测试通过；104项全量回归及整机物理验证正在运行。')
s+='\n阶段一提交 `1dcd9a9`，冻结证据 `reports/remote_album_20261019/phase1_pass/`；该数值只代表阶段一，不自动代表包含后续改动的当前源码。\n'
p.write_text(s,encoding='utf-8')
print('Marked frozen UART pass and current IR verification state')
