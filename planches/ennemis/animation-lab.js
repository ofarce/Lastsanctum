'use strict';
// Atelier isolé : aucun comportement ou asset du jeu n'est remplacé.
(() => {
const {K,fill,ell,seg,line}=ProjectUnitKit, TAU=Math.PI*2;
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x)), lerp=(a,b,t)=>a+(b-a)*t;
const ease=x=>{x=clamp(x);return x*x*(3-2*x)};
const pink=EnemyKit.Q.mag;
K.beastLight=pink;
ProjectUnitKit.HEAD.credo=(P,x,y,s)=>{
  ProjectUnitKit.HEAD.open(P,x,y,s);
  fill(P,[[x-7,y-5],[x-5,y-11],[x+3,y-13],[x+8,y-5]],s.hr||K.ivory,34,{v:.8});
  if(s.plume)for(let i=0;i<12;i++)ell(P,x-6+i*.8,y-13-Math.sin(i/12*Math.PI)*5,2,2,K.crim,29,{v:.7});
};
ProjectUnitKit.HEAD.champion=(P,x,y,s)=>{
  fill(P,[[x-6,y-8],[x+5,y-10],[x+8,y-4],[x+6,y+8],[x-5,y+7]],K.gold,30,{v:.8});
  line(P,x-3,y-1,x+6,y-2,s.dead?pink[0]:pink[4],34);
  for(let i=0;i<3;i++)fill(P,[[x-7+i*5,y-6],[x-9+i*5,y-17-i%2*3],[x-2+i*5,y-9]],K.gold,32,{v:.88});
  line(P,x+1,y,x+1,y+6,K.gold[1],33);
};
ProjectUnitKit.X.symbiote=(P,o,s,t)=>{
  const c=o.cx;
  for(let j=0;j<3;j++){
    line(P,c-10+j*3,31,c-5+j*2,36,pink[1],23);
    line(P,c-5+j*2,36,c-8+j*3,43,pink[2],23);
  }
  ell(P,c+2,36,3.8,4,K.gold,26,{v:.8});
  ell(P,c+2,36,2.2,2.7,s.dead?[pink[0],pink[1],pink[2]]:pink,27,{v:s.dead?.3:.75+.15*Math.sin(t*5)});
};
ProjectUnitKit.W.sunshield=(P,x,y,s)=>{
  const large=s.wall?1.2:1;
  const pts=[[x-7*large,y-20],[x+5*large,y-23],[x+12*large,y-17],[x+11*large,y+9],[x+2,y+20],[x-7*large,y+9]];
  fill(P,pts,K.gold,55,{v:.78,lx:.5});
  for(let i=0;i<pts.length;i++)line(P,...pts[i],...pts[(i+1)%pts.length],K.gold[5],56);
  line(P,x+2,y-16,x+2,y+12,K.gold[4],57);line(P,x-4,y-3,x+9,y-3,K.gold[4],57);
  if(s.organic){
    fill(P,[[x-5,y-3],[x+2,y-7],[x+9,y-3],[x+2,y+1]],s.dead?[pink[0],pink[1],pink[2]]:pink,58,{v:.8});
    ell(P,x+2,y-3,1.2,3,K.gun,59);
    for(let i=0;i<3;i++)line(P,x+2,y+1,x-3+i*4,y+12+i*2,pink[2],58);
  }
};
ProjectUnitKit.X.labblade=(P,o,s,t)=>{
  const h=o.hR, a=s.angle??-.8, len=s.blade||24;
  const end=[h[0]+Math.cos(a)*len,h[1]+Math.sin(a)*len];
  seg(P,h,end,3,s.organic?K.gold:K.polish,65,{v:.85});
  line(P,h[0],h[1],...end,s.organic?K.gold[5]:K.white[4],66);
  const nx=-Math.sin(a),ny=Math.cos(a);
  line(P,h[0]+nx*5,h[1]+ny*5,h[0]-nx*5,h[1]-ny*5,K.gold[4],67);
  seg(P,h,[h[0]-Math.cos(a)*5,h[1]-Math.sin(a)*5],2,K.leath,66);
};
const Q=EnemyKit.Q, F=EnemyKit.FAM[1];
// Même gabarit 80×84 rastérisé à 0,5 que buildEnemySprites du prototype.
const light={head:'hood',hc:Q.robe,mask:Q.gold,face:1,torso:K.leath,arms:Q.robe,fore:K.leath,legs:K.gun,boots:K.leath,skirt:Q.robe,sash:K.crim,pauld:.6,pr:Q.robe,seed:81};
const soldier={head:'credo',hr:Q.robe,torso:Q.robe,arms:Q.robe,legs:K.steel,boots:Q.robe,pr:Q.robe,pr2:Q.gold,pauld:.85,lames:2,rivets:1,gorget:1,knee:1,cape:K.crim,skirt:K.crim,seed:82};
const units=[
 {id:'creep',name:'Fanatique du Credo',role:'Infanterie du Credo · contact',kind:'melee',cd:1.15,old:true,s:{...F.fig.c}},
 {id:'spitter',name:'Thuriféraire de Fortuna',role:'Lumière souillée · distance',kind:'magic',cd:1.15,old:true,s:{...F.fig.s}},
 {id:'brute',name:'Automate doré de Byrsa',role:'Construction dorée · frappe lourde',kind:'golem',cd:1.7,old:true,s:{...F.b},model:'b'},
 {id:'beast',name:'Aberration du Dévoreur',role:'Faune de la Bête · morsure',kind:'beast',cd:1.15,old:true,s:{...EnemyKit.FAM[2].c},model:'c'},
 {id:'scout',name:'Infanterie légère',role:'Éclaireur · protection légère renforcée',kind:'melee',cd:1.05,s:{...light}},
 {id:'soldier',name:'Soldat du Credo',role:'Infanterie régulière · puissance moyenne',kind:'melee',cd:1.3,s:{...soldier,plume:true}},
 {id:'shield',name:'Bouclier doré',role:'Défense très élevée · épée et pavois',kind:'melee',cd:1.5,s:{...soldier,wall:true,left:'sunshield',bulk:1.08}},
 {id:'archer',name:'Archer de la Lumière',role:'Éclaireur · arc uniquement',kind:'bow',cd:1.4,s:{...light,under:['quiverBack'],seed:84}},
 {id:'strazhar',name:'Strazhar',role:'Champion de Byrsa · symbiose avec la Bête',kind:'melee',cd:.85,s:{...soldier,head:'champion',hr:Q.gold,torso:Q.gold,arms:Q.gold,fore:Q.gold,legs:Q.gold,boots:Q.gold,pr:Q.gold,pr2:K.bronze,left:'sunshield',pauld:.85,organic:true,over:['symbiote'],blade:28,seed:85}}
];
const $=id=>document.getElementById(id);
let selected=8, time=0, playing=!matchMedia('(prefers-reduced-motion: reduce)').matches, speed=1, zoom=2, guides=false, effects=true, ready=false;
const imageCache=new Map(), frameCache=new Map();
function load(src){return new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(new Error('Image introuvable : '+src));im.src=src})}
function angleAt(q){
  if(q<.3)return lerp(-.65,-2.2,ease(q/.3));
  if(q<.5)return lerp(-2.2,.65,ease((q-.3)/.2));
  return lerp(.65,-.65,ease((q-.5)/.5));
}
function pose(u,action,t){
  const q=(t%u.cd)/u.cd, dying=action==='death', d=dying?clamp(t/1.8):0;
  const spec={...u.s,dead:d>.6,noProj:true};
  if(dying)spec.death=d;
  spec.over=[...(spec.over||[])];
  if(action==='walk')spec.walk=(t/.9)%1;
  if(u.kind==='bow'){
    spec.pose=action==='attack'?'aim':undefined;
    spec.draw=action==='attack'?ease(q/.48):.12;
    spec.loosed=action==='attack'&&q>.5&&q<.65?1:0;
    spec.over.push('bowDraw');
    if(action!=='attack'){spec.hLo=[43,46];spec.hRo=[23,48];}
  }else if(u.kind==='magic'){
    spec.pose='twohand';spec.over=spec.over.filter(k=>k!=='staffEnergy');spec.over.push('staffEnergy');spec.energy='eGold';spec.noProj=true;
    if(action==='attack'){spec.hRo=[25+Math.sin(q*TAU)*2,50];spec.hLo=[40+ease(q/.5)*4,40-Math.sin(q*Math.PI)*3]}
  }else{
    spec.right=null;spec.over.push('labblade');spec.angle=action==='attack'?angleAt(q):-.65;
    if(action==='attack'){
      const a=spec.angle;spec.hRo=[27+Math.cos(a)*10,37+Math.sin(a)*10];spec.eRo=[17+Math.cos(a)*4,36+Math.sin(a)*4];
      spec.hLo=[42,44];
    }
  }
  if(dying){spec.angle=.6+d*.5;}
  if(u.id==='creep' && action!=='attack'){
    spec.right=u.s.right;spec.over=(u.s.over||[]).slice();
  }
  if(u.model)return {...u.s,noProj:true,dead:dying&&d>.68,death:dying?d:undefined,deathKind:u.kind,eye:dying&&d>.68?['','#34222e','#512e40','#704456']:u.s.eye,core:dying&&d>.68?['#20242a','#303743','#434c5b','#566070']:u.s.core,attack:action==='attack'?q:undefined};
  return spec;
}
function sprite(u,action,t){
  // Repos et marche existants : atlas Godot, pixels strictement inchangés.
  if(u.old && action==='walk'){
    const a=metadata.enemies[u.id].walk, f=Math.floor(t/.9*a.count)%a.count;
    const key=`native:${u.id}:${f}`;
    if(!frameCache.has(key)){
      const c=document.createElement('canvas');c.width=a.frame_w;c.height=a.frame_h;
      c.getContext('2d').drawImage(imageCache.get(u.id),(f%a.cols)*a.frame_w,Math.floor(f/a.cols)*a.frame_h,a.frame_w,a.frame_h,0,0,a.frame_w,a.frame_h);
      frameCache.set(key,c);
    }
    return frameCache.get(key);
  }
  const tt=action==='walk'?t%.9:action==='attack'?t%u.cd:Math.min(t,1.8);
  const f=Math.floor(tt*24),key=`${u.id}:${action}:${f}`;
  if(!frameCache.has(key)){
    const spec=pose(u,action,f/24);
    const out=u.model?EnemyKit.draw(u.model,spec,f/24,.5):ProjectUnitKit.figure(spec,f/24,.5);
    frameCache.set(key,out);
  }
  return frameCache.get(key);
}
function ground(g,w,h,t=0,scroll=false){
  g.imageSmoothingEnabled=false;
  const tile=imageCache.get('floor');
  if(tile){
    const sz=tile.width,shift=scroll?Math.floor(t*12)%sz:0;
    for(let y=-sz;y<h+sz;y+=sz)for(let x=-sz;x<w+sz;x+=sz)g.drawImage(tile,x-shift,y);
  }else{g.fillStyle='#323c4b';g.fillRect(0,0,w,h)}
  const rock=imageCache.get('rock');
  if(rock){g.drawImage(rock,0,0,rock.width,Math.min(22,rock.height),0,0,w,22)}
  const face=imageCache.get('face');
  if(face){g.drawImage(face,6,-8);g.drawImage(face,w-42,-8)}
}
function actor(g,u,action,t,x,y,scale=1,flip=false){
  const c=sprite(u,action,t),d=action==='death'?clamp(t/1.8):0;
  const wi=Math.floor(t/.9*6)%6,bob=action==='walk'&&(wi===1||wi===4)?1:0;
  const q=(t%u.cd)/u.cd;
  const hit=action==='attack'?Math.sin(clamp((q-.28)/.4)*Math.PI):0;
  const ax=u.model?20:15,ay=40;
  g.save();g.translate(Math.round(x),Math.round(y));g.scale(scale,scale);
  g.fillStyle='#0b1615a0';g.beginPath();g.ellipse(d*8,-d*3,8+d*10,3+d,0,0,TAU);g.fill();
  if(guides){g.strokeStyle='#f8df93';g.lineWidth=.5;g.beginPath();g.ellipse(0,0,u.model?9:6,3,0,0,TAU);g.stroke()}
  if(flip)g.scale(-1,1);
  const dx=Math.round(hit*(u.kind==='golem'?2:3));
  g.imageSmoothingEnabled=false;
  g.drawImage(c,-ax+dx,-ay-bob);
  // Ombre/lumière et barre de vie : mêmes teintes que UnitView.
  if(action!=='death'){
    const hpw=16;g.fillStyle='#191b1d';g.fillRect(-8,-(u.old?metadata.enemies[u.id].h:37)-5,hpw,2);
    g.fillStyle='#db7772';g.fillRect(-8,-(u.old?metadata.enemies[u.id].h:37)-5,hpw,1);
  }
  if(effects&&action==='attack'&&q>.39&&q<.64){
    const p=(q-.39)/.25;
    if(u.kind==='bow'||u.kind==='magic'){
      const px=Math.round(20+p*27),py=-22;
      g.fillStyle=u.kind==='magic'?'#f0cc66':'#ece4cc';g.fillRect(px-5,py,6,1);
      if(u.kind==='magic'){g.fillStyle='#fff2b0';g.fillRect(px-1,py-1,2,3)}
    }else if(u.kind!=='beast'){
      const col=u.s.organic?pink[3]:'#ece4cc';g.strokeStyle=col;g.lineWidth=1;
      g.beginPath();g.arc(14,-20,13,-1.7+p*.7,.2+p*.7);g.stroke();
    }
  }
  if(effects&&action==='death'){
    const impact=u.kind==='beast'?1.04:u.kind==='golem'?1.37:1.40;
    const age=t-impact;
    if(age>=0&&age<.32){
      const heavy=u.kind==='golem',n=heavy?7:4;
      g.fillStyle=heavy?'#9a9684':'#858573';g.globalAlpha=(1-age/.32)*.65;
      for(let i=0;i<n;i++){
        const side=i%2?1:-1,spread=(3+i*2)+age*(14+i*3);
        g.fillRect(Math.round(9+side*spread),Math.round(-2-age*8+age*age*34-(i%3)),heavy?2:1,1);
      }
    }
  }
  g.restore();
}
function target(g,x,y,s,t,impact){
  g.save();g.translate(x+(impact?Math.sin(t*50)*2:0),y);g.scale(s,s);
  g.fillStyle='#13150f70';g.beginPath();g.ellipse(0,0,14,4,0,0,TAU);g.fill();
  g.strokeStyle='#665239';g.lineWidth=4;g.beginPath();g.moveTo(0,0);g.lineTo(0,-53);g.moveTo(-15,-37);g.lineTo(15,-37);g.stroke();
  g.fillStyle=impact?'#ba9770':'#8a7858';g.fillRect(-9,-49,18,27);g.fillStyle='#a79673';g.fillRect(-6,-46,12,3);g.strokeStyle='#59472f';g.lineWidth=1;g.strokeRect(-9,-49,18,27);g.restore();
}
const stageBuffers=new WeakMap();
function scene(canvas,u,action){
  if(!stageBuffers.has(canvas)){const c=document.createElement('canvas');c.width=180;c.height=180;stageBuffers.set(canvas,c)}
  const c=stageBuffers.get(canvas),g=c.getContext('2d'),w=c.width,h=c.height,t=time%6;
  ground(g,w,h,t,action==='walk');
  const s=zoom,x=zoom>2?40:zoom>1?60:72,y=150;
  if(guides){g.strokeStyle='#e5cc7c55';g.setLineDash([2,3]);g.beginPath();g.moveTo(0,y);g.lineTo(w,y);g.stroke();g.setLineDash([])}
  if(action==='attack'){
    const q=(t%u.cd)/u.cd;
    const ranged=u.kind==='bow'||u.kind==='magic';
    target(g,x+s*(ranged?43:29),y,s*.42,t,q>.45&&q<.58);
  }
  actor(g,u,action,t,x,y,s);
  const out=canvas.getContext('2d');out.imageSmoothingEnabled=false;out.drawImage(c,0,0,canvas.width,canvas.height);
}
function original(){
  const c=$('original'),g=c.getContext('2d'),u=units[selected];g.clearRect(0,0,c.width,c.height);g.imageSmoothingEnabled=false;
  const im=imageCache.get(u.id),m=metadata?.enemies[u.id];
  if(im&&m){const a=m.walk,f=Math.floor(time/.9*a.count)%a.count;g.drawImage(im,(f%a.cols)*a.frame_w,Math.floor(f/a.cols)*a.frame_h,a.frame_w,a.frame_h,0,0,240,252)}
  else{g.fillStyle='#a4afa2';g.font='20px system-ui';g.textAlign='center';g.fillText('Concept',120,122);g.textAlign='left'}
}
let metadata;
function select(i){
  selected=i;const u=units[i];time=0;
  $('name').textContent=u.name;$('description').textContent=u.role;
  $('attack-time').textContent=`Cycle · ${u.cd.toLocaleString('fr')} s`;
  $('attack-description').textContent=u.kind==='bow'?'Mise en joue, tension de la corde, décoche et réarmement. Aucun équipement de mêlée.':u.kind==='magic'?'Concentration, émission d’un trait de lumière, puis récupération.':u.kind==='beast'?'Recul de la tête, morsure en avant et retour sur les appuis.':u.kind==='golem'?'Armement lourd, frappe des membres antérieurs et reprise d’appui.':'Armement du bras, frappe d’épée et retour en garde ; le bouclier reste porté.';
  $('reference-text').textContent=u.old?'À gauche et dans la scène de marche : le même atlas Godot, sans redessin. Attaque et mort sont proposées avec le générateur graphique d’origine, la même palette et la même résolution.':'Nouvelle unité dessinée avec les primitives et la palette du Credo du projet, sur le même gabarit natif de 40 × 42 pixels. À valider avant intégration.';
  document.querySelectorAll('nav button').forEach((b,j)=>b.setAttribute('aria-pressed',String(i===j)));
}
units.forEach((u,i)=>{const b=document.createElement('button');b.textContent=String(i+1).padStart(2,'0')+' · '+u.name;const s=document.createElement('span');s.textContent=u.old?'Atlas du jeu · 40 × 42 px':'Nouveau · même gabarit natif';b.appendChild(s);b.onclick=()=>select(i);$('roster').appendChild(b)});
function updatePlay(){ $('play').textContent=playing?'Pause':'Lire';$('play').setAttribute('aria-pressed',String(playing)); }
$('play').onclick=()=>{playing=!playing;updatePlay()};
$('restart').onclick=()=>{time=0};
$('step').onclick=()=>{playing=false;time=(Math.floor(time*30)+1)/30;updatePlay()};
$('speed').onchange=e=>speed=Number(e.target.value);
$('zoom').onchange=e=>zoom=Number(e.target.value);
$('guides').onchange=e=>guides=e.target.checked;
$('effects').onchange=e=>effects=e.target.checked;
$('time').oninput=e=>{playing=false;time=Number(e.target.value);updatePlay()};
select(selected);updatePlay();
const battleBuffer=document.createElement('canvas');battleBuffer.width=576;battleBuffer.height=192;
let previous=0;
function loop(now){
  const dt=previous?Math.min((now-previous)/1000,.08):0;previous=now;
  if(ready){
    if(playing)time=(time+dt*speed)%6;
    for(const c of document.querySelectorAll('.stage'))scene(c,units[selected],c.dataset.action);
    original();
    const c=battleBuffer,g=c.getContext('2d');ground(g,c.width,c.height);
    const action=time<2?'walk':time<4?'attack':'death',t=time<2?time:time<4?time-2:time-4;
    for(let i=0;i<units.length;i++){
      const x=25+i*60+(action==='walk'?Math.floor(time*4):8),y=104;
      if(action==='attack')target(g,x+29,y,.35,time,(t%units[i].cd)/units[i].cd>.45&&(t%units[i].cd)/units[i].cd<.58);
      actor(g,units[i],action,t,x,y,1);
      g.fillStyle='#e6dfc8';g.font='7px monospace';g.textAlign='center';g.fillText(String(i+1).padStart(2,'0'),25+i*60,132);g.textAlign='left';
    }
    const bg=$('battle').getContext('2d');bg.imageSmoothingEnabled=false;bg.drawImage(battleBuffer,0,0,$('battle').width,$('battle').height);
    $('time').value=String(time);$('clock').textContent=`${time.toLocaleString('fr',{minimumFractionDigits:2,maximumFractionDigits:2})} s`;
  }
  requestAnimationFrame(loop);
}
async function init(){
  try{
    const response=await fetch('../assets/baked/manifest.json');if(!response.ok)throw Error('Manifest indisponible');metadata=await response.json();
    await Promise.all([load('../assets/ardoise/world/tiles/floor.png').then(im=>imageCache.set('floor',im)),load('../assets/ardoise/world/tiles/rock.png').then(im=>imageCache.set('rock',im)),load('../assets/ardoise/world/runtime/face5_0.png').then(im=>imageCache.set('face',im)),...units.filter(u=>u.old).map(u=>load(`../assets/baked/enemies/${u.id}_walk.png`).then(im=>imageCache.set(u.id,im)))]);
    ready=true;$('loading').textContent='9 unités · pixels natifs du projet';
  }catch(e){$('error').textContent=e.message+' — ouvrez cette fiche depuis un serveur HTTP local.';$('loading').textContent='Chargement interrompu'}
}
async function exportAssets(){
  if(!ready)throw Error('Sprites non chargés');
  const manifest={version:1,source:'planches/ennemis-animations.html',death_duration:1.8,enemies:{}};
  const send=async(name,data)=>{const r=await fetch('/enemy-export/'+name,{method:'POST',body:data});if(!r.ok)throw Error('Export '+name+' : '+r.status)};
  for(const u of units){
    const meta={ax:u.model?20:15,ay:40,h:u.old?metadata.enemies[u.id].h:37,stride:u.old?metadata.enemies[u.id].stride:1.8,self_bob:false};
    for(const action of ['idle','walk','attack','death']){
      // Strazhar : marche à quatre pattes « La ruée » (planches/strazhar-quadrupede-propositions.html, choix 04).
      // Cadre plus large que le gabarit debout : ancre propre à la marche, foulée = 33 px natifs / 8 px par unité.
      if(u.id==='strazhar'&&action==='walk'){
        const Q=StrazharQuad,v=Q.VARIANTS.find(x=>x.id==='ruee'),cols=12,rows=Math.ceil(Q.FRAMES/cols);
        const sheet=document.createElement('canvas');sheet.width=Q.NW*cols;sheet.height=Q.NH*rows;
        for(let i=0;i<Q.FRAMES;i++)sheet.getContext('2d').drawImage(Q.get(v,i).canvas,(i%cols)*Q.NW,Math.floor(i/cols)*Q.NH);
        await send('strazhar_walk.png',await new Promise(resolve=>sheet.toBlob(resolve)));
        meta.stride=v.stride/2/8;meta.self_bob=true;
        meta.walk={frame_w:Q.NW,frame_h:Q.NH,cols,rows,count:Q.FRAMES,fps:Q.FRAMES/v.dur,ax:Math.round((v.Hx+v.Sx)/4),ay:Q.ground};
        continue;
      }
      const fps=action==='idle'?10:24;
      const count=action==='idle'?24:action==='walk'?24:action==='death'?45:Math.ceil(u.cd*fps);
      const images=[];
      for(let i=0;i<count;i++){
        let c;
        if(u.old&&(action==='idle'||action==='walk')){
          const a=metadata.enemies[u.id][action],im=action==='idle'?await load(`../assets/baked/enemies/${u.id}_idle.png`):imageCache.get(u.id);
          const f=action==='idle'?i%a.count:Math.floor(i/count*a.count)%a.count;
          c=document.createElement('canvas');c.width=a.frame_w;c.height=a.frame_h;
          c.getContext('2d').drawImage(im,(f%a.cols)*a.frame_w,Math.floor(f/a.cols)*a.frame_h,a.frame_w,a.frame_h,0,0,a.frame_w,a.frame_h);
        }else if(action==='idle'){
          const spec=pose(u,'walk',i/10);delete spec.walk;
          c=u.model?EnemyKit.draw(u.model,spec,i/10,.5):ProjectUnitKit.figure(spec,i/10,.5);
        }else c=sprite(u,action,action==='walk'?i/count*.9:i/fps);
        images.push(c);
      }
      const fw=Math.max(...images.map(c=>c.width)),fh=Math.max(...images.map(c=>c.height)),cols=12,rows=Math.ceil(count/cols);
      const sheet=document.createElement('canvas');sheet.width=fw*cols;sheet.height=fh*rows;
      images.forEach((im,i)=>sheet.getContext('2d').drawImage(im,(i%cols)*fw,Math.floor(i/cols)*fh));
      await send(`${u.id}_${action}.png`,await new Promise(resolve=>sheet.toBlob(resolve)));
      meta[action]={frame_w:fw,frame_h:fh,cols,rows,count,fps:action==='walk'?count/.9:fps};
    }
    manifest.enemies[u.id]=meta;
  }
  await send('manifest.json',JSON.stringify(manifest,null,2));
  return manifest;
}
if(new URLSearchParams(location.search).has('export')){
  const b=document.createElement('button');b.textContent='Exporter les animations Godot';b.id='export-assets';
  b.onclick=async()=>{b.disabled=true;try{await exportAssets();b.textContent='Export terminé : 9 ennemis, 36 atlas'}catch(e){b.textContent='Erreur : '+e.message;b.disabled=false}};
  document.querySelector('.toolbar').appendChild(b);
}
window.animationLab={exportAssets,units,get selected(){return selected},get time(){return time},get ready(){return ready},get cacheSize(){return frameCache.size},select};
init();requestAnimationFrame(loop);
})();
