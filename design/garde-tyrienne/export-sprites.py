"""Rasterise les commandes du Canvas en PNG transparents et atlas. Dépendance : Pillow."""
import copy,gzip,json,math
from pathlib import Path
from PIL import Image,ImageDraw,ImageColor,ImageFont
ROOT=Path(__file__).resolve().parent
SIZE=192

def render(operations):
 im=Image.new('RGBA',(SIZE,SIZE))
 state={'fillStyle':'#fff','strokeStyle':'#000','lineWidth':1,'globalAlpha':1,'mat':[1,0,0,1,0,0]};stack=[];path=[]
 def point(x,y):
  a,b,c,d,e,f=state['mat'];return(a*x+c*y+e,b*x+d*y+f)
 def color(text):
  if text.startswith('rgba'):
   v=text[5:-1].split(',');c=tuple(map(int,v[:3]))+(int(float(v[3])*255),)
  else:c=ImageColor.getcolor(text,'RGBA')
  return c[:3]+(int(c[3]*state['globalAlpha']),)
 def paint(fill):
  if len(path)<2:return
  layer=Image.new('RGBA',im.size);draw=ImageDraw.Draw(layer);c=color(state['fillStyle' if fill else 'strokeStyle'])
  if fill:draw.polygon(path,fill=c)
  else:draw.line(path,fill=c,width=max(1,round(state['lineWidth']*abs(state['mat'][0]))))
  im.alpha_composite(layer)
 for op in operations:
  k,*v=op
  if k=='set':state[v[0]]=v[1]
  elif k=='save':stack.append(copy.deepcopy(state))
  elif k=='restore':state=stack.pop()
  elif k=='translate':state['mat'][4:]=point(*v)
  elif k=='scale':
   a,b,c,d,e,f=state['mat'];state['mat']=[a*v[0],b*v[0],c*v[1],d*v[1],e,f]
  elif k=='beginPath':path=[]
  elif k in ('moveTo','lineTo'):path.append(point(*v))
  elif k=='closePath':
   if path:path.append(path[0])
  elif k=='arc':
   x,y,r,start,end,*_=v;path.extend(point(x+r*math.cos(start+(end-start)*i/48),y+r*math.sin(start+(end-start)*i/48)) for i in range(49))
  elif k in ('fill','stroke'):paint(k=='fill')
  elif k=='fillRect':
   x,y,w,h=v;old=path;path=[point(x,y),point(x+w,y),point(x+w,y+h),point(x,y+h)];paint(True);path=old
 return im

if __name__=='__main__':
 data=json.load(gzip.open(ROOT/'render-commands.json.gz','rt'))
 idle_atlas=Image.new('RGBA',(SIZE*4,SIZE*2));preview=Image.new('RGB',(SIZE*4,(SIZE+32)*2),'#152222');g=ImageDraw.Draw(preview)
 font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',15)
 metadata={'cell':{'width':SIZE,'height':SIZE,'pivot':{'x':96,'y':155}},'primaryDirection':'NE','directionConvention':'Screen coordinates: N up, E right, NE upper-right.','cycleMs':3600,'frameDurationMs':37.5,'atlas':{'columns':12,'rows':8,'frames':96},'projectile':'Not baked into turret frames; spawn separately along normalized screen direction.','events':{'hatchOpens':1,'liftBegins':5,'liftComplete':24,'tensionComplete':64,'fire':73,'cycleEnd':96},'sequences':{'reload':{'start':0,'count':73,'loop':False},'fire':{'start':73,'count':23,'loop':False},'cycle':{'start':0,'count':96,'loop':True}},'directions':{}}
 for index,item in enumerate(data):
  direction=item['id'];idle=render(item['idle']);idle.save(ROOT/f'idle-{direction}.png');render(item['inactive']).save(ROOT/f'inactive-{direction}.png');idle_atlas.paste(idle,((index%4)*SIZE,(index//4)*SIZE))
  preview.paste(idle,((index%4)*SIZE,(index//4)*(SIZE+32)),idle);g.text(((index%4)*SIZE+12,(index//4)*(SIZE+32)+SIZE+4),direction+(' · PRINCIPALE' if direction=='NE' else ''),font=font,fill='#e3c48b')
  atlas=Image.new('RGBA',(SIZE*12,SIZE*8));frames=[]
  for i,commands in enumerate(item['frames']):
   frame=render(commands);atlas.paste(frame,((i%12)*SIZE,(i//12)*SIZE));frames.append(frame)
  atlas.save(ROOT/f'atlas-{direction}.png',optimize=True)
  bbox=idle.getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<SIZE and bbox[3]<SIZE,(direction,bbox)
  for frame in frames:
   b=frame.getbbox();assert b and b[0]>0 and b[1]>0 and b[2]<SIZE and b[3]<SIZE,(direction,'clipped',b)
  d=next(d for d in [('N',0,-1),('NE',1,-1),('E',1,0),('SE',1,1),('S',0,1),('SO',-1,1),('O',-1,0),('NO',-1,-1)] if d[0]==direction);norm=math.hypot(d[1],d[2]);metadata['directions'][direction]={'idle':f'idle-{direction}.png','inactive':f'inactive-{direction}.png','atlas':f'atlas-{direction}.png','direction':{'x':d[1]/norm,'y':d[2]/norm},'frames':[{'x':i%12*SIZE,'y':i//12*SIZE,'w':SIZE,'h':SIZE} for i in range(96)]}
  if direction=='NE':
   gifs=[]
   for frame in frames:
    bg=Image.new('RGB',frame.size,'#152222');bg.paste(frame,mask=frame.getchannel('A'));gifs.append(bg.quantize(colors=128))
   gifs[0].save(ROOT/'cycle-NE.gif',save_all=True,append_images=gifs[1:],duration=[40 if i%4<3 else 30 for i in range(96)],loop=0)
  print(direction,'96 frames, bounds verified',flush=True)
 idle_atlas.save(ROOT/'orientations-transparent.png');preview.save(ROOT/'orientations.png');(ROOT/'sprites.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2))
