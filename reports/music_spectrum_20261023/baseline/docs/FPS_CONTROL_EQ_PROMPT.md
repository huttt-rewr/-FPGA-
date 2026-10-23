# FPS 定时器比较器等价改写 · 可落地提示词（2026-10-18）

> 用途：把本文件整段交给 GPT/协作者执行。目标：把 `fps_control` 的 27 位幅值比较器
> `elapsed>=last_cycle` 等价改写成 `elapsed==last_cycle`，验证行为零变化，并重跑 TD 布线，
> 看 SWNS 是否从 −0.592ns 收窄。
> **铁律**：零损害——只做纯组合表达式等价改写；任何功能/画质/资源取舍必须用户显式点头。

---

## 0. 真实现状（已核对，勿重复排查）

| 项 | 值 |
|---|---|
| 当前 HEAD | `d34c488`，`sd_fat32.v` 已恢复基线 33 位比较器 |
| 最终 SWNS / STNS | **−0.592ns / −1.362ns（Setup 仍失败）** |
| HWNS / HTNS | +0.024ns / +0.000ns（Hold 通过） |
| FAT32 窄化三候选 | 已全部实测撤回（−0.743 / −0.936 / PHY-8023），**不要再试** |
| 出 bit / 上板 | 均未执行 |

7 条负 setup 路径之和 = STNS −1.362ns，分三簇：

| 簇 | 路径 | Slack |
|---|---|---|
| FAT32 | `request_rel_reg[22]` → `stream_bad_reg` | −0.592 |
| FAT32 | `target_index_reg[13]` → `cursor_reusable_reg` | −0.327 |
| **fps_control** | `rate_control$timer/last_cycle_reg[7]` → `limited_reg` | −0.185 |
| **fps_control** | `last_cycle_reg[7]` → `elapsed_reg[1].ce` | −0.075 |
| **fps_control** | `last_cycle_reg[7]` → `elapsed_reg[2].ce` | −0.056 |
| **fps_control** | `last_cycle_reg[7]` → `elapsed_reg[10].ce` | −0.056 |
| 缩放器 | `y_acc_reg[16]` → `pixel_reg[4]` | −0.071 |

**本文件只处理 fps_control 那一簇（−0.372ns，超 1/4 STNS），其余簇不动。**

---

## 1. 铁律

- 零损害：只做纯组合表达式等价改写，不改寄存器、不加拍、不改流水、不动功能/画质/音频/双分辨率/EDID。
- 两个 HDMI 加密核 + SDRAM 硬宏不碰（音频只在加密核里，固定成本不可裁）。
- 复位高有效；`vs/de` 与像素同拍。
- 单点改动，独立验证，不批量改。
- 任何资源取舍（删 MBR/FAT、最近邻缩放、收缩行缓存等）必须用户显式点头，不在本文件默认路径里。

---

## 2. 本次改动（只一处，已落在工作区）

文件 [src/modules/control/fps_control.v](src/modules/control/fps_control.v)，比较器那一行：

```verilog
// 改前
   else if(elapsed>=last_cycle)begin

// 改后
   else if(elapsed==last_cycle)begin
```

实例层级：`sd_card_bmp_m0/rate_control$timer`
（[sd_card_bmp.v:257](src/modules/bmp/sd_card_bmp.v#L257) 的 `generate if(RATE_CONTROLS)begin:rate_control`、
[sd_card_bmp.v:263](src/modules/bmp/sd_card_bmp.v#L263) 的 `fps_control ... timer(...)`）。
`rate_tick/rate_limited` 驱动 bmp/audio 的帧调度，`requested_fps` 未接。

---

## 3. 为什么逐位等价（数学证明，协作者须独立核验后签名）

`elapsed` 与 `last_cycle` 均为 **27 位**（`CW=$clog2(CLK_FREQ_HZ+1)=$clog2(100000001)=27`）。
归纳证明 `elapsed` 在一切可达状态下**永不超过 `last_cycle`**：

1. 复位 / `!enable` / `mode!=previous_mode`：`elapsed<=0`，而 `last_cycle>=0`。
2. 未到 deadline（`elapsed<last_cycle`）：`elapsed<=elapsed+1`，加完仍 `<=last_cycle`。
3. 到 deadline 且 `busy`：`elapsed` 停在 `last_cycle` 不动。
4. 到 deadline 且 `!busy`：`elapsed<=0`。

（模式切换时，`elapsed<=0` 与 `last_cycle<=新周期-1` 在同一拍生效，无 `elapsed>新last_cycle` 的窗口。）

故对所有可达状态 `elapsed∈[0,last_cycle]`，于是 `elapsed>=last_cycle ⟺ elapsed==last_cycle`，**逐位一致**。

**综合器无法推断该不变量**：`>=` 会被综合成 27 位幅值比较器（进位链，结果扇出到 `limited` 与 27 个
`elapsed` 位各自的 CE，这正是 `last_cycle[7] → elapsed[1].ce` 长路径的来源）；`==` 是逐位异或 +
27 输入与树，更浅、更局部。这是本改法的全部动机，不含任何功能变化。

---

## 4. 验证（全绿才算过，缺一不可）

1. `python scripts/static_check.py` → **ALL PASS**（只改表达式，端口/引脚/源数不变）。
2. ModelSim 定向编译 + 运行 `tb_fps_control`、`tb_rate_player` → **ALL PASS**
   （覆盖 tick/limited 节奏、`busy` 停在 deadline、模式中途切换）。
3. ModelSim **全量 94 项回归 ALL PASS**（重点 sd/bmp/audio 相关 tb，因 `rate_control` 驱动帧调度）。
4. TD 完整 build（`python scripts/run_build.py`）：
   - 记录新 SWNS/STNS。**期望**：fps_control 的 −0.372 消失，STNS 从 −1.362 降到约 −0.99，
     最差仍是 FAT32 的 −0.592；只有当 **Setup WNS ≥ 0、Hold ≥ 0** 才允许出 bit。
   - 无 coredump；PHY-7002/5079 若仍在，按 [BOARD_PENDING](BOARD_PENDING.md) 记录，不算代码侧失败。
5. **若 SWNS 反而更差**（更负，或最差路径迁移到更坏处）：**一行回退** `==`→`>=`，如实记录
   "组合改写不改善该路径"，不要继续在这条线上加复杂度。

---

## 5. 验收硬线

**行为零变化（94 项回归逐位一致）+ static_check ALL PASS + 无新增 CRITICAL + 无 coredump；
SWNS/STNS 只准改善或持平，恶化即回退。**

---

## 6. 诚实兜底

同 FAT32 比较器的教训：组合等价改写可能因物理映射/布线改变而不改善、甚至迁移最差路径，只有重跑
布线能证明，不能把"逻辑更浅"当成"时序必然更好"。若本改法无效，零损害的代码手段即告用尽，剩下的
只有用户显式勾选的资源取舍（见 [ALGO_OPT_PROMPT.md](ALGO_OPT_PROMPT.md) /
[ALGO_LEVEL_OPT_PROMPT.md](ALGO_LEVEL_OPT_PROMPT.md)），每一项都要用户明确点头才做。
