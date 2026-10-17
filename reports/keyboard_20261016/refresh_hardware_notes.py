from pathlib import Path
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
for name in ['README_final.md','KEYBOARD_USAGE_final.md','publish_current_notes.py','record_stage.py','REVIEW_NOTES.md']:
 p=O/name;s=p.read_text(encoding='utf-8')
 s=s.replace('未确认DAT1/DAT2与上拉前不接板级工程','官方手册已确认DAT1=B15、DAT2=A11及10kΩ上拉；正式集成待阶段1～4验收')
 s=s.replace('DAT1/DAT2接线、上拉与50MHz CMD6协商/板级时序签核仍未完成','官方手册已确认六线映射和10kΩ上拉，正式四位集成、50MHz CMD6协商/板级时序签核仍未完成')
 s=s.replace('DAT1/DAT2焊球和上拉依据尚缺','六线映射和10kΩ上拉已由官方手册确认')
 s=s.replace('原生板DAT1/DAT2与上拉仍缺资料依据','官方板手册已确认DAT1=B15、DAT2=A11和10kΩ上拉，尚未正式接入四位')
 s=s.replace('DAT1/DAT2接线、上拉与50MHz','四位正式集成与50MHz')
 p.write_text(s,encoding='utf-8')
p=R/'docs/SD_NATIVE_4BIT_20261016.md';s=p.read_text(encoding='utf-8')
s=s.replace('剩余工作为接入与上拉核对','剩余工作为正式接入与整机/实板验证')
old='**仍待核对**：CMD、DAT0～3 的外部 10～100kΩ 上拉阻值与供电 —— 这本手册是 HDL 引脚映射手册、未给出阻值，正式上板前需完整原理图或板测确认。内部 `PULLUP` 约束不能证明板上已装规定阻值的电阻。'
new='2026-10-17重新渲染核对该手册PDF第20页图2-22：RN18/RN19标注10kΩ、公共端接3V3，CMD与DAT0～3有上拉连接，图面已补齐阻值依据；[核对图](../reports/keyboard_20261016/board_tf_page20.png)和[引脚表文字](../reports/keyboard_20261016/board_pin_evidence.txt)可复查。板卡实物版本和装配一致性仍待实板核对。内部 `PULLUP` 约束不替代外部电阻。'
assert old in s;s=s.replace(old,new)
s=s.replace('当前正式工程仍为63设计源、36位逻辑IO','源数量随键盘等阶段增加，准确登记数量见[构建状态](BUILD_STATUS.md)')
p.write_text(s,encoding='utf-8')
p=R/'docs/KEYBOARD_REMAINING_20261016.md';s=p.read_text(encoding='utf-8')
s=s.replace('DAT1、DAT2的真实板级映射与CMD/DAT上拉证据不足，不能把“有空闲PAD”当成卡座已经连接到该PAD。','官方手册PDF第20页已确认DAT1=B15、DAT2=A11和10kΩ上拉至3.3V；此前资料缺口已解除，仍须完成正式集成及板卡实物版本核对。')
s=s.replace('尚未确认真实接线时，不发布原生板级bit，不宣称50MHz或≥10MB/s实体吞吐。','六线映射资料已齐；正式集成与STA通过后可生成独立候选，但实物未测前不能宣称50MHz或≥10MB/s实体吞吐。')
p.write_text(s,encoding='utf-8')
print('Corrected hardware limitation using original PDF figure and six-pin table')
