// Martyre de Byrsa, version détaillée : figure, poses continues (repos, marche, frappe, lancers) et attaques à
// distance. Rendu pixel : trame de Bayer, contour noir, lueurs hors contour. ~77 px de haut (2 × un humain).
'use strict';
const MartyreV2=(()=>{
const OUT='#0b090b',FW=150,FH=120,CX=60,FY=114;
const B4=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map(r=>r.map(v=>(v+.5)/16));
const bay=(x,y)=>B4[y&3][x&3],cl=(v,a=0,b=1)=>v<a?a:v>b?b:v,lerp=(a,b,u)=>a+(b-a)*u;
const ease=x=>x*x*(3-2*x),easeOut=x=>1-(1-x)*(1-x),back=x=>{const c=1.7;return 1+(c+1)*Math.pow(x-1,3)+c*Math.pow(x-1,2)};
function rng(s){return()=>{s=(s*1664525+1013904223)>>>0;return s/4294967296}}

/* ---------- palettes (charte : carmin = la Bête, or = le Credo) ---------- */
const PAL={
 skin:['#2e1e20','#563a38','#8a6660','#b89282','#dcbca8','#f4e2d2'],
 hair:['#221e1a','#433c32','#686048','#928868','#bcb08c','#ddd4b4'],
 horn:['#1e120a','#3a2412','#5c3c1e','#86602e','#b08a48','#d8b878'],
 robe:['#3a3428','#5e5644','#8a806a','#b4aa90','#d6ceb4','#eee8d4'],
 gold:['#3a280c','#6a4a16','#a07424','#d0a038','#f0cc66','#fff2b0'],
 blood:['#200406','#4a0a0e','#7e1216','#b41c20','#e2382e','#ff8a6a'],
 ichor:['#060606','#121014','#1e1a1e','#2c2628','#3c3436'],
 cape:['#0a080a','#161216','#241c22','#33282e','#46363c'],
 shaft:['#1e120a','#3a2412','#5c3c1e','#86602e','#b08a48'],
};
const EYE=['#5a0c10','#ff5a40','#ffd0a0'];

/* ---------- tampon pixel ---------- */
class Px{constructor(w,h){this.w=w;this.h=h;this.c=new Array(w*h).fill(null);this.n=new Uint8Array(w*h);this.fx=new Array(w*h).fill(null)}
 set(x,y,c,no){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=this.w||y>=this.h||!c)return;this.c[y*this.w+x]=c;this.n[y*this.w+x]=no?1:0}
 fxs(x,y,c,a=1){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=this.w||y>=this.h||!c)return;if(a<1&&a<=bay(x,y))return;this.fx[y*this.w+x]=c}}
const sh=(r,v,x,y)=>{v=cl(v);const f=v*(r.length-1),i=Math.floor(f);return r[Math.min(r.length-1,f-i>bay(x&3,y&3)?i+1:i)]};
function ell(P,cx,cy,rx,ry,r,o={}){const v0=o.v??.6,l=o.l??.32,edge=o.edge??.22;
 for(let y=Math.floor(cy-ry-1);y<=cy+ry+1;y++)for(let x=Math.floor(cx-rx-1);x<=cx+rx+1;x++){
  const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry,d=dx*dx+dy*dy;if(d>1)continue;
  let v=v0+l*(-dx*.55-dy*.6)-(o.rim??.1)*d;const dx2=(x+1.5-cx)/rx,dy2=(y+1.5-cy)/ry;if(edge&&(dx2*dx2+dy*dy>1||dx*dx+dy2*dy2>1))v-=edge;
  if(o.spec&&d<.12&&dx<0&&dy<0)v+=o.spec;P.set(x,y,sh(r,v,x,y))}}
function inPoly(pts,x,y){let c=false;for(let i=0,j=pts.length-1;i<pts.length;j=i++){const[a,b]=pts[i],[e,f]=pts[j];if((b>y)!==(f>y)&&x<(e-a)*(y-b)/(f-b)+a)c=!c}return c}
function poly(P,pts,r,o={}){let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;for(const[x,y]of pts){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
 const cx=(x0+x1)/2,cy=(y0+y1)/2,hw=Math.max(1,(x1-x0)/2),hh=Math.max(1,(y1-y0)/2),v0=o.v??.55,l=o.l??.3,edge=o.edge??.2;
 for(let y=Math.floor(y0);y<=y1;y++)for(let x=Math.floor(x0);x<=x1;x++){if(!inPoly(pts,x+.5,y+.5))continue;
  const nx=(x+.5-cx)/hw,ny=(y+.5-cy)/hh;let v=v0+l*(-nx*.5-ny*.35);
  if(o.fold){const u=(y-y0)/(y1-y0||1);v+=o.fold*Math.sin((x+.5-cx-(o.foldDx||0)*u)/(1.2+u*1.6)*1.7+(o.foldPh||0))}
  if(o.grad)v+=o.grad*((y-y0)/(y1-y0||1)-.5);
  if(edge&&(!inPoly(pts,x+1.5,y+.5)||!inPoly(pts,x-.5,y+.5)||!inPoly(pts,x+.5,y+1.5)))v-=edge;
  P.set(x,y,sh(r,v,x,y))}}
function seg(P,a,b,w,r,o={}){const[ax,ay]=a,[bx,by]=b,L=Math.hypot(bx-ax,by-ay)||1,ux=(bx-ax)/L,uy=(by-ay)/L,R=w/2;
 for(let y=Math.floor(Math.min(ay,by)-R-1);y<=Math.max(ay,by)+R+1;y++)for(let x=Math.floor(Math.min(ax,bx)-R-1);x<=Math.max(ax,bx)+R+1;x++){
  const px=x+.5-ax,py=y+.5-ay,t=cl((px*ux+py*uy)/L),qx=px-ux*L*t,qy=py-uy*L*t,d=Math.hypot(qx,qy);if(d>R)continue;
  let v=(o.v??.58)-(o.l??.28)*((qx+qy)/R)*.45;if(d>R-1)v-=o.edge??.18;P.set(x,y,sh(r,v,x,y))}}
function line(P,x0,y0,x1,y1,c,fx,a){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let i=0;i<=n;i++){const x=x0+(x1-x0)*i/n,y=y0+(y1-y0)*i/n;fx?P.fxs(x,y,c,a):P.set(x,y,c)}}
function bez(p,t){const u=1-t;return[0,1].map(k=>u*u*u*p[0][k]+3*u*u*t*p[1][k]+3*u*t*t*p[2][k]+t*t*t*p[3][k])}
function horn(P,pts,r0,r1,ramp,o={}){const n=50;for(let i=0;i<=n;i++){const t=i/n,[x,y]=bez(pts,t),r=r0+(r1-r0)*t;
  const band=Math.floor(t*(o.bands||12))%2?-.12:.05;ell(P,x,y,Math.max(.6,r),Math.max(.6,r),ramp,{v:(o.v??.48)+band+t*.2,l:.45,edge:0,rim:.25})}}
function disc(P,x,y,r,c,a=1){for(let j=Math.floor(y-r);j<=y+r;j++)for(let i=Math.floor(x-r);i<=x+r;i++){const d=Math.hypot(i+.5-x,j+.5-y)/r;if(d<=1)P.fxs(i,j,c,a*(1-d*d*.7))}}
function glow(P,x,y,r,cols,a=1){disc(P,x,y,r,cols[0],a*.55);disc(P,x,y,r*.55,cols[1],a*.85);P.fxs(x,y,cols[2],a)}
function ring(P,x,y,r,ry,c,a,th=1.2){const n=Math.ceil(r*7);for(let k=0;k<n;k++){const g=k/n*Math.PI*2;for(let w=0;w<th;w+=.7)P.fxs(x+Math.cos(g)*(r+w),y+Math.sin(g)*(ry+w*ry/r),c,a)}}
const GLY=[['.#.','###','.#.','#.#'],['##.','.#.','.##','.#.'],['#.#','.#.','#.#','###'],['###','#..','##.','#..'],['.#.','#.#','.#.','.#.'],['#..','###','..#','.##']];
function glyph(P,x,y,g,c,a=1){GLY[g%GLY.length].forEach((row,j)=>[...row].forEach((ch,i)=>{if(ch==='#')P.fxs(x+i,y+j,c,a)}))}
const RGB={};const rgb=h=>RGB[h]||(RGB[h]=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)));
function raster(P){const W=P.w,H=P.h,c=document.createElement('canvas');c.width=W;c.height=H;const g=c.getContext('2d'),im=g.createImageData(W,H),d=im.data;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;let col=P.c[i];
  if(!col){for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;if(X>=0&&Y>=0&&X<W&&Y<H&&P.c[Y*W+X]&&!P.n[Y*W+X]){col=OUT;break}}}
  const f=P.fx[i];if(f)col=f;
  if(col){const[r,gg,b]=rgb(col);d[i*4]=r;d[i*4+1]=gg;d[i*4+2]=b;d[i*4+3]=255}}
 g.putImageData(im,0,0);return c}

/* ---------- trois niveaux de détail ---------- */
const VARIANTS=[
 {id:'gravee',name:'A · Armure gravée',desc:'La silhouette retenue, enrichie : cuirasse gravée d’un soleil, rivets, tassettes d’or sur la robe, épaulières à trois lames, gantelets articulés. Les fêlures rouges respirent lentement. Cape noire doublée de carmin, bas effiloché ; mèches pâles qui suivent le corps avec retard ; deux rubans carmin au disque du bâton.',
  crack:1,halo:false,filigree:true,veins:false},
 {id:'reliquaire',name:'B · Reliquaire solaire',desc:'A, plus un nimbe d’or ajouré derrière la tête, dont les rayons tournent au ralenti, et des glyphes du Credo qui courent sur l’ourlet de la robe. Plus « sainte », plus lisible de loin : le nimbe dépasse au-dessus des arbres.',
  crack:1,halo:true,filigree:true,veins:false,hemGlyphs:true},
 {id:'fendue',name:'C · Martyre fendue',desc:'A, rongée par la Bête : l’or est plus terne, les fêlures s’ouvrent en larges failles de lumière carmin qui palpitent, des veines rouges gagnent le cou et les bras, l’ichor goutte du bas de la cuirasse. Plus inquiétante, annonce une phase 2.',
  crack:2,halo:false,filigree:false,veins:true,dull:true},
];

/* ---------- figure ---------- */
// s : {v, t, by, crouch, lean, sw (cape), hair, hand [x,y], ang (bâton, 0 = vertical), disc (attaché), plates (0..1),
//      armL [x,y], feet (phase de marche ou null), k (lueur des fêlures 0..1), cast (lueur de la main gauche 0..1)}
let CUR=0;
function figure(P,s,ox=0,oy=0){const V=VARIANTS[s.v??CUR],p=PAL,t=s.t,by=s.by||0,cr=s.crouch||0,ln=s.lean||0,sw=s.sw||0,hl=s.hair||0;
 const gold=V.dull?['#2e220e','#56401a','#82642a','#a88438','#c8a654','#e4d090']:p.gold;
 const Q=(x,y)=>{const k=(FY-y)/(FY-36);return[x+ln*k+ox,y+(by+cr)*k+oy]};
 const QP=pts=>pts.map(([x,y])=>Q(x,y));
 const [hx,hy]=Q(60,44);
 // nimbe (B)
 if(V.halo){const[cx,cy]=Q(60,40);for(let k=0;k<96;k++){const g=k/96*Math.PI*2,x=cx+Math.cos(g)*13,y=cy+Math.sin(g)*13;P.set(x,y,gold[k%4?3:4]);if(k%3===0)P.set(cx+Math.cos(g)*12,cy+Math.sin(g)*12,gold[2])}
  for(let k=0;k<12;k++){const g=k/12*Math.PI*2+t*.25;line(P,cx+Math.cos(g)*14,cy+Math.sin(g)*14,cx+Math.cos(g)*(k%2?16:18),cy+Math.sin(g)*(k%2?16:18),gold[3])}}
 // cape, bas effiloché qui suit avec retard
 const hem=[];for(let i=10;i>=0;i--){const u=i/10;hem.push(Q(39+sw*1.2+u*42+sw*u*.6,FY-1-(i%2?3.5:0)-Math.sin(t*3.1+i*1.7)*.7))}
 poly(P,[Q(46,53),Q(74,53),...hem],p.cape,{v:.42,fold:.2,foldDx:sw*2.5,edge:.15});
 for(const side of[0,1]){const a=side?Q(74,54):Q(46,54),b=side?hem[0]:hem[hem.length-1];line(P,lerp(a[0],b[0],.15),lerp(a[1],b[1],.15),lerp(a[0],b[0],.97),lerp(a[1],b[1],.97),p.blood[side?2:3])}
 // cheveux dans le dos
 poly(P,QP([[53.5,41],[66.5,41],[69+hl,62],[66+hl*1.3,71],[61+hl*1.2,73],[55+hl*1.3,71],[51+hl,62]]),p.hair,{v:.45,fold:.22,foldDx:hl*2});
 // corne intacte (gauche), en deux arcs
 horn(P,[Q(55.5,40),Q(50,28.5),Q(41,26.5),Q(36.5,33.5)],3.2,1.5,p.horn,{bands:13});horn(P,[Q(36.5,33.5),Q(34.5,39),Q(38,43.5),Q(42.5,42)],1.5,.6,p.horn,{bands:6,v:.6});
 // robe
 poly(P,QP([[52,74],[68,74],[76.5+sw*.5,FY],[60,FY+.5],[43.5+sw*.4,FY]]),p.robe,{v:.62,fold:.2,foldDx:sw*1.4});
 for(let x=45;x<=75;x++){const[qx,qy]=Q(x,FY-2.5);P.set(qx,qy,(x%3===0)?gold[4]:gold[2]);if(x%3===1){const[a,b]=Q(x,FY-1.5);P.set(a,b,gold[3])}}
 if(V.hemGlyphs)for(let k=0;k<5;k++){const[gx,gy]=Q(47+k*6,FY-9);GLY[(k+Math.floor(t*1.5))%6].forEach((row,j)=>[...row].forEach((ch,i)=>{if(ch==='#')P.set(gx+i,gy+j,gold[(k+Math.floor(t*3))%5===0?5:3])}))}
 const R=rng(23);for(let i=0;i<26;i++){const x=46+R()*29,y=FY-1-R()*6;const[a,b]=Q(x,y);P.set(a,b,p.ichor[1+(i%2)])}
 // pieds (marche)
 if(s.feet!=null)for(const k of[0,1]){const ph=s.feet*Math.PI*2+k*Math.PI,lift=Math.max(0,Math.sin(ph));ell(P,55+k*10+Math.cos(ph)*3+ox,FY-1-lift*1.6+oy,2.8,1.8,gold,{v:.5})}
 // tassettes
 for(const[x0,x1,d]of[[51.5,56,-1],[57,63,0],[64,68.5,1]]){poly(P,QP([[x0,74],[x1,74],[x1+.6+d*1.2,84+(d?0:1.5)],[x0-.6+d*1.2,84+(d?0:1.5)]]),gold,{v:.5,edge:.28});const[a,b]=Q((x0+x1)/2,77);P.set(a,b,gold[5]);const[c2,d2]=Q((x0+x1)/2,85);P.set(c2,d2,gold[1])}
 // cuirasse
 poly(P,QP([[47.5,54],[72.5,54],[70,63],[66.5,74.5],[53.5,74.5],[50,63]]),gold,{v:.52,l:.42,edge:.25});
 {const[cx,cy]=Q(60,63);for(let k=0;k<20;k++){const g=k/20*Math.PI*2;P.set(cx+Math.cos(g)*3.2,cy+Math.sin(g)*3.2,gold[1])}
  for(let k=0;k<8;k++){const g=k/8*Math.PI*2+.2;line(P,cx+Math.cos(g)*4.4,cy+Math.sin(g)*4.4,cx+Math.cos(g)*(k%2?5.4:6.4),cy+Math.sin(g)*(k%2?5.4:6.4),gold[1])}P.set(cx,cy,gold[5]);P.set(cx-1,cy-1,gold[4])}
 if(V.filigree)for(const[x,y]of[[49.5,56],[70.5,56],[54.5,72.5],[65.5,72.5],[60,55.5]]){const[a,b]=Q(x,y);P.set(a,b,gold[5])}
 {const[a,b]=Q(53.5,74.5),[c2,d2]=Q(66.5,74.5);line(P,a,b,c2,d2,p.ichor[3]);const[e,f]=Q(60,74.5);P.set(e,f,gold[5]);P.set(e-1,f,gold[4]);P.set(e+1,f,gold[4])}
 // fêlures : tracé net, lueur hors contour qui respire
 const k=s.k??.5,cracks=V.crack>1?[[[53,56],[56,61],[54,66],[57,71]],[[66,55],[64,59],[67,63]],[[58,66],[61,69],[60,73]],[[69,60],[66,66]]]:[[[54,56],[57,62],[55,67]],[[66,55],[64.5,59]]];
 for(const c of cracks)for(let i=0;i+1<c.length;i++){const[a,b]=Q(...c[i]),[e,f]=Q(...c[i+1]);line(P,a,b,e,f,p.blood[4]);if(V.crack>1){line(P,a+1,b,e+1,f,p.blood[3])}
  const n=4;for(let j=0;j<=n;j++){const x=lerp(a,e,j/n),y=lerp(b,f,j/n);disc(P,x,y,V.crack>1?2.6:1.8,p.blood[3],.25+.45*k)}}
 if(V.crack>1){const d=(t*.7)%1;const[a,b]=Q(57,75);P.fxs(a,b+d*7,p.blood[3])}
 // cou, gorgerin
 seg(P,Q(60,49),Q(60,54),4.6,p.skin,{v:.42});
 poly(P,QP([[54,52],[66,52],[68,55.5],[52,55.5]]),gold,{v:.62,edge:.25});
 if(V.veins){const[a,b]=Q(58.5,50);line(P,a,b,a-1,b+3,p.blood[3]);const[c2,d2]=Q(61.5,49.5);line(P,c2,d2,c2+1,d2+3,p.blood[3])}
 // tête
 ell(P,hx,hy,5.8,6.6,p.skin,{v:.66,l:.36});
 const g=s.eyes||0;for(const ex of[hx-2.5,hx+1.5]){P.set(ex,hy-1,p.skin[2]);P.set(ex+1,hy-1,p.skin[2]);P.set(ex,hy,EYE[0]);P.set(ex+1,hy,g>.5?EYE[2]:EYE[1]);if(g>0)P.fxs(ex+1,hy-1,EYE[1],g*.6)}
 P.set(hx+.5,hy+2,p.skin[3]);P.set(hx,hy+4,p.blood[2]);P.set(hx+1,hy+4,p.blood[2]);
 line(P,hx,hy-6,hx,hy-4,p.blood[2]);P.set(hx-1,hy-6,p.blood[3]);P.set(hx+1,hy-5,p.blood[2]);
 line(P,hx-2.5,hy+1,hx-2.5,hy+3,p.blood[2]);line(P,hx+2.5,hy+1,hx+2.5,hy+4,p.blood[2]);{const d=(t*.8)%1;if(d<.7)P.fxs(hx+2.5,hy+5+d*7,p.blood[4])}
 // chevelure : calotte, mèches devant les épaules
 poly(P,[[hx-6,hy-1],[hx-5.5,hy-5],[hx-2,hy-7.4],[hx+2,hy-7.4],[hx+5.5,hy-5],[hx+6,hy-1],[hx+4,hy-4.5],[hx+.5,hy-6],[hx-4,hy-4.5]],p.hair,{v:.52,edge:.2});
 poly(P,[[hx-6,hy-2],[hx-4.4,hy-2],[hx-4.6,hy+6],[hx-6.2+hl*.7,hy+17],[hx-8+hl*.7,hy+15]],p.hair,{v:.6,fold:.12});
 for(let i=0;i<3;i++)line(P,hx-5.5+i*.5,hy+2+i*3,hx-6.5+hl*.6,hy+9+i*3,p.hair[2+(i%2)]);
 // corne brisée (droite), éclat à vif
 horn(P,[Q(64.5,40),Q(68.5,35),Q(70.5,32.5),Q(71.5,31.5)],3.2,2.5,p.horn,{bands:6});{const[a,b]=Q(71.5,31.5);P.set(a,b-1.5,p.horn[5]);P.set(a+1.5,b-.5,p.horn[4]);P.set(a+.5,b-2.5,p.horn[3])}
 // épaulières à trois lames (absentes si lancées : plates < 1)
 const pl=s.plates??1;for(const[cx,sd]of[[47,-1],[73,1]]){if(pl<=0)continue;for(let i=2;i>=0;i--){const[a,b]=Q(cx+sd*i*.4,56+i*2.6);ell(P,a,b,(5.6-i*.7)*pl+.3,(3.4-i*.4)*pl+.3,gold,{v:.58-i*.06,edge:.26,spec:.25})}
  const[a,b]=Q(cx,56);P.set(a,b-1,gold[5])}
 // bras gauche
 const ls=Q(47,59),lh=s.armL||Q(45,79),le=[lerp(ls[0],lh[0],.5)-2.2,lerp(ls[1],lh[1],.5)];
 seg(P,ls,le,5,gold,{v:.5});seg(P,le,lh,4.4,gold,{v:.56});ell(P,lh[0],lh[1]+1.5,2.8,3,gold,{v:.6,spec:.2});for(let i=0;i<3;i++)P.set(lh[0]-1.5+i*1.5,lh[1]+3.6,gold[1]);
 if(V.veins){line(P,le[0],le[1],le[0]+1,le[1]+4,p.blood[3])}
 if(s.cast>0)glow(P,lh[0],lh[1]+1,4+s.cast*3,[gold[3],gold[4],gold[5]],s.cast);
 // bâton et bras droit
 const hand=s.hand||Q(78,73),ang=s.ang||0,dx=Math.sin(ang),dy=-Math.cos(ang),top=[hand[0]+dx*40,hand[1]+dy*40],bot=[hand[0]-dx*36,hand[1]-dy*36];
 seg(P,bot,top,2.6,p.shaft,{v:.52,edge:.12});
 for(let i=-30;i<=34;i+=10){P.set(hand[0]+dx*i,hand[1]+dy*i,gold[4]);P.set(hand[0]+dx*i+dy*.9,hand[1]+dy*i-dx*.9,gold[3])}
 if(s.disc!==false){const dc=[top[0]+dx*4,top[1]+dy*4];
  // rubans carmin noués sous le disque
  for(const r of[0,1]){let x=top[0]-dx*2,y=top[1]-dy*2;for(let j=1;j<=9;j++){const wv=Math.sin(t*6-j*.8+r*1.7)*(j*.22);x+=(r?1.1:-.4)+wv*.4;y+=.95+Math.abs(wv)*.2;P.set(x,y,p.blood[j<4?4:3])}}
  ell(P,dc[0],dc[1],5.6,5.6,gold,{v:.7,spec:.3,edge:.25});ell(P,dc[0],dc[1],2.1,2.1,p.blood,{v:.85,edge:0});P.set(dc[0]-.6,dc[1]-.6,p.blood[5]);
  for(let i=0;i<8;i++){const gg=i/8*Math.PI*2+t*.6;line(P,dc[0]+Math.cos(gg)*6.6,dc[1]+Math.sin(gg)*6.6,dc[0]+Math.cos(gg)*(i%2?7.6:8.6),dc[1]+Math.sin(gg)*(i%2?7.6:8.6),gold[i%2?3:4])}
  if(s.discGlow)glow(P,dc[0],dc[1],6+s.discGlow*6,[gold[3],gold[4],gold[5]],s.discGlow)}
 const rs=Q(73,59),re=[lerp(rs[0],hand[0],.5)+2.4,lerp(rs[1],hand[1],.5)+1];
 seg(P,rs,re,5,gold,{v:.52});seg(P,re,hand,4.4,gold,{v:.58});ell(P,hand[0],hand[1],2.9,3.1,gold,{v:.62,spec:.2});P.set(hand[0]-1,hand[1]+2,gold[1]);
 const info={top,hand,disc:s.disc!==false?[top[0]+dx*4,top[1]+dy*4]:null,Q,hx,hy,cracks:cracks.map(c=>c.map(q=>Q(...q))),gold,ls,lh,rs};
 if(s.post)s.post(P,info,s);
 return info}

/* ---------- poses ---------- */
const IDLE_T=4,WALK_T=1.1;
function idle(t){const ph=2*Math.PI*t/IDLE_T;return{t,by:Math.sin(ph)*1.1,sw:Math.sin(ph-.7)*1.6,hair:Math.sin(ph-1.1)*1.3,k:.5+.5*Math.sin(ph*2),ang:Math.sin(ph-.4)*.03}}
function walk(t){const p=(t/WALK_T)%1,ph=2*Math.PI*p;return{t,by:-Math.abs(Math.sin(ph))*1.8+.9,lean:1.4,sw:-1.6+Math.sin(ph*2-.9)*1.1,hair:-1+Math.sin(ph*2-1.3)*.9,feet:p,k:.6,
 hand:[78+Math.sin(ph)*2.4,73-Math.abs(Math.cos(ph))*1.2],ang:Math.sin(ph)*.09}}
// frappe au sol, 1 s : anticipation, élévation, abattage (traînée), impact, retour avec léger dépassement
const STRIKE_IMPACT=.5;
function strike(a,t){const I=idle(t);let cr=0,ln=0,hand=[78,73],ang=0,eyes=0,smear=null;
 if(a<.25){const e=ease(a/.25);cr=2.6*e;ln=-1.6*e;hand=[78-5*e,73-4*e];ang=-.3*e;eyes=e}
 else if(a<.43){const e=easeOut((a-.25)/.18);cr=lerp(2.6,-1.2,e);ln=lerp(-1.6,-2.2,e);hand=[lerp(73,70,e),lerp(69,46,e)];ang=lerp(-.3,-.75,e);eyes=1}
 else if(a<.5){const e=(a-.43)/.07;cr=lerp(-1.2,3.2,e);ln=lerp(-2.2,2.6,e);hand=[lerp(70,86,e),lerp(46,72,e)];ang=lerp(-.75,2.25,e*e);eyes=1;smear={from:-.75,to:ang,hand}}
 else if(a<.72){const sh=Math.sin((a-.5)*60)*Math.max(0,1-(a-.5)/.1)*.06;cr=3.2;ln=2.6;hand=[86,72];ang=2.25+sh;eyes=1}
 else{const e=back((a-.72)/.28);cr=lerp(3.2,0,e);ln=lerp(2.6,0,e);hand=[lerp(86,78,e),lerp(72,73,e)];ang=lerp(2.25,0,e);eyes=1-e}
 return{...I,crouch:cr,lean:ln,hand,ang,eyes,smear,k:a>.4?1:I.k}}
// lancer : bâton pointé vers la droite (cible), épaulé
function aim(u,t,o={}){const I=idle(t),e=ease(cl(u));return{...I,crouch:1.2*e,lean:-.8*e,hand:[lerp(78,80,e),lerp(73,62,e)],ang:lerp(0,Math.PI/2-.12,e),eyes:e,...o}}

/* ---------- traînée de l'abattage ---------- */
function smearFx(P,sm,ox,oy){if(!sm)return;for(let i=0;i<10;i++){const g=lerp(sm.from,sm.to,i/10),x=sm.hand[0]+Math.sin(g)*44+ox,y=sm.hand[1]-Math.cos(g)*44+oy;disc(P,x,y,4,PAL.gold[4],.35+.05*i);disc(P,x,y,2,PAL.gold[5],.5)}}

/* ---------- attaques à distance : scène 320 × 132, Martyre à gauche, Ingénieur à droite ---------- */
const SW=320,SH=132,GY=122,BX=14,BY=GY-FY,EX=262;
const ATTACKS=[
 {id:'disque',name:'1 · Disque solaire',loop:3.2,
  pts:['<span>Geste</span> : elle arme le bâton, une ligne d’or pointillée marque la trajectoire (0,6 s), puis le disque se détache et part en tournoyant.','<span>Effet</span> : 8 dégâts à l’aller, 8 au retour : il revient à elle sur la même courbe.','<span>Parade</span> : s’écarter de la ligne, puis rester hors du retour.','<span>Portée</span> 20 · recharge 7 s.'],
  run(P,a,ctx){const t=ctx.t;let pose=aim(cl(a/.5),t,{disc:true});const out=cl((a-.6)/.8),ret=cl((a-1.4)/.8);
   const start=[BX+124,BY+67],end=[EX,GY-22];let pos=null;
   if(a>=.6&&a<2.2){pose.disc=false;const u=a<1.4?ease(out):1-ease(ret);pos=[lerp(start[0],end[0],u),lerp(start[1],end[1],u)-Math.sin(u*Math.PI)*16*(a<1.4?1:-.6)]}
   if(a>2.2)pose=aim(1-cl((a-2.2)/.5),t,{disc:true});
   figure(P,pose,BX,BY);
   if(a>.25&&a<.6)for(let x=start[0];x<end[0];x+=4){const u=(x-start[0])/(end[0]-start[0]);P.fxs(x,lerp(start[1],end[1],u)-Math.sin(u*Math.PI)*16,PAL.gold[4],.8)}
   if(pos){const sp=t*14;for(let i=1;i<6;i++)disc(P,pos[0]-(a<1.4?i*3:-i*3),pos[1],3.5-i*.5,PAL.gold[3],.5-i*.08);ell(P,pos[0],pos[1],5,5,PAL.gold,{v:.7,edge:.25});ell(P,pos[0],pos[1],2,2,PAL.blood,{v:.85,edge:0});
    for(let i=0;i<8;i++){const g=i/8*Math.PI*2+sp;line(P,pos[0]+Math.cos(g)*6,pos[1]+Math.sin(g)*6,pos[0]+Math.cos(g)*8,pos[1]+Math.sin(g)*8,PAL.gold[4])}}
   return{hit:(a>1.38&&a<1.5)}}},
 {id:'rayon',name:'2 · Rayon du Credo',loop:3.0,
  pts:['<span>Geste</span> : elle pointe le bâton ; le disque se charge et un fil d’or tremblant vise l’Ingénieur pendant 0,8 s.','<span>Effet</span> : un rayon de 0,5 s, 15 dégâts à qui reste sur la ligne. Le rayon part dans la direction visée au début de la charge, il ne suit pas.','<span>Parade</span> : faire un pas de côté pendant la charge.','<span>Portée</span> 24 · recharge 8 s.'],
  run(P,a,ctx){const t=ctx.t,ch=cl((a-.4)/.8),fire=a>=1.2&&a<1.7;const pose=aim(cl(a/.4),t,{discGlow:a<.4?0:a<1.7?ch:1-cl((a-1.7)/.4)});if(a>2.1)Object.assign(pose,aim(1-cl((a-2.1)/.5),t));
   const r=figure(P,pose,BX,BY);const o=r.disc||[BX+CX+48,BY+60];
   if(a>=.4&&a<1.2&&Math.sin(t*50)>-.3)line(P,o[0]+6,o[1],EX,GY-22,PAL.gold[3],true,.55+ch*.4);
   if(fire){const w=a<1.3?(a-1.2)*30:3;for(let x=o[0]+4;x<SW;x++){const y=lerp(o[1],GY-22,(x-o[0])/(EX-o[0]));for(let k=-w;k<=w;k++)P.fxs(x,y+k,Math.abs(k)<w*.4?PAL.gold[5]:Math.abs(k)<w*.8?PAL.gold[4]:PAL.gold[3],.95);if((x*7+Math.floor(t*30))%23===0)P.fxs(x,y-w-1-(x%3),PAL.blood[4])}
    glow(P,o[0]+4,o[1],7,[PAL.gold[3],PAL.gold[4],PAL.gold[5]],1)}
   return{hit:fire}}},
 {id:'eclats',name:'3 · Éclats d’armure',loop:3.2,
  pts:['<span>Geste</span> : elle se ramasse, les lames de ses épaulières rougeoient 0,5 s.','<span>Effet</span> : les lames éclatent en éventail de 5 éclats (±25°) ; 6 dégâts par éclat touché. Les épaulières repoussent en 2 s : elle est alors plus vulnérable (dégâts subis +25 %).','<span>Parade</span> : se placer entre deux éclats, ou au contact (l’éventail part trop haut).','<span>Portée</span> 18 · recharge 6 s.'],
  run(P,a,ctx){const t=ctx.t,crouch=a<.5?ease(a/.5)*2.5:a<.7?lerp(2.5,-1,ease((a-.5)/.2)):lerp(-1,0,cl((a-.7)/.3));
   const plates=a<.5?1:a<2.4?0:ease(cl((a-2.4)/.6));const I=idle(t);figure(P,{...I,crouch,plates,eyes:a<1?1:0,k:a<.5?1:I.k},BX,BY);
   if(a<.5){for(const sx of[47,73])glow(P,BX+sx,BY+58+crouch,4+a*6,[PAL.blood[3],PAL.blood[4],PAL.gold[5]],ease(a/.5))}
   let hit=false;if(a>=.5&&a<1.2){const u=easeOut((a-.5)/.6);for(let i=0;i<5;i++){const g=(-25+i*12.5)*Math.PI/180,sx=BX+(i%2?73:47),sy=BY+57,L=u*(EX-sx+20),x=sx+Math.cos(g)*L,y=sy+Math.sin(g)*L*.7+u*u*28;
     for(let k=1;k<5;k++)P.fxs(x-Math.cos(g)*k*2,y-Math.sin(g)*k*1.4,PAL.gold[3],.6-k*.1);poly(P,[[x-5,y-2.5],[x+5,y-1],[x+1.5,y+3.5],[x-4,y+2.5]],PAL.gold,{v:.65,edge:.25});P.set(x-1,y-1,PAL.gold[5]);glow(P,x-4,y,3,[PAL.blood[3],PAL.blood[4],PAL.gold[5]],.5);if(Math.abs(x-EX)<5&&Math.abs(y-(GY-20))<14)hit=true}}
   if(a>=1.2&&a<1.6)for(let i=0;i<5;i++)P.fxs(EX-12+i*6,GY-1,PAL.gold[3],1-(a-1.2)/.4);
   return{hit}}},
 {id:'felure',name:'4 · Fêlure rampante',loop:3.0,
  pts:['<span>Geste</span> : elle lève le bâton et frappe le sol devant elle.','<span>Effet</span> : une fêlure rouge court au sol vers l’Ingénieur (vitesse 20/s), puis la lumière jaillit là où elle s’arrête : 12 dégâts et 1 s d’étourdissement.','<span>Parade</span> : la fêlure vise la position au moment de la frappe ; se déplacer suffit.','<span>Portée</span> 22 · recharge 7 s.'],
  run(P,a,ctx){const t=ctx.t;const pose=a<1?strike(cl(a/1),t):idle(t);figure(P,pose,BX,BY);smearFx(P,pose.smear,BX,BY);
   const s0=BX+120,len=EX-s0,u=cl((a-.5)/.8);let hit=false;
   if(a>=.5){const R=rng(9);let y=GY-2,x=s0;const n=Math.floor(u*len);for(let i=0;i<n;i++){x=s0+i;y=GY-2+Math.sin(i*.35)*1.2+(R()-.5)*1.4;P.fxs(x,y,PAL.blood[4]);P.fxs(x,y+1,PAL.blood[2]);if(i%9===0)P.fxs(x+1,y-1,PAL.blood[3])}
    if(u<1)glow(P,x,y,4,[PAL.blood[3],PAL.blood[4],PAL.blood[5]],1);
    else{const k=cl((a-1.3)/.6);for(let j=0;j<7;j++){const sx=EX-12+j*4,h=(18+(j%3)*8)*(1-k)*Math.min(1,(a-1.3)*12);for(let yy=0;yy<h;yy++)P.fxs(sx+Math.sin(yy*.3+j)*.6,GY-2-yy,yy<h*.3?PAL.blood[5]:PAL.blood[4],1-yy/h*.6)}hit=k<.3}}
   if(a>.5&&a<.62)ring(P,BX+118,GY-2,6+(a-.5)*120,2+(a-.5)*40,PAL.gold[4],1-(a-.5)/.12);
   return{hit}}},
 {id:'sceaux',name:'5 · Sceaux du Credo',loop:3.4,
  pts:['<span>Geste</span> : elle lève la main gauche, un glyphe d’or s’y allume.','<span>Effet</span> : trois cercles de sceaux s’inscrivent au sol, sous l’Ingénieur et de part et d’autre ; ils se remplissent en 1,2 s, puis une colonne de lumière jaillit de chacun : 14 dégâts.','<span>Parade</span> : sortir des cercles pendant qu’ils se remplissent.','<span>Portée</span> 26 · recharge 9 s.'],
  run(P,a,ctx){const t=ctx.t,up=a<.5?ease(a/.5):a<2?1:1-ease(cl((a-2)/.5));const I=idle(t);
   figure(P,{...I,armL:[lerp(45,43,up)+BX,lerp(79,48,up)+BY],cast:up,eyes:up},BX,BY);
   const fill=cl((a-.6)/1.2),boom=a>=1.8&&a<2.4;let hit=false;
   if(a>=.6&&a<2.4)for(const[cx,i]of[[EX-40,0],[EX,1],[EX+38,2]]){const r=13;
    for(let k=0;k<64;k++){const g=k/64*Math.PI*2+(i%2?-1:1)*t*.8;P.fxs(cx+Math.cos(g)*r,GY-2+Math.sin(g)*r*.42,PAL.gold[k%8<5?4:2])}
    for(let k=0;k<5;k++){const g=k/5*Math.PI*2-t*.5;glyph(P,cx+Math.cos(g)*r*.65-1,GY-4+Math.sin(g)*r*.27,k+i,PAL.gold[3])}
    if(!boom){const rr=r*fill;for(let y=-rr*.42;y<=rr*.42;y++)for(let x=-rr;x<=rr;x++)if((x*x)/(rr*rr)+(y*y)/(rr*rr*.176)<1)P.fxs(cx+x,GY-2+y,PAL.gold[2],.28)}
    else{const k=(a-1.8)/.6,h=90*(1-k*.3);for(let y=0;y<h;y++){const w=r*.7*(1-y/h*.3)*(1-k);for(let x=-w;x<=w;x++)P.fxs(cx+x,GY-2-y,Math.abs(x)<w*.35?PAL.gold[5]:PAL.gold[4],(1-k)*(1-y/h*.7))}if(i===1)hit=k<.4}}
   return{hit}}},
 {id:'chaine',name:'6 · Chaîne de Byrsa',loop:3.6,
  pts:['<span>Geste</span> : elle ramène la main gauche en arrière, une chaîne d’or à crochet pend de son gantelet (0,5 s).','<span>Effet</span> : la chaîne file en ligne droite ; si elle accroche, 4 dégâts et l’Ingénieur est tiré à son contact, où elle enchaîne la frappe au sol.','<span>Parade</span> : s’écarter de la ligne. Réponse à l’Ingénieur qui la combat de loin.','<span>Portée</span> 22 · recharge 10 s.'],
  run(P,a,ctx){const t=ctx.t,I=idle(t);const throwU=cl((a-.5)/.4),pull=cl((a-1)/.6);
   const handL=a<.5?[lerp(45,38,ease(a/.5)),lerp(79,70,ease(a/.5))]:a<1.6?[lerp(38,54,ease(cl((a-.5)/.2))),lerp(70,64,ease(cl((a-.5)/.2)))]:[45,79];
   const st=a>=1.6&&a<2.6?strike(cl((a-1.6)/1),t):I;figure(P,{...st,armL:[handL[0]+BX,handL[1]+BY]},BX,BY);smearFx(P,st.smear,BX,BY);
   const pl=a<1?0:a<1.6?ease(pull):a<3?1:1-ease(cl((a-3)/.6)),ex=lerp(EX,BX+CX+44,pl),hx=handL[0]+BX,hy=handL[1]+BY+3,tipX=a<.5?hx:a<1?lerp(hx,ex-6,ease(throwU)):lerp(ex-6,ex-6,0),tipY=a<1?lerp(hy,GY-24,throwU):GY-24;
   let hit=false;
   if(a<1.6){const tx=a<1?tipX:ex-4;const n=Math.max(1,Math.floor((tx-hx)/3));for(let i=0;i<=n;i++){const u=i/n,x=lerp(hx,tx,u),y=lerp(hy,tipY,u)+Math.sin(u*Math.PI)*(a<.5?6:2);P.fxs(x,y,i%2?PAL.gold[4]:PAL.gold[2]);P.fxs(x,y+1,PAL.gold[1])}
    const cx=a<1?tipX:ex-4;line(P,cx,tipY,cx+3,tipY-3,PAL.gold[5],true);line(P,cx+3,tipY-3,cx+4,tipY+1,PAL.gold[4],true);hit=a>.9&&a<1.05}
   return{hit,ex}}},
];

return{bez,line,poly,seg,horn,inPoly,glyph,back,easeOut,setVariant:v=>{CUR=v},VARIANTS,ATTACKS,PAL,figure,idle,walk,strike,aim,smearFx,raster,Px,ell,glow,ring,disc,rng,cl,ease,lerp,FW,FH,CX,FY,SW,SH,GY,BX,BY,EX,IDLE_T,WALK_T,STRIKE_IMPACT}})();
