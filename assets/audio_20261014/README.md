# 图片与 WAV 演示素材

tone_48k_mono.wav：3秒440Hz、48kHz/16bit/mono，幅度10000。
pictures_and_audio.img：已有四张多分辨率BMP镜像后，LBA131072处追加完整WAV，末尾补齐扇区。

运行 `python scripts/prepare_audio.py verify assets/audio_20261014/pictures_and_audio.img` 校验。
未写物理卡。KEY3长按菜单→AUDIO MUTE→短按确认OFF才开始音频。
详细接线、制卡、控制和限制见 [音频手册](../../docs/WAV_AUDIO_20261014.md)。
