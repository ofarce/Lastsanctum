// Deuxième boss : l'Invocateur. Rendu pixel procédural (contour noir, trame de Bayer), même cadre que la Martyre
// (planches/assets/boss/boss-planches.js) : 140 × 112, pieds à FY. Silhouette frêle, ~60 px, enveloppée d'un grand
// bouclier personnel (sphère de 44 px de rayon).
'use strict';
const Inv=(()=>{
const W=140,H=112,CX=70,FY=104,OUT='#0b090b';
const B4=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map(r=>r.map(v=>(v+.5)/16));
const bay=(x,y)=>B4[y&3][x&3];
const cl=(v,a=0,b=1)=>v<a?a:v>b?b:v;
const ease=x=>{x=cl(x);return x*x*(3-2*x)};
const lerp=(a,b,t)=>a+(b-a)*t;

/* ---------- palettes (charte : carmin = la Bête, or = le Credo ; ni cyan, ni pourpre) ---------- */
const PAL={
 skin:['#2a1c20','#4a3034','#76565a','#a28078','#c8a898','#e6d0c2'],
 ash:['#1e1a1e','#36303a','#5a5058','#847a7e','#aaa2a2','#d0cac6'],
 hair:['#2e2a26','#5a5246','#8a7e6a','#b8ac90','#ddd4bc','#f2ecdc'],
 horn:['#1e120a','#3a2412','#5c3c1e','#86602e','#b08a48','#d8b878'],
 bone:['#1e1a16','#3a3228','#625644','#8e8068','#b8ac90','#e0d8c4'],
 robe:['#3a3428','#5e5644','#8a806a','#b4aa90','#d6ceb4','#eee8d4'],
 night:['#0a0a0e','#141218','#201c24','#2e2830','#40383e','#544a50'],
 gold:['#3a280c','#6a4a16','#a07424','#d0a038','#f0cc66','#fff2b0'],
 blood:['#200406','#4a0a0e','#7e1216','#b41c20','#e2382e','#ff8a6a'],
 flesh:['#2a0a0c','#4e1416','#7a2422','#a03a32','#c4604e','#e08c74'],
 pale:['#2c2024','#4c3a3c','#76605e','#a08a82','#c8b4a8','#ecdcd0'],
 ichor:['#060606','#121014','#1e1a1e','#2c2628'],
 slate:['#1b2028','#232933','#2b323d','#333a46','#404955'],
};

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
  P.set(x,y,sh(r,v,x,y),o.no)}}
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
function tube(P,pts,r0,r1,ramp,o={}){const n=40;for(let i=0;i<=n;i++){const t=i/n,[x,y]=bez(pts,t),r=r0+(r1-r0)*t;ell(P,x,y,Math.max(.6,r),Math.max(.6,r),ramp,{v:(o.v??.5)+t*(o.dv??.1),l:.4,edge:0,rim:.25})}}
const GLY=[['.#.','###','.#.','#.#'],['##.','.#.','.##','.#.'],['#.#','.#.','#.#','###'],['###','#..','##.','#..'],['.#.','#.#','.#.','.#.'],['#..','###','..#','.##']];
function glyph(P,x,y,g,c,fx,a){GLY[((g%GLY.length)+GLY.length)%GLY.length].forEach((row,j)=>[...row].forEach((ch,i)=>{if(ch==='#')fx?P.fxs(x+i,y+j,c,a):P.set(x+i,y+j,c)}))}
function disc(P,x,y,r,c,a=1){for(let j=Math.floor(y-r);j<=y+r;j++)for(let i=Math.floor(x-r);i<=x+r;i++){const d=Math.hypot(i+.5-x,j+.5-y)/r;if(d<=1)P.fxs(i,j,c,a*(1-d*d*.6))}}
function ring(P,x,y,r,ry,c,a,th=1.2){for(let k=0;k<Math.ceil(r*7);k++){const ang=k/(r*7)*Math.PI*2;for(let w=0;w<th;w+=.7){P.fxs(x+Math.cos(ang)*(r+w),y+Math.sin(ang)*(ry+w*ry/r),c,a)}}}
function rng(s){return()=>{s=(s*1664525+1013904223)>>>0;return s/4294967296}}
const RGB={};function rgb(h){return RGB[h]||(RGB[h]=[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)])}

// geste d'invocation : a ∈ [0,1] → lever (0–.3), tenir (.3–.78), relâcher (.78–1)
const raise=a=>a==null?0:a<.3?ease(a/.3):a<.78?1:1-ease((a-.78)/.22);
// instant de l'invocation proprement dite (la créature naît à a = .78)
const burst=a=>a==null?0:cl((a-.74)/.26);

/* ---------- bouclier personnel ---------- */
// sphère tramée : liseré, voile intérieur très léger, motif propre à chaque invocateur, reflet en haut à gauche.
const WARD={cx:70,cy:60,r:44};
function ward(F,st,ramp,style,o={}){const{cx,cy,r}=WARD,ry=r*.96,t=st.t,pul=.5+.5*Math.sin(t*2.2),open=o.open||0;
 for(let y=Math.floor(cy-ry-1);y<=cy+ry+1;y++)for(let x=Math.floor(cx-r-1);x<=cx+r+1;x++){
  const dx=(x+.5-cx)/r,dy=(y+.5-cy)/ry,d2=dx*dx+dy*dy;if(d2>1)continue;const d=Math.sqrt(d2);
  if(open&&Math.sin(Math.atan2(dy,dx)*7+t*9)>1-open*1.6)continue;
  if(d>.955){F.fxs(x,y,ramp[3+(pul>.6&&bay(x,y)>.5?1:0)]);continue}
  if(d>.9){F.fxs(x,y,ramp[2],.55);continue}
  if(dx<-.25&&dy<-.3&&d>.76&&d<.84){F.fxs(x,y,ramp[4],.32);continue}
  const z=Math.sqrt(1-d2),u=Math.atan2(dx,z),v=Math.asin(cl(dy,-1,1));// coordonnées sphériques
  let hit=false,c=ramp[3],a=.55;
  if(style==='hex'){const q=u*4.5+t*.25,w=v*4.5,row=Math.floor(w),qq=q+(row&1)*.5;hit=Math.abs(w-row-.5)>.46||Math.abs(qq-Math.round(qq))<.035;a=.4}
  else if(style==='threads'){const q=u*9+Math.sin(v*5+t*1.4)*.25;hit=Math.abs(q-Math.round(q))<.06;c=ramp[2];a=.75}
  else if(style==='membrane'){const n=Math.sin(u*6+t*.7)*Math.sin(v*7-t*.5)+Math.sin(u*13-v*9+t)*.4;hit=Math.abs(n)<.07;c=PAL.blood[3];a=.8}
  else if(style==='glyph'){hit=false}
  if(hit){F.fxs(x,y,c,a*(.45+.55*z));continue}
  // reflet mobile : une bande lumineuse traverse la sphère
  const band=Math.sin((dx+dy)*5-t*1.6);if(band>.96)F.fxs(x,y,ramp[4],.4*z);
  }
 if(style==='glyph'){// trois anneaux de glyphes qui tournent sur la sphère
  [-.45,.05,.55].forEach((lat,k)=>{const yy=cy+lat*ry,rr=r*Math.sqrt(1-lat*lat)*.92,n=14;
   for(let i=0;i<n;i++){const ang=i/n*6.283+t*(k%2?.35:-.28);const z=Math.cos(ang);if(z<-.15)continue;
    const x=cx+Math.sin(ang)*rr,lit=(i+Math.floor(t*3)+k*5)%7===0;glyph(F,x-1,yy-2+Math.sin(ang*2+t)*1.5,i+k*3,lit?ramp[5]:ramp[3],true,z>.3?1:.5)}});}
}

/* ---------- 4 propositions ---------- */
const PROPS=[
{id:'hierophante',name:'1 · Le Hiérophante de Byrsa',title:'Vieux prêtre du Credo, l’ostensoir levé',
 desc:'Un vieillard décharné qui ne tient plus debout : il flotte, la chasuble trop grande sur les os. Haute mitre d’or, barbe blanche, yeux creux qui s’allument quand il prie. Son ostensoir solaire ouvre des cercles de lumière d’où sortent les fidèles du Credo.',
 sw:['gold','robe','night','hair','blood'],ward:['gold','hex'],float:5,summon:'light',
 roster:['creep','scout','shield','brute'],
 pts:['<span>Bouclier</span> : sphère d’alvéoles d’or, la même lumière que le dôme de la Martyre.','<span>Invocations</span> : Fanatiques, Infanterie légère, Boucliers dorés, et un Automate doré de temps en temps.','<span>Geste</span> : il lève l’ostensoir à deux mains, un rai de lumière tombe sur chaque cercle.','<span>Lecture</span> : le plus classique, il prolonge la Martyre (Byrsa, or, Credo).'],
 draw(P,st){const p=PAL,L=st.lift,by=st.by-L,up=raise(st.a),hx=CX,hy=40+by;
  poly(P,[[61,50+by],[79,50+by],[86+st.sw*1.2,FY-L-2],[54+st.sw*.6,FY-L-2]],p.night,{v:.4,fold:.15,foldDx:st.sw*2,edge:.15});
  poly(P,[[63,52+by],[77,52+by],[81+st.sw*.8,FY-L],[70,FY-L+1],[59+st.sw*.5,FY-L]],p.robe,{v:.6,fold:.17,foldDx:st.sw});
  for(let i=0;i<14;i++){const x=60+(i*5%21),y=FY-L-1-(i*3%4);P.set(x,y,p.ichor[1+(i%2)])}
  // dentelure de l'ourlet
  for(let x=59;x<=81;x+=3)P.set(x+Math.round(st.sw*.6),FY-L+1,null);
  poly(P,[[62,51+by],[78,51+by],[76.5,79+by],[70,84+by],[63.5,79+by]],p.gold,{v:.5,fold:.05});
  line(P,70,53+by,70,82+by,p.blood[3]);line(P,71,53+by,71,81+by,p.blood[2]);
  glyph(P,64,58+by,2,p.gold[5]);glyph(P,74,60+by,4,p.gold[5]);
  // tête
  seg(P,[hx,hy+4],[hx,hy+9],3.5,p.ash,{v:.45});
  ell(P,hx,hy,4.6,5.4,p.ash,{v:.66,l:.36});
  const lit=up>.4;P.set(hx-2,hy,lit?p.gold[5]:p.ash[0]);P.set(hx+1,hy,lit?p.gold[5]:p.ash[0]);P.set(hx-2,hy-1,p.ash[1]);P.set(hx+1,hy-1,p.ash[1]);
  P.set(hx-3,hy+2,p.ash[2]);P.set(hx+2,hy+2,p.ash[2]);
  poly(P,[[hx-4.4,hy+2],[hx+4.4,hy+2],[hx+3,hy+13],[hx+.5,hy+19+st.sw*.4],[hx-2.5,hy+13]],p.hair,{v:.72,fold:.12});
  line(P,hx-1,hy+3,hx+1,hy+3,p.hair[1]);
  // mitre et fanons
  seg(P,[hx-4,hy-2],[hx-6+st.sw*.4,hy+9],2,p.gold,{v:.45});seg(P,[hx+4,hy-2],[hx+6+st.sw*.4,hy+9],2,p.gold,{v:.4});
  poly(P,[[hx-5,hy-3],[hx+5,hy-3],[hx+4.6,hy-13],[hx,hy-22],[hx-4.6,hy-13]],p.gold,{v:.62,l:.34});
  line(P,hx,hy-5,hx,hy-19,p.gold[1]);line(P,hx-5,hy-4,hx+5,hy-4,p.gold[1]);glyph(P,hx-3,hy-14,0,p.blood[3]);
  // bras gauche : main ouverte, levée pendant l'invocation
  const lh=[lerp(60,50,up),lerp(73,34,up)+by],le=[lerp(60,55,up),lerp(63,48,up)+by];
  seg(P,[63,54+by],le,4,p.robe,{v:.52});seg(P,le,lh,3.4,p.robe,{v:.58});
  ell(P,lh[0],lh[1]-1,1.8,2.2,p.ash,{v:.7});line(P,lh[0]-1,lh[1]-3,lh[0]-2,lh[1]-5,p.ash[3]);line(P,lh[0]+1,lh[1]-3,lh[0]+1,lh[1]-5,p.ash[3]);
  // bâton et ostensoir
  const sx=88,top=27+by-up*12,hy2=62+by-up*16;
  seg(P,[sx,top+7],[sx,FY-L-4-up*12],2.2,p.horn,{v:.5,edge:.1});
  ell(P,sx,top,5.2,5.2,p.gold,{v:.7});ell(P,sx,top,2.2,2.2,p.blood,{v:.75,edge:0});
  for(let i=0;i<12;i++){const g=i/12*6.283,R=i%2?7:8.5;line(P,sx+Math.cos(g)*5.6,top+Math.sin(g)*5.6,sx+Math.cos(g)*R,top+Math.sin(g)*R,p.gold[i%2?3:4])}
  seg(P,[77,54+by],[sx-2,hy2],3.6,p.robe,{v:.55});ell(P,sx-1,hy2+1,1.9,2.2,p.ash,{v:.68})},
 fx(F,st){const p=PAL,up=raise(st.a),b=burst(st.a),L=st.lift,by=st.by-L,top=27+by-up*12;
  if(up>0){disc(F,88,top,8+up*4,p.gold[5],up*.55);for(let i=0;i<8;i++){const g=i/8*6.283+st.t*.8;line(F,88+Math.cos(g)*9,top+Math.sin(g)*9,88+Math.cos(g)*(11+up*7),top+Math.sin(g)*(11+up*7),p.gold[4],true,up*.8)}}
  if(st.a!=null){const k=cl(st.a/.7);ring(F,40,FY+1,3+k*9,1.5+k*2.5,p.gold[4],.9);ring(F,40,FY+1,1+k*6,.8+k*1.6,p.gold[3],.6)
   if(b>0&&b<1){for(let y=8;y<FY;y++)if(bay(40,y)<1-b)for(let x=37;x<=43;x++)F.fxs(x,y,x===40?p.gold[5]:p.gold[4],(1-b)*(1-Math.abs(x-40)/4))}}
  if(st.ward)ward(F,st,p.gold,'hex',{open:st.open})}},

{id:'montreur',name:'2 · Le Montreur de Byrsa',title:'Marionnettiste du Credo souillé',
 desc:'Un bossu sous un manteau noir, visage caché derrière un masque de porcelaine fendu. Il tient au-dessus de lui une croix de manipulation en bois et or ; ses fils d’ichor descendent jusqu’au sol et relèvent des soldats tombés comme des pantins. Un petit pantin danse toujours à son côté.',
 sw:['night','bone','gold','ichor','blood'],ward:['bone','threads'],float:0,summon:'threads',
 roster:['scout','archer','shield','creep'],
 pts:['<span>Bouclier</span> : cage de fils tendus, pâle comme la porcelaine.','<span>Invocations</span> : des soldats du Credo « pendus » à ses fils, qui descendent du ciel et tombent sur leurs pieds.','<span>Geste</span> : la croix bascule, les fils se tendent vers le sol, le pantin s’agite.','<span>Lecture</span> : on comprend tout de suite d’où viennent les unités et qu’elles lui sont liées.'],
 draw(P,st){const p=PAL,L=st.lift,by=st.by,up=raise(st.a),jerk=st.a!=null?Math.sin(st.a*40)*up*1.5:0,tilt=Math.sin(st.t*1.4)*1.5+up*4;
  // manteau bossu, liseré d'or au bas et au col
  poly(P,[[58,60+by],[63,51+by],[72,48+by],[80,52+by],[85+st.sw*1.3,FY],[70,FY+1],[55+st.sw*.6,FY]],p.night,{v:.62,l:.4,fold:.22,foldDx:st.sw*2,edge:.15});
  ell(P,73,55+by,7,5,p.night,{v:.68,l:.4});// bosse
  for(let x=56;x<=85;x++){const y=FY-1-Math.round(Math.sin((x-56)/29*Math.PI)*.8);P.set(x+Math.round(st.sw*.8),y,p.gold[(x%3)?2:3])}
  line(P,66,62+by,62,FY-2,p.night[5]);line(P,76,60+by,80,FY-3,p.night[1]);
  for(let i=0;i<8;i++){const x=58+(i*7%26),y=FY-3-(i*5%9);P.set(x,y,p.ichor[0])}
  // capuche et masque, tête basse et en avant
  const hx=63,hy=56+by;
  poly(P,[[hx-8,hy+6],[hx-8,hy-4],[hx-3,hy-10],[hx+5,hy-9],[hx+9,hy-2],[hx+8,hy+7]],p.night,{v:.66,l:.4,edge:.2});
  ell(P,hx-.5,hy+.5,5.4,6.6,p.bone,{v:.82,l:.3});
  P.set(hx-3,hy-1,p.ichor[0]);P.set(hx-2,hy-1,p.ichor[0]);P.set(hx+1,hy-1,p.ichor[0]);P.set(hx+2,hy-1,up>.4?p.blood[5]:p.blood[3]);
  line(P,hx-2,hy+4,hx+1,hy+4,p.bone[2]);P.set(hx-3,hy+3,p.bone[2]);P.set(hx+2,hy+3,p.bone[2]);
  line(P,hx+1,hy-6,hx+2,hy-1,p.blood[3]);line(P,hx+2,hy-1,hx,hy+3,p.blood[2]);
  P.set(hx-2,hy+1,p.ichor[1]);P.set(hx-2,hy+2,p.ichor[1]);P.set(hx-2,hy+3,p.ichor[2]);// larme d'ichor
  line(P,hx-7,hy+8,hx+7,hy+8,p.gold[3]);
  // bras levés vers la croix
  const cx0=74,cy0=24+by-up*3+jerk;
  seg(P,[64,62+by],[69,cy0+9],3.4,p.night,{v:.55});seg(P,[80,58+by],[80,cy0+9],3.4,p.night,{v:.5});
  ell(P,69,cy0+7,1.8,2.2,p.ash,{v:.66});ell(P,80,cy0+7,1.8,2.2,p.ash,{v:.6});
  // croix de manipulation (bois et or)
  const ax=cx0-12,ay=cy0-tilt,bx=cx0+12,byy=cy0+tilt;
  seg(P,[ax,ay],[bx,byy],2.4,p.horn,{v:.55});seg(P,[cx0,cy0-8],[cx0,cy0+8],2.4,p.horn,{v:.5});
  for(const[x,y]of[[ax,ay],[bx,byy],[cx0,cy0-8],[cx0,cy0+8]])ell(P,x,y,1.6,1.6,p.gold,{v:.72,edge:0});
  // petit pantin suspendu
  const px=99+Math.sin(st.t*2.6)*2+jerk*2,py=72+Math.sin(st.t*5.2)*1.5-up*6;
  seg(P,[px,py+3],[px,py+10],3.2,p.robe,{v:.5});ell(P,px,py,2.4,2.6,p.bone,{v:.8});P.set(px+1,py,p.ichor[0]);
  line(P,px-1,py+4,px-4,py+8+Math.sin(st.t*5)*2,p.robe[2]);line(P,px+1,py+4,px+4,py+7-Math.sin(st.t*5)*2,p.robe[2]);
  line(P,px-1,py+10,px-2,py+15,p.robe[2]);line(P,px+1,py+10,px+2+Math.sin(st.t*5.2),py+15,p.robe[2]);
  P.set(px,py+6,p.gold[4]);
  this._k={ax,ay,bx,byy,cx0,cy0,px,py}},
 fx(F,st){const p=PAL,k=this._k,up=raise(st.a),b=burst(st.a);
  const thread=(x0,y0,x1,y1,c,a)=>{const n=Math.ceil(Math.hypot(x1-x0,y1-y0));for(let i=0;i<=n;i++){const u=i/n,sag=Math.sin(u*Math.PI)*1.5;F.fxs(lerp(x0,x1,u)+sag*.3,lerp(y0,y1,u)+sag,c,a)}};
  thread(k.bx,k.byy,k.px,k.py-2,p.bone[3],.8);thread(k.cx0,k.cy0+8,k.px-3,k.py+7,p.bone[3],.6);thread(k.cx0,k.cy0-8,k.px+4,k.py+6,p.bone[3],.6);
  if(st.a!=null){// les fils plongent vers le sol, à gauche, puis tirent le soldat vers le haut
   const tx=38,ty=FY-lerp(0,30,b)*(b<1?1:0);
   for(const[x,y,o]of[[k.ax,k.ay,-3],[k.cx0,k.cy0-8,0],[k.ax+4,k.ay,3]]){const reach=cl(st.a/.5);thread(x,y,lerp(x,tx+o,reach),lerp(y,ty-8,reach),up>.5?p.gold[3]:p.bone[3],.85)}
   const r=cl(st.a/.7);ring(F,tx,FY+1,2+r*8,1+r*2.2,p.ichor[3],1);ring(F,tx,FY+1,1+r*6,.6+r*1.6,p.bone[2],.7)}
  if(st.ward)ward(F,st,p.bone,'threads',{open:st.open})}},

{id:'berger',name:'3 · Le Berger des galeries',title:'Pâtre de la Chair du Dévoreur',
 desc:'Une longue silhouette voûtée, vêtue de chair pâle cousue. Sous la capuche, pas de visage : un nid de petites bouches et d’yeux rouges. Il tient une houlette d’os à clochette ; quand il frappe le sol, la terre se fend en lèvres de chair et vomit ses bêtes.',
 sw:['flesh','pale','bone','blood','ichor'],ward:['flesh','membrane'],float:0,summon:'flesh',
 roster:['beast','beast','beast','brute'],
 pts:['<span>Bouclier</span> : membrane de chair translucide, parcourue de veines qui battent.','<span>Invocations</span> : Aberrations du Dévoreur par trois, petites et rapides, et parfois un Automate souillé.','<span>Geste</span> : il lève la houlette et l’abat, la clochette sonne, le sol s’ouvre.','<span>Lecture</span> : rompt avec l’or du Credo : un boss de la Bête pour le biome des galeries.'],
 draw(P,st){const p=PAL,by=st.by,up=raise(st.a),a=st.a;let sy=0;if(a!=null){sy=a<.35?-ease(a/.35)*10:a<.5?-10+ease((a-.35)/.15)*12:2*(1-ease((a-.5)/.5))}
  const hx=68,hy=32+by;
  // robe de chair cousue, voûtée
  poly(P,[[60,42+by],[76,40+by],[85+st.sw*1.3,FY],[70,FY+1],[54+st.sw*.6,FY]],p.flesh,{v:.5,fold:.2,foldDx:st.sw*2,edge:.16});
  for(let x=54;x<=85;x+=2)if((x>>1)%2)P.set(x+Math.round(st.sw*.8),FY,null);
  // coutures et veines
  line(P,66,48+by,63,FY-6,p.pale[2]);for(let y=50;y<FY-6;y+=4)P.set(64-(y-50)/20,y+by*0,p.pale[4]);
  line(P,74,50+by,78,FY-10,p.blood[2]);line(P,76,66+by,80,72+by,p.blood[2]);
  // mantelet de chair pâle à bouches
  poly(P,[[57,44+by],[79,41+by],[82,54+by],[69,58+by],[56,55+by]],p.pale,{v:.6,fold:.1});
  for(const[x,y]of[[61,50],[73,48],[78,53]]){P.set(x,y+by,p.blood[1]);P.set(x+1,y+by,p.blood[1]);P.set(x,y+by-1,p.bone[5])}
  // capuche et nid de bouches
  poly(P,[[hx-8,hy+9],[hx-8,hy-4],[hx-3,hy-11],[hx+4,hy-11],[hx+8,hy-4],[hx+8,hy+9],[hx+2,hy+12],[hx-3,hy+12]],p.pale,{v:.56,edge:.22});
  ell(P,hx,hy+2,4.4,6,p.ichor,{v:.5,edge:0});
  const pul=.5+.5*Math.sin(st.t*4);
  [[hx-2,hy-1],[hx+2,hy],[hx,hy+3],[hx-2,hy+5],[hx+2,hy+6]].forEach(([x,y],i)=>{const lit=i%2?pul>.5||up>.3:true;P.set(x,y,lit?p.blood[4]:p.blood[2]);if(i>=2){P.set(x-1,y,p.bone[4]);P.set(x+1,y,p.bone[4])}});
  // bras gauche : longue main ouverte vers le sol
  const lh=[lerp(56,50,up),lerp(70,80,up)+by];seg(P,[60,48+by],lh,3.2,p.pale,{v:.55});
  for(let i=-1;i<=1;i++)line(P,lh[0]+i,lh[1]+1,lh[0]+i*2,lh[1]+5,p.pale[3]);
  // houlette d'os et clochette
  const sx=89,top=20+by+sy;
  seg(P,[sx,top+4],[sx,FY+sy*.3],2.4,p.bone,{v:.6,edge:.1});
  tube(P,[[sx,top+5],[sx+1,top-4],[sx-8,top-6],[sx-8,top+1]],1.3,1,p.bone,{v:.62});
  for(let y=top+10;y<FY;y+=7)line(P,sx-1,y,sx+1,y,p.bone[2]);
  const bell=Math.sin(st.t*3+(a!=null?a*30:0))*1.2;seg(P,[sx-8,top+1],[sx-8+bell,top+5],1,p.horn,{v:.4,edge:0});
  poly(P,[[sx-10+bell,top+9],[sx-6+bell,top+9],[sx-7+bell,top+5],[sx-9+bell,top+5]],p.horn,{v:.6,edge:.15});
  seg(P,[78,46+by],[sx-2,58+by+sy*.6],3.4,p.pale,{v:.55});ell(P,sx-1,59+by+sy*.6,2,2.2,p.pale,{v:.65})},
 fx(F,st){const p=PAL,a=st.a;
  if(a!=null){const u=cl((a-.48)/.5);if(u>0){const R=rng(53);
    for(let k=0;k<6;k++){const ang=Math.PI+(R()-.5)*1.8,Ln=(6+R()*22)*Math.min(1,u*2.4);let x=86,y=FY;for(let i=0;i<Ln;i++){x+=Math.cos(ang)+(R()-.5)*.7;y+=Math.sin(ang)*.3+(R()-.5)*.5;F.fxs(x,y,p.flesh[u<.6?4:3],1-u*.7);if(i%5===2)F.fxs(x,y-1,p.blood[4],1-u)}}
    ring(F,88,FY,4+u*24,1.5+u*7,p.flesh[4],(1-u)*.8);
    // lèvres qui s'ouvrent à l'endroit de l'invocation
    const o=Math.sin(Math.min(1,u*1.5)*Math.PI);for(let x=-6;x<=6;x++){const hgt=Math.round(o*2.6*(1-(x/6)**2));F.fxs(40+x,FY-hgt,p.flesh[4]);F.fxs(40+x,FY+hgt,p.flesh[3]);for(let y=-hgt+1;y<hgt;y++)F.fxs(40+x,FY+y,p.ichor[1])}}}
  if(st.ward)ward(F,st,p.flesh,'membrane',{open:st.open})}},

{id:'scribe',name:'4 · Le Scribe des Noms',title:'Greffier des morts du Credo',
 desc:'Un scribe aveugle, les yeux bandés d’or, qui flotte assis dans le vide. Autour de lui s’enroule un rouleau sans fin couvert des noms des soldats morts pour le Credo. Il lit à voix haute : chaque nom prononcé se détache du parchemin et revient en soldat de lumière.',
 sw:['robe','gold','hair','ichor','blood'],ward:['gold','glyph'],float:6,summon:'glyph',
 roster:['archer','spitter','scout','shield'],
 pts:['<span>Bouclier</span> : trois anneaux de glyphes qui tournent sur une sphère d’or.','<span>Invocations</span> : Archers, Thuriféraires, Infanterie légère, Boucliers dorés : ceux dont il lit le nom.','<span>Geste</span> : il pointe sa plume, un nom s’allume sur le rouleau et vole jusqu’au cercle.','<span>Lecture</span> : le plus « magique » ; le rouleau donne une jauge naturelle du nombre d’invocations restantes.'],
 draw(P,st){const p=PAL,L=st.lift,by=st.by-L,up=raise(st.a),hx=CX,hy=42+by,rot=st.t*.5;
  // rouleau : moitié arrière
  const band=(front)=>{const n=80;for(let i=0;i<n;i++){const ang=i/n*6.283,z=Math.sin(ang);if(front?z<0:z>=0)continue;
    const x=CX+Math.cos(ang)*27,y=70+by+Math.sin(ang)*7+Math.sin(ang*2+rot)*1.2;ell(P,x,y,1.6,2.6,p.robe,{v:front?.72:.46,edge:0,l:.1})}
   for(let i=0;i<16;i++){const ang=i/16*6.283+rot*.6,z=Math.sin(ang);if(front?z<0:z>=0)continue;const x=CX+Math.cos(ang)*27,y=70+by+Math.sin(ang)*7+Math.sin(ang*2+rot)*1.2;
    if(Math.abs(Math.cos(ang))>.93)continue;const lit=(i+Math.floor(st.t*2))%6===0||(up>.5&&i%3===0);P.set(x,y-1,lit?p.gold[5]:p.ichor[2]);P.set(x+(i%2?1:-1),y,lit?p.gold[4]:p.ichor[3])}};
  band(false);
  // corps assis en tailleur
  poly(P,[[63,50+by],[77,50+by],[80,72+by],[60,72+by]],p.robe,{v:.6,fold:.14,foldDx:st.sw});
  ell(P,70,76+by,13,5,p.robe,{v:.55});// genoux
  poly(P,[[61,74+by],[79,74+by],[76+st.sw,86+by],[70,88+by],[64+st.sw*.5,86+by]],p.robe,{v:.5,fold:.2});// pan qui pend
  line(P,70,52+by,70,72+by,p.gold[3]);
  // capuche, visage et bandeau d'or
  poly(P,[[hx-7,hy+8],[hx-7,hy-3],[hx-3,hy-9],[hx+3,hy-9],[hx+7,hy-3],[hx+7,hy+8]],p.robe,{v:.5,edge:.22});
  ell(P,hx,hy+1,4.2,5.2,p.skin,{v:.6});
  line(P,hx-4,hy-1,hx+4,hy-1,p.gold[4]);line(P,hx-4,hy,hx+4,hy,p.gold[3]);
  P.set(hx-2,hy+1,p.blood[3]);P.set(hx+2,hy+2,p.blood[3]);// larmes sous le bandeau
  const mouth=up>.2&&Math.sin(st.t*14)>0;P.set(hx,hy+4,mouth?p.ichor[0]:p.skin[2]);if(mouth)P.set(hx-1,hy+4,p.ichor[1]);
  // bras : la main droite tient la plume, la gauche guide le rouleau
  const qh=[lerp(80,86,up),lerp(66,48,up)+by];
  seg(P,[76,53+by],qh,3.4,p.robe,{v:.58});ell(P,qh[0],qh[1],1.8,2,p.skin,{v:.66});
  tube(P,[[qh[0]-1,qh[1]+2],[qh[0]+2,qh[1]-4],[qh[0]+5,qh[1]-9],[qh[0]+7,qh[1]-14]],1.8,.6,p.hair,{v:.7});
  seg(P,[64,53+by],[57,66+by],3.4,p.robe,{v:.52});ell(P,57,67+by,1.8,2,p.skin,{v:.62});
  band(true);this._q=qh},
 fx(F,st){const p=PAL,up=raise(st.a),b=burst(st.a),q=this._q;
  if(up>0){disc(F,q[0]+7,q[1]-14,2+up*2,p.gold[5],up*.8)}
  if(st.a!=null){// un nom quitte le rouleau et vole vers le cercle
   const k=cl((st.a-.2)/.55),sx=CX-24,sy=72,tx=40,ty=FY-6;
   if(k>0&&k<1){const x=lerp(sx,tx,k),y=lerp(sy,ty,k)-Math.sin(k*Math.PI)*22;glyph(F,x-1,y-2,Math.floor(st.t*8),p.gold[5],true);for(let i=1;i<6;i++){const kk=Math.max(0,k-i*.035);F.fxs(lerp(sx,tx,kk),lerp(sy,ty,kk)-Math.sin(kk*Math.PI)*22,p.gold[4],1-i/6)}}
   const r=cl(st.a/.75);ring(F,40,FY+1,3+r*9,1.3+r*2.5,p.gold[3],.9);for(let i=0;i<6;i++){const g=i/6*6.283+st.t;glyph(F,40+Math.cos(g)*(4+r*9)-1,FY+Math.sin(g)*(1.3+r*2.5)-2,i,p.gold[4],true,r)}
   if(b>0&&b<1)for(let y=20;y<FY;y++)for(let x=37;x<=43;x++)F.fxs(x,y,p.gold[x===40?5:3],(1-b)*(1-Math.abs(x-40)/4)*.9)}
  if(st.ward)ward(F,st,p.gold,'glyph',{open:st.open})}},
];

function render(prop,t,a,o={}){const P=new Px(),lift=prop.float?prop.float+Math.sin(t*1.8)*1.5:0;
 const st={t,by:Math.round(Math.sin(t*2)*.6),sw:Math.sin(t*1.3),a,lift:Math.round(lift),ward:o.ward!==false,open:o.open||0};
 prop.draw(P,st);const F=new Px();prop.fx&&prop.fx(F,st);const c=raster(P,F);c.lift=lift;return c}
function raster(P,F){
 const c=document.createElement('canvas');c.width=W;c.height=H;const g=c.getContext('2d'),im=g.createImageData(W,H),d=im.data;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;let col=P.c[i];
  if(!col){const nb=[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>{const X=x+dx,Y=y+dy;return X>=0&&Y>=0&&X<W&&Y<H&&P.c[Y*W+X]&&!P.n[Y*W+X]});if(nb)col=OUT}
  if(col){const[r,gg,b]=rgb(col);d[i*4]=r;d[i*4+1]=gg;d[i*4+2]=b;d[i*4+3]=255}}
 if(F)for(let i=0;i<W*H;i++){const col=F.fx[i];if(!col)continue;const[r,gg,b]=rgb(col);d[i*4]=r;d[i*4+1]=gg;d[i*4+2]=b;d[i*4+3]=255}
 g.putImageData(im,0,0);return c}
// sol d'ardoise tyrienne
function ground(w,h,seed){const c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d'),im=g.createImageData(w,h),d=im.data,S=PAL.slate;
 const n=(x,y)=>{const v=Math.sin(x*12.9898+y*78.233+seed)*43758.5453;return v-Math.floor(v)};
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const tx=Math.floor(x/16+(Math.floor(y/12)%2)*.5),ty=Math.floor(y/12),base=.25+n(tx,ty)*.35,edge=(x+(Math.floor(y/12)%2)*8)%16===0||y%12===0;
  let v=base+(n(x,y)-.5)*.18;if(edge)v-=.22;const f=cl(v)*(S.length-1),i=Math.floor(f),col=S[Math.min(S.length-1,f-i>bay(x,y)?i+1:i)],[r,gg,b]=rgb(col),k=(y*w+x)*4;d[k]=r;d[k+1]=gg;d[k+2]=b;d[k+3]=255}
 g.putImageData(im,0,0);return c}
function shadow(g,cx,cy,rx,ry){g.fillStyle='rgba(6,6,10,.55)';for(let y=Math.floor(cy-ry);y<=cy+ry;y++)for(let x=Math.floor(cx-rx);x<=cx+rx;x++){const dx=(x+.5-cx)/rx,dy=(y+.5-cy)/ry,q=dx*dx+dy*dy;if(q<=1&&(q<.55||bay(x,y)>.5))g.fillRect(x,y,1,1)}}
// pixel tramé direct sur un contexte 2D (scènes à l'échelle du jeu et schémas)
function dot(g,x,y,col,a=1){x=Math.round(x);y=Math.round(y);if(a<1&&a<=bay(x,y))return;g.fillStyle=col;g.fillRect(x,y,1,1)}
function gring(g,x,y,rx,ry,col,a=1){const n=Math.ceil(rx*7);for(let k=0;k<n;k++){const t=k/n*6.283;dot(g,x+Math.cos(t)*rx,y+Math.sin(t)*ry,col,a)}}
function gline(g,x0,y0,x1,y1,col,a=1){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))));for(let i=0;i<=n;i++)dot(g,x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,col,a)}
function gdisc(g,x,y,r,col,a=1){for(let j=Math.floor(y-r);j<=y+r;j++)for(let i=Math.floor(x-r);i<=x+r;i++)if(Math.hypot(i+.5-x,j+.5-y)<=r)dot(g,i,j,col,a)}
return{PROPS,PAL,WARD,render,ground,shadow,dot,gring,gline,gdisc,bay,cl,ease,lerp,rng,W,H,CX,FY}})();
