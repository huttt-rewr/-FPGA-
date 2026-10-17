# 阶段五基线：原生四位25MHz正式接入

本阶段78项ModelSim回归全部通过，静态检查、综合与布局布线完成；STA通过。原70bit状态布局和全部下标审计保持，构建输入哈希与冻结报告一致。

| SWNS | STNS | HWNS | HTNS |
|---|---|---|---|
| +0.260ns | 0.000ns | +0.022ns | 0.000ns |

资源：LUT15585、REG10752、BRAM9K61/64、DSP17、PLL2。没有降100MHz控制时钟，没有为功能路径增加false path，没有把内部复位removal当HDMI管脚hold，没有整体+0.5ns声明。

未生成本阶段新bit，未下载、未写实体卡，实板显示/出声/吞吐尚未验收。正式SD为原生四位25MHz；模型吞吐不是实体卡实测。50MHz尚待CMD6正式集成及板级验证。官方板手册已确认DAT1=B15、DAT2=A11和10kΩ上拉。

验证清单：[native25_delivery_validation.json](native25_delivery_validation.json)，[STA](native25_delivery/timing_summary.txt)，[完整回归](native25_delivery_regression.log)。
