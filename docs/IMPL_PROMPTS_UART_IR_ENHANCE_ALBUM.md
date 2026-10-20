# 实施提示词：UART 上位机 + 红外遥控 + 画质增强 + 电子相册时钟

> 本文档是四份可直接执行的实施提示词，面向协作者 GPT / 编码 agent。目标是**新增能力、零损害、时序无影响**。改完逐条跑验证（见「总约束 4」）。

## 0. 前提与环境

- 芯片：Anlogic **EG4S20BG256**（19600 LUT / 19600 reg / 64×9K BRAM / 29 DSP）。
- 工程：`E:\fpga`，顶层 `src/top.v`。
- 两个已有时钟域：
  - 控制侧 `sd_card_clk` = **100 MHz**（复位 `rst_controls`）；
  - 显示侧 `video_clk` = **25 MHz（640×480）/ 40 MHz（800×600）**（复位 `rst_video`）。
- 现有控制入口（`src/top.v`）：
  - 键盘：`ps2_keyboard` + `ps2_controls`（输出 `kb_next/kb_prev/kb_toggle/…/kb_res/kb_fps`）。
  - 拨码：`switch_controls`（输出 `captions_enable/scroll_enable/transition_mode`）。
  - 按键板：`picture_controls`（输出 `brightness/contrast/volume/mute/…`）。
  - 命令合并点：`assign cmd_next=board_next||kb_next; cmd_prev=kb_prev; cmd_toggle=board_toggle||kb_toggle;`（约 [top.v:647-649](src/top.v#L647-L649)）。
- 显示流水线（`video_clk` 域，全部寄存器输出、逐级对齐）：
  `source_rgb → picture_adjust → picture_gamma → transition_pixels → pixel_effects → glass_osd → audio_visualizer → caption_overlay → status_osd → snake_game → HDMI`。
- 现成但**未接线**的模块：`src/modules/control/uart_rx.v`、`uart_tx.v`、`uart_tx_queue.v`、`ir_nec_rx.v`、`player_control.v`。
- 现成跨域原语：`src/modules/common/cdc_snapshot.v`（捆绑数据握手，跨域唯一合法手段）。

---

## 总约束（四条红线，全部提示词共用）

1. **时钟域纪律**：新增逻辑只许落在 `sd_card_clk`（100MHz）或 `video_clk`（25/40MHz）两个已有域内。跨域**只许用 `cdc_snapshot`**（捆绑握手），禁止裸 2 级触发器同步多 bit 总线。
2. **流水线纪律**：显示链里新增模块必须**全寄存器输出**（`out_vs/out_de/out_x/out_y/out_rgb` 全为 `reg`），并把 `vs/de/x/y` 一起延迟，保证下游对齐不变。
3. **零损害**：所有新功能**默认关闭**；只允许「新增接线 + OR 合并 + 新增端口」，不改动现有画面/音频/EDID/双分辨率，不删任何现有信号语义。
4. **验证门槛**：每个提示词完成后依次执行，必须全绿：
   ```bash
   python scripts/static_check.py
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
   python scripts/run_build.py
   ```
   其中 `run_build.py` 的 STA 报告**不得出现新增时序违例**。

---

## 提示词一：UART 上位机 + 北京时间对时（Phase 1 零冲突）

**目标**：PC 通过串口（115200 8N1）控制 FPGA：`n` 下一张、`p` 上一张、`b` 暂停、`T123456` 设置北京时间；FPGA 每条命令回显一个 `K`（未知命令回 `?`）。北京时间由 PC 每秒喂一次。

### 1.1 新增 `src/modules/control/time_cmd.v`（完整源码，直接用）

```verilog
// 解析 "T"+6位ASCII数字(HHMMSS)，输出 BCD 时间 + 自增序号。运行于 sd_card_clk 域。
module time_cmd(
    input clk, input rst,
    input [7:0] uart_data, input uart_valid,
    output reg [23:0] time_bcd,
    output reg [7:0]  time_seq
);
    localparam IDLE=3'd0, D1=3'd1, D2=3'd2, D3=3'd3, D4=3'd4, D5=3'd5, D6=3'd6;
    reg [2:0] state;
    reg [23:0] acc;
    wire is_digit = (uart_data>=8'h30) && (uart_data<=8'h39);
    wire [3:0] nib  = uart_data[3:0];
    wire [23:0] nxt = {acc[19:0], nib};
    always @(posedge clk or posedge rst) begin
        if(rst) begin state<=IDLE; acc<=0; time_bcd<=0; time_seq<=0; end
        else if(uart_valid) begin
            case(state)
                IDLE: if(uart_data==8'h54) begin acc<=0; state<=D1; end
                D1,D2,D3,D4,D5: if(is_digit) begin acc<=nxt; state<=state+1'b1; end
                                 else state<=IDLE;
                D6: if(is_digit) begin time_bcd<=nxt; time_seq<=time_seq+1'b1; state<=IDLE; end
                    else state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
```

> 位序校验：第一个数字是**时十位**（落在 `time_bcd[23:20]`），第六个是**秒个位**（`[3:0]`），与 `caption_overlay` 的 `displayed_time` 一致。

### 1.2 改 `src/modules/osd/caption_overlay.v`

- 端口表（第 4-8 行）在 `output` 前加两个输入：
  ```verilog
  input [7:0] time_seq,input [23:0] time_bcd,
  ```
- 寄存器声明区（第 22-25 行附近）加：`reg [7:0] last_seq;`
- 复位块（第 27-30 行）加：`last_seq<=0;`
- 计数块（第 31-56 行）把 `if(second_count==...)` 改为 `else if`，并在其**前**插入装载（装载优先级高于计数）：
  ```verilog
  if(time_seq!=last_seq) begin
      last_seq<=time_seq;
      second_count<=0;
      sec_units<=time_bcd[3:0];  sec_tens<=time_bcd[7:4];
      min_units<=time_bcd[11:8]; min_tens<=time_bcd[15:12];
      hour_units<=time_bcd[19:16]; hour_tens<=time_bcd[23:20];
  end else if(second_count==((ADAPTIVE && mode_800)?40000000:CLK_HZ)-1) begin
      // ……原计数代码保持不变……
  end else second_count<=second_count+1'b1;
  ```

### 1.3 改 `src/top.v`

**（a）删两行占位**（现 [645-646 行](src/top.v#L645-L646)）：删 `assign uart_tx_pin=1'b1;` 和 `assign tx_overflow=1'b0;`。

**（b）命令 OR 合并**（现 [647-649 行](src/top.v#L647-L649)）改为：
```verilog
assign cmd_next=board_next || kb_next || pc_next;
assign cmd_prev=kb_prev || pc_prev;
assign cmd_toggle=board_toggle || kb_toggle || pc_toggle;
```

**（c）在 `ps2_controls` 实例之后**（现 662 行后）加实例化和新 wire：
```verilog
wire [7:0] uart_byte; wire uart_valid;
wire pc_next,pc_prev,pc_toggle,pc_reply_valid; wire [7:0] pc_reply;
wire [7:0] time_seq; wire [23:0] time_bcd;
wire auto_enh_en;   // 提示词三用，此处先声明

uart_rx #(.CLK_FREQ(100_000_000),.BAUD(115200)) uart(
    .clk(sd_card_clk),.rst(rst_controls),.rx(uart_rx_pin),
    .o_data(uart_byte),.o_valid(uart_valid));
time_cmd timecmd(.clk(sd_card_clk),.rst(rst_controls),
    .uart_data(uart_byte),.uart_valid(uart_valid),
    .time_bcd(time_bcd),.time_seq(time_seq));
player_control pc(.clk(sd_card_clk),.rst(rst_controls),
    .uart_data(uart_byte),.uart_valid(uart_valid),
    .ir_command(8'd0),.ir_valid(1'b0),       // 提示词二做完再换成 ir_cmd/ir_valid
    .next_pulse(pc_next),.prev_pulse(pc_prev),.toggle_pulse(pc_toggle),
    .reply_valid(pc_reply_valid),.reply(pc_reply),
    .volume(),.mute(),.osd_enable(),.brightness(),.test_pattern(),
    .transition_mode(),.captions_enable(),.scroll_enable(),.slogan_select(),
    .auto_enh_en(auto_enh_en));              // 提示词三给 player_control 加此端口
uart_tx_queue txq(.clk(sd_card_clk),.rst(rst_controls),
    .i_data(pc_reply),.i_send(pc_reply_valid),
    .o_tx(uart_tx_pin),.o_busy(),.overflow(tx_overflow));
```

> 若只做提示词一：`player_control` 尚未有 `auto_enh_en` 端口，则先去掉上面 `.auto_enh_en(...)` 一行和 `wire auto_enh_en;`，等提示词三再加。

**（d）在其它 `cdc_snapshot` 旁**（现 686-693 行附近）加时间跨域：
```verilog
wire [31:0] time_video;
cdc_snapshot #(.WIDTH(32)) time_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
    .src_data({time_seq,time_bcd}),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(time_video));
```

**（e）`caption_overlay` 实例**（现 729-732 行）补两个端口：
```verilog
.time_seq(time_video[31:24]),.time_bcd(time_video[23:0]),
```

### 1.4 PC 端 Python（`pyserial`）

```python
import serial, time, datetime
ser = serial.Serial('COM3', 115200, timeout=0.5)   # 改成你的串口号
def send(b):
    ser.write(b); return ser.read(1)                # 期待回显 'K'
print("切图回显:", send(b'n'))
while True:
    t = b'T' + datetime.datetime.now().strftime('%H%M%S').encode()
    print("对时回显:", send(t))
    time.sleep(1)
```

### 1.5 完成判据
`static_check.py` ALL PASS → `run_tests.ps1` 全 PASS → `run_build.py` STA 无新增违例；PC 发 `n` 能切图、发 `T123456` 后 OSD 时钟跳到 `12:34:56` 并继续走秒。

---

## 提示词二：IR 红外遥控（两行接线）

在 `src/top.v` 加实例（sd 域）：
```verilog
wire [7:0] ir_cmd; wire ir_valid, ir_repeat;
ir_nec_rx #(.CLK_FREQ(100_000_000)) ir(.clk(sd_card_clk),.rst(rst_controls),
    .ir_in(ir_rx_pin),.o_command(ir_cmd),.o_command_valid(ir_valid),.o_repeat(ir_repeat));
```
并把提示词一 1.3(c) 里 `player_control` 的 `.ir_command(8'd0),.ir_valid(1'b0)` 换成 `.ir_command(ir_cmd),.ir_valid(ir_valid)`。

码表已在 [player_control.v:13-19](src/modules/control/player_control.v#L13-L19)：`0x40`下一张、`0x15`上一张、`0x44`暂停（`0x46/0x16`音量、`0x45`静音、`0x47`OSD 属后续阶段）。**上板实测**：拿手头遥控器逐个键按，键不对就改这 6 行 case。

**完成判据**：遥控器某键能切图/暂停；`static_check`/`run_build` 全绿。

---

## 提示词三：画质增强（自动色阶，插入视频链，零损害）

### 3.1 生成 scale 查找表 `auto_enhance_scale.mem`

```python
# scale[r] = round(255*256/r)，r=1..255；r=0 -> 0
lines = ["0"]
for r in range(1, 256):
    lines.append(str(255*256//r))
open("auto_enhance_scale.mem","w").write("\n".join(lines)+"\n")
```

> 文件位置：放到 TD 综合与 ModelSim 仿真都能找到的工作目录（或写绝对路径）。合成时 `$readmemh` 找不到文件会报错，务必确认路径。

### 3.2 新增 `src/modules/video/auto_enhance.v`（全寄存器流水，1 帧统计滞后）

```verilog
// 自动色阶：每通道 min/max -> 线性拉伸。enable=0 时纯直通（零损害）。
module auto_enhance(
    input clk,input rst,input vs,input de,input [9:0] x,input [9:0] y,
    input [23:0] rgb,input enable,
    output reg out_vs,output reg out_de,output reg [9:0] out_x,output reg [9:0] out_y,
    output reg [23:0] out_rgb);
    reg [15:0] scale_mem [0:255];
    initial $readmemh("auto_enhance_scale.mem", scale_mem);
    // 阶段1：寄存 + 统计本帧 min/max
    reg v1,d1; reg [9:0] x1,y1; reg [23:0] rgb1; reg vs_d;
    reg [7:0] rmin,rmax,gmin,gmax,bmin,bmax;
    wire frame_start = vs_d && !vs;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            v1<=0;d1<=0;x1<=0;y1<=0;rgb1<=0;vs_d<=1;
            rmin<=255;rmax<=0;gmin<=255;gmax<=0;bmin<=255;bmax<=0;
        end else begin
            v1<=vs; d1<=de; x1<=x; y1<=y; rgb1<=rgb; vs_d<=vs;
            if(frame_start) begin
                rmin<=255;rmax<=0;gmin<=255;gmax<=0;bmin<=255;bmax<=0;
            end else if(de) begin
                if(rgb[23:16]<rmin) rmin<=rgb[23:16];
                if(rgb[23:16]>rmax) rmax<=rgb[23:16];
                if(rgb[15:8] <gmin) gmin<=rgb[15:8];
                if(rgb[15:8] >gmax) gmax<=rgb[15:8];
                if(rgb[7:0]  <bmin) bmin<=rgb[7:0];
                if(rgb[7:0]  >bmax) bmax<=rgb[7:0];
            end
        end
    end
    // 阶段2：frame_start 冻结 scale/min（同步读 BRAM，打一拍）
    reg [15:0] sR,sG,sB; reg [7:0] oR,oG,oB;
    reg v2,d2; reg [9:0] x2,y2; reg [23:0] rgb2; reg en2;
    always @(posedge clk or posedge rst) begin
        if(rst) begin sR<=0;sG<=0;sB<=0;oR<=0;oG<=0;oB<=0;v2<=0;d2<=0;x2<=0;y2<=0;rgb2<=0;en2<=0;end
        else begin
            v2<=v1; d2<=d1; x2<=x1; y2<=y1; rgb2<=rgb1; en2<=enable;
            if(frame_start) begin
                sR<=scale_mem[rmax-rmin]; sG<=scale_mem[gmax-gmin]; sB<=scale_mem[bmax-bmin];
                oR<=rmin; oG<=gmin; oB<=bmin;
            end
        end
    end
    // 阶段3：映射 (C-min)*scale>>8，防下溢、防 range=0
    wire [7:0] dR=(rgb2[23:16]>=oR)?(rgb2[23:16]-oR):8'd0;
    wire [7:0] dG=(rgb2[15:8] >=oG)?(rgb2[15:8] -oG):8'd0;
    wire [7:0] dB=(rgb2[7:0]  >=oB)?(rgb2[7:0]  -oB):8'd0;
    wire [23:0] pR=dR*sR, pG=dG*sG, pB=dB*sB;
    wire [7:0] rOut=(sR==0)?rgb2[23:16]:((pR[23:8]>255)?8'd255:pR[23:8]);
    wire [7:0] gOut=(sG==0)?rgb2[15:8] :((pG[23:8]>255)?8'd255:pG[23:8]);
    wire [7:0] bOut=(sB==0)?rgb2[7:0]  :((pB[23:8]>255)?8'd255:pB[23:8]);
    always @(posedge clk or posedge rst) begin
        if(rst) begin out_vs<=0;out_de<=0;out_x<=0;out_y<=0;out_rgb<=0;end
        else begin
            out_vs<=v2; out_de<=d2; out_x<=x2; out_y<=y2;
            out_rgb<=d2 ? (en2 ? {rOut,gOut,bOut} : rgb2) : 24'd0;
        end
    end
endmodule
```

> 若综合后 `scale_mem` 落在分布式 LUT 而非 BRAM，属正常（256×16 ≈ 4Kbit，在 LUT/BRAM 边界），资源上都够，不必强求 BRAM。

### 3.3 改 `src/top.v` 插入到流水线

在 [704-707 行](src/top.v#L704-L707) 的 `picture_gamma` 和 `transition_pixels` 之间插入：
```verilog
wire ae_vs,ae_de; wire [9:0] ae_x,ae_y; wire [23:0] ae_rgb;
auto_enhance autoe(.clk(video_clk),.rst(rst_video),.vs(gamma_vs),.de(gamma_de),
    .x(gamma_x),.y(gamma_y),.rgb(gamma_rgb),.enable(auto_enh_video),
    .out_vs(ae_vs),.out_de(ae_de),.out_x(ae_x),.out_y(ae_y),.out_rgb(ae_rgb));
```
并把 `transition_pixels effects(...)` 的输入从 `gamma_*` 改为 `.vs(ae_vs),.de(ae_de),.x(ae_x),.y(ae_y),.rgb(ae_rgb)`。

### 3.4 开关（独立 cdc，不碰 70 位 status）

- 改 `src/modules/control/player_control.v`：端口表加 `output reg auto_enh_en`；复位块加 `auto_enh_en<=0;`（归入**持久状态组**，与 `captions_enable/scroll_enable` 并列，不要放进每拍清 0 的脉冲组）；case 加：
  ```verilog
  "a":auto_enh_en<=~auto_enh_en;
  ```
- `src/top.v` 的 `pc` 实例补 `.auto_enh_en(auto_enh_en)`（已在 1.3(c) 预留 `wire auto_enh_en`）。
- 加 1 位独立快照（照抄 `game_control_cdc` 写法，**不塞进 70 位 status_source**）：
  ```verilog
  wire auto_enh_video;
  cdc_snapshot #(.WIDTH(1)) autoenh_cdc(.src_clk(sd_card_clk),.src_rst(rst_controls),
      .src_data(auto_enh_en),.dst_clk(video_clk),.dst_rst(rst_video),.dst_data(auto_enh_video));
  ```

### 3.5 完成判据
默认（`enable=0`）画面与原来**逐像素一致**；发 UART `a` 后暗照片变亮、亮照片压暗；`static_check`/`run_build` STA 无新增违例。**资源**：约 300-500 LUT + 1 BRAM + 3 DSP。

---

## 提示词四：电子相册时钟（依赖 ① 的时钟）

### 4.1 新增 `src/modules/control/slideshow_timer.v`

```verilog
// 自动轮播定时器：enable=1 时每 PERIOD 拍发一次单拍 next_pulse。sd_card_clk 域。
module slideshow_timer #(parameter PERIOD=100_000_000)(  // 默认 1s@100MHz
    input clk,input rst,input enable,output reg next_pulse);
    reg [31:0] cnt;
    always @(posedge clk or posedge rst) begin
        if(rst) begin cnt<=0; next_pulse<=0; end
        else begin
            next_pulse<=0;
            if(enable) begin
                if(cnt==PERIOD-1) begin cnt<=0; next_pulse<=1; end
                else cnt<=cnt+1'b1;
            end else cnt<=0;
        end
    end
endmodule
```

`src/top.v` 里：
```verilog
wire slide_next;
slideshow_timer #(.PERIOD(100_000_000*5)) slidet(.clk(sd_card_clk),.rst(rst_controls),
    .enable(slide_enable),.next_pulse(slide_next));
assign cmd_next=board_next || kb_next || pc_next || slide_next;   // 再加一个 OR 项
```
`slide_enable` 先接 `1'b0`（零损害），启用时接现有 `status_auto`（空格切换的 PLAY ON/OFF）或一个拨码开关。

### 4.2 大字时钟
直接复用 ① 的对时结果（`caption_overlay` 已是真北京时间）。加大字号/换位置只改 `in_clock` 坐标窗（现为 `xx>=448 && xx<624 && yy>=16 && yy<48`）及 `clock_char` 放大逻辑。

### 4.3 中文字幕 + 点阵字库

**（a）Python 生成字库 `zh_font.mem`**（每字 16×16 点阵 = 32 字节）：
```python
from PIL import Image, ImageDraw, ImageFont
font = ImageFont.truetype("C:/Windows/Fonts/simhei.ttf", 16)
chars = "欢迎光临电子相册参赛作品多媒体展示"   # 自选，20 字 ≈ 640B ≈ 1 块 BRAM
with open("zh_font.mem","w") as f:
    for ch in chars:
        img = Image.new("1",(16,16),0); d = ImageDraw.Draw(img)
        d.text((0,0), ch, font=font, fill=1)
        for y in range(16):
            row = 0
            for x in range(16):
                row = (row<<1) | (1 if img.getpixel((x,y)) else 0)
            f.write(f"{row:04x}\n")
```

**（b）新增 `src/modules/osd/zh_font_rom.v`**（BRAM，读打一拍）：
```verilog
module zh_font_rom(input clk,input [4:0] char_idx,input [3:0] row,
    output reg [15:0] bits);
    reg [15:0] mem [0:511];   // 最多 32 字 * 16 行
    initial $readmemh("zh_font.mem", mem);
    always @(posedge clk) bits <= mem[{char_idx,row}];
endmodule
```

**（c）新增渲染模块 `zh_overlay.v`**：接口与 `caption_overlay` 相同（`vs/de/x/y/rgb -> out_*`，全寄存器），在指定窗口按 `char_idx` 查 ROM、按 `row` 取点阵画字。插在 `caption_overlay` 之后、`status_osd` 之前（或与 caption 并列叠加）。

### 4.4 完成判据
相册定时切图（默认关，开启后每 5 秒自动下一张）；时钟显示真北京时间；中文字幕显示正确；`static_check`/`run_build` 全绿。**资源**：约 150-300 LUT + 1 BRAM（字库）。

---

## 落地顺序与验收

1. **顺序**：① → ② → ③ → ④（①② 接线收尾，先做；③ 独立算法随时插；④ 依赖 ① 时钟，最后）。
2. **每个提示词完成后**：跑 `static_check.py` → `run_tests.ps1` → `run_build.py`，把 `run_build.py` 的 STA 摘要交给把关人确认「无新增违例、无功能损伤」。
3. **重点实测项**：
   - ①：PC 发 `n` 切图、发 `T123456` 对时、收到 `K` 回显；
   - ②：遥控器按键切图；
   - ③：`enable=0` 时画面逐像素不变，`a` 开启后动态范围拉伸；
   - ④：定时切图 + 真北京时间 + 中文字幕。

**资源总账（四件全做）**：约 800-1500 LUT、1-2 BRAM、最多 3 DSP —— 当前剩余约 3700 LUT / 23 BRAM / 5 DSP，容量充足；真正的风险是 81% LUT 利用率下的布线，`run_build.py` 若遇路由拥塞需换策略跑。
