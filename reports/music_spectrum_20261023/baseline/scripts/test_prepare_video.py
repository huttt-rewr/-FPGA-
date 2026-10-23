"""AV16K20 packing contract; FFmpeg invocation tests use a controlled fake encoder."""
from pathlib import Path
import json
import struct
import tempfile
import unittest
import sys
from unittest.mock import patch

import prepare_video as video


class VideoTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.frames = self.root / 'video.bgr'
        self.audio = self.root / 'audio.pcm'
        self.output = self.root / 'video.avf'
        self.frame = bytes((11, 22, 33)) * (160 * 120)
        self.frames.write_bytes(self.frame * 2)
        self.audio.write_bytes(struct.pack('<1600h', *range(-800, 800)))

    def test_header_and_two_records(self):
        self.assertEqual(video.pack(self.frames, self.audio, self.output), 2)
        data = self.output.read_bytes()
        self.assertEqual(struct.unpack_from('<8sIHHHHII', data),
                         (b'AV16K20\0', 2, 160, 120, 20, 16000, 117, 0))
        self.assertEqual(data[28:512], bytes(484))
        self.assertEqual(len(data), (1 + 2 * 117) * 512)
        for n in range(2):
            start = (1 + n * 117) * 512
            self.assertEqual(data[start:start+1600], self.audio.read_bytes()[n*1600:(n+1)*1600])
            self.assertEqual(data[start+1600:start+2048], bytes(448))
            self.assertEqual(data[start+2048:start+2048+57600], self.frame)
            self.assertEqual(data[start+2048+57600:start+117*512], bytes(256))

    def test_short_audio_pads_silence(self):
        self.audio.write_bytes(struct.pack('<h', -32768))
        video.pack(self.frames, self.audio, self.output)
        data = self.output.read_bytes()
        self.assertEqual(data[512:2560], b'\x00\x80' + bytes(2046))
        self.assertEqual(data[118*512:122*512], bytes(2048))

    def test_long_audio_is_trimmed(self):
        self.audio.write_bytes(self.audio.read_bytes() + bytes(1600))
        video.pack(self.frames, self.audio, self.output)
        self.assertEqual(self.output.stat().st_size, 235 * 512)

    def test_malformed_streams_do_not_create_image(self):
        for raw in (b'', self.frame[:-1]):
            self.frames.write_bytes(raw)
            with self.assertRaises(ValueError):
                video.pack(self.frames, self.audio, self.output)
            self.assertFalse(self.output.exists())
        self.frames.write_bytes(self.frame)
        self.audio.write_bytes(b'\x01')
        with self.assertRaises(ValueError):
            video.pack(self.frames, self.audio, self.output)
        self.assertFalse(self.output.exists())

    def test_frame_limits(self):
        for n in (0, -1, video.MAX_FRAMES+1):
            with self.assertRaises(ValueError):
                video.header(n)
        self.assertEqual(len(video.header(video.MAX_FRAMES)), 512)

    def test_existing_output_preserved(self):
        self.output.write_bytes(b'keep this file')
        with self.assertRaises(FileExistsError):
            video.pack(self.frames, self.audio, self.output)
        self.assertEqual(self.output.read_bytes(), b'keep this file')

    def test_quality_header_payload_and_limit(self):
        # Raw input is already LE565: red, green, blue and white color bars.
        frame = struct.pack('<4H', 0xf800, 0x07e0, 0x001f, 0xffff) * (320*240//4)
        self.frames.write_bytes(frame * 2)
        self.assertEqual(video.pack(self.frames, self.audio, self.output, 'quality'), 2)
        data = self.output.read_bytes()
        self.assertEqual(struct.unpack_from('<8sIHHHHII', data),
                         (b'AV16K20\0', 2, 320, 240, 20, 16000, 304, 1))
        self.assertEqual(len(data), 512 + 2*304*512)
        for n in range(2):
            start = 512+n*304*512
            self.assertEqual(data[start:start+1600], self.audio.read_bytes()[n*1600:(n+1)*1600])
            self.assertEqual(data[start+1600:start+2048], bytes(448))
            self.assertEqual(data[start+2048:start+304*512], frame)
        maximum = (0xffffffff-512)//(304*512)
        self.assertEqual(len(video.header(maximum, 'quality')), 512)
        with self.assertRaises(ValueError):
            video.header(maximum+1, 'quality')

    def test_native_header_payload_and_limit(self):
        self.assertEqual(video.profile('native'), (640, 480, 2, 1204, 2))
        frame = struct.pack('<2H', 0xf800, 0x07e0) * (640 * 480 // 2)
        self.frames.write_bytes(frame * 2)
        self.assertEqual(video.pack(self.frames, self.audio, self.output, 'native'), 2)
        data = self.output.read_bytes()
        self.assertEqual(struct.unpack_from('<8sIHHHHII', data),
                         (b'AV16K20\0', 2, 640, 480, 20, 16000, 1204, 2))
        self.assertEqual(len(data), 512 + 2 * 1204 * 512)
        for n in range(2):
            start = 512 + n * 1204 * 512
            self.assertEqual(data[start:start+1600], self.audio.read_bytes()[n*1600:(n+1)*1600])
            self.assertEqual(data[start+1600:start+2048], bytes(448))
            self.assertEqual(data[start+2048:start+1204*512], frame)
        maximum = (0xffffffff - 512) // (1204 * 512)
        self.assertEqual(len(video.header(maximum, 'native')), 512)
        with self.assertRaises(ValueError):
            video.header(maximum + 1, 'native')

    def test_conversion_stream_selection_and_shared_timestamps(self):
        source = self.root / 'source.mp4'
        source.touch()
        commands = []

        def encode(command, **kwargs):
            commands.append(command)
            Path(command[command.index('rawvideo', command.index('-f')) + 1]).write_bytes(self.frame)
            if 's16le' in command:
                Path(command[-1]).write_bytes(struct.pack('<800h', *range(800)))

        for has_audio, fmt in ((False,'legacy'), (True,'legacy'),
                               (False,'quality'), (True,'quality'),
                               (False,'native'), (True,'native')):
            with self.subTest(has_audio=has_audio, fmt=fmt):
                streams = [{'codec_type': 'video'}] + ([{'codec_type': 'audio'}] if has_audio else [])
                target = self.root / f'{has_audio}_{fmt}.avf'
                width, height, bpp, _, _ = video.profile(fmt)
                self.frame = bytes(width*height*bpp) if fmt != 'legacy' else bytes((11,22,33))*(160*120)
                with patch.object(video, 'executable', side_effect=lambda v: v), \
                     patch.object(video.subprocess, 'check_output', return_value=json.dumps({'streams': streams})), \
                     patch.object(video.subprocess, 'run', side_effect=encode):
                    result = video.convert(source, target, fmt=fmt)
                self.assertEqual((result['fps'], result['duration_seconds'], result['has_source_audio']),
                                 (20, 0.05, has_audio))
                command = commands[-1]
                self.assertIn('-copyts', command)
                self.assertIn('-start_at_zero', command)
                self.assertIn('0:v:0', command)
                self.assertIn('fps=20:start_time=0', command[command.index('-vf')+1])
                self.assertIn('vflip', command[command.index('-vf')+1])
                self.assertEqual(command[command.index('-pix_fmt')+1], 'rgb565le' if fmt != 'legacy' else 'bgr24')
                self.assertIn(f'scale={width}:{height}:', command[command.index('-vf')+1])
                self.assertIn('flags=lanczos', command[command.index('-vf')+1])
                if has_audio:
                    self.assertIn('aresample=16000:async=1:first_pts=0', command)
                else:
                    self.assertEqual(target.read_bytes()[512:2560], bytes(2048))


if __name__ == '__main__':
    unittest.main(verbosity=2, testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
