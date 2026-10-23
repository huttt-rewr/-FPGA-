# 贪吃蛇小游戏 · 提示词（PS/2 交互演示）

> 用途：把本文件整段交给 GPT/协作者执行。目标是在现有 HDMI 视频链末端加一个
> **贪吃蛇小游戏**，用 PS/2 键盘方向键控制，作为"交互系统"演示亮点。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效、`vs/de/x/rgb` 流式接口、整数运算。

---

## 0. 硬约束（写错就是白写）

- 复位 `rst` **高有效**（全工程一致）。
- 视频流统一接口：`clk, rst, vs, de, x[9:0], rgb[23:0] → out_vs, out_de, out_rgb`；
  **`vs/de` 必须与像素同拍打齐**。
- 时钟 `video_clk`，复位 `rst_video`。
- **BRAM 新增必须为 0**（全工程 BRAM 只剩 3 块：61/64）。棋盘/蛇身/食物状态一律用
  **LUT 分布式 RAM**（`(* ram_style="dram" *)`，工程里 `pixel_effects.v` 的 `video_luma_window`
  就是这么写的），或用寄存器。
- 纯整数运算，不用浮点、不用除号（坐标到格子用 `>>4` 这种 2 的幂）。

---

## 1. 先读这些文件（对齐项目）

1. [src/top.v](src/top.v) 视频链 **724-770 行**，当前顺序：
   `source_coordinates → picture_adjust → picture_gamma → transition_pixels →
   pixel_effects → glass_osd → audio_visualizer → caption_overlay → status_osd → HDMI`。
2. [src/modules/osd/caption_overlay.v](src/modules/osd/caption_overlay.v)：**叠加层的风格范本**
   （怎么判 `in_banner`、怎么画色块、怎么 `composed=background; if(...)composed=颜色`）。
3. [src/modules/input/ps2_controls.v](src/modules/input/ps2_controls.v)：**方向键已经解码好了**——
   扩展码 `8'h74`=右、`8'h6b`=左、`8'h75`=上、`8'h72`=下（见文件内 `lane_code` 与 `key_extended` 的 case）。
   你要做的是把这些"按住"状态暴露出来给游戏用（见第 3 节）。
4. [src/modules/osd/osd_char_rom.v](src/modules/osd/osd_char_rom.v)：5×7 字库，用于画 "GAME OVER"/分数。

---

## 2. 新增模块：`src/modules/game/snake_game.v`

### 接口

```verilog
module snake_game #(
    parameter GW = 32,          // 格子列数（32*16=512px 宽）
    parameter GH = 24,          // 格子行数（24*16=384px 高）
    parameter CELL = 16         // 每格像素（16，2 的幂，坐标>>4）
)(
    input clk, rst,             // rst 高有效
    input vs, de,
    input [9:0] x, y,
    input [23:0] rgb,           // 上游 RGB（status_osd 输出）
    input game_enable,          // 游戏模式开关（键盘某键切换）
    input [1:0] dir_req,        // 方向请求 0=上 1=右 2=下 3=左（来自 PS/2 方向键）
    input tick,                 // 移动节拍：每 N 帧一个脉冲（顶层生成）
    output reg out_vs, output reg out_de,
    output reg [23:0] out_rgb,
    output reg [7:0] score,     // 分数，送 7 段码/OSD 显示
    output reg game_over
);
```

### 游戏区定位（居中）

- 游戏区 = 屏幕居中 `GW*CELL × GH*CELL` 矩形（默认 512×384，在 640×480 里居中）。
- `cx = x >> 4`、`cy = y >> 4`（CELL=16，`>>4` 代替除号）。
- 只有 `game_enable && (x,y) 在游戏区内` 才覆盖画面，其余原样透传 `rgb`。

### 蛇身与食物（关键：不占 BRAM）

```verilog
// 1 bit/格：0 空、1 蛇。GW*GH = 32*24 = 768 bit，LUT 分布式 RAM。
(* ram_style="dram" *) reg [0:GW*GH-1] board;
reg [4:0] head_x, head_y;        // 蛇头格子坐标
reg [9:0] tail_addr;             // 蛇尾在"身体坐标队列"里的指针
// 身体坐标队列：存每节身体的 (x,y)，环形 FIFO，同样 LUT RAM。
(* ram_style="dram" *) reg [9:0] body_x [0:GW*GH-1];
(* ram_style="dram" *) reg [9:0] body_y [0:GW*GH-1];
reg [9:0] len;                   // 当前长度（含头）
reg [4:0] food_x, food_y;        // 食物格子
```

### 每 tick 的更新逻辑（组合判定 + 时序落寄存器）

1. `dir` = 若 `dir_req` 与当前方向相反则保持原方向（**禁止 180° 掉头**），否则取 `dir_req`。
2. 新头 = 旧头 + 方向；若撞墙或撞自己（`board[新头]==1`）→ `game_over<=1`，本局冻结。
3. 若新头 == 食物：`len+1`，`score+1`，随机/伪随机重新生成食物（落在非蛇格，用 LFSR）。
4. 否则：清掉蛇尾（`board[尾]==0`），身体队列尾指针前移。
5. 置 `board[新头]=1`，队列头写入新头。

> 伪随机用 **LFSR**（线性反馈移位寄存器，~10 LUT），别引入 BRAM 的随机表。

### 渲染（组合，覆盖在画面上）

- 蛇格 → 绿色 `24'h20e060`；食物格 → 红色 `24'hff3030`。
- 游戏区背景 → 压暗（`{1'b0,rgb[23:17],...}`，即 `>>1`，工程 `status_osd.v` 的 `dark` 就这么写）。
- 边框 2px → 白色；`game_over` 时画面中央用 `osd_char_rom` 拼 "GAME OVER"。
- 除游戏区外 → 原样 `rgb`。

### 流水对齐（必须）

- 模块**固定 1 拍输出**：`out_rgb <= draw_de ? composed : 0`、`out_vs <= vs`、`out_de <= de`（照
  `caption_overlay.v` 最后那个 always 块的写法）。

---

## 3. PS/2 方向键接入（改 ps2_controls.v + top.v）

1. `ps2_controls.v` 里把 4 个方向键的"按住"状态**暴露成输出**：
   `output reg held_up, held_down, held_left, held_right;`（从现有 `held[h]` 位里对应取，
   扩展码映射见第 1 节第 3 条，`8'h75`=上 / `8'h72`=下 / `8'h6b`=左 / `8'h74`=右）。
2. `top.v` 里把这 4 个 `held_*` 译成 `dir_req[1:0]`（优先级：上/下/左/右），
   再送一个**开关键**（如 `Esc` 或某个空闲键）驱动 `game_enable`。
3. `tick` 由 `top.v` 里已有的**帧计数器/换图节拍逻辑**派生：每 5~8 帧给一个脉冲，
   让蛇以可玩速度移动。

---

## 4. 顶层接线（改 src/top.v）

在 `status_osd`（758-770 行）**之后**、HDMI 输出**之前**插入：

```verilog
snake_game game(.clk(video_clk),.rst(rst_video),.vs(osd_vs),.de(osd_de),
    .x(/* status_osd 输出的 pixel_x 或重建的 x */),.y(/* 同理 */),
    .rgb(osd_rgb),.game_enable(game_on),.dir_req(dir_req),.tick(game_tick),
    .out_vs(hdmi_vs),.out_de(hdmi_de),.out_rgb(hdmi_rgb),
    .score(game_score),.game_over(game_over));
```

> 注意：`status_osd` 已经输出 `pixel_x/pixel_y`（物理坐标），可复用；若插点处没有 x/y，
> 像 `caption_overlay` 那样内部用 `viewport_coordinates` 重建（见
> [src/modules/video/video_coordinates.v](src/modules/video/video_coordinates.v)）。

---

## 5. 验证（必须全绿）

1. 新增 `sim/tb_snake_game.v`：
   - 非游戏区逐像素等于输入；游戏区内蛇格/食物格/背景颜色正确。
   - 喂方向序列：直行、掉头被禁止、吃到食物 `len`/`score` 增、撞墙/撞自己 `game_over` 置位。
   - 断言 `vs/de` 与像素同拍。
2. `python scripts/static_check.py` **ALL PASS**；新源文件登记进
   `video_improve.al`（根目录与 `src/td_project/` **两份**）和 `scripts/design_files.txt`。
3. ModelSim 回归：`scripts/run_tests.ps1` 的 `$files` 与 foreach 列表加 `tb_snake_game`，**PASS**。
4. 核对 [reports/physical_area.txt](reports/physical_area.txt)：**BRAM 总数不得上涨**（棋盘/身体队列必须落在 LUT）。

---

## 6. 资源预期（验收线）

- LUT：棋盘/身体队列（LUT RAM）~300 + 游戏逻辑 ~200 + LFSR ~10 + 渲染 ~100 ≈ **600 LUT**（现余 ~3900，够）。
- BRAM：**新增 0**（关键成功标准：所有状态落在 LUT，不落 BRAM）。
