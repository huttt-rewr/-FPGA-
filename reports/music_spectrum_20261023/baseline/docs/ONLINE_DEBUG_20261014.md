# 板载诊断与TD在线逻辑分析仪观测清单

本轮控制只能使用KEY/SW；不需要UART、红外或额外输出管脚。先长按KEY3打开菜单，选择DIAG确认ON，再选DIAG PAGE逐页确认。六位数码管展示慢速快照，不能等价替代ILA的高速波形。TD的具体DEBUG_CORE/ChipWatcher插入方式要按本机TD手册和匹配器件支持确认，本文没有伪造已安装的调试IP。

## 四页十六进制编码

将六个字符理解为24位数`word`；bit23..20是页号，低位位置如下。

| 页 | 数据位 | 含义 |
|---|---|---|
| 0 | 19..12 | 帧计数，8位循环，VS下降沿加1 |
| 0 | 11..4 | 当前帧行计数低8位；HS下降沿加1，VS时清零 |
| 0 | 3..0 | 原始VS、HS、DE、转场busy；只是采样瞬间电平 |
| 1 | 19 | SDRAM初始化完成 |
| 1 | 18 | 刷新/初始化占用 |
| 1 | 17..9 | 显示读FIFO写侧占用（内存域） |
| 1 | 8..0 | 图片写FIFO读侧占用（内存域） |
| 2 | 18..11 | 标志：可见、坏帧、读欠载粘性、视频溢出、VS、HS、DE、转场busy |
| 2 | 10 | 显示读FIFO empty（像素域） |
| 2 | 9..1 | 显示读FIFO读侧占用（像素域） |
| 2 | 0 | 当前帧无效 |
| 3 | 19..12 | 视频看门狗重启次数，最大255 |
| 3 | 11..8 | SD初始化done、初始化error、传输error、播放器status_error |
| 3 | 7..4 | 原有SD状态码 |
| 3 | 3..0 | 保留为0 |

示例：页3的`301850`表示重启计数01、SD标志8、状态码5、保留0，不能把所有字符当十进制读。水位用`(word>>9)&0x1FF`等位提取，不是三个十进制数字。FIFO计数是跨域延迟后的近似占用；`empty/full`专用标志优先于用水位推导边界。本轮页中只公开活动相关的empty与占用，full可用下面内部抓取。

## 高速抓取信号及期望

| 所属时钟 | 信号路径/组 | 正常期望与故障判别 |
|---|---|---|
| video_clk | `hs_0/vs_0/de_0` | VGA每800拍一行、525行一帧；SVGA每1056拍一行、628行一帧；有效区每行640/800拍，共480/600行 |
| video_clk | `video_read_en`, `frame_read_write_m0.read_fifo_empty`, `read_fifo_rdusedw`, `memory_frame_invalid` | 首图提交后有效像素需要连续数据；empty被取读会置坏帧/粘性错误，下一帧重新对齐 |
| ext_mem_clk | `Sdr_init_done/Sdr_init_ref_vld/Sdr_busy` | 初始化后done为1；公开刷新计数器1250拍请求一次；实际refresh占用宽度由官方硬核决定，行为模型22拍不是硬件保证 |
| ext_mem_clk | `App_rd_en/App_rd_addr/Sdr_rd_en`, `frame_fifo_read_m0.burst_cnt/returned_count/state` | 每个已接受请求有一个返回；计数相等前不能清FIFO或交给写端；观察刷新暂停与在途尾数据 |
| ext_mem_clk | `App_wr_en/App_wr_addr/App_wr_din`, `frame_read_write_m0.rdusedw/wrusedw` | 有界写突发，不能与读所有权/刷新冲突；显示水位不足384时延后后台写 |
| ext_mem_clk | `frame_read_write_m0.read_fifo_full/write_fifo_empty` | full时不应继续写读FIFO，empty时不应从写FIFO取数据；结合官方FIFO语义核查 |
| sd_card_clk | `sd_card_write_en/pixel_write_ready`, `frame_read_write_m0.write_fifo_full/write_fifo_afull` | 背压后生产端保持/暂停，full时不得丢像素；`memory_overflow`为粘性证据 |
| video_clk | `commit_req/commit_ack/active_buffer/vblank/transition_busy` | 新图完整写完后才提交，地址仅在场消隐切换，未确认时不能覆盖旧显示缓冲 |
| sd_card_clk | `sd_card_bmp_m0.sd_init_done/sd_init_error/sd_transfer_error` | 读卡失败与FIFO故障分别记录；本輪没有更换SD协议或新增音频调度 |
| boot_clk | `supervisor.ready/elapsed/watchdog_resets`, `frame_heartbeat`同步结果 | PLL锁定后10ms释放，mode_ready后帧toggle持续；2秒没有新toggle才软复位 |

每次抓取选一个采样时钟，同域事件一起记录；跨域组合信号不能拿一个时钟无条件解释。用触发前缓存捕获empty且read_en、错误从0到1、刷新中发命令、看门狗超时等事件。高速脉冲可能在10Hz快照里看不到，因此没有出现标志不等于事件从未发生。

音频仍静音、UART/IR仍禁用，本轮不新增相关测试接线。若未来恢复音频，48kHz应是valid单拍事件每约20.833µs一次，不是valid高电平保持20.833µs；当前这个条目仅为未来参考。
