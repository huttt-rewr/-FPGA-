from pathlib import Path
import cmath
import math
import random

OUT=Path(__file__).resolve().parents[1]/'reports/music_spectrum_20261023'
OUT.mkdir(parents=True,exist_ok=True)
rng=random.Random(72351)
vectors=[
 [0]*256,[10000]*256,[-10000]*256,
 [32767 if n==70 else 0 for n in range(256)],
 [round(24000*math.sin(2*math.pi*8*n/256)) for n in range(256)],
 [round(16000*math.cos(2*math.pi*41*n/256)) for n in range(256)],
 [round(14000*math.sin(2*math.pi*3*n/256)+7000*math.cos(2*math.pi*28*n/256)
        +3000*math.sin(2*math.pi*100*n/256)) for n in range(256)],
 [32767 if n%2 else -32768 for n in range(256)],
 [rng.randint(-32768,32767) for _ in range(256)]]
samples=[];reference=[]
for block in vectors:
 samples.extend(f'{v&0xffff:04x}' for v in block)
 # Independent double-precision O(N^2) DFT: no copied RTL butterfly or LUT.
 windowed=[v*(1-math.cos(2*math.pi*n/255))/2 for n,v in enumerate(block)]
 for k in range(256):
  z=sum(v*cmath.exp(-2j*math.pi*k*n/256) for n,v in enumerate(windowed))/256
  reference.append(f'{round(z.real)&0xffff:04x}{round(z.imag)&0xffff:04x}')
(OUT/'fft_samples.mem').write_text('\n'.join(samples)+'\n',encoding='ascii')
(OUT/'fft_dft.mem').write_text('\n'.join(reference)+'\n',encoding='ascii')
print('Prepared 9 independent DFT cases (2304 complex bins).')
