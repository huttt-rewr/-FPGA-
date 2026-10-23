# 真·视频播放（raw 帧序列）· 可落地提示词（2026-10-18）

> 用途：把本文件整段交给 GPT/协作者执行。目标：把现有"图片轮播"升级成**连续帧视频播放**，
> 让"多媒体展示系统"名副其实。最诚实的一句话：**本设计里"视频"= 复用现成的 auto-play + 双缓冲 + frame_swap 通路，
> 把帧连续灌进去；它不是新写一路播放器，而是给现有读卡通路加一个"连续帧源"。**
> 时序安全铁律：**禁止碰 FAT32 比较器 / fps_control 比较器 / 缩放器 y_acc 三条负路径**；帧率以实测 SD 带宽封顶，`rate_limited` 已能自限速。

---

## 0. 现状与"视频"的真实含义（先读懂，别重造轮子）

现有链路（[sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v)）已是一条完整的连续帧播放器：

```
SD(FAT32) → bmp_read 解帧 → 缩放 → 写 SDRAM 非显示缓冲 → commit_req → frame_swap 切帧 → 循环
```

- `auto_play_en`（[sd_card_bmp.v:230](src/modules/bmp/sd_card_bmp.v#L230)）开自动播放。
- `fps_control`（[sd_card_bmp.v:263-266](src/modules/bmp/sd_card_bmp.v#L263)）按 `fps_mode`（0..5 = 1/2/5/10/15/**30** fps）发 `rate_tick`。
- 自动播放分支 [sd_card_bmp.v:559](src/modules/bmp/sd_card_bmp.v#L559)：`auto_play_en && auto_tick` → 载入下一帧到非显示缓冲 → 提交切帧。
- `rate_limited`（fps_control 的 `busy` 支路，[fps_control.v:33-35](src/modules/control/fps_control.v#L33)）在管线忙时置 1——**这是现成的"跟不上就限速"信号**。

所以"视频"不是新架构，而是：**(a) 一个连续的帧源（raw 容器），(b) 让 auto-play 锁定在视频模式，(c) 帧率受 SD 带宽约束。**
**本功能是三条里唯一真正会加大 100MHz 域吞吐压力的**，因此 §2 的"禁止碰三条负路径"是硬约束。

---

## 1. 铁律（比另外两条更硬）

- **零损害**：不动 FAT32 的 33 位比较器（`{1'b0,request_rel}>=request_sectors`）、不动 fps_control 的 `elapsed>=last_cycle`、不动缩放器 `y_acc→pixel` 路径。
- 视频新逻辑**只能**以"新源模式"插进现有 `bmp_read`/`sd_card_bmp` 流程，**禁止并行加一路独立的 SD 读/FAT32 查找**（那会新增第二条关键路径）。
- 帧率上限由实测 SD 带宽决定；`rate_limited` 拉起时**必须**接受降帧，不得硬塞。
- 单点改动、独立验证；每一阶段都重跑 STA。

---

## 2. Phase 2a —— 连帧 BMP 轮播（零新逻辑，先验证带宽，必做）

**目标**：先确认现有通路能跑多快，再谈容器。

1. 用脚本在 TF 卡根目录放 N 张**同尺寸、连续编号**的 BMP（如 640×480，帧序列 000.bmp..127.bmp）。
2. 把 `fps_mode` 置 5（30fps）、`auto_play_en` 常开，观察 `rate_limited` 与七段码状态：
   - 若 `rate_limited` 持续为 0 → 30fps 可持续，直接进入 2b。
   - 若 `rate_limited` 频繁为 1 → 测出实际可持续帧率（降低 fps_mode 直到不再 limited），**该值就是 2b 的封顶帧率**。
3. 此阶段**不改 RTL**，只跑测量；把"可持续帧率"如实记录进报告，作为 2b 的输入。

---

## 3. Phase 2b —— raw 帧容器（更优存储，中等）

### 3.1 格式（建议 .rvf：Raw Video Frames）

```
[4B magic "RVF1"][2B width][2B height][2B frame_count][2B bytes_per_pixel]
[每帧：width*height*bytes_per_pixel 字节，连续存储，无行间填充]
```

- 为省 SD 带宽与存储，`bytes_per_pixel` 支持 **3（RGB888）** 与 **2（RGB565）** 两种；RGB565 每帧 0.6MB（640×480），
  SD 原生 4-bit 50MHz 理论 ~25MB/s，RGB565 可持续 ~20fps，RGB888 可持续 ~13fps（均为理论，以 2a 实测为准）。
- 帧可先在上位机预缩放成 640×480 或 800×600，**下位机不做缩放**（省掉逐帧缩放开销与负路径）。

### 3.2 集成：把 raw 当"新源模式"插进现有读卡流程

1. 在 [bmp_read.v](src/modules/bmp/bmp_read.v) 增一个 `VIDEO_RAW` 源模式：识别 `RVF1` magic 后跳过 BMP 头解析，
   逐帧把像素喂进**同一** `write_en/write_data` 通道（[sd_card_bmp.v:274-275](src/modules/bmp/sd_card_bmp.v#L274)），
   帧内连续、帧间由 `commit_req` 触发切帧（复用 [sd_card_bmp.v:446-460](src/modules/bmp/sd_card_bmp.v#L446) 的提交逻辑）。
2. 文件仍走 FAT32 定位一次（拿起始簇），之后**簇链顺序读**（已有 FAT 链逻辑），**不改** FAT32 的越界/合法比较器。
3. 在 [sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v) 加 `video_mode`：进入后锁 `auto_play_en=1`、`fps_mode` 取用户设定、
   帧到末尾自动回绕（复用 `next_index_limited` 的回绕语义，[sd_card_bmp.v:304-313](src/modules/bmp/sd_card_bmp.v#L304)）。
4. `rate_limited` 拉高时**丢弃本帧、等待下一 tick**（现有 fps_control 的 `limited` 语义即此），不得堆积请求。

### 3.3 明确的"不碰"清单（违反即回退）

- 不碰 [sd_fat32.v](src/modules/sd/sd_fat32.v) 任何比较器（33 位越界、簇合法、`data_clusters`/`max_cluster`）。
- 不碰 [fps_control.v](src/modules/control/fps_control.v) 的比较器。
- 不碰 [bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v) 的 `y_acc→pixel`（本功能下位机不缩放，可整体旁路缩放，但旁路要在 bmp_read 层做，不改缩放器内部）。

---

## 4. 验证（全绿才算过）

1. `python scripts/static_check.py` → ALL PASS。
2. 新增 `sim/tb_video_raw.v`：喂一个 RVF1 容器（含多帧），断言
   (a) magic 识别正确；(b) 帧序号递增且到末尾回绕；(c) 每帧提交恰一次、commit/ack 握手不丢帧；
   (d) `rate_limited` 拉高时丢帧且不堆积。
3. `python scripts/run_build.py` → 布线通过；**记录 SWNS/STNS，必须不劣于改前**（重点看 FAT32 那 −0.592 是否因吞吐增大而劣化）。
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 ALL PASS。
5. **上板**：写一张含 RVF1 的卡，实测 (a) 视频能连续播放不花屏；(b) 记录实际帧率与 `rate_limited` 出现频率；(c) 800 音频同时正常。

---

## 5. 验收硬线

**回归 + static_check ALL PASS + SWNS/STNS 不劣化 + 无新增 CRITICAL；
上板视频连续、不花屏不卡死、音频同时正常、实测帧率与限速行为如实记录。**

---

## 6. 诚实兜底

1. **本条无法"保证时序没问题"**——它加大了 100MHz SD/FAT32 域吞吐，可能让 FAT32 那 −0.592 更负。
   唯一安全顺序：**先关掉 fps_control 的 `>=`→`==`、完成 640 自写腾资源、确认时序收敛，再做本功能**；否则视频只能低帧率跑。
2. 若 SWNS 劣化到比 −0.592 更负：先把 `fps_mode` 降到实测可持续值，再不行就回退 raw 容器、退回 2a 的连帧 BMP。
3. 若要真·编解码（MJPEG/JPEG 解码），超出本文件范围，是另一个量级的任务，不建议竞赛期硬上；raw 容器已足够"动起来"。
4. 帧存储上限受 TF 卡容量与 SDRAM 双缓冲约束（SDRAM 8MB，RGB565 一帧 0.6MB，双缓冲 ~1.2MB，余量充足；帧数取决于卡容量）。
