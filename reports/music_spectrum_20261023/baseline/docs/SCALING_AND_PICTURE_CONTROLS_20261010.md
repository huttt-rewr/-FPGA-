# 不同尺寸图片缩放、亮度与对比度：操作和实现

本版在FPGA内读取BMP原始宽高并缩放，不要求电脑先把所有图片做成640×480。显示器仍接 **HDMI_B**，10月11日源码按EDID选择640×480或800×600，图片与OSD同时适配，见 [屏幕适配手册](SCREEN_ADAPTATION_20261010.md)。旧10月10日缩放bit固定640×480；最新候选见 [构建状态](BUILD_STATUS.md)。控制全部使用板载SW和按键，没有串口操作。

## 一、支持的图片和实际效果

支持宽1～1920、高1～1080的正高度24位无压缩Windows BMP（BI_RGB，planes=1，DIB为40/108/124）。像素偏移54～4096且不得落入完整头部；声明长度、实际长度都应为 `像素偏移 + 行步长 × 高度`。行步长是 `(宽×3+3)&~3`，即每行向4字节对齐。

不是任意文件格式解码：JPG、PNG等先用Python转换为BMP，负高度BMP、32位BMP、压缩BMP、JPEG/PNG原文件不由FPGA直接读取。不同尺寸BMP可以混放在同一原始镜像中，最多4张。仍不解析FAT目录/簇链；不能把IMG作为文件复制到卡内代替原始镜像写卡。

缩放保持纵横比例并居中补黑边，不把竖图强行拉宽，也不切掉画面。计算目标内容区：宽图按输出宽度适配，高图按输出高度适配，另一边取整；奇数黑边可能相差1像素。

下表是640×480输出时的例子；800×600时，1280×720对应800×450，480×800对应360×600。

| 输入分辨率 | 屏幕上的内容区 | 用途 |
|---|---|---|
| 320×240 | 640×480 | 测试放大 |
| 321×241 | 639×480 | 测试非整数比例和BMP行填充 |
| 640×480 | 640×480 | 原尺寸显示，内容不变 |
| 800×600 | 640×480 | 测试缩小 |
| 1280×720 | 640×360 | 上下各约60像素黑边 |
| 480×800 | 288×480 | 左右各176像素黑边 |
| 1920×1080 | 640×360 | 测试当前支持上限 |

## 二、板上的按钮怎么调参数

四路SW继续负责字幕、滚动、转场，功能见 [SW手册](SW_CONTROLS_20261009.md)。新增使用官方按键例程 `J:/DEMO/2_key_led/AA.adc` 中已经列出的B1输入。

| 操作项 | B2对应按键（key1） | C1对应按键（key2） | B1对应按键（key3） |
|---|---|---|---|
| PLAY：正常播放 | 下一张 | 自动播放开/关 | 进入亮度调节 |
| BRIG：亮度调节 | 亮度减8 | 亮度加8 | 进入对比度调节 |
| CONT：对比度调节 | 对比度减0.25 | 对比度加0.25 | 回到正常播放 |

普通模式短按B1并松开选择操作项。2026-10-14新增长按约1.1秒开关菜单，菜单内KEY1上、KEY2下、KEY3短按确认，详见[KEY/SW教程](KEY_SW_OPERATION.md)。每次保持按下超过约20ms再松开；KEY1/2不连发。上电或复位时一直按住的键要先释放再按。实物丝印未必叫key1/2/3，以B2/C1/B1的三个板载用户按键为准，A2是整机复位。

亮度范围 **−64～+64**，默认0；对比度范围 **0.50～2.00**，默认1.00，到边界停止，不回绕。整机复位会恢复默认参数、回PLAY，并重新扫描图片。参数没有存入Flash，断电不保存。

调参时key1/key2不会同时触发翻页/自动播放，但已经开启的自动播放会继续运行。要在同一张照片上观察调参，先在PLAY状态按C1停掉自动播放。三路按键不提供组合键功能，逐个操作。

## 三、屏幕上的OSD怎么看

左上第一行示例：`SRC:1280X0720 ->640X480 FIT BILINEAR`。

- `SRC`显示已经完成换帧确认的图片原始尺寸，不是文件大小；首图确认前可显示0000×0000。
- 箭头右侧`640X480`或`800X600`是实际HDMI输出尺寸；输入1920×1080不会把HDMI输出变成1080p。
- `FIT`表示保持比例适配；`BILINEAR`表示双线性插值。
- 第三行如 `BRI:-16 CON:1.25 MODE:BRIG`：亮度−16、对比度1.25，当前两个操作键调整亮度。
- 第四行根据操作项提示 `K1:NEXT K2:AUTO` 或 `K1:MINUS K2:PLUS`，K3始终用于换操作项。

调节值通过跨时钟握手送到视频域，在一帧开始时锁存；照片处理和参数OSD使用同一份设置。因此按下后通常在下一帧看到变化。设置CDC和帧边界会带来少量延迟，不会在按下瞬间让所有像素立即变化。

亮度、对比度只处理图片层（包括其黑边），字幕和OSD后叠加，所以把照片调暗后菜单仍能看清。提高亮度时黑边也会变成灰色，这是当前处理顺序的预期行为。音频仍静音，当前没有新增音量调节。

## 四、已经准备好的测试文件

[测试目录](../assets/multires_20261010/README.md) 包含七张不同分辨率BMP、源测试图、文件哈希清单，以及一份四图混合镜像。测试图有TOP LEFT/BOTTOM RIGHT标记、边框、圆形和灰阶，便于检查方向、裁剪、比例、亮度与对比度。

混合镜像 `assets/multires_20261010/four_sizes.img` 包含320×240、800×600、1280×720、480×800四张图片，约64MiB。旁边JSON记录各图起始扇区、长度和SHA-256。工具已经校验镜像内容，但**没有写入你的存储卡**。

### 自己生成多个尺寸

主入口 [convert_bmp_variants.py](../scripts/convert_bmp_variants.py) 沿用官方转换脚本的Pillow RGB/LANCZOS/BMP方法，复用工程中带校验的 `prepare_media.py`，修复官方批量输出名写死640×480的问题，并处理EXIF方向、透明背景和拒绝覆盖。

```powershell
cd E:/fpga
python scripts/convert_bmp_variants.py media/my_variants --source "D:/照片/photo.jpg"
```

这会生成七种默认尺寸。安装Python依赖：`python -m pip install pillow`。若目录已经存在，换一个新目录名；不会覆盖原文件。

```powershell
python scripts/convert_bmp_variants.py media/custom --source "D:/照片/photo.jpg" --sizes 320x240 800x600 1280x720 --fit contain
python scripts/prepare_media.py convert "D:/照片/photo.jpg" media/portrait.bmp --width 480 --height 800 --fit crop
python scripts/prepare_media.py check media/portrait.bmp
```

`--fit stretch`将原照片拉到指定BMP尺寸，`contain`在电脑端保比例补边，`crop`保比例裁切；FPGA读取这些BMP后再按BMP实际宽高保比例适配当前输出视口。为了保留照片内容，日常转换推荐contain；演示分辨率时也可选择本来就具有目标比例的照片。批量脚本默认stretch用于展示目标尺寸，它不会改变FPGA的保比例行为。

按用户要求，还提供了七个固定尺寸快捷脚本，例如：

```powershell
python assets/multires_20261010/convert_320x240.py "D:/照片/photo.jpg" media/photo_small.bmp
python assets/multires_20261010/convert_1280x720.py "D:/照片/photo.jpg" media/photo_wide.bmp
```

快捷脚本依赖本工程 `scripts/prepare_media.py`，不要只复制一个快捷脚本到其他电脑而遗漏工程脚本。完整操作和各文件名见测试目录README。

混合尺寸打包、核验仍用同一工具：

```powershell
python scripts/prepare_media.py pack media/mixed.img media/photo_small.bmp media/photo_wide.bmp
python scripts/prepare_media.py verify media/mixed.img
```

写卡会覆盖卡上数据，按 [接线制卡教程](CONNECTION_AND_USAGE.md) 核对目标设备、备份和读回校验；本次没有自动写卡。

## 五、从基础理解实现

最近邻缩放直接选一个源像素，放大时容易出现大色块和锯齿。双线性插值选目标位置附近的四个像素：先分别按横向距离混合两行，再按纵向距离混合两行结果。本实现坐标步长保留16位小数，混合权重用8位小数，每次混合做四舍五入；目标端点显式对应源图端点，避免漏掉最右/最后一行。

插值仍在RGB码值空间进行；10月14日的可选伽马是缩放后图片层提亮，不是线性光空间插值。双线性改善一般放大和非整数缩放，但大比例缩小仍可能出现细纹混叠；它不是面积采样、多级滤波或Lanczos。电脑转换使用Lanczos不代表FPGA里也实现了Lanczos，两者发生在不同阶段。

不保存1920×1080整帧到内部BRAM：加载器使用一份512字节扇区缓存和两条最多1920像素的源行缓存。按目标行需要读入源行、跳过不需要的行、复用放大时重复使用的行。BMP逐行按4字节填充，加载器按真实行步长寻址，不会把填充字节当像素。

输入BMP正高度意味着文件从底行开始。加载器按底到顶产生完整640×480结果，现有SDRAM写入器继续做纵向地址翻转，最终显示方向正确。不同图片仍使用固定的两块640×480 SDRAM缓冲，不把原图尺寸误用为显示缓存尺寸。

```text
BMP头扫描/尺寸校验
    → 按需读取SD扇区 → 扇区缓存 → 两条源行缓存
    → 保比例坐标映射 → 双线性插值/黑边
    → 带背压的写FIFO → SDRAM备用帧 → 完成后提交转场
    → 显示帧像素 → 亮度/对比度 → 转场 → 字幕 → 参数OSD → HDMI_B
```

写FIFO接近满时，缩放器保持像素和valid并等待ready，防止小图放大输出太快导致丢像素。只有全部307200个像素送完、且SDRAM整帧实际写完，才提交新帧。短扇区、中途复位、加载异常不会冒充成功。可变尺寸加载超时预算15秒，单扇区无进度预算和转场提交超时仍分别约0.671秒、5秒；实际速度取决于卡和内存争用。

参数公式逐通道为：`输出 = clamp(round((输入−128)×对比度)+128+亮度, 0, 255)`。亮度是整体平移，较高对比度让128以下更暗、128以上更亮；超出0～255会饱和截断，过度调节会丢失暗部/亮部细节。像素和VS/DE/X坐标一起通过两级处理流水线，不单独延迟颜色而错位同步信号。

## 六、源文件和验证边界

| 文件 | 职责 |
|---|---|
| [bmp_read.v](../src/modules/bmp/bmp_read.v) | 扫描与合法头校验；ENABLE_SCALING接通新通路，默认旧模式用于兼容测试 |
| [bmp_scale_loader.v](../src/modules/video/bmp_scale_loader.v) | 运行时尺寸、顺序除法、源行/扇区缓存、双线性流水和输出背压 |
| [sd_card_bmp.v](../src/modules/bmp/sd_card_bmp.v) | 图片索引、加载超时、整帧提交及已确认原图宽高 |
| [frame_read_write.v](../src/modules/memory/frame_read_write.v) | 导出写FIFO ready，不改变官方内存IP |
| [picture_controls.v](../src/modules/control/picture_controls.v) | 三键同步/消抖、操作项、亮度与对比度边界 |
| [picture_adjust.v](../src/modules/video/picture_adjust.v) | 有符号增益、亮度、饱和及两级时序对齐 |
| [status_osd.v](../src/modules/osd/status_osd.v) | 原始分辨率、参数数值、操作项和按键提示 |
| [top.v](../src/top.v) | 激活缩放、连接背压，控制快照扩为60位并在帧边界锁存 |

旧 `optional/video_scaler.v` 是编译时固定尺寸最近邻参考，当前实际使用的是新 `bmp_scale_loader.v`。必要官方HDMI、SDRAM、FIFO、PLL文件保留，不以替换加密IP实现这两个扩展。

九种尺寸的测试对每帧307200像素逐一核对独立Python参考；还覆盖像素暂停、行填充、扩展头/像素偏移、加载中断后重试与短扇区错误。亮度/对比度测试穷举256种通道值×17档亮度×7档对比度；OSD检查40列字符；完整视频链测试连续行、转场叠加与合法HDMI背压。

缩放回归依赖 `reports/scaling_20261010/vectors/` 中的输入与参考像素文件；这些是测试数据，清理缓存时应保留。需要重新生成时，安装 `numpy` 和 `pillow`，在工程根目录执行 `python reports/scaling_20261010/make_vectors.py`，再运行回归。

历史固定VGA候选为 [video_improve_scaling.bit](../reports/scaling_20261010/video_improve_scaling.bit)。屏幕自适应版最终时序、回归数量与候选文件以 [构建状态](BUILD_STATUS.md) 为准。仿真不等于加密HDMI核或实物SD卡全系统验证；本次不自动烧录。内部复位removal不能写成HDMI管脚hold，不宣称整体达到+0.5ns。
