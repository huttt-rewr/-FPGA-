# 键盘媒体路线与CMD6四位25/50MHz正式集成

本阶段80项ModelSim回归全部通过，静态检查、综合与布局布线完成；STA通过。原70bit状态布局和全部下标审计保持，构建输入哈希与冻结报告一致。

| SWNS | STNS | HWNS | HTNS |
|---|---|---|---|
| +0.026ns | 0.000ns | +0.022ns | 0.000ns |

资源：LUT15709、REG10774、BRAM9K61/64、DSP17、PLL2。没有降100MHz控制时钟，没有为功能路径增加false path，没有把内部复位removal当HDMI管脚hold，没有整体+0.5ns声明。

未生成本阶段新bit，未下载、未写实体卡，实板显示/出声/吞吐尚未验收。正式SD已集成CMD6协商：确认成功才升四位50MHz，不支持或忙时留在四位25MHz；外部IO和实体卡吞吐仍待实板验证。官方板手册已确认DAT1=B15、DAT2=A11和10kΩ上拉。

验证清单：[native50_ultra_validation.json](native50_ultra_validation.json)，[STA](native50_ultra/timing_summary.txt)，[完整回归](native50_ultra_regression.log)。
