# R切模式、字幕流水与独立KEY计数：缩放器仍有一条setup违例

本阶段75项ModelSim回归全部通过，静态检查、综合与布局布线完成；STA未通过。原70bit状态布局和全部下标审计保持，构建输入哈希与冻结报告一致。

| SWNS | STNS | HWNS | HTNS |
|---|---|---|---|
| -0.284ns | -0.284ns | +0.019ns | 0.000ns |

资源：LUT15250、REG10427、BRAM9K61/64、DSP17、PLL2。没有降100MHz控制时钟，没有为功能路径增加false path，没有把内部复位removal当HDMI管脚hold，没有整体+0.5ns声明。

未生成本阶段新bit，未下载、未写实体卡，实板显示/出声/吞吐尚未验收。正式SD仍SPI25MHz。四位25MHz候选未接板，50MHz缺CMD6协商和板级签核。官方板手册已确认DAT1=B15、DAT2=A11和10kΩ上拉，尚未正式接入四位。

验证清单：[phase3_keys_validation.json](phase3_keys_validation.json)，[STA](phase3_keys/timing_summary.txt)，[完整回归](phase3_keys_regression.log)。
