"""Recreate removed historical AVF images to run the preserved contracts.

Uses existing tested AVF packer and FAT32 builder, never a physical device.
"""
from pathlib import Path
import struct
import sys
import json
import hashlib

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from prepare_video import header,PROFILES
import make_fat32_image as fat_builder

def verify_avf(path):
 # The stock verifier filters only BMP/WAV. Verify the AVF allocations/payloads
 # independently instead; keep the project's generator and verifier untouched.
 meta=json.loads(path.with_suffix('.json').read_text())
 with path.open('rb') as f:
  f.seek(meta['partition_lba']*512);boot=f.read(512)
  assert boot[510:]==b'\x55\xaa' and struct.unpack_from('<H',boot,11)[0]==512
  for rec in meta['files']:
   data=bytearray()
   for i,cluster in enumerate(rec['chain']):
    f.seek(meta['first_fat']*512+cluster*4)
    successor=struct.unpack('<I',f.read(4))[0]&0x0fffffff
    assert successor==(rec['chain'][i+1] if i+1<len(rec['chain']) else 0x0fffffff)
    f.seek((meta['first_data']+(cluster-2)*meta['spc'])*512)
    data+=f.read(meta['spc']*512)
   assert hashlib.sha256(data[:rec['size']]).hexdigest()==rec['sha256']
 print('ALL PASS AVF fixture allocation/payload',path.name,flush=True)

fat_builder.verify=verify_avf

def movie(fmt):
 w,h,bpp,sectors,encoding=PROFILES[fmt]
 result=bytearray(header(3,fmt))
 for frame in range(3):
  pcm=b''.join(struct.pack('<h',frame*1000+i+1) for i in range(800))
  result+=pcm.ljust(2048,b'\0')
  pixels=bytearray()
  for y in range(h):
   for x in range(w):
    if encoding==0:pixels+=bytes((x&255,y&255,(x+y+frame)&255))
    else:pixels+=struct.pack('<H',(((x+y+frame)%32)<<11)|((y%64)<<5)|(x%32))
  result+=pixels.ljust((sectors-4)*512,b'\0')
 return result

for fmt,folder in [('legacy','video_fat32_20261018'),('quality','video_quality_20261019'),('native','video_native_20261022')]:
 out=ROOT/'reports'/folder
 data=movie(fmt)
 variants={'movie_fat32.img':data}
 bad=bytearray(data);bad[0]=0;variants['movie_bad_header.img']=bad
 bad=bytearray(data);struct.pack_into('<I',bad,24,3);variants['movie_bad_encoding.img']=bad
 if fmt=='legacy':variants['movie_missing.img']=data
 for name,contents in variants.items():
  target=out/name
  if target.exists():verify_avf(target);continue
  extension='DAT' if name=='movie_missing.img' else 'AVF'
  files=[('FIRST   '+extension,bytes(contents)),('SECOND  '+extension,bytes(data))]
  fat_builder.create(target,mbr=True,spc=8,fragmented=True,supplied=files)
  print('Created',target,flush=True)
