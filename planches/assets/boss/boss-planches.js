// Premier boss : rendu pixel procédural (contour noir, trame de Bayer), ~76 px de haut = 2 × un humain du jeu.
'use strict';
const Boss=(()=>{
const W=140,H=112,CX=70,FY=104,OUT='#0b090b';
const B4=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map(r=>r.map(v=>(v+.5)/16));
const bay=(x,y)=>B4[y&3][x&3];
const cl=(v,a=0,b=1)=>v<a?a:v>b?b:v;

/* ---------- palettes (charte : carmin = la Bête, or = le Credo) ---------- */
const PAL={
 skin:['#2a1c20','#4a3034','#76565a','#a28078','#c8a898','#e6d0c2'],
 ash:['#1e1a1e','#36303a','#5a5058','#847a7e','#aaa2a2','#d0cac6'],
 hair:['#2e2a26','#5a5246','#8a7e6a','#b8ac90','#ddd4bc','#f2ecdc'],
 horn:['#1e120a','#3a2412','#5c3c1e','#86602e','#b08a48','#d8b878'],
 bone:['#1e1a16','#3a3228','#625644','#8e8068','#b8ac90','#e0d8c4'],
 robe:['#3a3428','#5e5644','#8a806a','#b4aa90','#d6ceb4','#eee8d4'],
 cloak:['#0c1210','#16201c','#24322c','#36483e','#4c6052','#647a6a'],
 night:['#0a0a0e','#141218','#201c24','#2e2830','#40383e'],
 gold:['#3a280c','#6a4a16','#a07424','#d0a038','#f0cc66','#fff2b0'],
 blood:['#200406','#4a0a0e','#7e1216','#b41c20','#e2382e','#ff8a6a'],
 flesh:['#2a0a0c','#4e1416','#7a2422','#a03a32','#c4604e','#e08c74'],
 ichor:['#060606','#121014','#1e1a1e','#2c2628'],
 slate:['#1b2028','#232933','#2b323d','#333a46','#404955'],
};
const EYE=['#5a0c10','#ff5a40','#ffd0a0'];

/* ---------- tampon pixel ---------- */
class Px{constructor(){this.c=new Array(W*H).fill(null);this.n=new Array(W*H).fill(0);this.fx=new Array(W*H).fill(null)}
 set(x,y,c,no){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=W||y>=H||!c)return;this.c[y*W+x]=c;this.n[y*W+x]=no?1:0}
 fxs(x,y,c,a=1){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=W||y>=H||!c)return;if(a<1&&a<=bay(x,y))return;this.fx[y*W+x]=c}}
const sh=(r,v,x,y)=>{v=cl(v);const f=v*(r.length-1),i=Math.floor(f);return r[Math.min(r.length-1,f-i>bay(x,y)?i+1:i)]};

function ell(P,cx,cy,rx,ry,r,o={}){const v0=o.v??.6,l=o.l??.32,edge=o.edge??.22;
 for(let y=Math.floor(cy-ry-1);y<=cy+ry+1;y++)for(let x=Math.floor(cx-rx-1);x<=cx+rx+1;x++){
  const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry,d=dx*dx+dy*dy;if(d>1)continue;
  let v=v0+l*(-dx*.55-dy*.6)-(o.rim??.1)*d;
  const dx2=(x+1.5-cx)/rx,dy2=(y+1.5-cy)/ry;if(edge&&(dx2*dx2+dy*dy>1||dx*dx+dy2*dy2>1))v-=edge;
  P.set(x,y,sh(r,v,x,y))}}
function inPoly(pts,x,y){let c=false;for(let i=0,j=pts.length-1;i<pts.length;j=i++){const[a,b]=pts[i],[e,f]=pts[j];if((b>y)!==(f>y)&&x<(e-a)*(y-b)/(f-b)+a)c=!c}return c}
function poly(P,pts,r,o={}){let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;for(const[x,y]of pts){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
 const cx=(x0+x1)/2,cy=(y0+y1)/2,hw=Math.max(1,(x1-x0)/2),hh=Math.max(1,(y1-y0)/2),v0=o.v??.55,l=o.l??.3,edge=o.edge??.2;
 for(let y=Math.floor(y0);y<=y1;y++)for(let x=Math.floor(x0);x<=x1;x++){if(!inPoly(pts,x+.5,y+.5))continue;
  const nx=(x+.5-cx)/hw,ny=(y+.5-cy)/hh;let v=v0+l*(-nx*.5-ny*.35);
  if(o.fold){const u=(y-y0)/(y1-y0||1);v+=o.fold*Math.sin((x+.5-cx-(o.foldDx||0)*u)/(1.2+u*1.6)*1.7+(o.foldPh||0))}
  if(o.grad)v+=o.grad*((y-y0)/(y1-y0||1)-.5);
  if(edge&&(!inPoly(pts,x+1.5,y+.5)||!inPoly(pts,x-.5,y+.5)||!inPoly(pts,x+.5,y+1.5)))v-=edge;
  if(o.mask&&!o.mask(x,y))continue;
  P.set(x,y,sh(r,v,x,y))}}
function seg(P,a,b,w,r,o={}){const[ax,ay]=a,[bx,by]=b,L=Math.hypot(bx-ax,by-ay)||1,ux=(bx-ax)/L,uy=(by-ay)/L,R=w/2;
 for(let y=Math.floor(Math.min(ay,by)-R-1);y<=Math.max(ay,by)+R+1;y++)for(let x=Math.floor(Math.min(ax,bx)-R-1);x<=Math.max(ax,bx)+R+1;x++){
  const px=x+.5-ax,py=y+.5-ay,t=cl((px*ux+py*uy)/L),qx=px-ux*L*t,qy=py-uy*L*t,d=Math.hypot(qx,qy);if(d>R)continue;
  const side=(qx*-uy+qy*ux)/R;let v=(o.v??.58)+(o.l??.28)*(-side*Math.sign(-uy||1)*.5-qy/R*.4);if(d>R-1)v-=o.edge??.18;
  P.set(x,y,sh(r,v,x,y))}}
function line(P,x0,y0,x1,y1,c,fx,a){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let i=0;i<=n;i++){const x=x0+(x1-x0)*i/n,y=y0+(y1-y0)*i/n;fx?P.fxs(x,y,c,a):P.set(x,y,c)}}
function bez(p,t){const u=1-t;return[0,1].map(k=>u*u*u*p[0][k]+3*u*u*t*p[1][k]+3*u*t*t*p[2][k]+t*t*t*p[3][k])}
// corne : courbe de Bézier, rayon décroissant, anneaux de croissance
function horn(P,pts,r0,r1,ramp,o={}){const n=46;for(let i=0;i<=n;i++){const t=i/n,[x,y]=bez(pts,t),r=r0+(r1-r0)*t;
  const band=o.bands===false?0:(Math.floor(t*(o.bands||11))%2?-.1:.04);ell(P,x,y,Math.max(.6,r),Math.max(.6,r),ramp,{v:(o.v??.5)+band+t*.18,l:.4,edge:0,rim:.25})}}
const GLY=[['.#.','###','.#.','#.#'],['##.','.#.','.##','.#.'],['#.#','.#.','#.#','###'],['###','#..','##.','#..'],['.#.','#.#','.#.','.#.'],['#..','###','..#','.##']];
function glyph(P,x,y,g,c,fx){GLY[g%GLY.length].forEach((row,j)=>[...row].forEach((ch,i)=>{if(ch==='#')fx?P.fxs(x+i,y+j,c):P.set(x+i,y+j,c)}))}
function disc(P,x,y,r,c,a=1){for(let j=Math.floor(y-r);j<=y+r;j++)for(let i=Math.floor(x-r);i<=x+r;i++){const d=Math.hypot(i+.5-x,j+.5-y)/r;if(d<=1)P.fxs(i,j,c,a*(1-d*d*.6))}}
function ring(P,x,y,r,ry,c,a,th=1.2){for(let k=0;k<Math.ceil(r*7);k++){const ang=k/(r*7)*Math.PI*2;for(let w=0;w<th;w+=.7){P.fxs(x+Math.cos(ang)*(r+w),y+Math.sin(ang)*(ry+w*ry/r),c,a)}}}
function rng(s){return()=>{s=(s*1664525+1013904223)>>>0;return s/4294967296}}

/* ---------- silhouette commune ---------- */
// st : {t, by (respiration), sw (balancement), a (attaque 0..1 ou null), lift (lévitation)}
function headAndFace(P,s,st){const hx=CX+(s.hx||0),hy=35+st.by-st.lift,p=s.pal,R=p.hair;
 if(s.backHair!==false)poly(P,[[hx-7,hy-3],[hx+7,hy-3],[hx+9+st.sw*.6,hy+24],[hx+2,hy+27],[hx-9+st.sw*.6,hy+24]],R,{v:.42,fold:.14,edge:.15});
 return{hx,hy}}
function drawHead(P,s,st,hx,hy){const p=s.pal;
 seg(P,[hx,hy+5],[hx,hy+9],4.5,p.skin,{v:.42});
 ell(P,hx,hy,5.8,6.6,p.skin,{v:.7,l:.36});
 // arcade sourcilière et yeux
 const glow=st.a!=null?Math.sin(cl(st.a/.5)*Math.PI/2):0;
 for(const ex of[hx-2.5,hx+1.5]){P.set(ex,hy-1,p.skin[2]);P.set(ex+1,hy-1,p.skin[2]);P.set(ex,hy,EYE[0]);P.set(ex+1,hy,glow>.5||s.eyeLit?EYE[2]:EYE[1])}
 P.set(hx+.5,hy+2,p.skin[3]);P.set(hx,hy+4,p.blood[2]);
 // fissures carmin du front
 if(s.cracks!==false){const C=p.blood;line(P,hx,hy-6,hx,hy-4,C[2]);P.set(hx-1,hy-6,C[3]);P.set(hx+1,hy-5,C[2]);if(s.cracks==='deep'){line(P,hx-3,hy-2,hx-4,hy+3,C[2]);line(P,hx+3,hy+1,hx+4,hy+4,C[2])}}
 // larmes de sang
 if(s.tears!==false){const C=p.blood;line(P,hx-2.5,hy+1,hx-2.5,hy+3,C[2]);line(P,hx+2.5,hy+1,hx+2.5,hy+4,C[2]);const d=(st.t*.8)%1;if(d<.75)P.fxs(hx+2.5,hy+5+d*8,C[4])}
 // cheveux : calotte + mèches avant
 const R=p.hair;poly(P,[[hx-6,hy-1],[hx-5.5,hy-5],[hx-2,hy-7.4],[hx+2,hy-7.4],[hx+5.5,hy-5],[hx+6,hy-1],[hx+4,hy-4.5],[hx+.5,hy-6],[hx-4,hy-4.5]],R,{v:.52,edge:.2});
 if(s.frontHair!==false){poly(P,[[hx-6,hy-2],[hx-4.4,hy-2],[hx-4.6,hy+6],[hx-6.5+st.sw*.4,hy+16],[hx-8+st.sw*.4,hy+14]],R,{v:.6,fold:.1});
  poly(P,[[hx+4.4,hy-2],[hx+6,hy-2],[hx+8+st.sw*.4,hy+14],[hx+6.5+st.sw*.4,hy+17],[hx+4.6,hy+6]],R,{v:.5,fold:.1})}}
function cloakBack(P,s,st,ramp,o={}){const y0=44+st.by-st.lift,yb=FY-st.lift+(o.short||0);poly(P,[[57,y0],[83,y0],[89+st.sw*1.5+(o.wide||0),yb],[70,yb+1],[50+st.sw*.8-(o.wide||0),yb]],ramp,{v:.4,fold:.16,foldDx:st.sw*2,edge:.15})}
function torso(P,s,st,ramp,o={}){const y=45+st.by-st.lift;poly(P,[[58,y],[82,y],[77,y+19],[63,y+19]],ramp,{v:o.v??.6,fold:o.fold??.06})}
function skirt(P,s,st,ramp,o={}){const y=63+st.by-st.lift,yb=FY-st.lift;poly(P,[[63,y],[77,y],[85+st.sw*.6,yb],[70,yb+.5],[56+st.sw*.4,yb]],ramp,{v:o.v??.62,fold:.16,foldDx:st.sw,mask:o.mask})}
function flaps(P,s,st,ramp){const y=44+st.by-st.lift,yb=FY-st.lift;
 poly(P,[[55,y],[66,y+1],[64,y+14],[62.5+st.sw*.3,yb],[51+st.sw*.8,yb]],ramp,{v:.42,fold:.18,edge:.18});
 poly(P,[[74,y+1],[85,y],[90+st.sw*1.3,yb],[78+st.sw*.4,yb],[76,y+14]],ramp,{v:.36,fold:.18,edge:.18})}
function glyphsOn(P,s,st,col,list){const fl=.5+.5*Math.sin(st.t*3);list.forEach(([x,y,g],i)=>glyph(P,x,y+st.by-st.lift,g,(i+Math.floor(st.t*2))%5===0&&fl>.5?col[5]:col[3]))}
function choker(P,st,c){const y=44+st.by-st.lift;for(let x=66;x<=74;x++)P.set(x,y,x%2?c[3]:c[4])}

/* ---------- 5 propositions ---------- */
const PROPS=[
{id:'prieure',name:'1 · La Prieure souillée',title:'Haute prêtresse du Credo, souillée par la Bête',
 desc:'La lecture la plus fidèle à l’inspiration : robe ivoire et or du Credo, cornes de bélier qui ont percé le crâne, cheveux pâles, front fendu de carmin, larmes de sang. Le doigt sur les lèvres devient son attaque.',
 sw:['robe','gold','cloak','horn','blood','hair'],
 pts:['<span>Arrivée</span> : à la fin de l’assaut 5, au milieu des fanatiques ; elle marche droit sur l’Ancre, sans courir.','<span>Attaque</span> : revers de lumière souillée au contact, petite zone.','<span>Signature « Silence »</span> : un doigt sur les lèvres, puis une onde carmin qui fige adeptes et soldats 2 s et coupe les prières en cours.','<span>Phase 2 (50 %)</span> : les glyphes d’or de sa cape virent au rouge, le Silence revient deux fois plus souvent.'],
 draw(P,st){const p=this.pal,{hx,hy}=headAndFace(P,this,st);
  cloakBack(P,this,st,p.cloak);
  horn(P,[[hx-4,hy-4],[hx-12,hy-16],[hx-22,hy-6],[hx-15,hy+6]],2.8,.7,p.horn);
  skirt(P,this,st,p.robe);torso(P,this,st,p.robe);
  for(let y=66;y<FY-1;y+=3)P.set(70,y+st.by,p.gold[3]);
  drawHead(P,this,st,hx,hy);
  horn(P,[[hx+4,hy-4],[hx+12,hy-16],[hx+22,hy-6],[hx+15,hy+6]],2.8,.7,p.horn);
  choker(P,st,p.gold);flaps(P,this,st,p.cloak);
  glyphsOn(P,this,st,st.a!=null&&st.a>.3?p.blood:p.gold,[[54,74,0],[55,84,3],[53,94,1],[84,72,2],[85,83,5],[87,94,4]]);
  // main gauche sous la cape, ongles rouges
  ell(P,61,75+st.by,2,2.4,p.skin,{v:.6});P.set(60,77+st.by,p.blood[3]);P.set(62,77+st.by,p.blood[3]);
  // bras droit levé : doigt sur les lèvres
  seg(P,[79,47+st.by],[82,59+st.by],6,p.robe,{v:.55});seg(P,[82,59+st.by],[74,44+st.by],4.4,p.robe,{v:.66});
  ell(P,73.5,43.5+st.by,1.8,2.4,p.skin,{v:.66});seg(P,[72,42.5+st.by],[71.5,38.5+st.by],1.4,p.skin,{v:.74,edge:0});
  P.set(74,44+st.by,p.gold[4]);P.set(75,46+st.by,p.gold[3]);P.set(77,49+st.by,p.gold[3])},
 fx(P,st){if(st.a==null)return;const a=st.a,p=this.pal;
  for(let k=0;k<3;k++){const u=a*1.4-k*.22;if(u<=0||u>1)continue;ring(P,CX,FY-2,8+u*62,3+u*20,p.blood[k?3:4],(1-u)*.9,1.6)}
  if(a<.35)for(let i=0;i<6;i++){const ang=i/6*6.28+st.t*4;P.fxs(71+Math.cos(ang)*3,38+st.by+Math.sin(ang)*3,p.blood[5],.8)}}},

{id:'sibylle',name:'2 · La Sibylle des glyphes',title:'Lectrice de Fortuna',
 desc:'La cape couverte de glyphes d’or devient l’arme : les signes se détachent du tissu et tournent autour d’elle. Cornes d’antilope rabattues vers l’arrière, haut col noir et or, bras ouverts paumes vers le bas.',
 sw:['night','gold','robe','bone','blood','hair'],
 pts:['<span>Position</span> : reste à distance derrière ses fanatiques, recule si on l’approche.','<span>Attaque</span> : les glyphes en orbite partent en salve vers la cible la plus proche, puis se reforment.','<span>Signature « Bouclier de lettres »</span> : tant que six glyphes l’entourent, elle est protégée de face ; les soldats d’Indra au contact les brisent un à un.','<span>Phase 2 (50 %)</span> : les glyphes s’inscrivent au sol en cercle et brûlent ce qui s’y tient.'],
 draw(P,st){const p=this.pal,{hx,hy}=headAndFace(P,this,st);
  cloakBack(P,this,st,p.night,{wide:4});
  horn(P,[[hx-3,hy-5],[hx-6,hy-17],[hx-12,hy-25],[hx-20,hy-27]],2.2,.5,p.bone,{bands:16});
  skirt(P,this,st,p.robe,{v:.5});torso(P,this,st,p.night,{v:.5});
  // bras ouverts vers le bas
  const up=st.a!=null?Math.sin(cl(st.a/.4)*Math.PI/2)*(1-cl((st.a-.7)/.3)):0;
  seg(P,[61,47+st.by],[54,60+st.by-up*6],5.5,p.night,{v:.45});seg(P,[54,60+st.by-up*6],[49,69+st.by-up*14],4,p.night,{v:.5});ell(P,48,71+st.by-up*15,2,2.4,p.skin,{v:.62});
  seg(P,[79,47+st.by],[86,60+st.by-up*6],5.5,p.night,{v:.45});seg(P,[86,60+st.by-up*6],[91,69+st.by-up*14],4,p.night,{v:.5});ell(P,92,71+st.by-up*15,2,2.4,p.skin,{v:.62});
  drawHead(P,this,st,hx,hy);
  // haut col noir et or
  poly(P,[[60,45+st.by],[64,37+st.by],[66,44+st.by],[74,44+st.by],[76,37+st.by],[80,45+st.by]],p.night,{v:.5});for(let y=38;y<45;y++){P.set(64+(y-37)*.3,y+st.by,p.gold[3]);P.set(76-(y-37)*.3,y+st.by,p.gold[3])}
  horn(P,[[hx+3,hy-5],[hx+6,hy-17],[hx+12,hy-25],[hx+20,hy-27]],2.2,.5,p.bone,{bands:16});
  flaps(P,this,st,p.night);
  glyphsOn(P,this,st,p.gold,[[53,70,0],[55,78,1],[52,86,2],[56,94,3],[85,68,4],[84,77,5],[87,85,0],[85,94,2],[67,50,3],[71,56,1]])},
 fx(P,st){const p=this.pal,a=st.a,n=6;
  for(let i=0;i<n;i++){const ang=i/n*6.283+st.t*1.6;let x=CX+Math.cos(ang)*24,y=70+st.by+Math.sin(ang)*8;
   if(a!=null){const u=cl((a-.15-i*.05)/.45);if(u>0&&u<1){x=x+(122-x)*u;y=y+(62-y)*u;for(let k=1;k<5;k++)P.fxs(x-k*3*u,y,p.gold[3],.6-k*.12)}else if(u>=1){const r=cl((a-.75)/.25);if(r<1)continue}}
   const front=Math.sin(ang)>0;if(!front&&a==null&&Math.sin(ang)<-.3){glyph(P,x-1,y-2,i,p.gold[2],true);continue}
   glyph(P,x-1,y-2,i,p.gold[4],true);P.fxs(x-2,y-3,p.gold[5],.35);P.fxs(x+2,y+2,p.gold[5],.35)}}},

{id:'epousee',name:'3 · L’Épousée de la Bête',title:'Celle que la Bête a gardée',
 desc:'La version la plus bestiale : le carmin domine, il ne reste du Credo qu’un collier d’or brisé. Épaules nues striées de veines rouges, cornes massives qui montent en lyre, longues griffes, manteau de chair en lambeaux qui traîne derrière elle.',
 sw:['ash','flesh','blood','horn','gold','hair'],
 pts:['<span>Position</span> : corps à corps pur, rapide pour sa taille ; bondit sur les archers.','<span>Attaque</span> : triple griffure en arc qui fait saigner (dégâts sur la durée).','<span>Signature « Festin »</span> : à chaque adepte tué, ses veines s’allument et elle accélère (cumulable, se dissipe en 10 s).','<span>Phase 2 (50 %)</span> : sa traîne laisse une trace d’ichor qui ralentit les alliés.'],
 draw(P,st){const p=this.pal,{hx,hy}=headAndFace(P,this,st);
  // traîne de chair en lambeaux
  const y0=44+st.by;poly(P,[[59,y0],[81,y0],[94+st.sw*2,FY],[86,FY-3],[80,FY+1],[70,FY-2],[60,FY+1],[52,FY-3],[46+st.sw,FY]],p.flesh,{v:.38,fold:.2,foldDx:st.sw*3});
  horn(P,[[hx-4,hy-4],[hx-14,hy-10],[hx-14,hy-24],[hx-8,hy-30]],3.6,.8,p.horn,{bands:9,v:.45});
  skirt(P,this,st,p.ichor,{v:.5});
  torso(P,this,st,p.ash,{v:.62,fold:0});
  // corset d'ichor
  poly(P,[[63,54+st.by],[77,54+st.by],[77,64+st.by],[63,64+st.by]],p.ichor,{v:.55});
  // veines
  const lit=st.a!=null?1:.5+.5*Math.sin(st.t*2.2);const R=rng(7);for(let k=0;k<7;k++){let x=60+R()*20,y=46+R()*5+st.by;for(let j=0;j<4;j++){x+=(R()-.5)*2.4;y+=R()*1.2;P.set(x,y,p.blood[lit>.6?4:3])}}
  drawHead(P,this,st,hx,hy);
  horn(P,[[hx+4,hy-4],[hx+14,hy-10],[hx+14,hy-24],[hx+8,hy-30]],3.6,.8,p.horn,{bands:9,v:.45});
  // collier d'or brisé
  for(let x=66;x<=73;x++)if(x!==70&&x!==71)P.set(x,44+st.by,p.gold[x%2?3:4]);P.set(70,46+st.by,p.gold[3]);
  // bras gauche pendant, griffes
  seg(P,[61,47+st.by],[57,60+st.by],5,p.ash,{v:.55});seg(P,[57,60+st.by],[57,72+st.by],4,p.ash,{v:.6});ell(P,57,74+st.by,2.2,2.4,p.ash,{v:.6});
  for(const d of[-1.5,0,1.5])line(P,57+d,76+st.by,57+d*1.5,82+st.by,p.blood[2]);
  // bras droit : griffure
  const a=st.a;let el=[85,59],hd=[86,72];if(a!=null){const pre=Math.sin(cl(a/.3)*Math.PI/2),rel=cl((a-.3)/.25);el=[85-pre*2+rel*8,59-pre*10+rel*6];hd=[86-pre*4+rel*22,72-pre*28+rel*14]}
  seg(P,[79,47+st.by],[el[0],el[1]+st.by],5,p.ash,{v:.55});seg(P,[el[0],el[1]+st.by],[hd[0],hd[1]+st.by],4,p.ash,{v:.62});ell(P,hd[0],hd[1]+2+st.by,2.2,2.4,p.ash,{v:.62});
  for(const d of[-1.5,0,1.5])line(P,hd[0]+d,hd[1]+4+st.by,hd[0]+d*1.5+(a!=null&&a>.3?3:0),hd[1]+10+st.by,p.blood[2])},
 fx(P,st){if(st.a==null)return;const u=cl((st.a-.32)/.35),p=this.pal;if(u<=0||u>=1)return;
  for(let k=0;k<3;k++){for(let i=0;i<14;i++){const ang=-1.1+i/14*1.9*u,x=88+Math.cos(ang)*(18+k*3),y=64+st.by+Math.sin(ang)*(18+k*3)-k*2;P.fxs(x,y,p.blood[i>9?5:4],1-u*.6)}}
  for(let i=0;i<5;i++)P.fxs(110+i*1.6,60+st.by+(i*5%7),p.blood[3],.7*(1-u))}},

{id:'martyre',name:'4 · La Martyre de Byrsa',title:'Championne de Byrsa',
 desc:'Championne de Byrsa, sœur d’armes du Strazhar : l’armure d’automate d’or s’est soudée à son corps et se fend sur une lumière rouge. Une corne intacte, l’autre brisée. Grand bâton surmonté d’un disque solaire, tenu comme une lance.',
 sw:['gold','robe','blood','horn','ichor','hair'],
 pts:['<span>Position</span> : lente et lourde, elle encaisse ; elle cible les bâtiments avant les unités.','<span>Attaque</span> : coup de bâton solaire qui repousse la cible.','<span>Signature « Fêlure »</span> : elle frappe le sol, des fissures rouges rayonnent et étourdissent ; deux automates dorés sortent de terre.','<span>Phase 2 (50 %)</span> : l’armure éclate (dégâts subis +50 %), elle devient rapide.'],
 draw(P,st){const p=this.pal,{hx,hy}=headAndFace(P,this,st);
  const a=st.a;let sy=0;if(a!=null){sy=a<.35?-Math.sin(cl(a/.35)*Math.PI/2)*12:a<.5?-12+cl((a-.35)/.15)*14:2*(1-cl((a-.5)/.5))}
  cloakBack(P,this,st,p.ichor,{short:-2});
  horn(P,[[hx-4,hy-4],[hx-9,hy-14],[hx-17,hy-15],[hx-21,hy-9]],2.8,.8,p.horn);
  skirt(P,this,st,p.robe,{v:.55});
  // taches d'ichor au bas de la robe
  for(let i=0;i<22;i++){const x=58+(i*7%27),y=FY-1-(i*5%7);P.set(x,y,p.ichor[1+(i%2)])}
  torso(P,this,st,p.gold,{v:.46,fold:0});
  // fissures de la cuirasse
  line(P,66,48+st.by,69,55+st.by,p.blood[4]);line(P,69,55+st.by,67,60+st.by,p.blood[3]);line(P,73,47+st.by,75,52+st.by,p.blood[3]);
  drawHead(P,this,st,hx,hy);
  // corne brisée
  horn(P,[[hx+4,hy-4],[hx+8,hy-9],[hx+10,hy-11],[hx+11,hy-12]],2.8,2.2,p.horn,{bands:5});P.set(hx+11,hy-13,p.horn[5]);P.set(hx+12,hy-12,p.horn[4]);
  // épaulières d'automate
  for(const[cx,d]of[[59,-1],[81,1]]){ell(P,cx,47+st.by,5,4,p.gold,{v:.55});line(P,cx-3,48+st.by,cx+3,48+st.by,p.gold[1])}
  P.set(57,46+st.by,p.blood[4]);
  // bras gauche gantelet
  seg(P,[58,50+st.by],[57,63+st.by],4.5,p.gold,{v:.55});ell(P,57,66+st.by,2.6,2.8,p.gold,{v:.6});P.set(57,66+st.by,p.blood[4]);
  // bâton solaire
  const bx=89,top=24+sy+st.by;seg(P,[bx,top+6],[bx,FY+sy*.2],2.4,p.horn,{v:.5,edge:.1});
  ell(P,bx,top,5,5,p.gold,{v:.72});ell(P,bx,top,2,2,p.blood,{v:.8,edge:0});for(let i=0;i<8;i++){const g=i/8*6.283;P.set(bx+Math.cos(g)*6.5,top+Math.sin(g)*6.5,p.gold[3])}
  seg(P,[81,50+st.by],[86,58+st.by+sy*.6],4.5,p.gold,{v:.55});ell(P,88,60+st.by+sy*.6,2.6,2.8,p.gold,{v:.62})},
 fx(P,st){if(st.a==null)return;const p=this.pal,u=cl((st.a-.48)/.5);if(u<=0)return;
  const R=rng(31);for(let k=0;k<7;k++){const ang=-.2+R()*3.5,L=(8+R()*22)*Math.min(1,u*2.5);let x=89,y=FY;for(let i=0;i<L;i++){x+=Math.cos(ang)+(R()-.5)*.8;y+=Math.sin(ang)*.35+(R()-.5)*.5;P.fxs(x,y,p.blood[u<.6?4:3],1-u*.8)}}
  ring(P,89,FY,6+u*30,2+u*9,p.horn[4],(1-u)*.8);for(let i=0;i<10;i++){const g=R()*6.28,d=u*18*R();P.fxs(89+Math.cos(g)*d,FY-u*10*R()-2,p.horn[3],.7*(1-u))}}},

{id:'mere',name:'5 · La Mère des larmes',title:'Oracle saignante, reine des fanatiques',
 desc:'Elle lévite, cheveux soulevés comme une flamme pâle, petites cornes qui épousent la mâchoire. Ses larmes coulent en fils rouges jusqu’à ses fanatiques, qu’elle mène comme des marionnettes. La plus inquiétante, la moins armée.',
 sw:['robe','blood','hair','bone','cloak','gold'],
 pts:['<span>Position</span> : flotte au-dessus des obstacles bas, reste au centre de sa troupe.','<span>Attaque</span> : pluie de larmes de sang autour d’elle ; les flaques blessent.','<span>Signature « Fils de sang »</span> : reliée à 3 fanatiques, elle se soigne tant qu’ils vivent. Tuer les marionnettes coupe les fils.','<span>Phase 2 (50 %)</span> : elle accroche un adepte et le retourne contre les siens 5 s.'],
 float:7,
 draw(P,st){const p=this.pal,hx=CX,hy=35+st.by-st.lift,R=p.hair;
  // cheveux soulevés
  for(let i=0;i<7;i++){const ox=(i-3)*2.4,w=Math.sin(st.t*2.4+i*1.3)*2;poly(P,[[hx+ox-2.4,hy-2],[hx+ox+2.4,hy-2],[hx+ox*1.6+w,hy-16-(i%3)*3]],R,{v:.55+(i%2)*.1,edge:.12})}
  // robe longue, bas en lambeaux
  const y0=45+st.by-st.lift,yb=FY-st.lift-2;
  poly(P,[[60,y0],[80,y0],[86+st.sw,yb],[82,yb+5],[78,yb+1],[74,yb+7],[70,yb+2],[66,yb+6],[62,yb+1],[58,yb+4],[54+st.sw*.5,yb]],p.robe,{v:.6,fold:.18,foldDx:st.sw*2,grad:-.2});
  poly(P,[[63,y0+18],[77,y0+18],[78,y0+22],[62,y0+22]],p.blood,{v:.45});
  // bras écartés, fils
  const up=st.a!=null?Math.sin(cl(st.a/.3)*Math.PI/2):0;
  const L=[44,52-up*10+st.by-st.lift],Rr=[96,52-up*10+st.by-st.lift];
  seg(P,[61,47+st.by-st.lift],[52,50-up*5+st.by-st.lift],4.5,p.robe,{v:.6});seg(P,[52,50-up*5+st.by-st.lift],L,3.5,p.skin,{v:.62});
  seg(P,[79,47+st.by-st.lift],[88,50-up*5+st.by-st.lift],4.5,p.robe,{v:.55});seg(P,[88,50-up*5+st.by-st.lift],Rr,3.5,p.skin,{v:.62});
  for(const h of[L,Rr])for(const d of[-1,0,1])line(P,h[0]+d*(h===L?-1:1)*.5,h[1]+1,h[0]+d*1.5,h[1]+4,p.skin[3]);
  drawHead(P,{...this,frontHair:false},st,hx,hy);
  // cornes basses le long de la mâchoire
  horn(P,[[hx-5,hy-2],[hx-9,hy+1],[hx-8,hy+7],[hx-5,hy+9]],1.8,.5,p.bone,{bands:8});
  horn(P,[[hx+5,hy-2],[hx+9,hy+1],[hx+8,hy+7],[hx+5,hy+9]],1.8,.5,p.bone,{bands:8});
  choker(P,{by:st.by,lift:st.lift},p.gold)},
 fx(P,st){const p=this.pal,lf=st.lift,up=st.a!=null?Math.sin(cl(st.a/.3)*Math.PI/2):0;
  // fils de sang vers les marionnettes (hors cadre)
  const hands=[[44,53-up*10+st.by-lf],[96,53-up*10+st.by-lf]],ends=[[6,92],[134,96],[24,108]];
  ends.forEach((e,i)=>{const h=hands[i===1?1:0],sag=6+Math.sin(st.t*1.7+i)*2;for(let k=0;k<=40;k++){const u=k/40,x=h[0]+(e[0]-h[0])*u,y=h[1]+(e[1]-h[1])*u+Math.sin(u*Math.PI)*sag;P.fxs(x,y,p.blood[(k+Math.floor(st.t*10))%6<1?4:3],.85)}});
  // pluie de larmes
  if(st.a!=null){const R=rng(5);for(let i=0;i<16;i++){const x=40+R()*60,ph=(st.a*1.6+R())%1,y=20+ph*82;if(y<FY-2)line(P,x,y,x,y+2,p.blood[4],true,.9);else disc(P,x,FY-1,1.5+R()*2,p.blood[2],.9)}}
  // ombre portée réduite : gérée par la scène
  }},
];
PROPS[0].pal={...PAL};PROPS[1].pal={...PAL};PROPS[2].pal={...PAL,skin:PAL.ash,hair:['#141012','#241e20','#3a3032','#544648','#6e5e5e','#8a7876']};PROPS[3].pal={...PAL};PROPS[4].pal={...PAL};

/* ---------- rendu ---------- */
const RGB={};const rgb=h=>RGB[h]||(RGB[h]=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)));
function render(prop,t,a){const P=new Px(),lift=prop.float?prop.float+Math.sin(t*1.8)*1.5:0;
 const st={t,by:Math.round(Math.sin(t*2)*.6),sw:Math.sin(t*1.3),a,lift:Math.round(lift)};
 prop.draw(P,st);
 const c=document.createElement('canvas');c.width=W;c.height=H;const g=c.getContext('2d'),im=g.createImageData(W,H),d=im.data;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;let col=P.c[i];
  if(!col){const nb=[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>{const X=x+dx,Y=y+dy;return X>=0&&Y>=0&&X<W&&Y<H&&P.c[Y*W+X]&&!P.n[Y*W+X]});if(nb)col=OUT}
  if(col){const[r,gg,b]=rgb(col);d[i*4]=r;d[i*4+1]=gg;d[i*4+2]=b;d[i*4+3]=255}}
 const F=new Px();prop.fx&&prop.fx(F,st);
 for(let i=0;i<W*H;i++){const col=F.fx[i];if(!col)continue;const[r,gg,b]=rgb(col);d[i*4]=r;d[i*4+1]=gg;d[i*4+2]=b;d[i*4+3]=255}
 g.putImageData(im,0,0);c.lift=lift;return c}
// sol d'ardoise tyrienne
function ground(w,h,seed){const c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d'),im=g.createImageData(w,h),d=im.data,S=PAL.slate;
 const n=(x,y)=>{const v=Math.sin(x*12.9898+y*78.233+seed)*43758.5453;return v-Math.floor(v)};
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const tx=Math.floor(x/16+(Math.floor(y/12)%2)*.5),ty=Math.floor(y/12),base=.25+n(tx,ty)*.35,edge=(x+(Math.floor(y/12)%2)*8)%16===0||y%12===0;
  let v=base+(n(x,y)-.5)*.18;if(edge)v-=.22;const f=cl(v)*(S.length-1),i=Math.floor(f),col=S[Math.min(S.length-1,f-i>bay(x,y)?i+1:i)],[r,gg,b]=rgb(col),k=(y*w+x)*4;d[k]=r;d[k+1]=gg;d[k+2]=b;d[k+3]=255}
 g.putImageData(im,0,0);return c}
function shadow(g,cx,cy,rx,ry){for(let y=Math.floor(cy-ry);y<=cy+ry;y++)for(let x=Math.floor(cx-rx);x<=cx+rx;x++){const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry,q=dx*dx+dy*dy;if(q<=1&&(q<.55||bay(x,y)>.5)){g.fillStyle='rgba(6,6,10,.55)';g.fillRect(x,y,1,1)}}}
return{PROPS,PAL,render,ground,shadow,W,H,CX,FY}})();
