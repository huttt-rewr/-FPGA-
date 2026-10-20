"""Create/verify read-only FAT32 simulation media; never accesses a physical disk.

Real boards use an ordinary FAT32 card and copied files. Generated .img files
are SD-peer fixtures for ModelSim, not the former raw-sector media format.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import wave

SECTOR = 512


def u16(b, o):
    return struct.unpack_from('<H', b, o)[0]


def u32(b, o):
    return struct.unpack_from('<I', b, o)[0]


def bmp(w, h):
    stride = (w*3+3) & ~3
    pixels = bytearray()
    for y in range(h):
        row = bytes(v for x in range(w) for v in
                    ((x*7+y*11) % 256, (x*17+y*3) % 256, (x*5+y*29) % 256))
        pixels += row + bytes(stride-len(row))
    return (struct.pack('<2sIHHI', b'BM', 54+len(pixels), 0, 0, 54)
            + struct.pack('<IiiHHIIiiII', 40, w, h, 1, 24, 0, len(pixels), 0, 0, 0, 0)
            + pixels)


def wav():
    out = io.BytesIO()
    with wave.open(out, 'wb') as f:
        f.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', int(24000*math.sin(i*2*math.pi/48)))
                              for i in range(2000)))
    return out.getvalue()


def scaled_reference(data, ow=640, oh=480):
    """Independent integer bilinear reference for the EXISTING scaler."""
    w, h, offset = u32(data, 18), u32(data, 22), u32(data, 10)
    stride = (w*3+3) & ~3
    if w*3 >= h*4:
        dw, dh = ow, max(1, h*ow//w)
    else:
        dw, dh = max(1, w*oh//h), oh
    px, py = (ow-dw)//2, (oh-dh)//2
    sx, sy = ((w-1)<<16)//max(1, dw-1), ((h-1)<<16)//max(1, dh-1)
    result = []
    for y in range(oh):
        ay = ((h-1)<<16) if y == py+dh-1 and dh > 1 else max(0, y-py)*sy
        y0, fy = ay >> 16, (ay >> 8) & 255
        for x in range(ow):
            if not (px <= x < px+dw and py <= y < py+dh):
                result.append('000000\n')
                continue
            ax = ((w-1)<<16) if x == px+dw-1 and dw > 1 else (x-px)*sx
            x0, fx = ax >> 16, (ax >> 8) & 255
            channels = []
            for ch in (2, 1, 0):
                a = data[offset+y0*stride+x0*3+ch]
                b = data[offset+y0*stride+min(x0+1, w-1)*3+ch]
                c = data[offset+min(y0+1, h-1)*stride+x0*3+ch]
                d = data[offset+min(y0+1, h-1)*stride+min(x0+1, w-1)*3+ch]
                top = (a*256+(b-a)*fx+128) >> 8
                bottom = (c*256+(d-c)*fx+128) >> 8
                channels.append((top*256+(bottom-top)*fy+128) >> 8)
            result.append(''.join(f'{c:02x}' for c in channels)+'\n')
    return ''.join(result)


def entry(name, cluster, size, attr=0x20):
    b = bytearray(32)
    b[:11] = name.encode('ascii').ljust(11, b' ')
    b[11] = attr
    struct.pack_into('<H', b, 20, cluster >> 16)
    struct.pack_into('<H', b, 26, cluster & 65535)
    struct.pack_into('<I', b, 28, size)
    return b


def create(path, mbr=False, spc=1, fragmented=True, supplied=None):
    assert spc in (1, 2, 4, 8, 16, 32, 64, 128)
    files = supplied or [('FIRST   BMP', bmp(37, 23)), ('SECOND  bmp', bmp(33, 25)),
                         ('THIRD   BMP', bmp(17, 13)), ('FOURTH  BMP', bmp(53, 9)),
                         ('SOUND   WAV', wav())]
    clusters, reserved = 65536, 32
    fat_size = ((clusters+2)*4+511)//512
    volume = reserved+2*fat_size+clusters*spc
    part = 2048 if mbr else 0
    first_data = part+reserved+2*fat_size
    fat = bytearray(fat_size*512)
    def link(c, n):
        struct.pack_into('<I', fat, c*4, n)
    link(0, 0x0ffffff8)
    link(1, 0xffffffff)
    link(2, 130)
    link(130, 0x0fffffff)
    used = {0, 1, 2, 130}
    cursor = 10
    records = []
    for index, (name, data) in enumerate(files):
        chain = []
        for j in range((len(data)+spc*512-1)//(spc*512)):
            c = (10+index*1800+j*137) if fragmented else cursor
            while c in used:
                c += 1
            cursor = c+1
            used.add(c)
            chain.append(c)
        for c, n in zip(chain, chain[1:]+[0x0fffffff]):
            link(c, n)
        records.append({'name': name, 'size': len(data), 'chain': chain,
                        'sha256': hashlib.sha256(data).hexdigest(), 'data': data})
    # The ignored directory and extra files are nevertheless valid allocations.
    for c in (903, 904, 905, 906):
        assert c not in used
        link(c, 0x0fffffff)
    bpb = bytearray(512)
    bpb[:11] = b'\xeb\x58\x90FPGA    '
    struct.pack_into('<HBHBHHBHHHII', bpb, 11, 512, spc, reserved, 2, 0, 0,
                     0xf8, 0, 63, 255, part, volume)
    struct.pack_into('<IHHIHH', bpb, 36, fat_size, 0, 0, 2, 1, 6)
    bpb[64] = 0x80
    bpb[66] = 0x29
    struct.pack_into('<I', bpb, 67, 0x46504741)
    bpb[71:82] = b'FPGA MEDIA '
    bpb[82:90] = b'FAT32   '
    bpb[510:512] = b'\x55\xaa'
    info = bytearray(512)
    struct.pack_into('<I', info, 0, 0x41615252)
    struct.pack_into('<III', info, 484, 0x61417272, 0xffffffff, 0xffffffff)
    struct.pack_into('<I', info, 508, 0xaa550000)
    root0 = bytearray(spc*512)
    for pos in range(0, len(root0), 32):
        root0[pos] = 0xe5
    root0[-32:] = entry(records[0]['name'], records[0]['chain'][0], records[0]['size'])
    root1 = bytearray(spc*512)
    # Deleted, long name, volume label and directory entries must all be skipped.
    root1[:32] = entry('DELETED BMP', 900, 1)
    root1[0] = 0xe5
    alias = 'LONGNA~1TXT'
    checksum = 0
    for c in alias.encode():
        checksum = (((checksum & 1) << 7) + (checksum >> 1) + c) & 255
    long_entry = bytearray(b'\xff'*32)
    long_entry[0], long_entry[11], long_entry[12], long_entry[13] = 0x41, 0x0f, 0, checksum
    long_entry[26:28] = b'\0\0'
    name_units = 'Long name.txt'.encode('utf-16le')
    for j, o in enumerate((1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30)):
        long_entry[o:o+2] = name_units[j*2:j*2+2]
    root1[32:64] = long_entry
    root1[64:96] = entry(alias, 906, 1)
    root1[96:128] = entry('LABEL   BMP', 0, 0, 0x08)
    root1[128:160] = entry('FOLDER  BMP', 903, 0, 0x10)
    pos = 160
    for rec in records[1:]:
        root1[pos:pos+32] = entry(rec['name'], rec['chain'][0], rec['size'])
        pos += 32
    root1[pos:pos+32] = entry('EXTRA   BMP', 904, 1)
    root1[pos+32:pos+64] = entry('SECOND  WAV', 905, 1)
    # Table end and a deceptive stale entry after it.
    root1[pos+96:pos+128] = entry('STALE   BMP', 906, 1)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('wb') as f:
        f.truncate((part+volume)*512)
        def put(lba, data):
            f.seek(lba*512)
            f.write(data)
        if mbr:
            m = bytearray(512)
            # Exercise selecting a non-first table slot.
            m[446+4] = 0x83
            m[462+4] = 0x0c
            struct.pack_into('<II', m, 462+8, part, volume)
            m[510:] = b'\x55\xaa'
            put(0, m)
        put(part, bpb)
        put(part+1, info)
        put(part+6, bpb)
        put(part+7, info)
        put(part+reserved, fat)
        put(part+reserved+fat_size, fat)
        put(first_data, root0)
        put(first_data+(130-2)*spc, root1)
        folder = bytearray(spc*512)
        folder[:32] = entry('.', 903, 0, 0x10)
        folder[32:64] = entry('..', 0, 0, 0x10)
        put(first_data+(903-2)*spc, folder)
        for c, value in ((904, b'B'), (905, b'W'), (906, b'T')):
            put(first_data+(c-2)*spc, value+bytes(spc*512-1))
        for rec in records:
            for j, c in enumerate(rec['chain']):
                block = rec['data'][j*spc*512:(j+1)*spc*512]
                put(first_data+(c-2)*spc, block+bytes(spc*512-len(block)))
    meta = {'partition_lba': part, 'spc': spc, 'first_fat': part+reserved,
            'first_data': first_data, 'root_chain': [2, 130], 'files': []}
    for rec in records:
        item = {k: v for k, v in rec.items() if k != 'data'}
        meta['files'].append(item)
        expected = path.with_name(path.stem+'_'+rec['name'].strip().replace(' ', '_')+'.hex')
        padded = rec['data']+bytes((-len(rec['data'])) % 512)
        expected.write_text(''.join(f'{v:02x}\n' for v in padded), encoding='ascii')
        item['expected'] = expected.name
    path.with_suffix('.json').write_text(json.dumps(meta, indent=2), encoding='utf-8')
    verify(path)
    return meta


def verify(path):
    """Independent on-disk BPB/directory/chain decoder, checked against manifest."""
    path = Path(path)
    with path.open('rb') as f:
        def sector(lba):
            f.seek(lba*512)
            b = f.read(512)
            assert len(b) == 512 and lba >= 0
            return b
        boot = sector(0)
        assert boot[510:] == b'\x55\xaa'
        part = 0
        if u16(boot, 11) != 512:
            part = next(u32(boot, 446+16*i+8) for i in range(4)
                        if boot[446+16*i+4] in (0x0b, 0x0c))
            boot = sector(part)
        spc, reserved, nf = boot[13], u16(boot, 14), boot[16]
        fat_size, total = u32(boot, 36), u32(boot, 32)
        assert u16(boot, 11) == 512 and spc and spc & (spc-1) == 0
        data_lba = part+reserved+nf*fat_size
        count = (total-reserved-nf*fat_size)//spc
        assert count >= 65525 and boot[510:] == b'\x55\xaa'
        def chain(first):
            seen = set()
            while first < 0x0ffffff8:
                assert 2 <= first <= count+1 and first not in seen
                seen.add(first)
                yield first
                b = sector(part+reserved+first//128)
                first = u32(b, first % 128*4) & 0x0fffffff
        found = []
        ended = False
        for c in chain(u32(boot, 44)):
            for s in range(spc):
                block = sector(data_lba+(c-2)*spc+s)
                for o in range(0, 512, 32):
                    e = block[o:o+32]
                    if e[0] == 0:
                        ended = True
                        break
                    if e[0] == 0xe5 or e[11] & 0x18 or e[11] & 0x0f == 0x0f:
                        continue
                    if e[8:11].upper() not in (b'BMP', b'WAV'):
                        continue
                    size = u32(e, 28)
                    first = (u16(e, 20) << 16) | u16(e, 26)
                    if ((e[8:11].upper() == b'BMP' and sum(r['name'][8:].upper() == 'BMP' for r in found) >= 4)
                            or (e[8:11].upper() == b'WAV' and any(r['name'][8:].upper() == 'WAV' for r in found))):
                        continue
                    cl = list(chain(first))
                    payload = b''.join(sector(data_lba+(c-2)*spc+s) for c in cl for s in range(spc))[:size]
                    assert len(payload) == size
                    found.append({'name': e[:11].decode(), 'size': size, 'chain': cl,
                                  'sha256': hashlib.sha256(payload).hexdigest()})
                if ended:
                    break
            if ended:
                break
        manifest = json.loads(path.with_suffix('.json').read_text())
        assert found == [{k: r[k] for k in ('name', 'size', 'chain', 'sha256')}
                         for r in manifest['files']]
        for rec in found:
            print(rec['name'], 'bytes=', rec['size'], 'chain=', rec['chain'])
        print('ALL PASS FAT32 verify:', path.name, 'MBR' if part else 'superfloppy', 'spc=', spc)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    make = sub.add_parser('create')
    make.add_argument('output', type=Path)
    make.add_argument('--mbr', action='store_true')
    make.add_argument('--spc', type=int, default=1)
    make.add_argument('--contiguous', action='store_true')
    check = sub.add_parser('verify')
    check.add_argument('image', type=Path)
    fixtures = sub.add_parser('fixtures')
    fixtures.add_argument('--out', type=Path, default=Path('reports/fat32_20261015/vectors'))
    args = parser.parse_args()
    if args.command == 'verify':
        verify(args.image)
    elif args.command == 'create':
        create(args.output, args.mbr, args.spc, not args.contiguous)
    else:
        create(args.out/'super.img')
        create(args.out/'mbr.img', mbr=True, spc=2)
        create(args.out/'contig.img', fragmented=False)
        for i, data in enumerate((bmp(37, 23), bmp(33, 25))):
            (args.out/f'pixels{i}.hex').write_text(scaled_reference(data), encoding='ascii')


if __name__ == '__main__':
    main()
