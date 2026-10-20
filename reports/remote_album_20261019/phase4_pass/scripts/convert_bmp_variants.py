"""Multi-resolution adaptation of official lab_ex4_tf/doc/convert/convert_images_to_bmp.py.

Retains Pillow RGB/LANCZOS/BMP conversion through prepare_media; fixes hardcoded
640x480 filenames and adds dimensions, EXIF/alpha handling, no-overwrite and checks.
Creates ordinary files only, never writes a card. --demo creates a labelled test image.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw
from prepare_media import convert, pack, verify

DEFAULT_SIZES=['320x240','321x241','640x480','800x600','1280x720','480x800','1920x1080']

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path)
    parser.add_argument('--source',type=Path)
    parser.add_argument('--demo',action='store_true')
    parser.add_argument('--sizes',nargs='+',default=DEFAULT_SIZES)
    parser.add_argument('--fit',choices=['contain','crop','stretch'],default='stretch')
    parser.add_argument('--pack-demo',action='store_true',help='Pack 320x240/800x600/1280x720/480x800 into a 64MiB ordinary IMG file')
    args=parser.parse_args()
    if bool(args.source)==args.demo:parser.error('Choose exactly one of --source or --demo')
    dims=[]
    for spec in args.sizes:
        try:w,h=map(int,spec.lower().split('x'))
        except ValueError:parser.error('Bad size: '+spec)
        if not(1<=w<=1920 and 1<=h<=1080):parser.error('Out of hardware range: '+spec)
        dims.append((w,h))
    if len(set(dims))!=len(dims):parser.error('Duplicate sizes')
    if args.output.exists():parser.error('Output directory exists; choose a new directory')
    if args.pack_demo and not {(320,240),(800,600),(1280,720),(480,800)}.issubset(dims):
        parser.error('--pack-demo needs all four default demo sizes')
    args.output.mkdir(parents=True)
    source=args.source
    if args.demo:
        source=args.output/'source_chart.png'
        im=Image.new('RGB',(1280,960));draw=ImageDraw.Draw(im)
        for x in range(1280):draw.line((x,0,x,959),fill=(x*255//1279,128,255-x*255//1279))
        for y in range(0,960,80):draw.line((0,y,1279,y),fill='white',width=2)
        for x in range(0,1280,80):draw.line((x,0,x,959),fill='white',width=2)
        draw.rectangle((4,4,1275,955),outline='yellow',width=8)
        draw.rectangle((20,20,300,120),fill='red');draw.text((35,40),'TOP LEFT',fill='white',font_size=40)
        draw.rectangle((940,840,1260,940),fill='blue');draw.text((950,860),'BOTTOM RIGHT',fill='white',font_size=32)
        draw.ellipse((440,280,840,680),outline='white',width=12)
        for n in range(16):draw.rectangle((100+n*64,730,163+n*64,810),fill=(n*17,)*3)
        im.save(source)
    records=[]
    for w,h in dims:
        target=args.output/f'image_{w}x{h}.bmp'
        records.append({'file':target.name,**convert(source,target,args.fit,w,h)})
    (args.output/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    if args.pack_demo:
        paths=[args.output/f'image_{w}x{h}.bmp' for w,h in [(320,240),(800,600),(1280,720),(480,800)]]
        pack(paths,args.output/'four_sizes.img');verify(args.output/'four_sizes.img')
    print(json.dumps(records,indent=2))

if __name__=='__main__':main()
