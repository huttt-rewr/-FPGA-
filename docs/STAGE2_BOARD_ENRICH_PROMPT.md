# 640 明文核完成后：上板验收 + 丰富功能包 · 可落地提示词（2026-10-19）

> 用途：把本文件整段交给 GPT/协作者执行。这是 `HDMI_SELFWRITE_640_PROMPT.md` 的**下一阶段**，
> 取代并更新 `ENRICH_PACKAGE_PROMPT.md` / `FFT_SPECTRUM_PROMPT.md` / `KENBURNS_TRANSITION_PROMPT.md` /
> `VIDEO_PLAYBACK_PROMPT.md` 里**过时的时序基线**（那些文件里的 −0.592 已修复、HEAD 已变）。
> 目标：① 真机闭环验证已完成的 640 明文核 + EDID；② 在验证通过后，把"更丰富"的功能
> （转场/变焦、FFT 频谱、raw 帧视频）按序、零损害、逐门禁地加上去。

---

## 0. 现状锚点（已核实，勿重复排查，勿用旧文档的旧数字）

640 加密实例已删除，替换为**明文 video-only TMDS 核 + 独立 boot 时钟 EDID**；800 加密核保留图声。当前构建证据：

| 项 | 值 |
|---|---|
| 当前 HEAD | `f32e7c9`（其上 `ffc8584` 完成 640 替换） |
| 明文新文件 | [hdmi_tmds_vga.v](src/modules/hdmi/hdmi_tmds_vga.v)、[tmds_encoder.v](src/modules/hdmi/tmds_encoder.v)、[edid_i2c.v](src/modules/hdmi/edid_i2c.v)（已登记进 `reports/design_sources.tcl`） |
| 640 集成 | [top.v:569-578](src/top.v#L569)：`u_hdmi_640`(video-only) + `u_edid_i2c`(boot_clk) |
| 800 集成 | [top.v:580-625](src/top.v#L580)：`u_hdmi_svga` 保留图声，`I_acr_cts=40000` |
| 资源 | **LUT 15785/19600 (80.54%)、BRAM 41/64 (64.06%)、DSP 23/29、REG 10158** |
| 时序 | **SWNS +0.044ns、STNS 0、HWNS +0.024、HTNS 0**；0 违例，10480 endpoints，43315 paths |
| 回归 | **101 项 ModelSim 全过**（含新增 640 明文核/EDID 相关） |

**关键结论**：删 640 核释放了 **17 BRAM + ~1555 LUT**，资源天花板已解除（BRAM 剩 23、LUT 80.5%）。
但**时序余量反而从 +0.131 收窄到 +0.044**——再次证明"逻辑更浅 ≠ 时序更好"，后面 Part C 要格外守门禁。

---

## 1. 铁律（继承 + 本轮新增）

- **零损害**：保留双分辨率、800 的图声、EDID 协商、全部 OSD/字幕/玻璃/波形/特效/游戏/画质。
- 800 加密核、`hdmi_phy_wrapper`、`lane_lvds_10_1`、PLL/SDRAM 相位、引脚约束、**70 位 status_source** 不碰。
- **640 现在是 video-only（无声）**：这是已确认的取舍，不是本文件默认砍。要 640 也出声另立 Phase C（最难）。
- 不改 70 位 status_source（转场仍只在既有 2 位槽内扩展；Ken-Burns/FFT 用独立使能位绕开总线）。
- **单点改动、独立验证、逐阶段过门禁**；一个 Part 做完、重跑 STA 不劣化，才做下一个。
- **禁止**把任何纯像素域逻辑（转场/变焦/FFT/频谱显示）放进 `sd_card_clk`/`ext_mem_clk`。

---

## 2. Part 1 —— 上板验收（唯一能证明 640 明文核的环节，**必做且必须先做**）

### 2.1 为什么必须先上板

仿真只能证明 TMDS 8b/10b 编码与参考一致、EDID 时序状态机正确，**证明不了显示器锁相**。
位序 / 同步极性 / 帧对齐只能真机闭环。640 明文核是后续所有功能的地基，**地基没验证不许往上盖**。

### 2.2 验收清单（逐项打勾，全过才算过）

1. **640 出静态图 + OSD**：无噪点、无左右/上下偏移、颜色正确（红/绿/蓝三色分别验证）。
2. **800 出图 + 出声**：与删核前完全一致，音频正常不爆音。
3. **EDID 协商**：接"支持 800"的显示器能协商进 800；接"只支持 640"的显示器回退 640。
4. **双模式切换**（R 键 / 复位）：不花屏、不卡死、时钟切换后重新锁相正常。

### 2.3 已知风险与兜底（按顺序试，一个解决再下一个）

1. **同步极性（已修复，不再作为兜底项）**：DVI 1.0 控制字要求高有效，而内部 HS/VS 是低有效，
   [hdmi_tmds_vga.v](src/modules/hdmi/hdmi_tmds_vga.v) blue 通道已改为 `.control({!vs,!hs})`，
   `tb_hdmi_tmds_vga` 的 oracle 同步改成高有效参考，回归已锁住极性。上板若仍不锁，改查第 3/4 条（位序、DDC），不再怀疑同步极性。
2. **帧对齐 1 拍偏移**：`frame_start` 处 `h<=1`（注释已说明"该沿消费像素(0,0)"）。若整屏左/右偏 1 像素，
   改回 `h<=0` 试。
3. **位序/颜色错乱**：若红蓝互换、灰度反转，查 `hdmi_phy_wrapper` 的位反排约定，确认 LSB-first 未被二次反排。
4. **EDID 读不出**：查 DDC 上拉（`HDMI_DDC_SCL/SDA` 外部上拉是否存在）、`edid_i2c` 的
   `QUARTER_CYCLES=63` 在 boot_clk 下 SCL 是否 ~100kHz；示波器看 SDA 是否有 A0/A1 波形。

### 2.4 通过判据与记录

- 640/800/EDID/切换四项全过，且把**最终采用的同步极性、h 初值**写进报告（这是后面所有工作的基线）。
- 上板未通过前，**禁止进入 Part 2**；先回头按 2.3 排障。

---

## 3. Part 2 —— 丰富功能包（A 转场/变焦 → B FFT → C 视频）

> 执行顺序硬性：**A → B → C**，每个 Part 独立过 §4 门禁后才做下一个。
> A/B 在 25/40MHz 慢速像素域，时序基本安全；C 碰 100MHz SD/FAT32 域，是唯一真会动时序的。

### 3.1 新资源预算（已按 640 替换后的实际值更新）

| 资源 | 当前 | Part A-b 变焦 | Part B FFT | Part C 视频 | 加完 |
|---|---|---|---|---|---|
| BRAM | 41/64 | +~6 | +~3-6 | 0（走 SDRAM） | ~50-53 ✅ |
| LUT | 15785 | +400-600 | +~500-800 | +少量 | ~16.7-17.2k ✅ |
| DSP | 23/29 | +1-2 | +1-2 | 0 | ~25-27 ⚠️ 紧 |

- BRAM 不再是问题（剩 23）；LUT 充足；**DSP 只剩 6 个、A+b 要 2-4 个，是新的紧约束**——蝶形和插值优先复用，别额外开乘法器。
- 时序 SWNS +0.044（薄）：A/B 慢速域不影响；**C 必须逐级重跑 STA，劣化即降帧率/回退**。

### 3.2 时序安全三条硬规矩（三样共用）

1. 纯像素域效果（转场、变焦、频谱显示）**只放 video_clk**，禁止进 `sd_card_clk`/`ext_mem_clk`。
2. 碰 100MHz 的只有"视频源"，且**复用现有 SD→SDRAM 通路**，禁止新增第二条独立 SD 读/FAT32 查找。
3. 不碰三条负路径源表达式：FAT32 33 位比较器、fps_control `elapsed>=last_cycle`、缩放器 `y_acc→pixel`。

### 3.3 Part A —— 更多转场 + Ken-Burns 变焦（🟢 低风险，先做）

**实现与验证细节照 [KENBURNS_TRANSITION_PROMPT.md](KENBURNS_TRANSITION_PROMPT.md) Part A 执行**，补充/更新：

- **A-a 三种新转场（擦除/圆开/棋盘）**：`effect_mode` 扩到 `[2:0]`（仅模块内+frame_swap 间，**不出 70 位 status 总线**）；纯组合判定，**0 BRAM**。可**独立先行**，不依赖变焦。
- **A-b Ken-Burns 变焦**：新 `video_zoom.v`，两行缓存 `1024×24bit × 2 行`。**注意资源更正**：1024 深度 BRAM9K 一行只能存 8-9bit，故 **1024×24 一行 = 3 个 BRAM9K，两行 = 6 个**（旧提示词写 "2 BRAM" 是低估，以 6 为准）。约束 z∈[1,1.5]，双线性插值可拆 2 拍流水。
- 插在 [top.v](src/top.v) transition_pixels 之后、pixel_filter 之前；`zoom_n/pan_x` 由本地慢速计数器生成，独立使能位，不占 status 总线。

### 3.4 Part B —— 音乐频谱 FFT（🟢 低风险）

**实现与验证细节照 [FFT_SPECTRUM_PROMPT.md](FFT_SPECTRUM_PROMPT.md) 执行**，补充/更新：

- 新 `audio_spectrum.v`：128 点 radix-2 分时 FFT，离屏算、双缓冲 BRAM、屏上只画柱。
- **资源更正**：采样缓冲 + 旋转因子 + 幅度谱双缓冲 + 蝶形工作区 ≈ **3-6 BRAM9K**（不是"几乎不占"）。用 `|re|+|im|` 近似幅度，省 sqrt。
- DSP 复用：单蝶形复乘用 1 个 DSP 分时，别为 128 点开并行乘法器（DSP 只剩 6）。
- 插在 [top.v](src/top.v) waveform 之后、captions 之前；面板坐标与波形错开，`enable` 接 `video_osd`。

### 3.5 Part C —— raw 帧视频（🟡 中风险，最后做，时序收敛后）

**实现与验证细节照 [VIDEO_PLAYBACK_PROMPT.md](VIDEO_PLAYBACK_PROMPT.md) 执行**，补充/更新：

- 先做 **Phase C-a 连帧 BMP 轮播测带宽（不改 RTL）**，测出可持续帧率，作为 C-b 封顶。
- 再做 **Phase C-b .rvf 容器**（RGB565/RGB888），以"新源模式"插进 `bmp_read`/`sd_card_bmp`，复用 commit/frame_swap。
- **铁律最硬**：不碰 FAT32/fps_control/缩放器三条比较器；`rate_limited` 拉起就丢帧、不堆积。
- 因为 SWNS 只有 +0.044，**每步必须重跑 STA**；若 SWNS 变负，先降 `fps_mode` 到实测可持续值，再不行回退 C-b、退回 C-a 连帧 BMP。

---

## 4. 统一验证门禁（每完成一个 Part 都跑一遍，缺一不可）

1. `python scripts/static_check.py` → **ALL PASS**（新增源文件须登记，端口/引脚/源数一致）。
2. 对应新增 ModelSim 单测 → **ALL PASS**（A：`tb_transition_effects`/`tb_video_zoom`；B：`tb_audio_spectrum`；C：`tb_video_raw`）。
3. `python scripts/run_build.py` → 综合/布线通过；**记录 SWNS/STNS，必须不劣于 +0.044 基线**；无新增 CRITICAL、无 coredump。
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 → **ALL PASS**。

**统一验收硬线**：static_check + 全量回归 ALL PASS + SWNS/STNS 不劣化 + 无新增 CRITICAL；
功能肉眼正确、原有画质/音频/双分辨率/OSD/游戏不变。

**统一回退原则**：某 Part 让 SWNS 更负 → 先用 TD 时钟域/路径报告确认"新逻辑是否被错误放进 100MHz 域"——
违规则是实现错误，回退修正；未违规仍劣化则如实记录并回退该 Part，不在这条线上继续加复杂度。

---

## 5. 诚实兜底

1. **上板是唯一闭环**：仿真证编码正确 ≠ 显示器锁相。Part 1 不过，Part 2 一律免谈。
2. **无法"保证"时序**：A/B 靠"慢速域 + 重跑 STA"证明；C 靠"复用通路 + 逐级 STA + 降帧/回退"守住。
3. 资源新的紧约束是 **DSP（剩 6）**，不是 BRAM/LUT；蝶形与插值必须分时复用 DSP。
4. 真·编解码（MJPEG/JPEG/H.264）超出本包范围，竞赛期不建议；raw 容器 + 转场 + 频谱已足够"丰富"。
5. 640 出声（Phase C of 自写核）是另一个量级的任务，与本包无依赖，用户明确要求才单独立项。
