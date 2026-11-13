"""Export GIF et storyboard depuis les commandes du Canvas ; Pillow requis."""
import gzip,json,runpy
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent
runtime=runpy.run_path(str(ROOT.parent/'garde-tyrienne'/'export-sprites.py'));render=runtime['render'];render.__globals__['SIZE']=420
records=json.load(gzip.open(ROOT/'render-commands.json.gz','rt'));images=[]
for record in records:
 im=render(record['ops']).crop((0,0,420,290)).convert('RGB');images.append(im)
images[0].save(ROOT/'reparation-NE.gif',save_all=True,append_images=images[1:],duration=[40 if i%6<5 else 50 for i in range(len(images))],loop=0,optimize=True)
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13)
frames=[0,2,4,6,8,10.8];names=['Vestige envahi','Déblaiement','Relevage au câble','Remontage des bras','Tourelle fonctionnelle','Chargement et tir NE']
out=Image.new('RGB',(840,660),'#142223');g=ImageDraw.Draw(out)
for i,(time,label) in enumerate(zip(frames,names)):
 im=images[round(time*24)].resize((280,193),Image.Resampling.NEAREST);x=i%3*280;y=i//3*330;out.paste(im,(x,y+25));g.text((x+12,y+238),f'{time:g} s · {label}',font=font,fill='#e3c48b')
 for rec in [records[round(time*24)]]:
  g.text((x+12,y+263),'Coût : 0 · Ingénieur',font=font,fill='#a7b7aa')
out.save(ROOT/'storyboard.png')
print('GIF de 12 s et storyboard exportés.',flush=True)
