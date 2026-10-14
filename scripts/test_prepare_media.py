"""Host-side regression: image content, malformed headers and sector layout."""
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

from PIL import Image
import prepare_media as media


class MediaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root/'source.png'
        image = Image.new('RGB', (640, 480), 'red')
        image.paste('blue', (0, 240, 640, 480))
        image.save(self.source)
        self.bmp = self.root/'image.bmp'
        media.convert(self.source, self.bmp)

    def test_color_orientation_and_format(self):
        info = media.check_bytes(self.bmp.read_bytes())
        self.assertEqual((info['bytes'], info['pixel_offset']), (921654, 54))
        with Image.open(self.bmp) as im:
            self.assertEqual(im.getpixel((0, 0)), (255, 0, 0))
            self.assertEqual(im.getpixel((0, 479)), (0, 0, 255))
        self.assertEqual(self.bmp.read_bytes()[54:57], bytes((255, 0, 0)))

    def test_fit_and_transparency(self):
        Image.new('RGBA', (100, 100), (255, 0, 0, 0)).save(self.source)
        media.convert(self.source, self.root/'alpha.bmp')
        with Image.open(self.root/'alpha.bmp') as im:
            self.assertEqual(im.getbbox(), None)
        Image.new('RGB', (100, 100), 'red').save(self.source)
        for fit in ('contain', 'crop', 'stretch'):
            target = self.root/(fit+'.bmp')
            media.convert(self.source, target, fit)
            with Image.open(target) as im:
                self.assertEqual(im.getpixel((0, 0)), (0, 0, 0) if fit=='contain' else (255, 0, 0))

    def test_invalid_headers(self):
        original = self.bmp.read_bytes()
        mutations = [(14, '<I', 12), (14, '<I', 64), (26, '<H', 0), (26, '<H', 2),
                     (18, '<i', 800), (22, '<i', -480), (28, '<H', 32),
                     (30, '<I', 1), (10, '<I', 53), (2, '<I', 100)]
        for offset, fmt, value in mutations:
            with self.subTest(offset=offset, value=value):
                data = bytearray(original); struct.pack_into(fmt, data, offset, value)
                with self.assertRaises(ValueError): media.check_bytes(data)
        for data in (original[:20], original[:-1], original+b'garbage'):
            with self.assertRaises(ValueError): media.check_bytes(data)

    def test_extended_headers(self):
        original = self.bmp.read_bytes()
        for dib in (108, 124):
            data = bytearray(original[:54] + bytes(dib-40) + original[54:])
            struct.pack_into('<I', data, 14, dib)
            struct.pack_into('<I', data, 10, 14+dib)
            struct.pack_into('<I', data, 2, len(data))
            self.assertEqual(media.check_bytes(data)['dib_size'], dib)

    def test_variable_sizes_and_padding(self):
        for w,h in [(1,1),(321,241),(800,600),(1280,720),(480,800),(1920,1080)]:
            path=self.root/f'{w}x{h}.bmp'
            info=media.convert(self.source,path,'stretch',w,h)
            self.assertEqual((info['width'],info['height']),(w,h))
            self.assertEqual(info['bytes'],54+((w*3+3)&~3)*h)
        paths=[self.root/'321x241.bmp',self.root/'1280x720.bmp',self.root/'480x800.bmp']
        record=media.pack(paths,self.root/'mixed.img')
        self.assertEqual(media.verify(self.root/'mixed.img'),record)

    def test_dimension_bounds(self):
        for w,h in [(0,480),(640,0),(1921,480),(640,1081),(-1,10)]:
            path=self.root/f'invalid_{w}_{h}.bmp'
            with self.assertRaises(ValueError):media.convert(self.source,path,'stretch',w,h)
            self.assertFalse(path.exists())

    def test_pack_and_scan(self):
        target = self.root/'card.img'
        result = media.pack([self.bmp]*4, target, 2)
        self.assertEqual([x['start_sector'] for x in result['images']], [2, 1803, 3604, 5405])
        self.assertEqual(media.verify(target), result)
        data = target.read_bytes()
        self.assertEqual(len(data), 64*1024*1024)
        tail = (5405+1801)*512
        self.assertFalse(any(data[tail:]))
        # Independent sector walk follows the RTL's ceil(file_length/512) skip.
        sector = 0; found = []
        while sector*512 < len(data):
            offset = sector*512
            if data[offset:offset+2] == b'BM':
                found.append(sector)
                size = int.from_bytes(data[offset+2:offset+6], 'little')
                sector += (size+511)//512
            else: sector += 1
        self.assertEqual(found, [2, 1803, 3604, 5405])
        # Even a rehashed image must not hide a stale BMP in the scan-window tail.
        damaged = bytearray(data); damaged[-512:-510] = b'BM'; target.write_bytes(damaged)
        manifest_path = Path(str(target)+'.json')
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        manifest['image_sha256'] = media.hashlib.sha256(damaged).hexdigest()
        manifest_path.write_text(json.dumps(manifest), encoding='utf-8')
        with self.assertRaises(ValueError): media.verify(target)
        manifest_path.write_text(json.dumps(result), encoding='utf-8')
        damaged = bytearray(data); damaged[2*512+60] ^= 1; target.write_bytes(damaged)
        with self.assertRaises(ValueError): media.verify(target)

    def test_reject_before_writing(self):
        target = self.root/'bad.img'
        for files, start in (([], 0), ([self.bmp]*5, 0), ([self.bmp], -1), ([self.bmp], 131071)):
            with self.assertRaises(ValueError): media.pack(files, target, start)
            self.assertFalse(target.exists())
        self.bmp.write_bytes(b'broken')
        with self.assertRaises(ValueError): media.pack([self.bmp], target)
        self.assertFalse(target.exists())

    def test_no_overwrite(self):
        before = self.bmp.read_bytes()
        with self.assertRaises(ValueError): media.convert(self.source, self.bmp)
        self.assertEqual(self.bmp.read_bytes(), before)
        output = self.root/'exists.img'; output.write_bytes(b'keep')
        with self.assertRaises(ValueError): media.pack([self.bmp], output)
        self.assertEqual(output.read_bytes(), b'keep')

    def test_cli_failure(self):
        result = subprocess.run([sys.executable, str(Path(media.__file__)), 'check', str(self.source)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('ERROR:', result.stderr)


if __name__ == '__main__':
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
