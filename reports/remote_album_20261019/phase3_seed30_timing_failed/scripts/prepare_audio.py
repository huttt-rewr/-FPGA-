"""Create regular WAV/image files only; never write physical disks."""
import argparse,array,hashlib,json,math,struct,sys,wave
from pathlib import Path
from prepare_media import regular_path,new_output,verify as verify_bmp,check_bytes as bmp_bytes
START_SECTOR=131072
MAX_BYTES=16777216
def check(path):
 return check_bytes(regular_path(path).read_bytes())

def check_bytes(data):
 if len(data)<44 or data[:4]!=b'RIFF' or data[8:12]!=b'WAVE':raise ValueError('Expected RIFF/WAVE')
 end=struct.unpack_from('<I',data,4)[0]+8
 if end!=len(data) or end>MAX_BYTES:raise ValueError('RIFF length mismatch or >16MiB')
 pos=12;fmt=None;pcm=None
 while pos+8<=end:
  name=data[pos:pos+4];size=struct.unpack_from('<I',data,pos+4)[0];body=pos+8;next_pos=body+size+(size&1)
  if next_pos>end:raise ValueError('Chunk exceeds RIFF')
  if name==b'fmt ':
   if fmt is not None or size<16:raise ValueError('Invalid/duplicate fmt')
   fmt=struct.unpack_from('<HHIIHH',data,body)
   if fmt!=(1,1,48000,96000,2,16):raise ValueError('Require PCM/mono/48kHz/16bit')
  elif name==b'data':
   if fmt is None or size<2 or size&1:raise ValueError('Invalid PCM chunk/order')
   pcm=(body,size);break
  pos=next_pos
 if pcm is None:raise ValueError('Missing data')
 return dict(bytes=len(data),data_offset=pcm[0],pcm_bytes=pcm[1],seconds=pcm[1]/96000,rate=48000,channels=1,bits=16,sha256=hashlib.sha256(data).hexdigest())
def write_wav(output,samples):
 payload=array.array('h',samples)
 if sys.byteorder!='little':payload.byteswap()
 if len(payload)*2+44>MAX_BYTES:raise ValueError('Audio exceeds 16MiB')
 target=new_output(output,'.wav')
 with target.open('xb') as f:
  with wave.open(f,'wb') as w:
   w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes(payload.tobytes())
 return check(target)
def convert(source,output):
 with wave.open(str(regular_path(source)),'rb') as w:
  channels,width,rate,frames=w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes()
  if w.getcomptype()!='NONE' or width not in (1,2,3,4) or channels not in (1,2):raise ValueError('Input: PCM WAV, 1/2 channels, 8/16/24/32bit')
  if rate<=0 or frames*48000/rate*2+44>MAX_BYTES:raise ValueError('Duration exceeds budget')
  raw=w.readframes(frames)
 if len(raw)!=frames*channels*width:raise ValueError('Truncated PCM')
 mono=[]
 for i in range(frames):
  values=[]
  for c in range(channels):
   p=(i*channels+c)*width;b=raw[p:p+width]
   value=(b[0]-128)<<8 if width==1 else int.from_bytes(b,'little',signed=True)>>(8*(width-2))
   values.append(value)
  mono.append(sum(values)/channels)
 count=round(frames*48000/rate)
 if not count:raise ValueError('Empty audio')
 result=[]
 # Simple linear resampling; ffmpeg is preferable for filtered high-quality conversion.
 for i in range(count):
  x=i*rate/48000;a=min(int(x),frames-1);b=min(a+1,frames-1);f=x-int(x)
  result.append(max(-32768,min(32767,round(mono[a]*(1-f)+mono[b]*f))))
 return write_wav(output,result)
def pack(image,wav_path,output):
 image=regular_path(image);wav_path=regular_path(wav_path);images=verify_bmp(image);audio=check(wav_path)
 target=new_output(output,'.img');manifest=new_output(str(target)+'.json','.json')
 audio_data=wav_path.read_bytes();payload=image.read_bytes()+audio_data+bytes((-len(audio_data))%512)
 with target.open('xb') as f:f.write(payload)
 record=dict(format='fpga-bmp-wav-v1',filesystem=None,sector_bytes=512,image_bytes=len(payload),image_sha256=hashlib.sha256(payload).hexdigest(),images=images['images'],audio=dict(start_sector=START_SECTOR,**audio))
 with manifest.open('x',encoding='utf-8') as f:json.dump(record,f,ensure_ascii=False,indent=2)
 return record
def verify(path):
 path=regular_path(path);data=path.read_bytes();r=json.loads(regular_path(str(path)+'.json').read_text(encoding='utf-8'))
 if r['format']!='fpga-bmp-wav-v1' or len(data)!=r['image_bytes'] or hashlib.sha256(data).hexdigest()!=r['image_sha256']:raise ValueError('Combined image hash/length mismatch')
 if r['audio']['start_sector']!=START_SECTOR:raise ValueError('Sector mismatch')
 start=START_SECTOR*512;end=start+r['audio']['bytes']
 if len(data)<end or any(data[end:]) or hashlib.sha256(data[start:end]).hexdigest()!=r['audio']['sha256']:raise ValueError('WAV extent/hash mismatch')
 info=check_bytes(data[start:end])
 if any(r['audio'][k]!=v for k,v in info.items()):raise ValueError('WAV metadata mismatch')
 if not 1<=len(r['images'])<=4:raise ValueError('Invalid image count')
 previous=0
 for entry in r['images']:
  begin=entry['start_sector']*512;size=entry['bytes'];stop=begin+entry['sectors']*512
  if begin<previous or stop>start or entry['sectors']!=(size+511)//512:raise ValueError('Invalid BMP allocation')
  if any(data[previous:begin]) or any(data[begin+size:stop]):raise ValueError('Nonzero image gap/padding')
  if any(entry[k]!=v for k,v in bmp_bytes(data[begin:begin+size]).items()):raise ValueError('BMP metadata mismatch')
  previous=stop
 if any(data[previous:start]):raise ValueError('Nonzero scan tail')
 return r
def main():
 p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='command',required=True)
 c=s.add_parser('convert');c.add_argument('source');c.add_argument('output')
 t=s.add_parser('tone');t.add_argument('output');t.add_argument('--seconds',type=float,default=3);t.add_argument('--hz',type=float,default=440)
 c=s.add_parser('check');c.add_argument('wav')
 c=s.add_parser('pack');c.add_argument('bmp_image');c.add_argument('wav');c.add_argument('output')
 c=s.add_parser('verify');c.add_argument('image');a=p.parse_args()
 if a.command=='convert':r=convert(a.source,a.output)
 elif a.command=='tone':
  if not 0<a.seconds<=170 or not 0<a.hz<24000:raise ValueError('Invalid tone')
  r=write_wav(a.output,(round(10000*math.sin(2*math.pi*a.hz*i/48000)) for i in range(round(a.seconds*48000))))
 elif a.command=='check':r=check(a.wav)
 elif a.command=='pack':r=pack(a.bmp_image,a.wav,a.output)
 else:r=verify(a.image)
 print(json.dumps(r,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
