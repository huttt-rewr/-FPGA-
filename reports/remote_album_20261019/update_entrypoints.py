from pathlib import Path
root=Path(__file__).resolve().parents[2]
note='> **2026-10-20 UART/对时增量仍在物理验证，尚未交付新 bit。** 阶段一源码支持 n/p/b 与 THHMMSS，103 项 ModelSim 已通过；完整物理门禁尚未通过，红外、画质增强、相册候选尚未接入。原 KEY/SW/PS/2 保留。见 [本轮操作与状态](UART_IR_ALBUM_20261020.md)。下文 10 月 19 日及更早的时序属于各自冻结历史版本，不能代表当前源码。'
for name in ('README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','docs/BUILD_STATUS.md','docs/README.md'):
 p=root/name;s=p.read_text(encoding='utf-8-sig')
 current=note.replace('(UART_IR_ALBUM_20261020.md)','(docs/UART_IR_ALBUM_20261020.md)') if name=='README.md' else note
 first,rest=s.split('\n',1)
 p.write_text(first+'\n\n'+current+'\n'+rest,encoding='utf-8')
p=root/'docs/SOURCE_MAP.md';s=p.read_text(encoding='utf-8-sig')
s=s.replace('旧UART/IR播放命令参考，正式KEY/SW/键盘路径不实例化。','UART播放命令译码；PC_COMMANDS选择n/p/b新协议，KEY/SW/键盘仍走原消费者。')
s=s.replace('UART字节接收参考，正式控制禁用。','UART 115200 8N1接收，经remote_controls过滤播放命令或原子时间包。')
s=s.replace('UART字节发送参考，正式控制禁用。','UART字节发送，由uart_tx_queue排队返回K或?。')
s=s.replace('旧串口应答排队，正式控制禁用。','UART应答有界排队；溢出粘滞标志进入既有状态错误位。')
s+='\n## 2026-10-20 增量源码（物理门禁尚未通过）\n\n'
s+='| 源文件 | 作用 |\n|---|---|\n'
s+='| [remote_controls.v](../src/modules/control/remote_controls.v) | UART播放、对时、回显整合；包内字符不触发播放。 |\n'
s+='| [time_cmd.v](../src/modules/control/time_cmd.v) | 六位BCD范围检查、0.5秒半包超时、原子时间与序号发布。 |\n'
s+='\n状态和接线限制见 [本轮手册](UART_IR_ALBUM_20261020.md)。\n'
p.write_text(s,encoding='utf-8')
print('Updated current experimental state at documentation entry points')
