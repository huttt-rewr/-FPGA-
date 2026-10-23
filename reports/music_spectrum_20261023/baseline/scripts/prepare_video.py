"""Convert a video to an AV16K20 .avf file for the FAT32 card root.

Requires ffmpeg and ffprobe; this script never writes a physical card.
Video: 320x240 RGB565LE (quality), native 640x480 RGB565LE, or legacy
160x120 BGR24, bottom-up,
20 fps. Audio: 16 kHz signed LE16 mono. CLI defaults to the quality profile.
"""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

from prepare_media import regular_path

WIDTH, HEIGHT, FPS, AUDIO_HZ = 160, 120, 20, 16000
SECTOR = 512
SAMPLES = AUDIO_HZ // FPS
VIDEO_BYTES = WIDTH * HEIGHT * 3
AUDIO_BYTES = SAMPLES * 2
VIDEO_SECTORS = (VIDEO_BYTES + SECTOR - 1) // SECTOR
AUDIO_SECTORS = (AUDIO_BYTES + SECTOR - 1) // SECTOR
RECORD_SECTORS = VIDEO_SECTORS + AUDIO_SECTORS
MAGIC = b'AV16K20\0'
MAX_FRAMES = (0xffffffff - SECTOR) // (RECORD_SECTORS * SECTOR)


def executable(value):
    found = shutil.which(value)
    if found:
        return found
    path = Path(value)
    if path.is_file():
        return str(path.resolve())
    raise ValueError(f'Cannot find {value}; install FFmpeg or supply its full path')


PROFILES = {
    'legacy': (160, 120, 3, 117, 0),
    'quality': (320, 240, 2, 304, 1),
    'native': (640, 480, 2, 1204, 2),
}


def profile(fmt='legacy'):
    return PROFILES[fmt]


def header(frame_count, fmt='legacy'):
    width, height, _, sectors, encoding = profile(fmt)
    maximum = (0xffffffff - SECTOR) // (sectors * SECTOR)
    if not 1 <= frame_count <= maximum:
        raise ValueError(f'Frame count must be in 1..{maximum}')
    return struct.pack('<8sIHHHHII', MAGIC, frame_count, width, height,
                       FPS, AUDIO_HZ, sectors, encoding).ljust(SECTOR, b'\0')


def pack(video, audio, output, fmt='legacy'):
    """Pack already-converted streams, bounding RAM usage to one frame."""
    width, height, bpp, sectors, _ = profile(fmt)
    frame_bytes = width * height * bpp
    size = video.stat().st_size
    if size % frame_bytes:
        raise ValueError('Incomplete raw video frame')
    count = size // frame_bytes
    prefix = header(count, fmt)
    if audio.stat().st_size % 2:
        raise ValueError('Incomplete PCM sample')
    # Exclusive output avoids overwriting an existing image or a source video.
    with video.open('rb') as frames, audio.open('rb') as samples, output.open('xb') as dest:
        dest.write(prefix)
        for _ in range(count):
            pcm = samples.read(AUDIO_BYTES)
            if len(pcm) % 2:
                raise ValueError('Incomplete PCM sample')
            dest.write(pcm.ljust(AUDIO_SECTORS * SECTOR, b'\0'))
            frame = frames.read(frame_bytes)
            if len(frame) != frame_bytes:
                raise ValueError('Raw video changed during conversion')
            dest.write(frame.ljust((sectors - AUDIO_SECTORS) * SECTOR, b'\0'))
    return count


def convert(source, output, ffmpeg='ffmpeg', ffprobe='ffprobe', fmt='legacy'):
    source, output = regular_path(source), regular_path(output)
    if not source.is_file():
        raise ValueError('Input video does not exist')
    if output.suffix.lower() != '.avf' or output.exists():
        raise ValueError('Choose a new output path ending in .avf')
    ffmpeg, ffprobe = executable(ffmpeg), executable(ffprobe)
    info = json.loads(subprocess.check_output(
        [ffprobe, '-v', 'error', '-show_streams', '-of', 'json', str(source.resolve())],
        text=True, encoding='utf-8'))
    streams = info.get('streams', [])
    if not any(s.get('codec_type') == 'video' for s in streams):
        raise ValueError('Input has no video stream')
    has_audio = any(s.get('codec_type') == 'audio' for s in streams)
    width, height, _, _, _ = profile(fmt)
    pixel_format = 'rgb565le' if fmt in ('quality', 'native') else 'bgr24'
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fpga_video_', dir=output.parent) as temporary:
        temporary = Path(temporary)
        raw_video, raw_audio = temporary / 'video.bgr', temporary / 'audio.pcm'
        # One invocation and common input timestamps retain audio/video offsets.
        # fps start_time and aresample first_pts pad/trim to the same origin.
        video_filter = (
            f'fps={FPS}:start_time=0,scale={width}:{height}:flags=lanczos:force_original_aspect_ratio=decrease,'
            f'pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,vflip,format={pixel_format}')
        command = [ffmpeg, '-nostdin', '-v', 'error', '-y', '-copyts', '-start_at_zero',
                   '-i', str(source.resolve()), '-map', '0:v:0', '-an',
                   '-vf', video_filter, '-c:v', 'rawvideo', '-pix_fmt', pixel_format,
                   '-f', 'rawvideo', str(raw_video)]
        if has_audio:
            command += ['-map', '0:a:0', '-vn', '-af',
                        'aresample=16000:async=1:first_pts=0', '-ac', '1',
                        '-ar', '16000', '-c:a', 'pcm_s16le', '-f', 's16le', str(raw_audio)]
        subprocess.run(command, check=True)
        if not has_audio:
            raw_audio.touch()
        count = pack(raw_video, raw_audio, output, fmt)
    return dict(output=str(output.resolve()), frames=count, duration_seconds=count / FPS,
                width=width, height=height, pixel_format=pixel_format, fps=FPS, audio_hz=AUDIO_HZ,
                audio_channels=1, has_source_audio=has_audio,
                bytes=output.stat().st_size)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', help='Input video, e.g. MP4')
    parser.add_argument('output', help='New .avf file; copy to the FAT32 card root')
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--ffprobe', default='ffprobe')
    parser.add_argument('--profile', choices=['quality', 'legacy', 'native'], default='quality',
                        help='quality: 320x240 RGB565; legacy: 160x120 BGR24; native: 640x480 RGB565')
    args = parser.parse_args()
    try:
        result = convert(args.source, args.output, args.ffmpeg, args.ffprobe, args.profile)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f'Conversion failed: {exc}\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
