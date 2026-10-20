"""Prepare BMPs and a raw, contiguous-sector image for this project's scanner.

RGB/LANCZOS/BMP conversion follows the supplied lab_ex4_tf converter.
This adaptation adds validation and builds regular files only; it never writes a card.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

PIXEL_BYTES = 640 * 480 * 3
SECTOR = 512
SCAN_SECTORS = 131072


def check_bytes(data):
    if len(data) < 54:
        raise ValueError('Truncated BMP header')
    signature, size, _, _, offset = struct.unpack_from('<2sIHHI', data)
    dib, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', data, 14)
    if signature != b'BM' or dib not in (40, 108, 124) or planes != 1:
        raise ValueError('Expected Windows BMP (DIB 40/108/124), planes=1')
    if not (1 <= width <= 1920 and 1 <= height <= 1080 and bits == 24 and compression == 0):
        raise ValueError('Expected positive-height 1..1920 x 1..1080, 24-bit BI_RGB')
    if not max(54, 14 + dib) <= offset <= 4096:
        raise ValueError('Invalid pixel offset')
    stride = (width * 3 + 3) & ~3
    if size != offset + stride * height or len(data) != size:
        raise ValueError('Declared/actual BMP length must equal offset + padded_stride * height')
    return dict(width=width, height=height, bits=bits, dib_size=dib,
                pixel_offset=offset, bytes=size, sha256=hashlib.sha256(data).hexdigest())


def regular_path(value):
    path = Path(value)
    # Reject device/UNC syntax and Windows alternate data streams before opening.
    if str(value).startswith(('\\\\', '//')) or ':' in str(path)[len(path.drive):]:
        raise ValueError('Only ordinary local file paths are supported')
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise ValueError('Expected a regular file')
    if path.name.split('.')[0].upper() in {'CON', 'PRN', 'AUX', 'NUL',
            *('COM'+str(i) for i in range(10)), *('LPT'+str(i) for i in range(10))}:
        raise ValueError('Device names are not supported')
    return path


def new_output(value, suffix):
    path = regular_path(value)
    if path.suffix.lower() != suffix:
        raise ValueError('Output must end with ' + suffix)
    if path.exists():
        raise ValueError('Output exists; choose a new file name: ' + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def convert(source, target, fit='contain', width=640, height=480):
    from PIL import Image, ImageOps
    if not (1 <= width <= 1920 and 1 <= height <= 1080):
        raise ValueError('Dimensions must be in 1..1920 x 1..1080')
    source = regular_path(source)
    target = new_output(target, '.bmp')
    with Image.open(source) as image:
        image = ImageOps.exif_transpose(image).convert('RGBA')
        base = Image.new('RGBA', image.size, (0, 0, 0, 255))
        base.alpha_composite(image)
        image = base.convert('RGB')
        if fit == 'stretch':
            image = image.resize((width, height), Image.Resampling.LANCZOS)
        elif fit == 'crop':
            image = ImageOps.fit(image, (width, height), method=Image.Resampling.LANCZOS)
        else:
            image = ImageOps.pad(image, (width, height), method=Image.Resampling.LANCZOS, color='black')
        # Exclusive creation prevents accidental replacement of source or old output.
        with target.open('xb') as stream:
            image.save(stream, 'BMP')
    return check_bytes(target.read_bytes())


def pack(sources, output, start_sector=0):
    if not 1 <= len(sources) <= 4:
        raise ValueError('Select 1 to 4 BMPs, in display order')
    if not 0 <= start_sector < SCAN_SECTORS:
        raise ValueError('Start sector must be within 0..131071')
    payloads = []
    entries = []
    sector = start_sector
    for source in sources:
        path = regular_path(source)
        data = path.read_bytes()
        info = check_bytes(data)
        sectors = (len(data) + SECTOR - 1) // SECTOR
        if sector + sectors > SCAN_SECTORS:
            raise ValueError('Image data would exceed the 64 MiB preparation limit')
        entries.append(dict(source=str(path.resolve()), start_sector=sector, sectors=sectors, **info))
        payloads.append(data + bytes(sectors * SECTOR - len(data)))
        sector += sectors
    output = new_output(output, '.img')
    manifest_path = new_output(str(output) + '.json', '.json')
    # Cover the entire RTL scan window, including stale pictures beyond the last
    # selected image. A compact prefix alone would leave old card sectors intact.
    image_data = (bytes(start_sector * SECTOR) + b''.join(payloads)
                  + bytes((SCAN_SECTORS - sector) * SECTOR))
    record = dict(format='fpga-contiguous-bmp-v1', filesystem=None,
                  image_bytes=len(image_data), image_sha256=hashlib.sha256(image_data).hexdigest(),
                  sector_bytes=SECTOR, images=entries)
    with output.open('xb') as stream:
        stream.write(image_data)
    with manifest_path.open('x', encoding='utf-8') as stream:
        json.dump(record, stream, ensure_ascii=False, indent=2)
    return record


def verify(image_path):
    path = regular_path(image_path)
    data = path.read_bytes()
    record = json.loads(regular_path(str(path)+'.json').read_text(encoding='utf-8'))
    if record['format'] != 'fpga-contiguous-bmp-v1' or record['sector_bytes'] != SECTOR:
        raise ValueError('Unsupported image manifest')
    if (len(data) != SCAN_SECTORS * SECTOR or len(data) != record['image_bytes']
            or hashlib.sha256(data).hexdigest() != record['image_sha256']):
        raise ValueError('Image length/hash mismatch')
    if not 1 <= len(record['images']) <= 4:
        raise ValueError('Invalid image count')
    end = 0
    for entry in record['images']:
        start = entry['start_sector'] * SECTOR
        size = entry['bytes']
        padded_end = start + entry['sectors'] * SECTOR
        if (start < end or start < 0 or padded_end > min(len(data), SCAN_SECTORS * SECTOR)
                or entry['sectors'] != (size + SECTOR - 1) // SECTOR):
            raise ValueError('Invalid sector allocation')
        if any(data[end:start]) or any(data[start + size:padded_end]):
            raise ValueError('Nonzero gap/padding could contain stale headers')
        info = check_bytes(data[start:start + size])
        if any(entry[key] != value for key, value in info.items()):
            raise ValueError('BMP metadata/hash mismatch')
        end = padded_end
    if any(data[end:]):
        raise ValueError('Scan-window tail must be zero to exclude stale pictures')
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    cmd = commands.add_parser('convert')
    cmd.add_argument('source'); cmd.add_argument('output')
    cmd.add_argument('--fit', choices=('contain', 'crop', 'stretch'), default='contain')
    cmd.add_argument('--width', type=int, default=640)
    cmd.add_argument('--height', type=int, default=480)
    cmd = commands.add_parser('check'); cmd.add_argument('files', nargs='+')
    cmd = commands.add_parser('pack'); cmd.add_argument('output'); cmd.add_argument('files', nargs='+')
    cmd.add_argument('--start-sector', type=int, default=0)
    cmd = commands.add_parser('verify'); cmd.add_argument('image')
    args = parser.parse_args()
    try:
        if args.command == 'convert': result = convert(args.source, args.output, args.fit, args.width, args.height)
        elif args.command == 'check': result = [check_bytes(regular_path(p).read_bytes()) for p in args.files]
        elif args.command == 'pack': result = pack(args.files, args.output, args.start_sector)
        else: result = verify(args.image)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, ImportError) as exc:
        print('ERROR: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
