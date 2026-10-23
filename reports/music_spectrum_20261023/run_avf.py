from pathlib import Path
import json
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/'avf'
OUT.mkdir(exist_ok=True)
TOOLS=Path('J:/win64')
WORK=OUT/'avf_work'
CONTRACTS=ROOT/'reports/native640_20261022/adapted_contracts'
if not WORK.exists():subprocess.run([str(TOOLS/'vlib.exe'),str(WORK)],check=True)
sources=[]
for folder in ('common','control','osd','video','audio','bmp','sd','memory','input'):
 sources.extend((ROOT/'src/modules'/folder).glob('*.v'))
sources.extend((ROOT/'src/modules/sd/native').glob('*.v'))
sources.extend((ROOT/'src/ip/fifo').glob('*.v'))
sources.extend([ROOT/'sim/sd_native_card_model.v',ROOT/'sim/tb_av_native.v'])
sources.extend(CONTRACTS.glob('*.v'))
with (OUT/'compile.log').open('wb') as f:
 result=subprocess.run([str(TOOLS/'vlog.exe'),'-work',str(WORK),
       '+incdir+'+(ROOT/'src/modules/video').as_posix()+'+'+ROOT.as_posix()+'+'+(ROOT/'src/modules/memory').as_posix(),*[str(p) for p in sources]],
       cwd=ROOT/'sim',stdout=f,stderr=subprocess.STDOUT)
assert result.returncode==0,'AVF compile failed'
cases=[('tb_av_sync',{}),('tb_av_controls',{}),('tb_av_phase',{}),('tb_av_fast_scaler',{}),
       ('tb_av_faults',{}),('tb_sd_av',{}),('tb_av_memory',{}),('tb_boot_media_select',{}),
       ('tb_media_mode_switch',{}),('tb_fat32_movie',{}),('tb_av_fast_scaler',{'HQ':1}),
       ('tb_av_memory',{'HQ':1}),('tb_fat32_movie',{'HQ':1}),
       ('tb_fat32_movie',{'SCENARIO':1}),('tb_fat32_movie',{'SCENARIO':2}),
       ('tb_fat32_movie',{'HQ':1,'SCENARIO':2}),('tb_fat32_movie',{'HQ':1,'SCENARIO':3}),
       ('tb_av_native',{'VIDEO_FORMAT':0}),('tb_av_native',{'VIDEO_FORMAT':1}),
       ('tb_av_native',{'VIDEO_FORMAT':2})]
cases += [('tb_av_native',{'VIDEO_FORMAT':2,'FAULT':n}) for n in range(1,6)]
cases += [('tb_av_memory_native',{}),('tb_fat32_movie_native',{}),
          ('tb_fat32_movie_native',{'SCENARIO':2}),('tb_fat32_movie_native',{'SCENARIO':3})]
results=[]
for tb,parameters in cases:
 name=tb+''.join('_'+key+str(value) for key,value in parameters.items())
 log=OUT/(name+'.log')
 result=subprocess.run([str(TOOLS/'vsim.exe'),'-c','-lib',WORK.as_posix(),tb,
      *[f'-g{key}={value}' for key,value in parameters.items()],
      '-do','run -all; quit -f','-l',log.as_posix()],cwd=ROOT/'sim',
      stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 text=log.read_text(errors='replace')
 if result.returncode or re.search(r'FAILED|\*\* Fatal',text) or 'ALL PASS '+tb not in text:
  print(text);raise SystemExit('FAILED '+name)
 print('ALL PASS '+name,flush=True);results.append(name)
(OUT/'validation.json').write_text(json.dumps({'pass':True,'count':len(results),'cases':results},indent=2),encoding='utf-8')
print('ALL PASS AVF 29 cases')
