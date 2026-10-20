from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
chars='欢迎光临电子相册参赛作品多媒体展示'
font=ImageFont.truetype('C:/Windows/Fonts/simhei.ttf',16)
preview=Image.new('RGB',(len(chars)*32,32),'black')
for i,ch in enumerate(chars):
 glyph=Image.new('1',(16,16));ImageDraw.Draw(glyph).text((0,0),ch,font=font,fill=1,anchor='lt')
 preview.paste(glyph.convert('RGB').resize((32,32),Image.Resampling.NEAREST),(i*32,0))
preview.save(Path(__file__).with_name('zh_message_preview.png'))
print('17 glyphs, actual 16x16 bitmap candidate enlarged 2x, production inputs unchanged')
