'use strict';
// Planche « Caverne et blocs » : cinq jeux de blocs (sol, roche, parois, stalactites, extérieur) conformes à la charte.
// Échelle du jeu : une case = 4 unités = 32 px natifs ; parois vues de face (3/4 de dessus), contour noir franc.
const CAV=(()=>{
const CM=new Map();
function ci(c){if(typeof c==='number')return c;let v=CM.get(c);if(v===undefined){v=parseInt(c.slice(1),16);CM.set(c,v)}return v}
const E=c=>ci(c)|0x1000000; // émissif : non assombri la nuit
function sh(c,k){const n=ci(c),em=n&0x1000000,f=v=>Math.max(0,Math.min(255,Math.round(k<0?v*(1+k):v+(255-v)*k)));return em|f(n>>16&255)<<16|f(n>>8&255)<<8|f(n&255)}
const R_=a=>a.map(ci),OUTL=ci('#0b0a0e'),hexs=R=>R.map(v=>'#'+(v&0xffffff).toString(16).padStart(6,'0'));
function hash(x,y,s=0){let h=(Math.imul(x|0,374761393)+Math.imul(y|0,668265263)+Math.imul(s|0,982451653))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296}
function vnoise(x,y,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf),a=hash(xi,yi,s),b=hash(xi+1,yi,s),c=hash(xi,yi+1,s),d=hash(xi+1,yi+1,s);return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v}
const fbm=(x,y,s)=>vnoise(x,y,s)*.6+vnoise(x*2.1,y*2.1,s+7)*.28+vnoise(x*4.3,y*4.3,s+13)*.12;
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+.5)/16),bay=(x,y)=>BAY[(y&3)*4+(x&3)];
function rp(R,v,x,y){const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]}
function rng(s){return()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const clamp=(v,a,b)=>v<a?a:v>b?b:v;
function inside(p,x,y){let r=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const[xi,yi]=p[i],[xj,yj]=p[j];if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)r=!r}return r}

// ---------- palettes de la charte (reprises de da-planches.js) ----------
const GRASS=R_(['#1c3822','#244a29','#2d5d30','#387234','#47873b','#5c9e44','#7ab450']);
const DIRT=R_(['#3a281a','#523620','#6a4a2a','#836034','#9a7642','#b08c54']);
const MOSS=R_(['#22401f','#2f5528','#3e6c31','#52833a']);
const LEAF=R_(['#10261a','#173a20','#1f4f27','#2a652e','#387b35','#4b923c','#66aa48','#8cc45c']);
const BARK=R_(['#24160e','#3a2416','#52341f','#6b4629','#835a36']);
const WOOD=R_(['#2a1a10','#40281a','#5a3a24','#74502f','#8e663c','#a87e4c']);
const PALE=R_(['#4a4438','#655c4c','#807663','#9b907a','#b5aa92','#cdc3aa','#e2dac4']);
const SILVER=R_(['#4a4e5a','#6e7482','#9aa0ae','#c4c8d2','#e4e6ee']);

// ---------- tampon de pixels ----------
class Pix{constructor(w,h){this.w=w;this.h=h;this.c=new Int32Array(w*h).fill(-1);this.bx0=w;this.by0=h;this.bx1=-1;this.by1=-1}
 set(x,y,c){x=Math.floor(x);y=Math.floor(y);if(x<0||y<0||x>=this.w||y>=this.h||c==null)return;if(typeof c!=='number')c=ci(c);if(c<0)return;this.c[y*this.w+x]=c;if(x<this.bx0)this.bx0=x;if(x>this.bx1)this.bx1=x;if(y<this.by0)this.by0=y;if(y>this.by1)this.by1=y}
 get(x,y){x=Math.floor(x);y=Math.floor(y);return x<0||y<0||x>=this.w||y>=this.h?-1:this.c[y*this.w+x]}
 dark(x,y,k){const v=this.get(x,y);if(v<0||v&0x1000000)return;this.c[Math.floor(y)*this.w+Math.floor(x)]=sh(v,k-1)}
 rect(x,y,w,h,c){for(let j=Math.round(y);j<Math.round(y+h);j++)for(let i=Math.round(x);i<Math.round(x+w);i++)this.set(i,j,typeof c==='function'?c(i,j):c)}
 ell(cx,cy,rx,ry,c){for(let j=Math.floor(cy-ry);j<=Math.ceil(cy+ry);j++)for(let i=Math.floor(cx-rx);i<=Math.ceil(cx+rx);i++){const dx=(i+.5-cx)/rx,dy=(j+.5-cy)/ry;if(dx*dx+dy*dy<=1)this.set(i,j,typeof c==='function'?c(i,j,dx,dy):c)}}
 line(x0,y0,x1,y1,c){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let k=0;k<=n;k++)this.set(Math.round(x0+(x1-x0)*k/n),Math.round(y0+(y1-y0)*k/n),typeof c==='function'?c(k/n):c)}
 poly(pts,fn){let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;for(const[x,y]of pts){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
  for(let y=Math.floor(y0);y<=y1;y++)for(let x=Math.floor(x0);x<=x1;x++)if(inside(pts,x+.5,y+.5))this.set(x,y,typeof fn==='function'?fn(x,y):fn)}
 outline(col=OUTL){if(this.bx1<0)return;const w=this.w,h=this.h,s=this.c,n=new Int32Array(s);
  for(let y=Math.max(0,this.by0-1);y<=Math.min(h-1,this.by1+1);y++)for(let x=Math.max(0,this.bx0-1);x<=Math.min(w-1,this.bx1+1);x++){const i=y*w+x;if(s[i]!==-1)continue;if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}
  this.c=n;this.bx0=Math.max(0,this.bx0-1);this.by0=Math.max(0,this.by0-1);this.bx1=Math.min(w-1,this.bx1+1);this.by1=Math.min(h-1,this.by1+1)}
 blit(s){for(let y=s.by0;y<=s.by1;y++)for(let x=s.bx0;x<=s.bx1;x++){const v=s.c[y*s.w+x];if(v!==-1)this.c[y*this.w+x]=v}}}

// ---------- éclairage (mêmes clés horaires que la charte) ----------
const KEYS=[[0,[.27,.3,.48]],[4.5,[.29,.31,.49]],[6.5,[.8,.62,.66]],[8.5,[1,.96,.9]],[13,[1.05,1.02,.96]],[17,[1,.93,.82]],[19,[.95,.62,.5]],[20.5,[.44,.4,.58]],[24,[.27,.3,.48]]];
function ambient(h){h=((h%24)+24)%24;for(let k=1;k<KEYS.length;k++)if(h<=KEYS[k][0]){const[a,A]=KEYS[k-1],[b,B]=KEYS[k],t=(h-a)/(b-a);return A.map((v,i)=>v+(B[i]-v)*t)}return KEYS[0][1]}
class Scene{constructor(w,h){this.w=w;this.h=h;this.P=new Pix(w,h);this.lights=[];this.beams=[];this.L=[0,0,0].map(()=>new Float32Array(w*h));this.A=[0,0,0].map(()=>new Float32Array(w*h))}
 render(g,hour,t){const{w,h}=this,amb=ambient(hour),lum=.3*amb[0]+.59*amb[1]+.11*amb[2],night=clamp((.9-lum)/.6,0,1),[lr,lg,lb]=this.L,[ar,ag,ab]=this.A;
  for(const a of[lr,lg,lb,ar,ag,ab])a.fill(0);
  for(const L of this.lights){const fl=L.fl||0,I=L.i*(L.always?1:night)*(1+fl*(Math.sin(t*9.3+L.x)*.5+Math.sin(t*14.1+L.y*1.7)*.35));if(I<.01)continue;
   const c=L.cN?L.c.map((v,i)=>v+(L.cN[i]-v)*night):L.c,add=(L.add??.12)*(L.always?1-night*.5:1),R=L.r*(1+fl*.1*Math.sin(t*6.1+L.x*.7));
   for(let y=Math.max(0,Math.floor(L.y-R/1.3));y<=Math.min(h-1,L.y+R/1.3);y++)for(let x=Math.max(0,Math.floor(L.x-R));x<=Math.min(w-1,L.x+R);x++){const dx=x+.5-L.x,dy=(y+.5-L.y)*1.3,d=Math.sqrt(dx*dx+dy*dy)/R;if(d>=1)continue;let f=1-d;f=f*f*(3-2*f);const q=Math.floor(f*5+bay(x,y))/5;if(q<=0)continue;const i=y*w+x;
    lr[i]+=c[0]*I*q;lg[i]+=c[1]*I*q;lb[i]+=c[2]*I*q;if(add){const k=add*I*q*255;ar[i]+=c[0]*k;ag[i]+=c[1]*k;ab[i]+=c[2]*k}}}
  if(!this.img||this.img.width!==w)this.img=g.createImageData(w,h);const d=this.img.data,P=this.P.c;
  for(let i=0,o=0;i<w*h;i++,o+=4){const v=P[i];if(v<0){d[o]=11;d[o+1]=18;d[o+2]=14;d[o+3]=255;continue}const r=v>>16&255,gg=v>>8&255,b=v&255;
   if(v&0x1000000){const k=1+night*.15;d[o]=Math.min(255,r*k);d[o+1]=Math.min(255,gg*k);d[o+2]=Math.min(255,b*k)}
   else{d[o]=Math.min(255,r*(amb[0]+lr[i])+ar[i]);d[o+1]=Math.min(255,gg*(amb[1]+lg[i])+ag[i]);d[o+2]=Math.min(255,b*(amb[2]+lb[i])+ab[i])}d[o+3]=255}
  g.putImageData(this.img,0,0);
  // puits de lumière : colonne tramée, chaude le jour, lunaire la nuit
  for(const B of this.beams){const c=B.c.map((v,i)=>Math.round(255*Math.min(1,(v+(B.cN[i]-v)*night)*.85)));g.fillStyle=`rgb(${c})`;const fr=Math.floor(t*6);
   for(let y=Math.max(0,B.y-B.h);y<B.y;y++){const k=(y-(B.y-B.h))/B.h,cx=B.x+B.dx*(1-k),hw=B.w*(.6+.4*k);for(let x=Math.floor(cx-hw);x<=cx+hw;x++)if(((x+y*2+fr)&7)===0||(((x*3+y+fr)&15)===0))g.fillRect(x,y,1,1)}}}}

// ---------- briques communes ----------
// herbe commune aux cinq propositions (palette de la charte) : seuls les blocs changent
function grass(x,y){let v=.28+fbm(x/14,y/9,1)*.5;const b=hash(x,y,3);if(b>.94)v+=.32;else if(b<.05)v-=.2;return rp(GRASS,v,x,y)}
function pathAt(x,y,cx){return Math.abs(x-cx-6*Math.sin(y/17))<26+(fbm(x/9,y/9,5)-.5)*16}
function cone(L,x,yb,w,h,R,lean=0,shade){L.poly([[x-w,yb],[x+lean,yb-h],[x+w,yb]],(px,py)=>{const ax=x+lean*(yb-py)/h,lit=px<ax?.28:px<ax+1?.12:-.05;return rp(R,(shade??.45)+lit+(yb-py)/h*.12,px,py)})}
function icicle(L,x,yt,w,len,R,lean=0,shade){L.poly([[x-w,yt],[x+w,yt],[x+lean,yt+len]],(px,py)=>{const ax=x+lean*(py-yt)/len,lit=px<ax?.28:px<ax+1?.1:-.08;return rp(R,(shade??.5)+lit-(py-yt)/len*.08,px,py)})}
function blob(L,x,y,rx,ry,R,base=.5,seed=0){L.ell(x,y,rx,ry,(px,py,dx,dy)=>rp(R,base-(dx*.3+dy*.45)*.45-(dx*dx+dy*dy)*.12+(hash(px,py,seed)-.5)*.1,px,py))}
// autel de l'Ancre (bloc taillé dans la pierre de la proposition) et l'Ancre elle-même, noire aux reflets pourpres
function altar(L,x,y,R){const w=22,d=12,hh=9,x0=x-w,y0=y-d-hh;
 L.rect(x0,y0,w*2,d,(px,py)=>{const j=((px-x0)%11===0)||((py-y0)%6===0);return rp(R,.72+(hash(px>>1,py>>1,91)-.5)*.14-(j?.22:0),px,py)});
 L.rect(x0,y0+d,w*2,hh,(px,py)=>{const j=((px-x0+((py-y0-d)>4?5:0))%11===0)||py===y0+d+4;return rp(R,.42-(py-y0-d)/hh*.12-(j?.18:0),px,py)});
 L.line(x0,y0+d,x0+w*2-1,y0+d,R[R.length-1]);
 // anneau de glyphes gravé sur le dessus
 for(let a=0;a<40;a++){const px=x+Math.cos(a/40*6.283)*13,py=y0+d/2+Math.sin(a/40*6.283)*4;if(a%5<3)L.set(px,py,R[1])}
 const oy=y0+d/2-15,r=8;
 L.ell(x,oy,r,r,(px,py,dx,dy)=>{const rim=dx*dx+dy*dy>.62&&dx+dy<-.1;return rim?E(dx+dy<-.9?'#c060e0':'#6a2088'):E(dy>.45?'#170c20':'#08050c')});
 L.set(x-3,oy-4,E('#e0a0ff'));L.set(x-2,oy-4,E('#c060e0'));
 return[{x,y:oy,r:52,i:.9,c:[.78,.3,1.05],fl:.15}]}
// roche en cours de minage : fissures (stade 1 à 3) gravées sur le dessus du bloc
function crack(P,x0,y0,stage,lip,seed){const R=rng(seed*7+stage),n=[0,2,4,7][stage];
 for(let k=0;k<n;k++){let x=x0+16+(R()-.5)*6,y=y0+16+(R()-.5)*6,a=R()*6.283;const len=6+R()*(5+stage*3);
  for(let i=0;i<len;i++){a+=(R()-.5)*.8;x+=Math.cos(a);y+=Math.sin(a)*.8;if(x<x0+2||x>x0+29||y<y0+3||y>y0+29)break;P.set(x,y,OUTL);P.set(x,y+1,lip);if(stage>1&&R()<.3)P.set(x+1,y,OUTL)}}
 if(stage===3)for(let k=0;k<5;k++){const x=x0+5+R()*22|0,y=y0+6+R()*20|0;P.set(x,y,lip);P.set(x+1,y,OUTL)}}

// ---------- ingénieur, pour l'échelle et la lisibilité sur chaque sol ----------
let ENG=null;
function engPix(){if(ENG!==null)return ENG;ENG=false;if(typeof EngineerKit==='undefined')return ENG;
 const im=EngineerKit.draw({},0,.5),g=im.getContext('2d'),d=g.getImageData(0,0,im.width,im.height).data,px=[];let x0=1e9,x1=-1,y1=-1;
 for(let y=0;y<im.height;y++)for(let x=0;x<im.width;x++){const o=(y*im.width+x)*4;if(d[o+3]>110){px.push([x,y,(d[o]<<16)|(d[o+1]<<8)|d[o+2]]);x0=Math.min(x0,x);x1=Math.max(x1,x);y1=Math.max(y1,y)}}
 return ENG={px,ax:Math.round((x0+x1)/2),ay:y1}}

// ---------- construction d'une scène depuis une carte de cases ----------
// R roche pleine, c roche entamée (minage), . sol de caverne, d case creusée, g herbe (sentier si pathX)
const T=32;
function build(St,D){const map=D.map,rows=map.length,cols=map[0].length,w=cols*T,h=rows*T,S=new Scene(w,h),P=S.P,R=rng(St.seed+(D.seed||0));
 const cell=(i,j)=>map[clamp(j,0,rows-1)][clamp(i,0,cols-1)],solid=(i,j)=>{const c=cell(i,j);return c==='R'||c==='c'},out=j=>j>=(D.out??99);
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=x>>5,j=y>>5,c=cell(i,j);
  P.set(x,y,c==='R'||c==='c'?St.top(x,y):c==='g'?(D.pathX!=null&&pathAt(x,y,D.pathX)?St.path(x,y):grass(x,y)):c==='d'?St.dug(x,y):St.floor(x,y))}
 if(St.decal)St.decal(P,D,cell);
 // bords de roche vus de dessus : contour noir et arête claire
 for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){if(!solid(i,j))continue;const x0=i*T,y0=j*T,c=cell(i,j);
  if(c==='c')crack(P,x0,y0,D.crack?.[i]??2,St.lip,i+j*7);
  if(!solid(i,j-1))for(let x=0;x<T;x++){const k=Math.round(hash(x0+x>>2,y0,5)*1.4);P.set(x0+x,y0+k,OUTL);P.set(x0+x,y0+k+1,St.lip);P.set(x0+x,y0+k+2,St.lip2);for(let q=0;q<k;q++)P.set(x0+x,y0+q,St.floor(x0+x,y0+q))}
  if(!solid(i-1,j))for(let y=0;y<T;y++){P.set(x0,y0+y,OUTL);P.set(x0+1,y0+y,St.lip);for(let k=1;k<4;k++)P.dark(x0-k,y0+y,.55+k*.12)}
  if(!solid(i+1,j))for(let y=0;y<T;y++){P.set(x0+T-1,y0+y,OUTL);P.set(x0+T-2,y0+y,St.side);for(let k=0;k<3;k++)P.dark(x0+T+k,y0+y,.6+k*.12)}}
 // ombres au sol des objets posés
 for(const o of D.objs||[]){if(o.k==='light'&&St.lightKind==='puits')continue;const rx=(o.k==='altar'?26:o.k==='boulder'?14:o.k==='eng'?9:o.k==='rubble'?7:10)*(o.s||1),ry=rx*.32;
  for(let y=Math.floor(o.y-ry);y<=o.y+ry;y++)for(let x=Math.floor(o.x-rx+2);x<=o.x+rx+2;x++){const dx=(x-o.x-2)/rx,dy=(y-o.y)/ry,dd=dx*dx+dy*dy;if(dd<1&&bay(x,y)<.9-dd*.6)P.dark(x,y,.6)}}
 const objs=[];
 for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){if(!solid(i,j)||solid(i,j+1))continue;const o=out(j+1);let H=o?St.H[2]:j===D.bigRow?St.H[0]:St.H[1];if(!solid(i,j-1))H=Math.min(H,26);else if(!solid(i,j-2))H=Math.min(H,T+24);
  const x0=i*T,yb=(j+1)*T,lf=!(solid(i-1,j)&&!solid(i-1,j+1)),rf=!(solid(i+1,j)&&!solid(i+1,j+1));
  objs.push({y:yb-.5,draw(){for(let ly=0;ly<H;ly++)for(let lx=0;lx<T;lx++){const x=x0+lx,y=yb-H+ly,c=St.face(x,ly,H,y,o);if(c!=null)P.set(x,y,c)}
   for(let lx=0;lx<T;lx++){P.set(x0+lx,yb-1,OUTL);for(let k=0;k<4;k++)P.dark(x0+lx,yb+k,.5+k*.13)}
   if(lf)for(let y=yb-H;y<yb;y++){P.set(x0,y,OUTL);P.set(x0+1,y,sh(P.get(x0+1,y),.12))}if(rf)for(let y=yb-H;y<yb;y++){P.set(x0+T-1,y,OUTL);P.set(x0+T-2,y,sh(P.get(x0+T-2,y),-.25))}}});
  if(!o&&D.stalac!==false&&(D.stalac==='force'||hash(i,j,St.seed)>.3))objs.push({y:yb,layer:true,draw:L=>St.stalac(L,x0+1,yb-H+2,T-2,H,rng(i*31+j*17+St.seed))});
  if(St.faceProp&&(D.props||D.stalac==='prop')&&(D.stalac==='prop'||(o?0:hash(i,j,77)>.55)))objs.push({y:yb+.1,layer:true,draw:L=>St.faceProp(L,x0,yb,H,o)})}
 for(const o of D.objs||[]){const r=rng(Math.round(o.x*13+o.y*7)+St.seed);
  if(o.k==='eng')objs.push({y:o.y,draw(){const e=engPix();if(!e)return;for(const[x,y,c]of e.px)P.set(o.x+x-e.ax,o.y+y-e.ay,c)}});
  else if(o.k==='altar')objs.push({y:o.y,layer:true,draw:L=>altar(L,o.x,o.y,St.altar)});
  else objs.push({y:o.y,layer:true,draw:L=>St[o.k](L,o.x,o.y,r,o.s||1)})}
 if(St.extras)objs.push(...St.extras(D,P));
 objs.sort((a,b)=>a.y-b.y);
 for(const o of objs){if(o.layer){const L=new Pix(w,h),ls=o.draw(L,S);L.outline();P.blit(L);if(ls)for(const l of ls)l.beam?S.beams.push(l):S.lights.push(l)}else{const ls=o.draw(S);if(ls)S.lights.push(...ls)}}
 return S}

// ======================= LES CINQ PROPOSITIONS =======================
// 1 · ARDOISE TYRIENNE ----------------------------------------------------
const SL=R_(['#141922','#1c222d','#262e3b','#323c4b','#424e5f','#556274','#6c7a8c','#8a98a8']);
const SLF=R_(['#2a2f37','#353b45','#424954','#515863','#626973','#757b84','#8a8f96']);
const EARTH1=R_(['#2a241d','#372f26','#463c30','#574b3b','#695a47']);
const QUARTZ=['#8e9aac','#b6c0ce','#dfe5ee','#f6f8fb'].map(E);
const ardoise={id:'ardoise',seed:11,name:'Ardoise tyrienne',H:[60,44,34],lip:SL[7],lip2:SL[5],side:SL[2],altar:SL,lightKind:'quartz',
 tag:'Continuité avec les ruines',
 desc:'La montagne est taillée dans la même ardoise bleutée que les ruines tyriennes : parois en feuillets horizontaux, sol de dalles anciennes déchaussées où la terre réapparaît. Les stalactites sont des éclats d’ardoise, la lumière vient de grappes de quartz laiteux.',
 pros:'Le plus cohérent avec la charte (ruines en ardoise). Sol clair et régulier : les unités s’y lisent très bien.',cons:'Caverne un peu froide et « bâtie » : on sent la ruine plus que la grotte.',
 chips:[...hexs(SL),...hexs(SLF).slice(1,6),'#dfe5ee'],
 top(x,y){let v=.36+(fbm(x/9,y/7,11)-.5)*.4;if(((x+y*2+Math.floor(vnoise(x/12,y/12,3)*10))%9)===0)v-=.14;if(fbm(x/10,y/8,13)>.7)return rp(MOSS,v+.15,x,y);return rp(SL,v,x,y)},
 face(x,ly,H,y,out){if(ly===0)return SL[7];const off=Math.floor(vnoise(x/14,0,21)*6),yy=ly+off,band=Math.floor(yy/5),bl=yy%5;
  let v=.6-ly/H*.32+(hash(band,Math.floor(x/(7+hash(band,1,2)*9)),23)-.5)*.22;if(bl===0)v+=.13;if(bl===4)v-=.2;
  if(out&&ly<H*.45&&fbm(x/6,y/4,25)>.58)return rp(MOSS,v+.1,x,y);return rp(SL,v,x,y)},
 floor(x,y){const row=Math.floor(y/14),off=(row&1)*9,col=Math.floor((x+off)/18),lu=x+off-col*18,lv=y-row*14;
  if(hash(col,row,31)>.82||fbm(x/16,y/12,30)>.7)return rp(EARTH1,.35+fbm(x/5,y/5,33)*.45,x,y);if(lu===0||lv===0)return rp(EARTH1,.15,x,y);
  let v=.55+(hash(col,row,32)-.5)*.26+(fbm(x/7,y/7,34)-.5)*.2;if(lv===1)v+=.12;if(lu===17||lv===13)v-=.12;if(hash(x,y,35)>.97)v-=.2;return rp(SLF,v,x,y)},
 dug(x,y){if(hash(x>>1,y>>1,40)>.86)return rp(SL,.55,x,y);return rp(EARTH1,.3+fbm(x/6,y/5,41)*.5,x,y)},
 path(x,y){const row=Math.floor(y/12),col=Math.floor((x+(row&1)*8)/16);if(hash(col,row,42)>.72&&(x+(row&1)*8)%16&&y%12)return rp(SLF,.5+(hash(col,row,43)-.5)*.3,x,y);return rp(DIRT,.3+fbm(x/8,y/6,44)*.5,x,y)},
 stalac(L,x0,yt,w,H,R){const n=2+Math.floor(R()*3);for(let k=0;k<n;k++){const x=x0+3+R()*(w-6),len=5+R()*H*.42,wd=1.5+R()*1.6;L.poly([[x-wd,yt],[x+wd+1,yt],[x+wd*.3,yt+len*.6],[x+(R()-.5)*2,yt+len]],(px,py)=>rp(SL,(px<x?.75:.5)-(py-yt)/len*.15,px,py))}},
 stalag(L,x,y,R,s){for(let k=0;k<3;k++){const ox=(k-1)*5+(R()-.5)*2,h=(10+R()*12)*s*(k===1?1.4:1),wd=3+R()*2;L.poly([[x+ox-wd,y],[x+ox-wd+1,y-h*.7],[x+ox+R()*2-1,y-h],[x+ox+wd,y-h*.5],[x+ox+wd,y]],(px,py)=>{let v=(px<x+ox?.62:.38)+(((py+k*2)%5)===0?-.15:0);return rp(SL,v,px,py)})}},
 light(L,x,y,R){L.poly([[x-9,y],[x-6,y-5],[x+6,y-5],[x+9,y]],(px,py)=>rp(SL,.45,px,py));
  for(let k=0;k<5;k++){const ox=(k-2)*3.2+(R()-.5)*2,h=7+R()*11+(k===2?6:0),lean=(k-2)*1.6,wd=1.6+R();L.poly([[x+ox-wd,y-3],[x+ox-wd*.6+lean,y-3-h*.85],[x+ox+lean,y-3-h],[x+ox+wd*.6+lean,y-3-h*.85],[x+ox+wd,y-3]],(px,py)=>QUARTZ[px<x+ox+lean*.5?(py<y-3-h*.6?3:2):1])}
  return[{x,y:y-10,r:44,i:.85,c:[.95,1.02,1.14],fl:.04}]},
 rubble(L,x,y,R,s){for(let k=0;k<4;k++){const ox=(R()-.5)*14*s,oy=(R()-.5)*5*s;L.poly([[x+ox-4*s,y+oy],[x+ox-2*s,y+oy-3*s],[x+ox+4*s,y+oy-2*s],[x+ox+3*s,y+oy+1]],(px,py)=>rp(SL,py<y+oy-1?.75:.4,px,py))}},
 boulder(L,x,y,R,s){const w=13*s,d=7*s,hh=10*s;L.poly([[x-w,y-d-hh],[x+w-3,y-d-hh-2],[x+w,y-hh],[x-w,y-hh]],(px,py)=>fbm(px/5,py/4,46)>.6?rp(MOSS,.7,px,py):rp(SL,.7+(hash(px>>1,py,47)-.5)*.15,px,py));
  L.poly([[x-w,y-hh],[x+w,y-hh],[x+w-1,y],[x-w+2,y]],(px,py)=>{const g=(px-x+w)%9<5&&Math.abs(py-y+hh/2)<2&&(px-x+w)>3&&(px-x+w)<w*2-3;return g?SL[1]:rp(SL,.45-(py-y+hh)/hh*.15,px,py)});
  L.line(x-w,y-hh,x+w-1,y-hh,SL[7])},
};

// 2 · TERRE ET RACINES ---------------------------------------------------------
const EA=R_(['#1a120c','#24180f','#302014','#3e2a1a','#4e3622','#60442b','#745436','#8a6644']);
const EF=R_(['#3d2d1e','#4c3826','#5c4630','#6d553b','#806548','#957756','#aa8a64']);
const SHROOM=['#ff8f7c','#ffb6a6','#ffe0d6'].map(E),STEM=['#9a8a78','#c6b8a4','#e6dccb'].map(E);
function clod(x,y,cw,chh,seed){const row=Math.floor(y/chh),off=(row&1)*cw/2,col=Math.floor((x+off)/cw),cx=col*cw-off+cw/2,cy=row*chh+chh/2,dx=(x+.5-cx)/(cw/2),dy=(y+.5-cy)/(chh/2),d=dx*dx+dy*dy;return{d,v:-(dx*.25+dy*.35)*.5-d*.15+(hash(col,row,seed)-.5)*.16,col,row}}
const terre={id:'terre',seed:23,name:'Terre et racines',H:[58,42,34],lip:EA[7],lip2:EA[5],side:EA[1],altar:PALE,lightKind:'champignons',
 tag:'Au plus près de Core Keeper',
 desc:'Parois de terre sombre en mottes arrondies, comme les blocs de Core Keeper, percées de racines de la jungle au-dessus. Le sol est une terre battue claire semée de cailloux. Stalactites de terre et racines pendantes ; la lumière vient de champignons luminescents saumon.',
 pros:'Le plus chaleureux et le plus « grotte vivante ». Les racines relient la caverne à la jungle au-dessus.',cons:'Moins de lien avec les ruines tyriennes ; le brun général demande de surveiller le contraste avec les adeptes en robes de terre.',
 chips:[...hexs(EA).slice(1),...hexs(EF).slice(2),'#ffb6a6'],
 top(x,y){const c=clod(x,y,9,7,51);if(c.d>1.15)return EA[0];if(fbm(x/11,y/9,52)>.7)return rp(MOSS,.5+c.v,x,y);return rp(EA,.5+c.v,x,y)},
 face(x,ly,H,y,out){if(out&&ly<3+Math.floor(hash(x,0,53)*5))return rp(GRASS,.75-ly*.1,x,y);if(ly===0)return EA[7];
  const r=hash(Math.floor(x/3),0,54);if(r>.9&&ly<H*(.4+hash(x>>2,1,55)*.5)&&Math.abs(Math.sin(ly*.4+x)*1.2)<.9)return BARK[2+(x&1)];
  const c=clod(x,ly+3,11,8,56);if(c.d>1.1)return EA[0];return rp(EA,.62-ly/H*.3+c.v,x,y)},
 floor(x,y){let v=.48+(fbm(x/11,y/8,57)-.5)*.42;if(fbm(x/6,y/4,58)>.7)v-=.16;const p=hash(x>>1,y>>1,59);if(p>.955)return PALE[3+((x^y)&1)];if(p>.94)v-=.25;return rp(EF,v,x,y)},
 dug(x,y){const c=clod(x,y,6,5,60);if(c.d<.5&&hash(c.col,c.row,61)>.7)return rp(EA,.55+c.v,x,y);return rp(EF,.28+fbm(x/6,y/5,62)*.36,x,y)},
 path(x,y){return rp(EF,.35+fbm(x/9,y/7,63)*.45,x,y)},
 stalac(L,x0,yt,w,H,R){const n=2+Math.floor(R()*2);for(let k=0;k<n;k++){const x=x0+4+R()*(w-8),len=6+R()*H*.32;icicle(L,x,yt,2+R()*1.5,len,EA,(R()-.5)*2,.45)}
  for(let k=0;k<2;k++){let x=x0+3+R()*(w-6);const len=H*.4+R()*H*.4;for(let i=0;i<len;i++){x+=Math.sin(i*.5+k)*.45;L.set(x,yt+i,BARK[2+(i%5===0)]);if(i>len*.6&&i%4===0)L.set(x+(k?1:-1),yt+i+1,BARK[1])}}},
 stalag(L,x,y,R,s){blob(L,x,y-6*s,9*s,7*s,EA,.55,71);cone(L,x-1,y-9*s,5*s,12*s,EA,1,.4);cone(L,x+5*s,y-4*s,3*s,7*s,EA,0,.35)},
 light(L,x,y,R){const M=[[-6,0,4,6],[0,-2,6,10],[7,1,3,5]];for(const[ox,oy,r,h]of M){L.rect(x+ox-1,y+oy-h,2,h,(px,py)=>STEM[px<x+ox?2:1]);
   L.ell(x+ox,y+oy-h,r,r*.55,(px,py,dx,dy)=>dy<.1?SHROOM[dx<-.3&&dy<-.3?2:dx<.3?1:0]:-1);if(r>4){L.set(x+ox-2,y+oy-h-1,SHROOM[2]);L.set(x+ox+2,y+oy-h,SHROOM[2])}}
  return[{x,y:y-8,r:42,i:.95,c:[1.32,.72,.6],fl:.05}]},
 rubble(L,x,y,R,s){for(let k=0;k<4;k++)blob(L,x+(R()-.5)*14*s,y+(R()-.5)*4*s,(2+R()*2.4)*s,(1.6+R()*1.6)*s,EA,.6,72)},
 boulder(L,x,y,R,s){blob(L,x,y-8*s,14*s,10*s,PALE,.55,73);L.ell(x-2*s,y-14*s,10*s,4*s,(px,py)=>fbm(px/3,py/3,74)>.4?rp(MOSS,.6+(hash(px,py,1)-.5)*.3,px,py):-1)},
};

// 3 · BASALTE ET MOUSSE --------------------------------------------------------
const BS=R_(['#0f0f12','#17171b','#202025','#2a2a30','#36363d','#44444c','#56555e','#6c6a74']);
const GRV=R_(['#2f2c28','#3c3833','#4b463f','#5b554c','#6c655b','#7f776b']);
const WATER=R_(['#141c24','#1d2730','#27333e','#34424e']);
const CALC=R_(['#5a564c','#857f70','#b0a894','#d8d0bc']);
const LICHEN=['#a8a070','#e6dca0','#fff6c8'].map(E);
function hexCell(x,y,s){const hy=s*.87,row=Math.floor(y/hy);let best=1e9,sec=1e9,id=0,cx0=0,cy0=0;for(let r=row-1;r<=row+1;r++){const off=(r&1)*s/2;for(let c=Math.floor((x-off)/s)-1;c<=Math.floor((x-off)/s)+1;c++){const cx=c*s+off+s/2,cy=r*hy+hy/2,d=Math.hypot(x-cx,(y-cy)*1.15);if(d<best){sec=best;best=d;id=c*131+r;cx0=cx;cy0=cy}else if(d<sec)sec=d}}return{id,e:sec-best,dx:x-cx0,dy:y-cy0}}
const basalte={id:'basalte',seed:37,name:'Basalte et mousse',H:[62,46,36],lip:BS[7],lip2:BS[5],side:BS[1],altar:BS,lightKind:'lichen',
 tag:'Le plus graphique',
 desc:'Orgues basaltiques : le dessus de la roche montre des colonnes hexagonales, les parois des colonnes verticales de hauteurs inégales qui dentellent l’arête. Sol de gravier sombre avec flaques. Stalactites de calcite pâle pour trancher sur le noir, lichen luminescent crème.',
 pros:'Silhouette des parois très reconnaissable ; l’arête crénelée casse l’effet « grille ». Les stalactites pâles ressortent fort.',cons:'Le plus sombre : de nuit, la caverne dépend beaucoup de ses lumières. Le noir du basalte côtoie celui de l’Ancre.',
 chips:[...hexs(BS),...hexs(GRV).slice(1,5),'#e6dca0'],
 top(x,y){const h=hexCell(x,y,9);if(h.e<1.1)return BS[1];let v=.42+(hash(h.id,0,81)-.5)*.22+(h.dx+h.dy<-3?.12:0)+(h.dx+h.dy>4?-.1:0);if(fbm(x/12,y/9,82)>.66)return rp(MOSS,v+.1,x,y);return rp(BS,v,x,y)},
 face(x,ly,H,y,out){const c=Math.floor(x/7),lu=x-c*7,top=Math.floor(hash(c,9,83)*5);if(ly<top)return null;if(ly===top)return BS[7];
  if(out&&ly<top+3+Math.floor(hash(x,2,84)*4))return rp(MOSS,.8-(ly-top)*.12,x,y);if(lu===6)return BS[0];if((ly+Math.floor(hash(c,0,85)*20))%17===0)return BS[1];
  return rp(BS,.62-ly/H*.32+(lu<2?.16:lu>4?-.1:0)+(hash(c,Math.floor(ly/6),86)-.5)*.08,x,y)},
 floor(x,y){const f=fbm(x/16,y/12,63);if(f>.68){const hl=f>.72&&((x+y*3)%11===0);return hl?BS[6]:rp(WATER,.3+(f-.68)*3+(hash(x,y>>1,64)-.5)*.2,x,y)}
  if(f>.655)return GRV[0];const g=hash(x>>1,y>>1,65);let v=.42+(g-.5)*.32+(fbm(x/7,y/6,66)-.5)*.2;if(g>.93)v+=.2;return rp(GRV,v,x,y)},
 dug(x,y){const h=hexCell(x,y,5);if(hash(h.id,1,67)>.75&&h.e>1)return rp(BS,.5,x,y);return rp(GRV,.3+fbm(x/5,y/5,68)*.4,x,y)},
 path(x,y){if(fbm(x/7,y/5,69)>.68)return rp(MOSS,.5,x,y);return rp(GRV,.35+(hash(x>>1,y>>1,70)-.5)*.4+fbm(x/9,y/9,71)*.2,x,y)},
 stalac(L,x0,yt,w,H,R){const n=3+Math.floor(R()*3);for(let k=0;k<n;k++){const x=x0+3+R()*(w-6),len=4+R()*H*(k===0?.5:.3);icicle(L,x,yt,1+R()*1.4,len,CALC,0,.5)}},
 stalag(L,x,y,R,s){for(const[ox,hh,wd]of[[-5,9,4],[2,15,4],[7,6,3]]){const X=x+ox*s,Hh=hh*s*(.8+R()*.4),W=wd*s;L.rect(X-W,y-Hh,W*2,Hh,(px,py)=>rp(BS,(px<X-W+2?.7:px>X+W-2?.3:.5)-(py-y+Hh)/Hh*.1,px,py));L.ell(X,y-Hh,W,W*.5,(px,py)=>rp(BS,.85,px,py))}},
 light(L,x,y,R){blob(L,x,y-4,8,5,BS,.45,87);for(let k=0;k<26;k++){const a=R()*6.283,d=Math.sqrt(R());const px=x+Math.cos(a)*9*d,py=y-5+Math.sin(a)*5*d;L.set(px,py,LICHEN[k%3===0?2:k%3])}
  return[{x,y:y-6,r:40,i:.8,c:[1.12,1.08,.8],fl:.03}]},
 rubble(L,x,y,R,s){for(let k=0;k<3;k++){const X=x+(k-1)*7*s+(R()-.5)*3,W=3*s,Hh=(3+R()*3)*s;L.rect(X-W,y-Hh,W*2,Hh,(px,py)=>rp(BS,px<X?.6:.35,px,py));L.ell(X,y-Hh,W,W*.5,(px,py)=>rp(BS,.8,px,py))}},
 boulder(L,x,y,R,s){const W=9*s,Hh=14*s;for(const[ox,k]of[[-W,0],[0,1],[W,.6]]){const X=x+ox,h=Hh*(.6+k*.4);L.rect(X-W/2,y-h,W,h,(px,py)=>rp(BS,px<X-W/2+2?.65:.4,px,py));L.ell(X,y-h,W/2,W/4,(px,py)=>fbm(px/3,py/2,88)>.45?rp(MOSS,.7,px,py):rp(BS,.85,px,py))}},
};

// 4 · CALCAIRE ET GOURS ---------------------------------------------------------
const LM=R_(['#3a3328','#504739','#685d4b','#82765f','#9c8f75','#b5a88b','#cdc0a2','#e2d7bc']);
const CL=R_(['#3a3024','#4a3d2e','#5a4b38','#6b5a43','#7c6a50','#8e7a5e']);
const POOL=R_(['#2c3632','#36433d','#43514a','#536157']);
const calcaire={id:'calcaire',seed:53,name:'Calcaire et gours',H:[60,44,34],lip:LM[7],lip2:LM[5],side:LM[2],altar:LM,lightKind:'puits',
 tag:'La grotte claire',
 desc:'Roche calcaire pâle et chaude, creusée de rigoles (lapiaz) sur le dessus, drapée de coulées verticales sur les parois. Sol d’argile ocre ponctué de gours, ces petits bassins en terrasses. Stalactites et stalagmites classiques en cônes annelés ; pas de minéral lumineux : la lumière tombe de puits ouverts dans la voûte, chaude le jour et lunaire la nuit.',
 pros:'La plus lisible de jour et la plus naturaliste. Les puits de lumière donnent des zones d’intérêt sans couleur réservée.',cons:'Moins mystérieuse ; la roche claire rapproche le décor du marbre gris de Sigil, à distinguer par le grain.',
 chips:[...hexs(LM),...hexs(CL).slice(2),'#536157'],
 top(x,y){let v=.58+(fbm(x/8,y/6,91)-.5)*.3;if(Math.abs(vnoise(x/6,y/15,92)-.5)<.035)v-=.22;if(fbm(x/4,y/4,93)>.74)v-=.3;if(fbm(x/11,y/9,94)>.74)return rp(MOSS,v,x,y);return rp(LM,v,x,y)},
 face(x,ly,H,y,out){if(ly===0)return LM[7];let v=.64-ly/H*.26+Math.sin(x*1.3+vnoise(x/5,ly/9,95)*6)*.07+(vnoise(x/3,ly/14,96)-.5)*.22;if(ly>H*.78)v-=.12;if(ly%11===3)v+=.06;
  if(out&&hash(x>>2,ly>>2,97)>.93)return rp(LEAF,.6,x,y);return rp(LM,v,x,y)},
 floor(x,y){const f=fbm(x/16,y/11,75);if(f>.7)return f>.72?rp(POOL,.35+(f-.72)*4+(((x*3+y)%13)===0?.4:0),x,y):LM[6];if(f>.675&&f<.685)return LM[5];
  let v=.5+(fbm(x/9,y/7,76)-.5)*.36;if(hash(x>>1,y>>1,77)>.96)v+=.25;return rp(CL,v,x,y)},
 dug(x,y){if(hash(x>>1,y>>1,78)>.85)return rp(LM,.6,x,y);return rp(CL,.3+fbm(x/6,y/5,79)*.4,x,y)},
 path(x,y){return rp(PALE,.35+fbm(x/9,y/7,80)*.4,x,y)},
 stalac(L,x0,yt,w,H,R){const n=2+Math.floor(R()*3);for(let k=0;k<n;k++){const x=x0+3+R()*(w-6),len=7+R()*H*.45,wd=1.6+R()*1.6;icicle(L,x,yt,wd,len,LM,0,.6);for(let r=4;r<len-3;r+=5)L.set(x-wd*(1-r/len)+1,yt+r,LM[7])}
  if(R()<.6){const x=x0+4+R()*(w-14);for(let i=0;i<10;i++){const len=4+Math.abs(Math.sin(i*.9))*8;L.line(x+i,yt,x+i,yt+len,LM[i&1?5:6])}}},
 stalag(L,x,y,R,s){L.ell(x,y,9*s,3*s,(px,py)=>rp(POOL,.5,px,py));cone(L,x,y-1,5*s,22*s,LM,0,.5);cone(L,x+6*s,y,3*s,9*s,LM,0,.45);for(let r=4;r<20*s;r+=5)L.set(x-4*s*(1-r/(22*s))+1,y-1-r,LM[7])},
 light(L,x,y,R){return[{x,y,r:46,i:.55,c:[1.25,1.12,.85],cN:[.62,.76,1.2],always:true,add:.3},{beam:true,x,y,h:Math.min(y,90),w:9,dx:14,c:[1,.92,.7],cN:[.55,.66,.95]}]},
 rubble(L,x,y,R,s){for(let k=0;k<4;k++)blob(L,x+(R()-.5)*14*s,y+(R()-.5)*4*s,(2+R()*2.6)*s,(1.6+R()*1.6)*s,LM,.75,98)},
 boulder(L,x,y,R,s){blob(L,x,y-8*s,14*s,10*s,LM,.7,99);for(let k=0;k<4;k++){L.ell(x-6*s+R()*12*s,y-12*s+R()*8*s,1.6,1.2,LM[1])}L.ell(x+6*s,y-15*s,3,2,(px,py)=>rp(LEAF,.6,px,py))},
};

// 5 · MINE TYRIENNE ------------------------------------------------------------
const MN=R_(['#15110e','#1e1814','#29211b','#352b23','#43372d','#544538','#685545','#7e6854']);
const ORE=R_(['#3e2614','#5e3a1e','#86562e','#b07a44']);
const GV=R_(['#2c2620','#3a322a','#4a4035','#5a4f42','#6c5f50','#807160']);
const LANT=['#ffb860','#ffd890','#fff4d0'].map(E);
const vein=(x,y)=>(Math.abs(vnoise(x/18,y/14,101)-.5)<.012||Math.abs(vnoise(x/11,y/20,102)-.5)<.007)&&vnoise(x/30,y/30,100)>.45;
const mine={id:'mine',seed:71,name:'Mine tyrienne',H:[58,44,34],lip:MN[7],lip2:MN[5],side:MN[1],altar:MN,lightKind:'lanternes',
 tag:'Une caverne déjà exploitée',
 desc:'La salle est une ancienne mine tyrienne : roche brun sombre veinée de cuivre natif, parois marquées de coups de pic et soutenues par des étais de bois, rails sur un sol de gravier compacté. Peu de stalactites, petites et rouillées. Lanternes à huile accrochées aux étais ; un cadre de mine encadre l’entrée du tunnel.',
 pros:'Raconte une histoire (les Tyriens ont creusé avant les Exilés) et justifie le minage de l’Ingénieur. Les étais rythment les parois.',cons:'Le plus chargé en objets. La lumière ambrée des lanternes reste proche de l’orange d’Indra : à garder pâle et discrète.',
 chips:[...hexs(MN).slice(1),...hexs(ORE).slice(1),'#ffd890'],
 top(x,y){if(vein(x,y))return rp(ORE,.55+(hash(x,y,103)-.5)*.4,x,y);if(hash(x,y,104)>.988)return SILVER[2];let v=.4+(fbm(x/8,y/6,105)-.5)*.42;return rp(MN,v,x,y)},
 face(x,ly,H,y,out){if(ly===0)return MN[7];if(vein(x,y*1.6))return rp(ORE,.5+(hash(x,ly,106)-.5)*.4,x,y);if(((x*2+ly)%9===0)&&hash(x>>2,ly>>2,107)>.45)return MN[1];
  let v=.6-ly/H*.32+(fbm(x/6,ly/5,108)-.5)*.3;if(out&&ly<5&&hash(x,0,109)>.4)return rp(GRASS,.6-ly*.1,x,y);if(out&&hash(x>>1,1,110)>.8&&ly>4)v+=.1;return rp(MN,v,x,y)},
 floor(x,y){const g=hash(x>>1,y>>1,111);let v=.45+(g-.5)*.3+(fbm(x/10,y/8,112)-.5)*.3;if(g>.95)return rp(ORE,.5,x,y);return rp(GV,v,x,y)},
 dug(x,y){if(hash(x>>1,y>>1,113)>.82)return hash(x,y,114)>.6?rp(ORE,.6,x,y):rp(MN,.6,x,y);return rp(GV,.25+fbm(x/6,y/5,115)*.4,x,y)},
 path(x,y){return rp(GV,.4+fbm(x/9,y/7,116)*.4,x,y)},
 decal(P,D){if(D.rails==null)return;const[x0,y0,y1]=D.rails;for(let y=y0;y<y1;y++){if(y%6<2)for(let x=x0-7;x<=x0+7;x++)P.set(x,y,rp(WOOD,y%6?.45:.65,x,y));for(const rx of[x0-5,x0+5]){P.set(rx,y,SILVER[3]);P.set(rx+1,y,SILVER[1])}}},
 faceProp(L,x0,yb,H,out){const top=yb-H+3;for(const px of[x0+3,x0+T-6])L.rect(px,top,3,H-3,(x,y)=>rp(WOOD,x===px?.75:.45,x,y));L.rect(x0+1,top,T-2,3,(x,y)=>rp(WOOD,y===top?.8:.5,x,y))},
 extras(D){const o=[];if(D.portal){const[x0,x1,yb,h]=D.portal;o.push({y:yb+.2,layer:true,draw:L=>{for(const px of[x0,x1-4])L.rect(px,yb-h,4,h,(x,y)=>rp(WOOD,x===px?.8:.45,x,y));L.rect(x0-3,yb-h-4,x1-x0+6,5,(x,y)=>rp(WOOD,y===yb-h-4?.85:.5,x,y))}})}return o},
 stalac(L,x0,yt,w,H,R){const n=1+Math.floor(R()*2);for(let k=0;k<n;k++){const x=x0+4+R()*(w-8);icicle(L,x,yt,1.2,4+R()*7,ORE,0,.35)}},
 stalag(L,x,y,R,s){cone(L,x,y,6*s,14*s,MN,0,.45);cone(L,x+5*s,y+1,3*s,7*s,MN,0,.4);L.line(x-1,y-12*s,x-2,y-3,ORE[1])},
 light(L,x,y,R){L.rect(x-1,y-24,3,24,(px,py)=>rp(WOOD,px===x-1?.8:.45,px,py));L.rect(x-1,y-24,8,2,WOOD[3]);L.line(x+5,y-22,x+5,y-19,SILVER[1]);
  L.rect(x+3,y-19,5,7,(px,py)=>px===x+3||px===x+7||py===y-19||py===y-13?MN[2]:LANT[py<y-16?2:1]);L.rect(x+4,y-20,3,1,MN[3]);
  return[{x:x+5,y:y-15,r:50,i:.95,c:[1.3,.88,.5],fl:.35}]},
 rubble(L,x,y,R,s){for(let k=0;k<4;k++){const X=x+(R()-.5)*14*s,Y=y+(R()-.5)*4*s;L.poly([[X-3*s,Y],[X-2*s,Y-3*s],[X+2*s,Y-4*s],[X+3*s,Y]],(px,py)=>hash(px,py,117)>.8?ORE[3]:rp(MN,py<Y-2?.7:.45,px,py))}},
 boulder(L,x,y,R,s){blob(L,x,y-8*s,14*s,10*s,MN,.6,118);for(let k=0;k<12;k++)L.set(x-8*s+R()*16*s,y-12*s+R()*8*s,ORE[2+(k&1)])},
};

const STYLES=[ardoise,terre,basalte,calcaire,mine];

// ---------- scène principale : jungle → tunnel → salle → galerie creusée ----------
const MAIN={map:[
 'RRRRRRRRRRRR',
 'RRRRRRRRRRRR',
 'RR.......RRR',
 'R.........RR',
 'R........ddc',
 'RR.......RRR',
 'RRRR...RRRRR',
 'RRRR...RRRRR',
 'gggggggggggg',
 'gggggggggggg'],out:8,bigRow:1,pathX:176,rails:[176,150,256],portal:[128,224,256,30],props:true,crack:{11:2},
 objs:[{k:'stalag',x:46,y:112},{k:'stalag',x:272,y:110,s:.8},{k:'stalag',x:62,y:178,s:.9},{k:'stalag',x:122,y:226,s:.7},
  {k:'light',x:96,y:96},{k:'light',x:268,y:166},{k:'rubble',x:240,y:96},{k:'rubble',x:84,y:160,s:.8},{k:'rubble',x:300,y:150,s:.7},
  {k:'altar',x:176,y:128},{k:'eng',x:132,y:150},{k:'eng',x:328,y:154},
  {k:'boulder',x:52,y:300},{k:'boulder',x:310,y:290,s:.8},{k:'boulder',x:262,y:316,s:.6},{k:'rubble',x:96,y:278,s:.7}]};
const ITEMS=[
 {id:'sol',label:'Sol de caverne',D:{map:['..','..'],objs:[{k:'eng',x:32,y:46}]}},
 {id:'roche',label:'Bloc de roche',D:{map:['...','.R.','...'],stalac:false}},
 {id:'paroi',label:'Paroi intérieure',D:{map:['RR','RR','..'],bigRow:1,stalac:false}},
 {id:'stalac',label:'Stalactites',D:{map:['RR','RR','..'],bigRow:1,stalac:'force'}},
 {id:'stalag',label:'Stalagmite',D:{map:['..','..'],objs:[{k:'stalag',x:30,y:44}]}},
 {id:'light',label:'Lumière',D:{map:['..','..'],objs:[{k:'light',x:30,y:44}]}},
 {id:'eboulis',label:'Éboulis',D:{map:['..','..'],objs:[{k:'rubble',x:20,y:22,s:.8},{k:'rubble',x:40,y:44}]}},
 {id:'minage',label:'Minage · 3 stades',D:{map:['ccc','...'],crack:{0:1,1:2,2:3},stalac:false}},
 {id:'creuse',label:'Case creusée',D:{map:['RRR','.d.','...'],stalac:false}},
 {id:'falaise',label:'Falaise extérieure',D:{map:['RR','RR','gg'],out:2}},
 {id:'bloc',label:'Bloc extérieur',D:{map:['gg','gg'],objs:[{k:'boulder',x:32,y:46}]}},
 {id:'autel',label:'Autel de l’Ancre',D:{map:['..','..'],objs:[{k:'altar',x:32,y:50}]}},
 {id:'sentier',label:'Sentier',D:{map:['gg','gg'],pathX:32}}];
function item(St,it){const D={...it.D};if(it.id==='light'&&St.lightKind==='lanternes')D.objs=[{k:'light',x:26,y:50}];if(it.id==='stalac'&&St.id==='mine')D.stalac='prop';return build(St,D)}
const LIGHT_NAMES={quartz:'Quartz laiteux',champignons:'Champignons',lichen:'Lichen luminescent',puits:'Puits de lumière',lanternes:'Lanterne d’étai'};
return{STYLES,MAIN,ITEMS,LIGHT_NAMES,build,item,ambient}})();
