"""Host-side RIFF/PCM conversion, allocation and corruption checks."""
import importlib.util,json,struct,tempfile,wave
from pathlib import Path
import prepare_audio as a
import prepare_media as b
def rejects(fn):
 try:fn()
 except (ValueError,KeyError,OSError):return
 raise AssertionError('Expected rejection')
with tempfile.TemporaryDirectory(prefix='fpga_audio_') as temp:
 root=Path(temp);tone=root/'tone.wav';a.write_wav(tone,[0,32767,-32768,-1]*100)
 assert a.check(tone)['pcm_bytes']==800
 rejects(lambda:a.write_wav(tone,[0]))
 for rate,bits,channels in [(44100,16,1),(48000,8,1),(48000,16,2)]:
  raw=bytearray(tone.read_bytes());struct.pack_into('<I',raw,24,rate);struct.pack_into('<H',raw,34,bits);struct.pack_into('<H',raw,22,channels);p=root/f'bad{rate}_{bits}_{channels}.wav';p.write_bytes(raw);rejects(lambda:a.check(p))
 # 未知奇数块和padding在fmt之前，data不再固定44字节。
 raw=tone.read_bytes();junk=b'JUNK'+struct.pack('<I',3)+b'abc\0';v=raw[:12]+junk+raw[12:];v=v[:4]+struct.pack('<I',len(v)-8)+v[8:];p=root/'junk.wav';p.write_bytes(v);assert a.check(p)['data_offset']==56
 p=root/'stereo.wav'
 with wave.open(str(p),'wb') as w:w.setparams((2,2,24000,0,'NONE','not compressed'));w.writeframes(struct.pack('<hhhhhhhh',1000,3000,-1000,-3000,0,0,32767,32767))
 converted=root/'converted.wav';a.convert(p,converted)
 with wave.open(str(converted),'rb') as w:assert w.getparams()[:3]==(1,2,48000) and struct.unpack('<8h',w.readframes(8))==(2000,0,-2000,-1000,0,16384,32767,32767)
 # 最小合法BMP，镜像前64MiB保持扫描规则，音频不覆盖图片。
 image=bytearray(58);struct.pack_into('<2sIHHI',image,0,b'BM',58,0,0,54);struct.pack_into('<IiiHHI',image,14,40,1,1,1,24,0);image[54:57]=b'\x01\x02\x03'
 bmp=root/'one.bmp';bmp.write_bytes(image);base=root/'base.img';b.pack([bmp],base)
 out=root/'combined.img';r=a.pack(base,tone,out);assert r['audio']['start_sector']==131072 and out.read_bytes()[:67108864]==base.read_bytes();a.verify(out)
 manifest=Path(str(out)+'.json');meta=json.loads(manifest.read_text());meta['audio']['start_sector']=120000;manifest.write_text(json.dumps(meta));rejects(lambda:a.verify(out))
 meta['audio']['start_sector']=131072;manifest.write_text(json.dumps(meta));raw=bytearray(out.read_bytes());raw[67108864+50]^=1;out.write_bytes(raw);rejects(lambda:a.verify(out))
 for device in ['NUL','COM1.wav',r'\\.\PhysicalDrive1']:
  rejects(lambda:a.regular_path(device))
print('ALL PASS prepare_audio: RIFF chunks, format rejection, PCM conversion, layout, exclusive outputs, corruption/device rejection')
