/* TempleIncantation — construction « M1 · L'incantation » du Temple de Sigil (planche temple-miroir-propositions.html).
   Les pierres du sprite de jeu se décollent d'un éboulis, montent, traversent en arc et se tassent à leur place (aucun fondu).
   L'ingénieur s'agenouille, un miroir de l'Ancre (sphère noire, bulles et éclairs violets) flotte au-dessus de lui
   et une bulle de dialogue affiche l'incantation, un vers par assise. Tout est fonction du temps : aucun état interne. */
(function(global){
'use strict';
const O=['#120a22','#24164a','#3c2a78','#5c46aa','#8a72d8','#c4b2ff','#efe6ff'];
const VERSES=['Ka·ren·thal','Vos·me·dri','Aun·tir·ae','Sel·va·rün','Ix·or·tha'];
// une formule par bâtiment : vers récités pendant le chantier, puis mot de clôture
const FORMULAS={
 templeJob:{verses:VERSES,end:'Thal·de·mor !'},
 sawmillJob:{verses:['Me·dei·nar','Sil·va·ruun','Ar·bo·thel','Ve·rid·aa','Lu·nem·or'],end:'Ruun·sil·va !'},
 foundryJob:{verses:['Ae·ther·ka','Fer·ro·dun','Ig·nar·oth','Kal·mo·rak','Dur·ae·tha'],end:'Ig·nar·dun !'},
 barracksJob:{verses:['In·dra·vel','Tor·ra·kan','Vaj·rü·na','Ka·ru·dra','Sha·nam·or'],end:'Vaj·ra·kan !'},
 turretJob:{verses:['Ty·rel·os','Ba·lis·tar','Ar·kon·ve','Tel·mo·rae','Sa·gi·thar'],end:'Ty·ra·los !'}};
const ENDS=new Set(Object.values(FORMULAS).map(f=>f.end));
const TS=6,D=.11,SW=320,SH=240;
const cl=v=>v<0?0:v>1?1:v,lerp=(a,b,u)=>a+(b-a)*u,eio=u=>u<.5?4*u*u*u:1-Math.pow(-2*u+2,3)/2,eo=u=>1-Math.pow(1-u,3);
const hs=n=>{const s=Math.sin(n*127.1+311.7)*43758.5453;return s-Math.floor(s)};
const R=(g,x,y,w,h,c)=>{g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),w,h)};
function L(g,x0,y0,x1,y1,c){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let i=0;i<=n;i++)R(g,x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,1,1,c)}
function ring(g,cx,cy,rx,ry,c,n,rot=0,dash=0){for(let i=0;i<n;i++){if(dash&&i%dash===0)continue;const a=i/n*6.2832+rot;R(g,cx+Math.cos(a)*rx,cy+Math.sin(a)*ry,1,1,c)}}
function disc(g,cx,cy,r,c){for(let y=-r;y<=r;y++){const w=Math.floor(Math.sqrt(r*r-y*y+.5));R(g,cx-w,cy+y,w*2+1,1,c)}}
const canvas=(w,h)=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c};

/* ---------- découpe du sprite en pierres (paresseux : PixelBuildings est chargé après) ---------- */
const CACHE={};let K0=null;
// Source : une image du bâtiment achevé, rendue par le moteur de jeu à l'échelle 1 (ancre en (ax,ay)).
function init(kind='temple',opts={}){const key=kind+(opts.variant?':v':'');if(CACHE[key])return CACHE[key];
 const ref=PixelBuildings.sprite(kind,opts.variant),[ax,ay]=ref.anchor,full=canvas(SW,SH),fg=full.getContext('2d');
 PixelBuildings.draw(fg,kind,ax,ay,1,0,1,{...opts,yaw:opts.yaw||0,phase:0});const d=fg.getImageData(0,0,SW,SH).data;
 const dim=canvas(SW,SH),dg=dim.getContext('2d');dg.drawImage(full,0,0);const id=dg.getImageData(0,0,SW,SH);
 for(let i=0;i<id.data.length;i+=4){const l=(id.data[i]+id.data[i+1]+id.data[i+2])/3;id.data[i]=l*.45+18;id.data[i+1]=l*.42+14;id.data[i+2]=l*.5+22}dg.putImageData(id,0,0);
 const tiles=[];let top=SH,bot=0;
 for(let y=0;y<SH;y+=TS)for(let x=0;x<SW;x+=TS){let n=0;for(let j=y;j<y+TS;j++)for(let i=x;i<x+TS;i++)if(d[(j*SW+i)*4+3]>120)n++;if(n>4){tiles.push({x,y,id:tiles.length});top=Math.min(top,y);bot=Math.max(bot,y)}}
 let sm=0;for(const p of tiles){const h=(bot-p.y)/(bot-top||1);p.s=h*.78+hs(p.id*3.1)*.12;sm=Math.max(sm,p.s);if(p.y+TS>ay){p.gy=p.y;p.rx=p.x}else{p.gy=ay-6+hs(p.id*2.3)*16;p.rx=p.x+(hs(p.id*7.7)*2-1)*16}} // assise basse : pierres déjà posées (atténuées) dès le début
 for(const p of tiles)p.n=p.s/sm;
 return CACHE[key]={full,dim,tiles,ax,ay,scratch:canvas(SW,SH)}}
function shared(){return K0||(K0={fx:canvas(120,110),kneel:[]})}
function path(p,u){const sx=p.rx,sy=p.gy;if(u<.3){const k=eo(u/.3);return[sx+Math.sin(u*40+p.id)*.6,sy-k*9]}
 if(u<.9){const k=eio((u-.3)/.6);return[lerp(sx,p.x,k),lerp(sy-9,p.y-2,k)-Math.sin(Math.PI*k)*10]}const k=(u-.9)/.1;return[p.x,p.y-2+k*2+Math.sin(k*Math.PI)]}
function puff(g,x,y,age,seed){if(age<0||age>.7)return;const k=age/.7;for(let i=0;i<4;i++){const a=hs(seed+i)*Math.PI,v=6+hs(seed*3+i)*8;
 R(g,x+Math.cos(a)*v*k*(hs(seed+i*5)>.5?1:-1),y-Math.sin(a)*v*k*.4-k*2,k<.5?2:1,k<.5?2:1,k<.4?'#8d8770':'#6c6856')}}

/* Chantier : progress ∈ [0,1[, dur = durée totale (s). Renvoie les pierres en vol en coordonnées écran. */
function drawSite(ctx,px,py,k,progress,dur=8,kind='temple',opts={}){const S=init(kind,opts),g=S.scratch.getContext('2d');g.clearRect(0,0,SW,SH);g.imageSmoothingEnabled=false;
 const moving=[],fx=[],tile=(img,p,x,y)=>g.drawImage(img,p.x,p.y,TS,TS,Math.round(x),Math.round(y),TS,TS);
 for(const p of S.tiles){const raw=(progress-p.n*(1-D))/D;if(raw<=0)tile(S.dim,p,p.rx,p.gy)}
 for(const p of S.tiles){const raw=(progress-p.n*(1-D))/D;if(raw<=0)continue;const u=cl(raw),t=D*dur;
  if(u>=1){tile(S.full,p,p.x,p.y);const age=(raw-1)*t;if(age<.7)fx.push(()=>puff(g,p.x+3,p.y+TS,age,p.id));continue}
  const[x,y]=path(p,u);tile(S.full,p,x,y);moving.push([x+3,y+3]);if(u*t<.5)fx.push(()=>puff(g,p.rx+3,p.gy+TS,u*t,p.id+7))}
 for(const f of fx)f();
 const x0=px-S.ax*k,y0=py-S.ay*k,sm=ctx.imageSmoothingEnabled;ctx.imageSmoothingEnabled=false;ctx.drawImage(S.scratch,x0,y0,SW*k,SH*k);ctx.imageSmoothingEnabled=sm;
 return moving.map(([x,y])=>[x0+x*k,y0+y*k])}

/* ---------- ingénieur agenouillé (figure de jeu sans outils, buste abaissé) ---------- */
const KN=12,KLOOP=2.4;
function kneelFrame(spec,time,sk=.5){const S=shared(),i=Math.floor(((time%KLOOP)+KLOOP)%KLOOP/KLOOP*KN);if(S.kneel[i])return S.kneel[i];
 const f=UnitKit.figure({...spec,noProj:true,right:null,left:null},i*KLOOP/KN,sk),c=canvas(f.width,f.height),g=c.getContext('2d'),x=Math.round(30*sk)+2,y=Math.round(80*sk),lo=9,cut=30;
 R(g,x-9,y-3,9,3,'#22262c');R(g,x-10,y-1,3,2,'#121418');g.drawImage(f,0,0,f.width,cut,0,lo,f.width,cut);
 R(g,x-1,y-6,9,4,'#353b43');R(g,x-1,y-6,9,1,'#4f5862');R(g,x+5,y-3,4,4,'#2a2f36');R(g,x+5,y,5,1,'#121418');R(g,x+6,y-6,2,2,'#c2bca2');
 const hx=x+5,hy=y-23+lo;R(g,hx-1,hy,3,4,'#16191d');R(g,hx,hy-1,1,1,'#4f5862');R(g,hx-4,hy+2,4,2,'#353b43');
 return S.kneel[i]=c}
const HAND=[7,-15]; // mains jointes par rapport aux pieds (pixels natifs, sk .5)

/* ---------- miroir de l'Ancre : sphère, bulles, éclairs (pixels natifs puis mise à l'échelle) ---------- */
function bolt(g,x0,y0,x1,y1,seed){let px=x0,py=y0;for(let i=1;i<=4;i++){const u=i/4,j=i<4?(hs(seed+i)*2-1)*4:0,nx=lerp(x0,x1,u)+j,ny=lerp(y0,y1,u)+j*.5;L(g,px,py,nx,ny,O[5]);px=nx;py=ny}R(g,x0,y0,1,1,O[6])}
function bubbles(g,t,cx,cy,spread,n,inten,seed){const pos=[];for(let i=0;i<n;i++){const life=2.2+hs(seed+i)*1.6,q=(t+hs(seed+i*3)*life)/life,ph=q%1,cyc=Math.floor(q);
 const x=cx+(hs(seed+i*7+cyc)*2-1)*spread+Math.sin(ph*9+i)*2,y=cy-ph*(38+hs(seed+i*5)*26),r=ph<.1||ph>.9?1:(hs(seed+i)>.6?3:2);
 g.globalAlpha=inten*Math.min(1,(1-ph)*1.6);ring(g,x,y,r,r,O[4],r*8);R(g,x-r*.5,y-r*.5,1,1,O[6]);g.globalAlpha=1;pos.push([x,y,ph])}return pos}
// fx : origine = pieds de l'ingénieur à l'écran ; act ∈ [0,1] ; fin = secondes depuis l'achèvement (onde) ; targets = pierres en vol (écran)
function drawMirror(ctx,fx,fy,k,t,act,targets=[],fin=Infinity,face=1){const S=shared(),c=S.fx,g=c.getContext('2d'),W=c.width,H=c.height,ox0=60,oy0=90;g.clearRect(0,0,W,H);g.imageSmoothingEnabled=false;
 if(act<=0&&fin>.6)return;const hx=ox0+HAND[0]*face,hy=oy0+HAND[1],ox=hx-6*face,oy=hy-26+Math.sin(t*2)*1.5;
 if(act>0){g.globalAlpha=act;R(g,hx,hy,1,1,O[6]);ring(g,ox,oy,8,3,O[4],40,t*2,4);disc(g,ox,oy,4,'#07060c');R(g,ox-2,oy-2,1,1,O[5]);ring(g,ox,oy,5,5,O[3],30);g.globalAlpha=1;
  const pos=bubbles(g,t,ox,oy+30,18,8,act,91);g.globalAlpha=act;for(const[x,y,ph]of pos)if(ph>.5){const w=(ph-.5)/.5;R(g,lerp(x,ox,w),lerp(y,oy,w),1,1,O[5])}g.globalAlpha=1}
 const x0=fx-ox0*k,y0=fy-oy0*k,sm=ctx.imageSmoothingEnabled;ctx.imageSmoothingEnabled=false;
 if(fin<.6){g.globalAlpha=1-fin/.6;ring(g,ox,oy,4+fin*90,(4+fin*90)*.35,O[5],120);g.globalAlpha=1}
 ctx.drawImage(c,x0,y0,W*k,H*k);
 // éclairs vers les pierres en vol : tracés à l'écran pour pouvoir atteindre le chantier
 const f=Math.floor(t*6);if(act>0&&targets.length&&hs(f)>.45){const m=targets[f%targets.length],sx=x0+ox*k,sy=y0+oy*k;ctx.save();ctx.globalAlpha=act;ctx.fillStyle=O[5];
  let px=sx,py=sy;for(let i=1;i<=5;i++){const u=i/5,j=i<5?(hs(f*3+i)*2-1)*4*k:0,nx=lerp(sx,m[0],u)+j,ny=lerp(sy,m[1],u)+j*.5,n=Math.ceil(Math.hypot(nx-px,ny-py)/k);
   for(let s=0;s<=n;s++)ctx.fillRect(Math.round(lerp(px,nx,s/n)),Math.round(lerp(py,ny,s/n)),Math.max(1,k),Math.max(1,k));px=nx;py=ny}ctx.restore()}
 ctx.imageSmoothingEnabled=sm}

/* ---------- bulle d'incantation (résolution d'écran, texte net) ---------- */
function verse(progress,dur=8,since=Infinity,kind='templeJob'){const F=FORMULAS[kind]||FORMULAS.templeJob,V=F.verses;if(progress>=1)return since<2.4?F.end:'';const n=V.length,i=Math.min(n-1,Math.floor(progress*n)),u=progress*n-i;
 return V[i].slice(0,Math.ceil(V[i].length*cl(u*1.7)))||'…'}
function drawSpeech(ctx,x,y,k,text,t){if(!text)return;const u=Math.max(1,Math.round(k)),fs=Math.max(11,Math.round(5.2*k));ctx.save();ctx.font=`600 ${fs}px 'Pixelify Sans',system-ui,monospace`;
 const w=ctx.measureText(text).width+fs*1.4,h=fs*2,bx=Math.round(x-w*.3),by=Math.round(y-h);
 ctx.fillStyle='#1a1028';ctx.fillRect(bx-u,by,w+2*u,h);ctx.fillRect(bx,by-u,w,h+2*u);ctx.fillStyle='#ece6cc';ctx.fillRect(bx,by,w,h);
 for(let i=0;i<3;i++){ctx.fillStyle='#1a1028';ctx.fillRect(x+i*u-u,by+h+u+i*u,(4-i)*u,u);ctx.fillStyle='#ece6cc';ctx.fillRect(x+i*u,by+h+i*u,(3-i)*u-u,u)}
 ctx.fillStyle='#5c46aa';ctx.fillRect(bx,by+h-u,w,u);ctx.fillStyle='#24164a';ctx.textBaseline='middle';ctx.textAlign='left';ctx.fillText(text,bx+fs*.7,by+h/2);
 if(!ENDS.has(text)){ctx.fillStyle=Math.floor(t*6)%2?'#8a72d8':'#c4b2ff';ctx.fillRect(bx+w-u*3,by+u*2,u*2,u*2)}ctx.restore()}

global.TempleIncantation={VERSES,FORMULAS,drawSite,kneelFrame,prepare:init,drawMirror,verse,drawSpeech,HAND};
})(window);
