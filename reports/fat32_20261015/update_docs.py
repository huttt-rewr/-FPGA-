from pathlib import Path
import re
root=Path(__file__).resolve().parents[2]
intro='2026-10-15 FAT32 v1：正式顶层读取普通FAT32卡根目录，直接复制最多4个BMP和第一个WAV，支持碎片簇链。无需裸镜像烧卡；KEY/SW与媒体格式要求保持。操作见[FAT32拷贝文件教程](FAT32_USAGE_20261015.md)，实际回归/STA见[本轮结果](../reports/fat32_20261015/RESULT.md)。旧裸扇区版的制卡方法与bit不适用于此版本。\n\n'
for name in ('docs/USER_GUIDE.md','docs/CONNECTION_AND_USAGE.md','docs/KEY_SW_OPERATION.md','docs/WAV_AUDIO_20261014.md','docs/SOURCE_MAP.md'):
    p=root/name
    t=p.read_text(encoding='utf-8-sig')
    if '2026-10-15 FAT32 v1' not in t:
        first=t.index('\n')+1
        t=t[:first]+'\n'+intro+t[first:]
    t=t.replace('准备至少两张支持范围内的正高度24位BMP的原始扇区镜像。普通复制文件不是本工程的可靠制卡方式。',
                '把至少两张支持范围内的正高度24位BMP复制到普通FAT32卡根目录。详见[FAT32教程](FAT32_USAGE_20261015.md)。')
    if name.endswith('USER_GUIDE.md'):
        t=re.sub(r'## 图片和存储卡\n.*?(?=## 首次运行)',
          '## 图片和存储卡\n\n使用普通FAT32卡，根目录复制1～4张24位BI_RGB BMP和可选的48kHz/16bit/mono PCM WAV。仅8.3短名、根目录；按目录顺序取前4张BMP和第一个WAV。支持碎片，不要求连续扇区；不支持FAT16/exFAT/GPT。详细转换、复制和排障见[FAT32教程](FAT32_USAGE_20261015.md)。不执行旧pack/烧IMG流程。\n\n',t,flags=re.S)
        t=t.replace('`.img`用于SD图片数据','本轮`.img`仅用于FAT32仿真卡')
    if name.endswith('CONNECTION_AND_USAGE.md'):
        t=re.sub(r'## 7\. 把照片做成 FPGA 能读的卡\n.*?(?=## 8\.)',
          '## 7. 把照片做成 FPGA 能读的卡\n\n确认卡为FAT32、512字节扇区。用`prepare_media.py convert/check`生成并检查BMP，用`prepare_audio.py convert/check`准备可选WAV；然后在资源管理器中直接复制到卡根目录、安全弹出、插回TF卡座并复位。\n\n文件建议命名`1.BMP`、`2.BMP`、`SOUND.WAV`，主体≤8个英文/数字字符；按目录顺序取前4个BMP和首个WAV。图片格式、尺寸范围与之前一致，音频仍只支持48kHz/16bit/mono PCM。**本版不烧写裸镜像，不需要固定64MiB地址。**完整步骤见[FAT32拷贝文件教程](FAT32_USAGE_20261015.md)。\n\n',t,flags=re.S)
        t=t.replace('| 有背景无图 | 仍在扫描、IMG数量、原始写卡方式 | 检查verify、是否又格式化；再定位SDRAM |',
                    '| 有背景无图 | FAT32挂载、根目录BMP数量和格式 | 查本轮FAT32教程与数码管错误；再定位SDRAM |')
    if name.endswith('WAV_AUDIO_20261014.md'):
        t=t.replace('WAV原字节在固定连续扇区；不读FAT文件名、目录、簇链','FAT32根目录第一个WAV；支持碎片簇链')
        t=re.sub(r'## 3\. 准备镜像\n.*?(?=## 4\.)',
          '## 3. 准备FAT32卡\n\n本轮直接把BMP和WAV复制到FAT32根目录，不使用旧镜像pack/烧卡流程。用下面命令生成或转换符合要求的普通WAV，然后在资源管理器中复制到卡：\n\n```powershell\npython scripts/prepare_audio.py tone media/SOUND.wav --seconds 3 --hz 440\npython scripts/prepare_audio.py check media/SOUND.wav\n```\n\n已有其他WAV可用`python scripts/prepare_audio.py convert input.wav media/SOUND.wav`转换。完整文件名、目录和卡格式要求见[FAT32教程](FAT32_USAGE_20261015.md)。旧裸镜像候选不支持普通文件拷贝，需使用本轮重新构建的配置。\n\n',t,flags=re.S)
    if name.endswith('SOURCE_MAP.md'):
        t=t.replace('原始扇区布局','FAT32根目录文件与簇链映射').replace('固定原始扇区PCM WAV','FAT32根目录PCM WAV')
        t+='\n## 2026-10-15 FAT32文件读取\n\n[sd_fat32.v](../src/modules/sd/sd_fat32.v)夹在BMP/WAV解析器与原扇区仲裁器之间，挂载MBR或superfloppy、枚举根目录、按双流簇链映射和缓存FAT扇区；原SD三层栈、仲裁、BMP头/缩放/帧提交、WAV RIFF状态机保持。测试见tb_fat32_mount/stream/player，仿真媒体工具为[make_fat32_image.py](../scripts/make_fat32_image.py)。\n'
    p.write_text(t,encoding='utf-8')
p=root/'README.md'
t=p.read_text(encoding='utf-8-sig')
block=intro.replace('(FAT32_USAGE_20261015.md)','(docs/FAT32_USAGE_20261015.md)').replace('(../reports/','(reports/')
if '2026-10-15 FAT32 v1' not in t:
    first=t.index('\n')+1
    t=t[:first]+'\n'+block+'以下10月14日及更早的构建数值、裸镜像操作和候选链接是历史记录；当前状态以本轮报告为准。\n\n'+t[first:]
t=t.replace('从 TF/SD 连续原始扇区读取 BMP','从普通 FAT32 TF/SD 根目录读取 BMP/WAV（支持碎片簇链）')
t=t.replace('不同尺寸可混放到同一原始镜像，最多4张。','不同尺寸BMP可直接复制到同一FAT32根目录，最多4张。')
t=t.replace('生成的镜像固定64MiB，图片按连续扇区排列，其余扫描区域清零，并附SHA-256清单。',
            '其中convert/check仍用于生成普通BMP；pack/verify仅保留给历史裸扇区测试。当前制卡是普通FAT32根目录文件复制，见[FAT32教程](docs/FAT32_USAGE_20261015.md)。旧工具生成的镜像固定64MiB，')
t=t.replace('| BMP扫描与图片调度 |','| BMP文件解析与图片调度 |')
t+='\n## FAT32读取层（2026-10-15）\n\n[sd_fat32.v](src/modules/sd/sd_fat32.v)负责分区/BPB几何、根目录8.3枚举、碎片簇链和双流FAT扇区缓存。[bmp_read.v](src/modules/bmp/bmp_read.v)在正式模式仅用文件索引加载，原头解析/缩放不变；[audio_wav.v](src/modules/audio/audio_wav.v)输出相对文件扇区，原格式和延时重试不变。[sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v)连接此中间层与原仲裁器。仅用现有KEY/SW，未修改官方IP、引脚或时钟约束。验证媒体由[make_fat32_image.py](scripts/make_fat32_image.py)纯Python生成/自检，不写实体卡。\n'
p.write_text(t,encoding='utf-8')
print('Updated current operation entry points; retained dated historical evidence')
