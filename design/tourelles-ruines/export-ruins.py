"""Export des ruines depuis les commandes Canvas. Pillow requis."""
from pathlib import Path
import json,runpy,zipfile
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent
render=runpy.run_path(str(ROOT.parent/'garde-tyrienne'/'export-sprites.py'))['render']
data=json.loads((ROOT/'render-commands.json').read_text())
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
small=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',11)
preview=Image.new('RGB',(4*288,284),'#152222');g=ImageDraw.Draw(preview)
metadata={'cell':{'width':192,'height':192,'pivot':{'x':96,'y':155}},'primaryDirection':'NE','selectedState':'04-enfouie','states':[]}
for item in data:
 im=render(item['operations']);b=im.getbbox();assert b and b[0]>0 and b[1]>0 and b[2]<192 and b[3]<192,(item['id'],item['direction'],b)
 assert im.getpixel((0,0))[3]==0
 im.save(ROOT/f"{item['id']}-{item['direction']}.png")
 if item['direction']=='NE':
  i=item['kind'];enlarged=im.resize((288,288),Image.Resampling.NEAREST);preview.paste(enlarged,(i*288,-25),enlarged);g.text((i*288+14,244),item['name'],font=font,fill='#e3c48b');g.text((i*288+14,267),item['tag'].split(' · ')[0],font=small,fill='#a7b7aa')
for i in range(4):
 items=[d for d in data if d['kind']==i];atlas=Image.new('RGBA',(768,384))
 for j,item in enumerate(items):atlas.paste(Image.open(ROOT/f"{item['id']}-{item['direction']}.png"),((j%4)*192,(j//4)*192))
 atlas.save(ROOT/f"{items[0]['id']}-orientations.png")
 metadata['states'].append({key:items[0][key] for key in ['id','name','tag','desc','repair'] }|{'atlas':f"{items[0]['id']}-orientations.png",'directions':{item['direction']:{'file':f"{item['id']}-{item['direction']}.png",'x':j%4*192,'y':j//4*192,'width':192,'height':192} for j,item in enumerate(items)}})
preview.save(ROOT/'propositions-ruines-NE.png');(ROOT/'sprites.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
print('32 sprites transparents, 4 atlas et planche NE exportés ; limites vérifiées.')
