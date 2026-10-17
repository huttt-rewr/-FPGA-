"""Small independent 12-image/3-audio FAT32 fixture, ordinary files only."""
import importlib.util
import io
from pathlib import Path
import struct
import wave
ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('fat_fixture',ROOT/'scripts/make_fat32_image.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
out=Path(__file__).resolve().parent
files=[]
for i in range(12):
    b=bytearray(m.bmp(4,4));b[54:]=bytes([i*15,20,240-i*15])*16
    files.append((f'IMG{i:05}BMP',bytes(b)))
for i in range(3):
    b=io.BytesIO()
    with wave.open(b,'wb') as w:
        w.setparams((1,2,48000,0,'NONE','not compressed'))
        w.writeframes(struct.pack('<h',(i+1)*3000)*1024)
    files.append((f'AUD{i:05}WAV',b.getvalue()))
first=1058;fat=bytearray(513*512);directory=bytearray(512)
struct.pack_into('<III',fat,0,0x0ffffff8,0xffffffff,0x0fffffff)
boot=bytearray(512)
struct.pack_into('<HBHB',boot,11,512,1,32,2)
struct.pack_into('<I',boot,32,first+65536)
struct.pack_into('<I',boot,36,513);struct.pack_into('<I',boot,44,2)
boot[510:]=b'\x55\xaa'
with (out/'media.img').open('wb') as f:
    f.truncate((first+65536)*512)
    f.write(boot)
    for i,(name,data) in enumerate(files):
        chain=[1000+i*300+j*7 for j in range((len(data)+511)//512)]
        directory[i*32:i*32+32]=m.entry(name,chain[0],len(data))
        for j,c in enumerate(chain):
            struct.pack_into('<I',fat,c*4,chain[j+1] if j+1<len(chain) else 0x0fffffff)
            f.seek((first+c-2)*512);f.write(data[j*512:(j+1)*512].ljust(512,b'\0'))
    f.seek(32*512);f.write(fat);f.seek(545*512);f.write(fat)
    f.seek(first*512);f.write(directory)
print('Generated 12 constant-color 4x4 BMP and 3 distinct constant PCM WAV')
