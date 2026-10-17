# 阶段三候选：头字段与按键复位整改，时序未通过

本阶段74项ModelSim回归全部通过，静态检查、综合与布局布线完成；STA未通过。原70bit状态布局和全部下标审计保持，构建输入哈希与冻结报告一致。

| SWNS | STNS | HWNS | HTNS |
|---|---|---|---|
| -2.313ns | -12.702ns | +0.021ns | 0.000ns |

资源：LUT15385、REG10257、BRAM9K61/64、DSP17、PLL2。没有降100MHz控制时钟，没有为功能路径增加false path，没有把内部复位removal当HDMI管脚hold，没有整体+0.5ns声明。

未生成本阶段新bit，未下载、未写实体卡，实板显示/出声/吞吐尚未验收。正式SD仍SPI25MHz。四位25MHz候选未接板，50MHz缺CMD6协商和板级签核。原生板DAT1/DAT2与上拉仍缺资料依据。

验证清单：[phase3_header_validation.json](phase3_header_validation.json)，[STA](phase3_header/timing_summary.txt)，[完整回归](phase3_header_regression.log)。
