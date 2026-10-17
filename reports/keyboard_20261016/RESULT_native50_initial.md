# CMD6高速初版：80项通过，索引组合路径setup未通过

本阶段80项ModelSim回归全部通过，静态检查、综合与布局布线完成；STA未通过。原70bit状态布局和全部下标审计保持，构建输入哈希与冻结报告一致。

| SWNS | STNS | HWNS | HTNS |
|---|---|---|---|
| -0.245ns | -0.245ns | +0.022ns | 0.000ns |

资源：LUT15771、REG10786、BRAM9K61/64、DSP17、PLL2。没有降100MHz控制时钟，没有为功能路径增加false path，没有把内部复位removal当HDMI管脚hold，没有整体+0.5ns声明。

未生成本阶段新bit，未下载、未写实体卡，实板显示/出声/吞吐尚未验收。正式SD为原生四位25MHz；模型吞吐不是实体卡实测。50MHz尚待CMD6正式集成及板级验证。官方板手册已确认DAT1=B15、DAT2=A11和10kΩ上拉。

验证清单：[native50_initial_validation.json](native50_initial_validation.json)，[STA](native50_initial/timing_summary.txt)，[完整回归](native50_initial_regression.log)。
