# 更多转场 + Ken-Burns 动效 · 可落地提示词（2026-10-18）

> 用途：把本文件整段交给 GPT/协作者执行。目标：在现有"淡入淡出/滑动"转场之外，新增若干转场（擦除/圆开/棋盘），
> 并加一个 Ken-Burns 式慢速数字变焦（缓慢推近/平移）动效。
> 时序安全铁律：**全部逻辑放在 25/40MHz 慢速像素域**（video_clk），每拍 40/25ns 余量，不碰 100MHz 关键域。

---

## 0. 为什么时序安全 + 一个必须先知道的结构约束

1. 像素链在 **video_clk（25/40MHz）**，负路径全在 100MHz 域，故本功能对整体时序影响极小。
2. **结构约束（关键）**：转场类型经 `transition_mode[1:0]` 走 **70 位 status_source 总线**（[top.v:181](src/top.v#L181)
   `video_effect=status_video[29:28]`），该总线被历史文档锁定为"70 位未动"。**不要为了加转场去加宽 status 总线**。
   新转场只能在**既有 2 位 4 个槽位内复用/内部扩展**；Ken-Burns 用独立模块 + 使能位，完全绕开 status 总线。

---

## 1. 已核对的现状

- 转场引擎 [transition_pixels.v](src/modules/video/transition_pixels.v)：
  - `effect_mode[1:0]`：0=无 / 1=淡入淡出（`fade_level` 乘系数）/ 2=滑动（`line_mem[0:1023]` 行缓存 + `slide_offset`）/ 3=交替。
  - 已含 1024×24 行缓存、两拍流水，像素域。
- 调度 [frame_swap.v](src/modules/video/frame_swap.v)：根据 `transition_mode[1:0]` 生成 `effect_mode/fade_level/slide_offset`，
  状态机 IDLE→OUT→SWITCH→IN，只在 `vblank` 推进。
- 顶层实例：[top.v:729-733](src/top.v#L729)（frame_swap）、[top.v:742-745](src/top.v#L742)（transition_pixels）。
- 转场类型来源：`switch_controls` → `status_source` → `video_effect`（[top.v:181](src/top.v#L181)）。

---

## 2. 铁律

- **零损害**：不改 70 位 status_source、不改 frame_swap 状态机时序语义、不改 SDRAM 读写/缩放/FAT32/fps_control。
- 全部新增逻辑在 video_clk；不新增 100MHz 关键路径。
- 单点改动、独立验证；过门禁再下一步。

---

## 3. Phase 4a —— 更多转场（擦除 / 圆开 / 棋盘），低风险必做

### 3.1 方案（不动 status 总线）

在 [transition_pixels.v](src/modules/video/transition_pixels.v) 内部把 `effect_mode` 从 `[1:0]` 扩到 `[2:0]`（仅模块内部 + frame_swap 之间，**不出去 status 总线**），新增三种转场的**内部编码**；对外 2 位槽位映射保持不变：

- 槽 2（原"滑动"）保留滑动；
- 槽 3（原"交替"）改为"擦除/圆开/棋盘"三者按帧自动轮换（复用 [frame_swap.v](src/modules/video/frame_swap.v) 已有的 `alternate_slide` 翻转思路，改成 2 位轮换计数）。

新增转场本质都是**每像素一个组合判定**，慢速域零压力：

1. **水平擦除 wipe**：`covered = (x < 擦除边界)`，边界由 `slide_offset` 复用（把 slide_offset 当"已擦除宽度"）。
2. **圆形 iris 开**：`covered = ((x-cx)^2 + (y-cy)^2 > r^2)`，r 由 fade/slide 计数器映射；乘法用慢速域组合逻辑或 1 个 DSP。
3. **棋盘 checkerboard**：`covered = ((x>>k) ^ (y>>k))[0]`，k 随进度递减；纯 LUT，零成本。

> 注：这三种只需"当前图"（无跨帧依赖），与滑动一样只读本行已写像素或直接黑场遮罩，**不引入新的 SDRAM 随机读**。

### 3.2 改动点

- [transition_pixels.v](src/modules/video/transition_pixels.v)：`effect_mode[2:0]`、新增三种 `covered` 计算、`shift_q/covered_q` 逻辑扩展；行缓存 `line_mem` 保留给滑动。
- [frame_swap.v](src/modules/video/frame_swap.v)：`effect_mode[2:0]`、`transition_mode==3` 分支改成轮换编码。
- 不改 top.v 的 status 连线。

---

## 4. Phase 4b —— Ken-Burns 数字变焦（可选，资源中等）

### 4.1 结构事实（决定做法）

显示帧是从 SDRAM **顺序读出**的（video_timing_data 顺序地址 → frame_read_write），**不支持随机缩放读**。
所以 Ken-Burns 用**像素域行缓存变焦**：对已读出的流做"数字放大"，不碰 SDRAM 读架构。

### 4.2 实现：新建 `src/modules/video/video_zoom.v`

```verilog
module video_zoom #(parameter ZOOM_FRAC=4)(
    input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,
    input [9:0] zoom_n,      // 缩放分子，如 16(1.0x)..24(1.5x)，ZOOM_FRAC=4 → 实际 z=zoom_n/16
    input [9:0] pan_x,       // 缓慢平移量
    output reg out_vs,out_de,output reg [23:0] out_rgb);
```

- **两行缓存**（`(* ram_style="bram" *) [23:0] linebuf[1:0][0:1023]`）：存当前行 + 上一行。
- 输出像素 (x,y) 取输入 ( (x<<ZOOM_FRAC)/zoom_n + pan_x , (y<<ZOOM_FRAC)/zoom_n )，对两行缓存做双线性插值。
- **约束 z∈[1, 1.5]**（只放大不缩小），两行缓存足够；pan 缓慢变化，由慢速帧计数器驱动的 LUT 生成（如 8 秒推近 + 平移一个来回）。
- 时序安全：双线性插值（4 个乘加）在 25/40MHz 下余量充足；可加 1~2 拍流水把乘法拆开，仍是慢速域。
- 资源估计：~400-600 LUT + 1~2 DSP + **6 BRAM**（行缓存：1024 深度 BRAM9K 一行只存 8-9bit，1024×24 一行 = 3 个、两行 = 6 个；旧值"2 BRAM"低估）。

### 4.3 集成（绕开 status 总线）

在 [top.v](src/top.v) 的 transition_pixels 之后（`effects` 与 `pixel_filter` 之间，[top.v:742-745](src/top.v#L742) 与 [top.v:752](src/top.v#L752)）插入 `video_zoom`，
`zoom_n/pan_x` 由本地慢速计数器生成（或用一个**独立使能位**门控，不由 status 总线选择），输出接 pixel_filter 的输入。
使能来源建议复用现有 `transition_mode`（转场进行中放大）或新增一个 `video_osd` 无关的本地开关，二选一并写清。

---

## 5. 验证（全绿才算过）

1. `python scripts/static_check.py` → ALL PASS。
2. 新增 `sim/tb_transition_effects.v` / `sim/tb_video_zoom.v`：
   - 转场：断言每种 covered 判定在边界像素处正确、非面板/非遮罩区逐位透传、vs/de 对齐。
   - zoom：断言 z=1.0 时输出=输入（恒等）、z=1.5 时输出坐标映射正确、插值无越界。
3. `python scripts/run_build.py` → 布线通过；记录 SWNS/STNS **不劣于改前**。
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 ALL PASS。

---

## 6. 验收硬线

**回归 + static_check ALL PASS + SWNS/STNS 不劣化 + 无新增 CRITICAL；
新转场肉眼正确、Ken-Burns 缓慢推近不撕裂不花屏、原有画质/音频不变。**

---

## 7. 诚实兜底

1. "保证时序没问题"只由"慢速域 + 重跑 STA"证明，不能靠断言。若 SWNS 劣化，先确认新逻辑没被错误放进 100MHz 域（TD 时钟域报告），违规则回退。
2. 若 zoom 的 4 乘加在 25MHz 仍吃紧（不会，但以防万一），拆成 2 拍流水即可，输出延迟 2 拍、功能不变。
3. 若 Ken-Burns 的 pan/zoom 参数 LUT 想更丰富（随机、加速曲线），都只改参数生成器，不动缩放核。
4. 真·缩小（z<1）需要更深行缓存（多行），超出本文件范围，默认不做；需要时另立任务。
