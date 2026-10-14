"""Rebuild deleted regression fixtures; leave image RTL/testbenches unchanged.

Independent endpoint-aligned Q16/Q8 bilinear RGB reference, bottom-up BMP rows.
The original generator was lost with reports; these are documented replacement
fixtures, not a claim to have recovered the exact historical vector hashes.
"""
from pathlib import Path
import hashlib
import json
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/multires_20261010'


def bitmap(w, h, offset=54):
    y, x = np.indices((h, w))
    rgb = np.stack(((17*x+3*y)%256, (5*x+29*y)%256,
                    (x*x+11*y+127)%256), axis=2).astype(np.uint8)
    stride = (w*3+3) & ~3
    rows = np.zeros((h, stride), dtype=np.uint8)
    rows[:, :w*3] = rgb[:, :, ::-1].reshape(h, w*3)
    size = offset + h*stride
    hdr = struct.pack('<2sIHHI', b'BM', size, 0, 0, offset)
    hdr += struct.pack('<IiiHHIIiiII', 40, w, h, 1, 24, 0, h*stride, 0, 0, 0, 0)
    return hdr + bytes(offset-len(hdr)) + rows.tobytes()


def decode(data):
    offset, = struct.unpack_from('<I', data, 10)
    w, h = struct.unpack_from('<ii', data, 18)
    assert 1 <= w <= 1920 and 1 <= h <= 1080
    stride = (w*3+3) & ~3
    rgb = np.frombuffer(data, np.uint8, offset=offset, count=h*stride)
    return rgb.reshape(h, stride)[:, :w*3].reshape(h, w, 3)[:, :, ::-1].astype(np.int64)


def resize(rgb, ow, oh):
    h, w, _ = rgb.shape
    if w*3 >= h*4:
        dw, dh = ow, max(1, h*ow//w)
    else:
        dw, dh = max(1, w*oh//h), oh
    def coordinates(source, dest):
        a = np.arange(dest, dtype=np.int64) * (((source-1)<<16)//max(1, dest-1))
        if dest > 1:
            a[-1] = (source-1)<<16
        return a >> 16, (a >> 8) & 255
    x, fx = coordinates(w, dw)
    y, fy = coordinates(h, dh)
    xp, yp = np.minimum(x+1, w-1), np.minimum(y+1, h-1)
    fx, fy = fx[None, :, None], fy[:, None, None]
    a, b = rgb[y[:, None], x], rgb[y[:, None], xp]
    c, d = rgb[yp[:, None], x], rgb[yp[:, None], xp]
    upper = (a*256+(b-a)*fx+128) >> 8
    lower = (c*256+(d-c)*fx+128) >> 8
    pixels = (upper*256+(lower-upper)*fy+128) >> 8
    frame = np.zeros((oh, ow, 3), dtype=np.int64)
    px, py = (ow-dw)//2, (oh-dh)//2
    frame[py:py+dh, px:px+dw] = pixels
    return (frame[:, :, 0]<<16) | (frame[:, :, 1]<<8) | frame[:, :, 2]


def main():
    images = [(ASSETS/f'image_{size}.bmp').read_bytes() for size in
              ('320x240', '321x241', '480x800', '640x480', '800x600', '1280x720', '1920x1080')]
    # Last case is also used for short-sector injection. It must have no
    # vertical black padding: that test requires zero pixels before SD fails.
    images += [bitmap(1, 1, 1078), bitmap(17, 13, 122)]
    manifests = {}
    for directory, ow, oh in [('scaling_20261010', 640, 480), ('screen_adapt_20261010', 800, 600)]:
        out = ROOT/'reports'/directory/'vectors'
        out.mkdir(parents=True, exist_ok=True)
        records = []
        for i, data in enumerate(images):
            rgb = decode(data)
            data += bytes((-len(data))%512)
            case, expected = out/f'case{i}.hex', out/f'expected{i}.hex'
            case.write_text('\n'.join(f'{v:02x}' for v in data)+'\n', encoding='ascii')
            np.savetxt(expected, resize(rgb, ow, oh).reshape(-1), fmt='%06x')
            records.append({'case': i, 'width': int(rgb.shape[1]), 'height': int(rgb.shape[0]),
                            'offset': struct.unpack_from('<I', data, 10)[0],
                            'case_sha256': hashlib.sha256(case.read_bytes()).hexdigest(),
                            'expected_sha256': hashlib.sha256(expected.read_bytes()).hexdigest()})
        manifests[directory] = records
        print(directory, '9 independent full-frame references generated')
    (Path(__file__).parent/'restored_vectors.json').write_text(json.dumps(manifests, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
