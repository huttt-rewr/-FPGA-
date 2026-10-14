# 不同分辨率测试素材

2026-10-10生成。七个BMP都通过头部、长度、行填充与哈希检查。源图为自绘测试图，不含外部照片版权素材。完整操作见 [缩放与调参手册](../../docs/SCALING_AND_PICTURE_CONTROLS_20261010.md)。

| BMP | 实际分辨率 | 固定尺寸转换快捷脚本 |
|---|---|---|
| [image_320x240.bmp](image_320x240.bmp) | 320×240 | [convert_320x240.py](convert_320x240.py) |
| [image_321x241.bmp](image_321x241.bmp) | 321×241 | [convert_321x241.py](convert_321x241.py) |
| [image_640x480.bmp](image_640x480.bmp) | 640×480 | [convert_640x480.py](convert_640x480.py) |
| [image_800x600.bmp](image_800x600.bmp) | 800×600 | [convert_800x600.py](convert_800x600.py) |
| [image_1280x720.bmp](image_1280x720.bmp) | 1280×720 | [convert_1280x720.py](convert_1280x720.py) |
| [image_480x800.bmp](image_480x800.bmp) | 480×800 | [convert_480x800.py](convert_480x800.py) |
| [image_1920x1080.bmp](image_1920x1080.bmp) | 1920×1080 | [convert_1920x1080.py](convert_1920x1080.py) |

快捷脚本用法（Python需要Pillow；在工程根目录运行）：

```powershell
python assets/multires_20261010/convert_800x600.py "D:/photo.jpg" media/my_800.bmp
```

可追加 `--fit contain`（默认保比例补边）、`--fit crop` 或 `--fit stretch`。脚本调用本工程prepare_media，不是独立于工程的完整拷贝。需要一次生成多尺寸可使用 [批量工具](../../scripts/convert_bmp_variants.py)。

[four_sizes.img](four_sizes.img) 是64MiB原始镜像，依次包含320×240、800×600、1280×720、480×800。其 [扇区/哈希清单](four_sizes.img.json) 已用verify检查；本次没有写入物理卡。镜像要原始写卡，不能复制IMG文件到FAT目录，写卡前核对设备和备份。

[manifest.json](manifest.json) 记录七个BMP哈希和尺寸。[source_chart.png](source_chart.png) 是转换前图案。[contact_sheet.png](contact_sheet.png) 是电脑端缩略预览，不是FPGA实板截图。

321×241专门覆盖行尾填充；480×800覆盖竖图；1920×1080覆盖当前输入上限。图中圆形在部分stretch生成的BMP内会被拉伸，FPGA保持的是BMP本身的比例，不会恢复已经被电脑拉伸的照片。
