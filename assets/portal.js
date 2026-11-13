// Portail tyrien : rendu pixel dans le plan d'un mur isométrique, 3 designs × 10 états. Dépend de decor.js et units.js.
'use strict';
const PortalKit=(()=>{const PW_=130,PH_=112,OX=66,OY=104,RC=46,RI=25,RO=35;
const ENG=UnitKit.ENGINEERS[4].s;
const DESIGNS=[
 {name:'A · Arche tyrienne',desc:'Fidèle au storyboard : anneau de pierre segmenté sur des contreforts en gradins moussus, porte circulaire gravée qui s’ouvre en deux battants coulissants, lueur ambrée.',
  shape:'arch',door:'slide',stone:['#22231f','#33342e','#48473e','#5e5c4f','#777361','#918b74','#aaa38a'],glow:['#5a2a08','#a0560e','#e08a1e','#ffc04a','#fff0b0','#ffffff']},
 {name:'B · Porte-sceau monolithique',desc:'Dalle massive de basalte percée d’un oculus, couronnée d’un fronton. La porte s’ouvre en diaphragme depuis le centre ; lueur blanc-bleu d’Énonciation.',
  shape:'slab',door:'iris',stone:['#15171b','#1f2228','#2c3038','#3c414b','#515762','#6a717d','#868e9a'],glow:['#0a2a5a','#1c5ab0','#4a9cf0','#a8d8ff','#f0faff','#ffffff']},
 {name:'C · Anneau suspendu',desc:'Huit segments d’anneau flottent au-dessus d’un socle à deux piliers ; à l’ouverture ils s’écartent et tournent, la porte se dissout. Lueur violette, celle de l’Ancre.',
  shape:'ring',door:'dissolve',stone:['#2a2620','#3d3830','#544d42','#6e6656','#8a806c','#a69b84','#c2b69c'],glow:['#2a1460','#5a32b0','#9a6cf0','#d0b8ff','#f8f0ff','#ffffff']},
];
const STATES=[
 {n:'1 · État initial',d:'Portail inactif et scellé.'},
 {n:'2 · Activation',d:'Les sceaux tyriens s’illuminent et s’alignent.',glyph:1,seals:1,rim:.3},
 {n:'3 · Ouverture',d:'Le portail s’ouvre et libère un flux d’énergie.',glyph:.6,seals:1,open:.55,field:.7,rim:.8,arcs:1,dust:1},
 {n:'4 · Émergence',d:'L’Ingénieur Exilé franchit le seuil.',glyph:.3,seals:1,open:1,field:1,rim:1,arcs:.6,unit:'emerge'},
 {n:'5 · Stabilisation',d:'Le portail reste ouvert, prêt pour le déploiement.',glyph:.2,seals:.8,open:1,field:.55,rim:.6,unit:'stand'},
 {n:'1 · Initiation',d:'L’ingénieur lance la séquence de fermeture.',open:1,field:.8,rim:1,arcs:1,seals:1,unit:'console'},
 {n:'2 · Dissipation',d:'Le flux se résorbe, le champ s’affaiblit.',open:1,field:.35,rim:.5,flicker:1,arcs:.3,dust:1,seals:.7},
 {n:'3 · Refermeture',d:'Les segments se rejoignent et se verrouillent.',open:.35,field:.2,seam:1,seals:.6,rim:.3},
 {n:'4 · Scellement',d:'Les sceaux se stabilisent, le portail redevient inactif.',glyph:1,seals:1,seam:.4},
 {n:'5 · État final',d:'Portail scellé jusqu’à la prochaine activation.'},
];
const B4=(x,y)=>BAYER[y&3][x&3];
const ramp=(r,v,x,y)=>{v=Math.max(0,Math.min(.999,v))*(r.length-1);let i=Math.floor(v);if(v-i>B4(x,y))i++;return r[Math.min(i,r.length-1)]};
const mixHex=(a,b,k)=>{const A=hex(a),Bc=hex(b);return'#'+A.map((c,i)=>Math.round(c+(Bc[i]-c)*k).toString(16).padStart(2,'0')).join('')};

/* ---------- géométrie : (u le long du mur, v vers le haut), origine au pied du portail ---------- */
function frameAt(D,u,v,S,t){const r=Math.hypot(u,v-RC),au=Math.abs(u);
 if(D.shape==='arch'){if(r>=RI&&r<=RO&&v>=4)return'ring';const lim=RO+14;if(au>=RO-8&&au<=lim&&v>=4){const hb=Math.round((74-(au-(RO-8))*2.4)/7)*7;if(v<hb)return'block'}return null}
 if(D.shape==='slab'){const top=RC+RO+6-Math.max(0,au-6)*.55;if(au<=RO+6&&v>=4&&v<=top&&r>=RI)return au>RO+3||v>top-3?'edge':'slab';return null}
 // anneau suspendu : segments qui s'écartent et tournent à l'ouverture
 const op=S.open||0,a=Math.atan2(v-RC,u)-op*.35-t*.15*op,seg=((a/(Math.PI/4))%1+1)%1,lift=Math.sin(t*1.6)*1.2,rr=Math.hypot(u,v-RC-lift)-op*5;
 if(rr>=RI&&rr<=RO-3&&seg>.08&&seg<.92)return'ring';if(au>=RO-2&&au<=RO+6&&v>=4&&v<RC-12)return'pillar';return null}
function doorAt(D,u,v,S,x,y){const op=S.open||0;let du=u;
 if(D.door==='slide'){du=u-Math.sign(u||1)*op*RI;if(Math.sign(du)!==Math.sign(u||1))return null}
 const r=Math.hypot(du,v-RC);if(r>=RI)return null;
 if(D.door==='iris'&&Math.hypot(u,v-RC)<op*RI*1.05)return null;
 if(D.door==='dissolve'&&(hash(Math.floor(u),Math.floor(v),3)*.6+B4(x,y)*.4)<op)return null;
 return{du,r}}
function seals(u,v){const a=Math.atan2(v-RC,u),k=Math.round(a/(Math.PI/4)),ka=k*Math.PI/4,cx=Math.cos(ka)*(RI+RO)/2,cy=RC+Math.sin(ka)*(RI+RO)/2;return Math.abs(u-cx)<2.2&&Math.abs(v-cy)<2.2}

/* ---------- matériau d'un point du plan du mur ---------- */
function shade(D,u,v,S,t,x,y){const st=D.stone,gl=D.glow,pulse=.78+.22*Math.sin(t*4),r=Math.hypot(u,v-RC),fl=S.flicker?(Math.sin(t*23)*Math.sin(t*7.7)>.2?1:.45):1;
 if(v<0)return null;
 if(v<6&&Math.abs(u)<46){let k=.55-v*.03+(hash(Math.floor(u/6),Math.floor(v/2),2)-.5)*.15;if(v%2<1)k-=.18;return ramp(st,k,x,y)}
 const f=frameAt(D,u,v,S,t);
 if(f){let k=f==='edge'?.75:.52+Math.cos(Math.atan2(v-RC,u)-2.2)*.12+(fbm(u/7,v/7,4)-.5)*.2;
  if(f==='ring'){const a=Math.atan2(v-RC,u);if(((a/(Math.PI/8))%1+1)%1<.07)k-=.25;
   if(seals(u,v)){const s=(S.seals||0)*pulse*fl;return s>.05?ramp(gl,.35+s*.6,x,y):ramp(st,.2,x,y)}
   if(Math.abs(r-RI)<1.3&&(S.rim||0)>0)return ramp(gl,(S.rim)*.85*fl*pulse,x,y)}
  if(f==='block'||f==='pillar'||f==='slab'){const row=Math.floor(v/7),col=Math.floor((u+(row%2)*4.5)/9);if(v%7<1||((u+(row%2)*4.5)%9+9)%9<1)k-=.22;k+=(hash(row,col,7)-.5)*.14}
  if(fbm(u/9,v/6,11)>.68&&(f!=='slab'||v>RC))return ramp(['#1a3a1c','#2a5228','#3e6c34','#5a8a44'],k+.15,x,y);
  if(f==='slab'&&Math.abs(r-RI-2)<1&&(S.rim||0)>0)return ramp(gl,S.rim*.8*fl,x,y);
  return ramp(st,k,x,y)}
 const d=doorAt(D,u,v,S,x,y);
 if(d){const{du}=d,dr=Math.hypot(du,v-RC);let k=.5+(fbm(du/6,v/6,5)-.5)*.2-dr/RI*.12;
  const groove=[9,17,22.5].some(q=>Math.abs(dr-q)<.7),seam=Math.abs(du)<1.4,glyph=(Math.abs(du)<1.4||Math.abs(v-RC)<.9)&&dr<RI-2||Math.abs(dr-6)<.9;
  if(seam&&(S.seam||0)>0)return ramp(gl,.45+S.seam*.5*pulse,x,y);
  if(glyph){const g=(S.glyph||0)*pulse*fl;return g>.06?ramp(gl,.3+g*.65,x,y):ramp(st,.18,x,y)}
  if(groove||seam)k-=.24;return ramp(st,k,x,y)}
 if(r<RI&&D.shape!=='slab'||(D.shape==='slab'&&r<RI)){const fi=(S.field||0)*fl;if(fi<.02)return ramp(['#070908','#0e1210','#161c18'],.5-r/RI*.4,x,y);
  const a=Math.atan2(v-RC,u),val=.3+.32*Math.sin(a*3+r*.28-t*5)+.18*Math.sin(a*5-r*.4+t*3)+.35*(1-r/RI);
  if(fi>.75&&r<5+fi*2)return ramp(gl,.92,x,y);return ramp(gl,Math.max(0,val)*fi,x,y)}
 return null}
/* ---------- rendu d'un état ---------- */
function render(D,S,t){const c=document.createElement('canvas');c.width=PW_;c.height=PH_;const g=c.getContext('2d'),img=g.createImageData(PW_,PH_),a=img.data;
 const put=(x,y,col)=>{x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=PW_||y>=PH_)return;const i=(y*PW_+x)*4,h=hex(col);a[i]=h[0];a[i+1]=h[1];a[i+2]=h[2];a[i+3]=255};
 const toXY=(u,v)=>[OX-u,OY+u*.5-v];
 for(let y=0;y<PH_;y++)for(let x=0;x<PW_;x++){let u=OX-x,v=OY+u*.5-y,col=shade(D,u,v,S,t,x,y);
  if(!col){const u2=OX-(x-3),v2=OY+u2*.5-(y-1.5);const f=v2>=6&&frameAt(D,u2,v2,S,t);if(f)col=D.stone[0]}
  if(col){const i=(y*PW_+x)*4,h=hex(col);a[i]=h[0];a[i+1]=h[1];a[i+2]=h[2];a[i+3]=255}}
 // contour sombre
 const m=new Uint8Array(PW_*PH_);for(let i=0;i<m.length;i++)m[i]=a[i*4+3]>0;
 for(let y=1;y<PH_-1;y++)for(let x=1;x<PW_-1;x++){const i=y*PW_+x;if(!m[i]&&(m[i-1]||m[i+1]||m[i-PW_]||m[i+PW_]))put(x,y,'#070808')}
 // arcs électriques le long du bord intérieur
 if(S.arcs)for(let k=0;k<6;k++){if(k>=S.arcs*6)break;const a0=k*1.047+Math.sin(t*2+k)*.6,len=10+Math.sin(t*3+k)*5;let ang=a0,rr=RI-1;
  for(let j=0;j<len;j++){ang+=.06*Math.sin(t*9+j+k);rr+=Math.sin(j*1.7+t*11+k)*1.3-.25;const[x,y]=toXY(Math.cos(ang)*rr,RC+Math.sin(ang)*rr);put(x,y,j%3?D.glow[3]:D.glow[5])}}
 // poussière et étincelles au pied
 if(S.dust)for(let k=0;k<26;k++){const ph=((k*.37+t*.5)%1),u=(k%2?1:-1)*(8+((k*13)%28)),v=2+ph*10,[x,y]=toXY(u+Math.sin(t+k)*3,v);put(x,y,ph<.4?D.glow[3]:'#5e574a')}
 g.putImageData(img,0,0);
 // ingénieur
 if(S.unit){const fig=UnitKit.figure(ENG,t,.5);const fw=fig.width,fh=fig.height;
  if(S.unit==='emerge'){const[x,y]=toXY(0,4);g.globalAlpha=1;g.drawImage(fig,Math.round(x-15),Math.round(y-40))}
  if(S.unit==='stand'){const[x,y]=toXY(-18,0);g.drawImage(fig,Math.round(x+6-15),Math.round(y+6-40))}
  if(S.unit==='console'){const[px,py]=toXY(-30,0);g.fillStyle='#070808';g.fillRect(px+5,py-14,12,16);g.fillStyle='#3c3c36';g.fillRect(px+6,py-13,10,14);g.fillStyle=D.glow[3];g.fillRect(px+7,py-12,8,4);g.fillStyle=D.glow[4];g.fillRect(px+9+Math.round(Math.sin(t*5)*2),py-11,2,2);
   g.drawImage(fig,Math.round(px+14),Math.round(py-36))}}
 return c}

return{DESIGNS,STATES,render,W:PW_,H:PH_,OX,OY}})();
