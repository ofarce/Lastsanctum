// Kit de sprites d'unités pixel art (gabarit 80×84). Dépend de assets/decor.js.
// Expose UnitKit.figure(spec, temps, échelle) et les fiches UnitKit.UNITS / UnitKit.TIREUR.
'use strict';
const UnitKit=(()=>{
const K={
 steel:['#1a1b20','#2a2c33','#3e414a','#575b64','#767b84','#9da2a9','#c8ccd0'],
 gun:['#101012','#1a1a1e','#26262c','#34343b','#46464e','#5e5e68'],
 ivory:['#3e372c','#5e5644','#847a62','#a99e82','#cbc1a4','#e6dfc8'],
 crim:['#2a070c','#460e16','#661620','#8a222c','#ac3438','#c85048'],
 gold:['#3e2c10','#6a4c1c','#9a7228','#c89c3c','#ecc862','#fff0a8'],
 leath:['#1a110a','#2a1c10','#3e2a18','#543a22','#6c4c2e'],
 skin:['#3a2016','#663e2a','#8e5a3e','#b47a56','#d49e78','#ecc4a0'],
 skin2:['#24140c','#3e2414','#5a361e','#7a4c2a','#9a663a','#b88250'],
 saff:['#3a1606','#64280c','#9a4414','#cc6620','#ee8e34','#ffbc62'],
 blue:['#08142e','#0e2858','#18448e','#2e6cc8','#64a2f4','#bcdcff'],
 bronze:['#24160a','#422a12','#6a421c','#966228','#c08a3a','#e8b860'],
 violet:['#120a22','#24164a','#3c2a78','#5c46aa','#8a72d8','#c4b2ff'],
 green:['#0c1e12','#16321c','#22492a','#33623a','#4c7e48','#6e9c5a'],
 amber:['#4a2206','#8a420c','#d0781a','#ffb03c','#ffe08a'],
 hair:['#140e0a','#261a12','#3a281a','#523a24'],
 white:['#5a5a58','#8a8a86','#b4b4ae','#d8d8d0','#f2f2ea'],
 teal:['#0a1e1e','#123232','#1c4a48','#2a6662','#40867e'],
 polish:['#141518','#25272b','#3a3d42','#55585e','#767a80','#a2a6ab','#d6d9dc','#ffffff'],
 eGold:['#5a3a08','#a87018','#f0b830','#ffe070','#fff8d0'],
 eBlue:['#0a2a5a','#1c5ab0','#4a9cf0','#a8d8ff','#f0faff'],
 eViolet:['#2a1460','#5a32b0','#9a6cf0','#d0b8ff','#f8f0ff'],
 eGreen:['#0e3a1e','#1e7a3a','#46c060','#a8f0a0','#f0fff0'],
 eWhite:['#5a6070','#9aa4b8','#d8e0f0','#f4f8ff','#ffffff'],
};
const OUT='#0a0a0c';
/* ---------- primitives ---------- */
function bbox(pts){let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;for(const[x,y]of pts){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}return[x0,x1,y0,y1]}
function fill(P,pts,ramp,z,o={}){const[x0,x1,y0,y1]=bbox(pts);P.poly(pts,(x,y)=>{let v=(o.v??.62)-(x-x0)/(x1-x0+1)*(o.lx??.42)-(y-y0)/(y1-y0+1)*(o.ly??.15);if(o.tex)v+=(hash(x,y,o.tex)-.5)*.14;if(o.fold&&((x*3+y)%7===0))v-=.12;return P.ramp(ramp,v,x,y)},z)}
function ell(P,cx,cy,rx,ry,ramp,z,o={}){for(let y=Math.floor(cy-ry);y<=cy+ry;y++)for(let x=Math.floor(cx-rx);x<=cx+rx;x++){const nx=(x+.5-cx)/rx,ny=(y+.5-cy)/ry,d=nx*nx+ny*ny;if(d>1)continue;let v=(o.v??.62)-(nx*.45+ny*.5)*.5-d*.08;P.set(x,y,P.ramp(ramp,v,x,y),z)}}
function seg(P,a,b,w,ramp,z,o){const dx=b[0]-a[0],dy=b[1]-a[1],l=Math.hypot(dx,dy),nx=-dy/l*w/2,ny=dx/l*w/2;fill(P,[[a[0]+nx,a[1]+ny],[b[0]+nx,b[1]+ny],[b[0]-nx,b[1]-ny],[a[0]-nx,a[1]-ny]],ramp,z,o)}
function line(P,x0,y0,x1,y1,col,z){P.line(x0,y0,x1,y1,col,z)}
function outlineAll(P){const w=P.w,h=P.h,a=P.d.data,m=new Uint8Array(w*h);for(let i=0;i<w*h;i++)m[i]=a[i*4+3]>0;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){if(m[y*w+x])continue;if((x>0&&m[y*w+x-1])||(x<w-1&&m[y*w+x+1])||(y>0&&m[(y-1)*w+x])||(y<h-1&&m[(y+1)*w+x])){const i=(y*w+x)*4;a.set(hex(OUT),i);a[i+3]=255}}}
function glowDots(P,cx,cy,r,col,n,R){for(let k=0;k<n;k++){const a=R()*6.283,d=r*(.6+R()*.5);P.set(cx+Math.cos(a)*d,cy+Math.sin(a)*d,col,40)}}

/* ---------- casques et têtes (centre cx, cy) ---------- */
const HEAD={
 coif:(P,cx,cy,s)=>{fill(P,[[cx-7,cy+8],[cx-7,cy-4],[cx-1,cy-8],[cx+5,cy-7],[cx+7,cy],[cx+7,cy+8]],K.steel,30,{v:.6,tex:7});ell(P,cx+2,cy+1,3.6,4.2,s.skin||K.skin2,31,{v:.75});P.set(cx+1,cy,OUT,32);P.set(cx+4,cy,OUT,32);
  if(s.hc)fill(P,[[cx-8,cy+9],[cx-8,cy-3],[cx-2,cy-10],[cx+4,cy-9],[cx+7,cy-5],[cx-3,cy-5],[cx-5,cy+9]],s.hc,33,{v:.6,fold:1});if(s.band)fill(P,[[cx-4,cy-5],[cx+6,cy-6],[cx+6,cy-4],[cx-4,cy-3]],s.band,34)},
 kettle:(P,cx,cy,s)=>{ell(P,cx+2,cy+1,4,5,s.skin||K.skin2,30,{v:.75});P.set(cx+1,cy,OUT,31);P.set(cx+4,cy,OUT,31);fill(P,[[cx-6,cy+7],[cx-6,cy-1],[cx-2,cy-1],[cx-2,cy+7]],K.steel,30,{v:.4,tex:7});
  ell(P,cx,cy-4,6,4,s.hr||K.steel,32,{v:.75});fill(P,[[cx-10,cy-2],[cx+10,cy-3],[cx+8,cy-1],[cx-9,cy]],s.hr||K.steel,33,{v:.7});if(s.band)fill(P,[[cx-6,cy-3],[cx+6,cy-4],[cx+6,cy-2],[cx-6,cy-2]],s.band,34)},
 hoodMask:(P,cx,cy,s)=>{fill(P,[[cx-8,cy+8],[cx-8,cy-3],[cx-1,cy-10],[cx+6,cy-7],[cx+8,cy+1],[cx+8,cy+8]],s.hc||K.green,30,{v:.62,fold:1});fill(P,[[cx-1,cy-3],[cx+7,cy-4],[cx+7,cy+1],[cx-1,cy+1]],s.skin||K.skin2,31,{v:.6});P.set(cx+2,cy-2,OUT,32);P.set(cx+5,cy-2,OUT,32);
  fill(P,[[cx-1,cy+1],[cx+7,cy+1],[cx+7,cy+6],[cx-1,cy+6]],s.mask||K.saff,32,{v:.6})},
 greathelm:(P,cx,cy,s)=>{fill(P,[[cx-6,cy-7],[cx+6,cy-7],[cx+7,cy+6],[cx-6,cy+6]],K.steel,30,{v:.7});line(P,cx-5,cy-1,cx+5,cy-1,OUT,31);line(P,cx,cy-1,cx,cy+5,K.steel[1],31);for(let i=0;i<3;i++)P.set(cx+3,cy+2+i,OUT,31);
  if(s.plume)for(let i=0;i<9;i++)fill(P,[[cx-1+i*.3,cy-7-i],[cx+2+i*.6,cy-7-i],[cx+3+i*.8,cy-5-i],[cx+i*.4,cy-5-i]],s.plume,29,{v:.7-i*.04})},
 saurus:(P,cx,cy,s)=>{fill(P,[[cx-6,cy-6],[cx+5,cy-7],[cx+9,cy-2],[cx+9,cy+3],[cx+5,cy+6],[cx-6,cy+5]],s.hr||K.gun,30,{v:.75});for(let i=0;i<3;i++)P.set(cx+3+i*2,cy-1,OUT,31);
  for(let i=0;i<5;i++)fill(P,[[cx+3-i*2.6,cy-6],[cx+5-i*2.6,cy-6],[cx+2-i*3.2,cy-12-(i<2?2:0)+i]],i%2?K.steel:K.gun,29,{v:.6})},
 open:(P,cx,cy,s)=>{ell(P,cx+1,cy+1,5,6,s.skin||K.skin,29,{v:.7});if(s.beard)fill(P,[[cx-3,cy+3],[cx+5,cy+3],[cx+3,cy+8],[cx-1,cy+8]],K.hair,30,{v:.6});P.set(cx+2,cy,OUT,31);P.set(cx+4,cy,OUT,31);
  fill(P,[[cx-6,cy-7],[cx+6,cy-8],[cx+7,cy-1],[cx-6,cy-1]],s.hr||K.steel,32,{v:.75});fill(P,[[cx+2,cy-2],[cx+3,cy-2],[cx+3,cy+3],[cx+2,cy+3]],s.hr||K.steel,33);fill(P,[[cx-7,cy-2],[cx-4,cy-2],[cx-4,cy+5],[cx-7,cy+4]],s.hr||K.steel,32,{v:.4})},
 hood:(P,cx,cy,s)=>{fill(P,[[cx-8,cy+7],[cx-7,cy-4],[cx-1,cy-9],[cx+5,cy-7],[cx+8,cy],[cx+8,cy+7]],s.hc||K.ivory,30,{v:.72,fold:1});fill(P,[[cx-2,cy-3],[cx+6,cy-4],[cx+7,cy+5],[cx-1,cy+5]],s.face?s.skin||K.skin:K.gun,31,{v:s.face?.5:.25});
  if(s.face){P.set(cx+2,cy-1,OUT,32);P.set(cx+5,cy-1,OUT,32)}if(s.mask)fill(P,[[cx,cy-1],[cx+7,cy-1],[cx+12,cy+3],[cx+6,cy+4],[cx,cy+3]],s.mask,32,{v:.65})},
 veil:(P,cx,cy,s)=>{fill(P,[[cx-8,cy+9],[cx-7,cy-5],[cx,cy-9],[cx+6,cy-7],[cx+8,cy+2],[cx+7,cy+9]],s.hc||K.white,30,{v:.75,fold:1});ell(P,cx+2,cy+1,4,5,s.skin||K.skin,31,{v:.75});fill(P,[[cx-3,cy-5],[cx+6,cy-6],[cx+7,cy-3],[cx-3,cy-3]],s.band||K.ivory,32);P.set(cx+1,cy,OUT,33);P.set(cx+4,cy,OUT,33)},
 turban:(P,cx,cy,s)=>{ell(P,cx+1,cy+2,5,6,s.skin||K.skin2,29,{v:.7});if(s.beard)fill(P,[[cx-3,cy+4],[cx+5,cy+4],[cx+3,cy+9],[cx-1,cy+9]],K.hair,30);P.set(cx+2,cy+1,OUT,31);P.set(cx+5,cy+1,OUT,31);
  ell(P,cx,cy-4,7,5,s.tc||K.saff,32,{v:.75});for(let i=-5;i<6;i+=2)P.set(cx+i,cy-4+Math.abs(i)*.3,(s.tc||K.saff)[1],33);ell(P,cx+2,cy-5,1.5,1.5,s.gem||K.blue,34,{v:.9})},
 topknot:(P,cx,cy,s)=>{ell(P,cx+1,cy+1,5,6,s.skin||K.skin2,29,{v:.7});ell(P,cx-1,cy-6,3,3,K.hair,30,{v:.6});fill(P,[[cx-5,cy-4],[cx+5,cy-5],[cx+6,cy-2],[cx-5,cy-2]],K.hair,30);P.set(cx+2,cy,OUT,31);P.set(cx+5,cy,OUT,31);for(let i=-1;i<2;i++)P.set(cx+1+i,cy-3,K.saff[5],31);if(s.beard)fill(P,[[cx-2,cy+4],[cx+5,cy+4],[cx+3,cy+8],[cx],[cy+8]].filter(p=>p.length===2),K.hair,30)},
 bronzehelm:(P,cx,cy,s)=>{ell(P,cx+1,cy+2,5,5,s.skin||K.skin2,29,{v:.65});P.set(cx+2,cy+1,OUT,31);P.set(cx+5,cy+1,OUT,31);if(s.beard)fill(P,[[cx-3,cy+4],[cx+5,cy+4],[cx+3,cy+9],[cx-1,cy+9]],K.hair,30);
  fill(P,[[cx-6,cy-1],[cx-5,cy-6],[cx,cy-9],[cx+5,cy-7],[cx+7,cy-1]],K.bronze,32,{v:.8});line(P,cx,cy-9,cx,cy-14,K.bronze[4],32);P.set(cx,cy-15,K.blue[4],33);fill(P,[[cx-7,cy-1],[cx-4,cy-1],[cx-4,cy+6],[cx-7,cy+5]],K.bronze,32,{v:.45})},
};
/* ---------- armes et boucliers (main en hx,hy) ---------- */
const W={
 holySword:(P,hx,hy,s,t)=>{const g=K[s.glow||'eGold'],amp=.5+.5*Math.sin(t*4+s.seed),L=s.blade||30,R=rng(s.seed*7+Math.floor(t*6));
  for(let i=0;i<L;i++){const x=hx+i*(s.swing||0),y=hy-4-i;for(let k=-2;k<=2;k++){const c=Math.abs(k)===2?g[1]:Math.abs(k)===1?g[2+(i%3===0)]:g[3+(amp>.6)];P.set(x+k,y,c,50)}}
  P.set(hx+L*(s.swing||0),hy-4-L,g[4],50);for(let k=0;k<12+amp*14;k++){const i=R()*L,d=2.5+R()*(2+amp*4),a=R()*6.283;P.set(hx+i*(s.swing||0)+Math.cos(a)*d,hy-4-i+Math.sin(a)*d*.6,g[2+(R()<amp*.6)],49)}
  fill(P,[[hx-6,hy-4],[hx+6,hy-4],[hx+6,hy-1],[hx-6,hy-1]],K.polish,51,{v:.8});fill(P,[[hx-1,hy-1],[hx+1,hy-1],[hx+1,hy+5],[hx-1,hy+5]],K.leath,51);ell(P,hx,hy+6,1.8,1.8,K.polish,51,{v:.9})},
 quiver:(P,hx,hy)=>{},
};
const X={
 // bâton tenu à deux mains en diagonale, tête crépitante, projectile tiré vers l'avant
 staffEnergy:(P,o,s,t)=>{const g=K[s.energy||'eViolet'],a=[o.hR[0]-6,o.hR[1]+14],b=[o.hL[0]+7,o.hL[1]-18],R=rng(s.seed*13+Math.floor(t*10));
  seg(P,a,b,2.4,s.shaft||K.polish,49,{v:.7});for(const k of[.25,.55])P.set(a[0]+(b[0]-a[0])*k,a[1]+(b[1]-a[1])*k,K.gold[4],50);
  fill(P,[[b[0]-4,b[1]+1],[b[0]+3,b[1]-2],[b[0]+1,b[1]+3]],K.gold,50,{v:.8});
  const cx=b[0]+1,cy=b[1]-5,amp=.5+.5*Math.sin(t*5+s.seed);ell(P,cx,cy,3.6+amp*.8,3.6+amp*.8,g,52,{v:.95});
  for(let k=0;k<3;k++){let x=cx,y=cy;const dir=R()*6.283;for(let j=0;j<6+R()*5;j++){x+=Math.cos(dir)*1.6+(R()-.5)*2.2;y+=Math.sin(dir)*1.6+(R()-.5)*2.2;P.set(x,y,g[3+(R()<.4)],53)}}
  // projectile
  const ph=(t*1.2+s.seed*.37)%1,px=cx+6+ph*30,py=cy+ph*6;if(px<78&&!s.noProj){ell(P,px,py,3,2.2,g,55,{v:1});for(let i=1;i<10;i++)P.set(px-i*1.4,py-i*.2+(R()-.5)*1.4,g[i<4?3:2],54-i*.1)}},
 // arc long bandé : arc à la main avant, corde tirée jusqu'à la main arrière, flèche à pointe chargée
 bowDraw:(P,o,s,t)=>{const h=o.hL,r=o.hR,g=K[s.energy||'eBlue'],d=s.loosed?0:(s.draw??1),vib=s.loosed?(s.loosed===1?1.6:-.8):0;for(let k=-22;k<=22;k++){const x=h[0]+2+Math.cos(k/22*1.25)*(3.5+d*2.5)+vib*(1-Math.abs(k)/22),y=h[1]+k;P.set(x,y,(s.bow||K.leath)[4-(Math.abs(k)>16)],48);P.set(x+1,y,(s.bow||K.leath)[2],48)}
  const tip=[h[0]+2,h[1]-22],bot=[h[0]+2,h[1]+22];
  // corde lâchée : elle revient droite et vibre ; sinon elle suit la main arrière
  if(s.loosed){const nx=h[0]+2+vib*1.5;line(P,tip[0],tip[1],nx,h[1],K.white[3],47);line(P,bot[0],bot[1],nx,h[1],K.white[3],47);
   if(s.loosed===1){const R=rng(s.seed);for(let i=0;i<10;i++)P.set(h[0]+16+i*2.2,h[1]-1,i<3?g[4]:g[3-(i>6)],53);for(let k=0;k<10;k++)P.set(h[0]+14+R()*8,h[1]-1+(R()-.5)*6,g[2+(R()<.5)],53)}return}
  line(P,tip[0],tip[1],r[0],r[1],K.white[3],47);line(P,bot[0],bot[1],r[0],r[1],K.white[3],47);
  if(d<.15)return; // flèche pas encore encochée
  line(P,r[0],r[1],h[0]+12,h[1]-1,K.leath[4],51);fill(P,[[h[0]+12,h[1]-3],[h[0]+16,h[1]-1],[h[0]+12,h[1]+1]],K.polish,52,{v:.9});
  for(const dd of[-1,1])line(P,r[0],r[1],r[0]-3,r[1]+dd*2,K.crim[4],51);
  if(s.charged&&d>.6){const amp=.5+.5*Math.sin(t*6+s.seed),R=rng(Math.floor(t*12)+s.seed);for(let k=0;k<8+amp*8;k++)P.set(h[0]+14+(R()-.3)*6,h[1]-1+(R()-.5)*5,g[2+(R()<.5)],53)}},
 quiverBack:(P,o,s)=>{seg(P,[o.cx+6,24],[o.cx-6,48],5,K.leath,2,{v:.6});for(let i=0;i<4;i++){line(P,o.cx+5+i,24-i,o.cx+7+i,19-i,K.crim[3+(i%2)],3);P.set(o.cx+7+i,18-i,K.white[4],3)}},
 bladeAt:(P,o,s,t)=>{const g=K[s.glow||'eGold'],h=o.hR,a=s.ang??-Math.PI/2,L=s.blade||28,ux=Math.cos(a),uy=Math.sin(a),px=-uy,py=ux,pow=s.power??.5,R=rng(s.seed*7+Math.floor(t*20));
  if(s.trail){const[a0,a1]=s.trail,n=Math.ceil(Math.abs(a1-a0)*L*.9);for(let i=0;i<=n;i++){const aa=a0+(a1-a0)*i/n,fade=i/n;for(let rr=L*.45;rr<=L+2;rr+=1){if(BAYER[Math.floor(rr)&3][i&3]>fade*.95)continue;P.set(h[0]+Math.cos(aa)*rr,h[1]+Math.sin(aa)*rr,g[1+Math.round(fade*2+(rr>L*.85))],64)}}}
  for(let i=4;i<L;i++){const x=h[0]+ux*i,y=h[1]+uy*i;for(let k=-1;k<=1;k++)P.set(x+px*k,y+py*k,k===0?g[3+(pow>.7)]:g[2],66)}P.set(h[0]+ux*L,h[1]+uy*L,g[4],50);
  for(let k=0;k<6+pow*16;k++){const i=4+R()*(L-4),d=2+R()*(1+pow*4),aa=R()*6.283;P.set(h[0]+ux*i+Math.cos(aa)*d,h[1]+uy*i+Math.sin(aa)*d,g[2+(R()<pow*.6)],65)}
  for(let k=-5;k<=5;k++)P.set(h[0]+ux*3+px*k,h[1]+uy*3+py*k,K.polish[5-(Math.abs(k)>3)],67);for(let i=-3;i<3;i++)P.set(h[0]+ux*i,h[1]+uy*i,K.leath[3],67);P.set(h[0]-ux*4,h[1]-uy*4,K.polish[6],67)},
 crossbow:(P,o,s,t)=>{const r=o.hR,l=o.hL,y=r[1]-1,amp=.5+.5*Math.sin(t*4);
  fill(P,[[r[0]-7,y-2],[l[0]+8,y-3],[l[0]+8,y+1],[r[0]-7,y+2]],K.gun,48,{v:.7});fill(P,[[r[0]-9,y-3],[r[0]-5,y-3],[r[0]-5,y+5],[r[0]-9,y+4]],K.leath,48);
  ell(P,r[0]+5,y+4,4.5,4.5,K.gun,49,{v:.7});for(let i=0;i<3;i++){const yy=y+1+((i*2+(s.drumRot||0))%7);fill(P,[[r[0]+2,yy],[r[0]+8,yy],[r[0]+8,yy+1],[r[0]+2,yy+1]],K.amber,50,{v:.7+amp*.25+(s.drumHot||0)*.2})}
  fill(P,[[r[0]+3,y-6],[r[0]+9,y-6],[r[0]+9,y-3],[r[0]+3,y-3]],K.gun,50,{v:.6});P.set(r[0]+9,y-5,K.amber[4],51);
  const fx=l[0]+7;for(const d of[-1,1]){for(let i=0;i<9;i++)P.set(fx-i*.35,y-1+d*i,K.gun[4-(i>6)],49);P.set(fx-3,y-1+d*9,K.steel[5],49)}
  line(P,fx-3,y-10,r[0]+6,y-1,K.white[3],47);line(P,fx-3,y+8,r[0]+6,y-1,K.white[3],47);line(P,r[0]+6,y-2,fx+5,y-2,K.steel[5],51);P.set(fx+6,y-2,K.amber[4],52);P.set(fx+7,y-2,K.amber[3],52)},
 strips:(P,o,s)=>{const cx=o.cx;[[-8,K.crim,66],[-4,K.ivory,72],[0,K.crim,70],[4,K.ivory,74],[8,K.crim,68]].forEach(([dx,r,yb])=>fill(P,[[cx+dx-2.5,48],[cx+dx+2.5,48],[cx+dx+3,yb],[cx+dx-3,yb]],r,9,{v:.62,fold:1}))},
 ichor:(P,o,s,t)=>{const R=rng(s.seed*31),ic=['#0a0a0a','#160c12','#24101c','#3a1630'];
  for(let k=0;k<9;k++){const x=o.cx-10+R()*22,y0=30+R()*24,l=8+R()*22;for(let y=0;y<l;y++){const w=y<l*.7?1:0;for(let i=0;i<=w;i++)P.set(x+i+Math.sin(y*.4+k)*.6,y0+y,ic[(y+k)%4>1?1:2],45)}P.set(x,y0+l+((t*8+k)%3),ic[0],45)}
  for(let k=0;k<5;k++){let x=o.cx-6+R()*14,y=24+R()*18;for(let j=0;j<6;j++){x+=R()-.5;y+=1;P.set(x,y,s.ichorGold?'#f0cc66':ic[3],46)}}
  P.set(o.cx+3,22,ic[0],46);P.set(o.cx+3,23,ic[1],46);P.set(o.cx+3,24,ic[1],46);P.set(o.cx+6,22,ic[0],46);P.set(o.cx+6,23,ic[1],46)},
 cloak:(P,o,s)=>{fill(P,[[o.cx-11,30],[o.cx+9,30],[o.cx+13,s.cloakY||74],[o.cx-15,s.cloakY||74]],s.cloakC||K.green,1,{v:.45,fold:1})},
 shine:(P,o,s)=>{const c=K.polish[7],d=K.polish[6];for(const sd of[-1,1]){const x=o.cx+sd*10.5*o.B;for(let i=0;i<3;i++)P.set(x-2+i,28+i*0,i===1?c:d,30)}for(let i=0;i<4;i++)P.set(o.cx-3+i*.5,33+i,i<2?c:d,30);P.set(o.cx+4,61,c,30);P.set(o.cx-5,61,d,30)},
 sword:(P,hx,hy)=>{fill(P,[[hx-1,hy-27],[hx+1,hy-27],[hx+1.5,hy-4],[hx-1.5,hy-4]],K.steel,50,{v:.85,lx:.6});line(P,hx,hy-27,hx,hy-29,K.steel[6],50);fill(P,[[hx-5,hy-4],[hx+5,hy-4],[hx+5,hy-2],[hx-5,hy-2]],K.gold,51);fill(P,[[hx-1,hy-2],[hx+1,hy-2],[hx+1,hy+3],[hx-1,hy+3]],K.leath,51);ell(P,hx,hy+4,1.6,1.6,K.gold,51)},
 greatsword:(P,hx,hy)=>{for(let t=0;t<34;t++){const x=hx+t*.55,y=hy-4-t;fill(P,[[x-1.5,y],[x+1.5,y],[x+1.5,y+1],[x-1.5,y+1]],K.steel,50,{v:.85-t/80})}fill(P,[[hx-6,hy-4],[hx+5,hy-6],[hx+6,hy-4],[hx-5,hy-2]],K.gold,51);seg(P,[hx,hy-3],[hx-2,hy+5],2.5,K.leath,51)},
 mace:(P,hx,hy)=>{seg(P,[hx,hy+4],[hx+1,hy-16],2.5,K.leath,50);ell(P,hx+1,hy-19,4.5,4.5,K.steel,51,{v:.75});for(const[a,b]of[[-5,0],[5,0],[0,-5]])P.set(hx+1+a,hy-19+b,K.steel[5],52)},
 hammer:(P,hx,hy)=>{seg(P,[hx,hy+6],[hx+1,hy-20],2.5,K.leath,50);fill(P,[[hx-5,hy-26],[hx+7,hy-26],[hx+7,hy-19],[hx-5,hy-19]],K.steel,51,{v:.75});fill(P,[[hx-5,hy-24],[hx+7,hy-24],[hx+7,hy-23],[hx-5,hy-23]],K.gold,52)},
 flail:(P,hx,hy)=>{seg(P,[hx,hy+3],[hx+1,hy-12],2.5,K.leath,50);for(let i=0;i<6;i++)P.set(hx+2+i*1.2,hy-13-i*.6+(i*i)*.15,K.steel[4],51);ell(P,hx+10,hy-13,4,4,K.gun,52,{v:.7});for(const[a,b]of[[-4,0],[4,0],[0,-4],[0,4]])P.set(hx+10+a*1.25,hy-13+b*1.25,K.steel[5],53)},
 staffLantern:(P,hx,hy)=>{seg(P,[hx,hy+22],[hx,hy-30],2,K.leath,50);fill(P,[[hx-3,hy-34],[hx+3,hy-34],[hx+3,hy-28],[hx-3,hy-28]],K.gun,51);fill(P,[[hx-2,hy-33],[hx+2,hy-33],[hx+2,hy-29],[hx-2,hy-29]],K.amber,52,{v:.9});line(P,hx-3,hy-35,hx,hy-37,K.gun[3],51);line(P,hx+3,hy-35,hx,hy-37,K.gun[3],51);glowDots(P,hx,hy-31,7,K.amber[3],10,rng(hx))},
 staffOrb:(P,hx,hy)=>{seg(P,[hx,hy+22],[hx,hy-28],2,K.gun,50);fill(P,[[hx-4,hy-28],[hx+4,hy-28],[hx+1,hy-25],[hx-1,hy-25]],K.gold,51);ell(P,hx,hy-32,4,4,K.violet,52,{v:.75});glowDots(P,hx,hy-32,8,K.violet[4],14,rng(hx+1))},
 staffSickle:(P,hx,hy)=>{seg(P,[hx,hy+22],[hx,hy-28],2,K.leath,50);for(let t=0;t<12;t++){const a=-1.6+t*.22;P.set(hx+Math.cos(a)*6,hy-30+Math.sin(a)*6,K.steel[5-(t>8)],51);P.set(hx+Math.cos(a)*5,hy-30+Math.sin(a)*5,K.steel[3],51)}for(let i=0;i<4;i++)P.set(hx-2+(i&1),hy-20+i*2,K.green[4],52)},
 censer:(P,hx,hy)=>{for(let i=0;i<10;i++)P.set(hx,hy+i,K.gold[3],50);ell(P,hx,hy+13,4,3,K.gold,51,{v:.7});P.set(hx-1,hy+11,K.amber[3],52);const R=rng(3);for(let k=0;k<10;k++)P.set(hx-2+R()*5,hy+6-k*1.5,k%2?'#8a8a8a':'#6a6a6a',30)},
 spearVajra:(P,hx,hy)=>{seg(P,[hx,hy+20],[hx,hy-30],2,K.leath,50);fill(P,[[hx-1,hy-30],[hx+1,hy-30],[hx+2,hy-36],[hx,hy-42],[hx-2,hy-36]],K.gold,51,{v:.85});fill(P,[[hx-4,hy-32],[hx-2,hy-31],[hx-1,hy-37],[hx-3,hy-36]],K.gold,51);fill(P,[[hx+2,hy-31],[hx+4,hy-32],[hx+3,hy-36],[hx+1,hy-37]],K.gold,51);const R=rng(9);let x=hx,y=hy-42;for(let k=0;k<8;k++){x+=R()<.5?-1:1;y-=1;P.set(x,y,K.blue[5],52);P.set(x+1,y,K.blue[4],52)}},
 talwar:(P,hx,hy)=>{for(let t=0;t<22;t++){const x=hx+t*.45+t*t*.012,y=hy-3-t;P.set(x,y,K.steel[5],50);P.set(x+1,y,K.steel[3],50);P.set(x-1,y,K.steel[4],50)}fill(P,[[hx-3,hy-3],[hx+3,hy-3],[hx+3,hy-1],[hx-3,hy-1]],K.gold,51);seg(P,[hx,hy-1],[hx,hy+4],2,K.leath,51)},
 bow:(P,hx,hy)=>{for(let t=-20;t<=20;t++){const x=hx+5-Math.abs(t)*.0+Math.cos(t/20*1.3)*6,y=hy-8+t;P.set(x,y,K.leath[4-(Math.abs(t)>15)],50);P.set(x+1,y,K.leath[2],50)}line(P,hx+5,hy-28,hx+5,hy+12,K.white[3],49);for(let i=0;i<20;i++)P.set(hx+5-i*.1,hy-8,K.leath[3],51)},
 gada:(P,hx,hy)=>{seg(P,[hx,hy+4],[hx+1,hy-14],3,K.bronze,50);ell(P,hx+1,hy-20,5.5,6.5,K.bronze,51,{v:.8});for(let i=-5;i<6;i+=2)P.set(hx+1+i,hy-20,K.bronze[1],52);ell(P,hx+1,hy-27,1.6,1.6,K.gold,52)},
 beads:(P,hx,hy)=>{for(let i=0;i<12;i++)P.set(hx-2+Math.cos(i/12*6.283)*3,hy+5+Math.sin(i/12*6.283)*4,K.crim[4],50)},
 glowHand:(P,hx,hy)=>{glowDots(P,hx,hy,6,K.amber[4],18,rng(4));ell(P,hx,hy,2.5,2.5,K.amber,52,{v:.95})},
 // boucliers
 kite:(P,hx,hy,s)=>{const pts=[[hx-7,hy-14],[hx+7,hy-15],[hx+8,hy-4],[hx+1,hy+12],[hx-6,hy-3]];fill(P,pts,s.sh||K.ivory,55,{v:.78,lx:.5});if(s.emblem!==false){fill(P,[[hx-1,hy-12],[hx+2,hy-12],[hx+2,hy+6],[hx-1,hy+6]],K.crim,56);fill(P,[[hx-5,hy-6],[hx+6,hy-6],[hx+6,hy-3],[hx-5,hy-3]],K.crim,56)}for(let i=0;i<pts.length;i++){const a=pts[i],b=pts[(i+1)%pts.length];line(P,a[0],a[1],b[0],b[1],K.steel[4],57)}},
 tower:(P,hx,hy,s)=>{fill(P,[[hx-7,hy-20],[hx+8,hy-21],[hx+9,hy+14],[hx-6,hy+15]],s.sh||K.gun,55,{v:.7});fill(P,[[hx-4,hy-16],[hx+5,hy-17],[hx+6,hy+11],[hx-3,hy+12]],K.crim,56,{v:.6});ell(P,hx+1,hy-3,3,3,K.gold,57,{v:.8});for(const[a,b]of[[-6,-19],[7,-20],[8,13],[-5,14]])P.set(hx+a,hy+b,K.steel[5],58)},
 round:(P,hx,hy,s)=>{ell(P,hx+1,hy-2,9,10,s.sh||K.bronze,55,{v:.72});for(let a=0;a<48;a++)P.set(hx+1+Math.cos(a/48*6.283)*9,hy-2+Math.sin(a/48*6.283)*10,K.bronze[1],56);ell(P,hx+1,hy-2,3,3,K.gold,57,{v:.85});if(s.sun)for(let a=0;a<8;a++)line(P,hx+1+Math.cos(a/8*6.283)*4,hy-2+Math.sin(a/8*6.283)*4,hx+1+Math.cos(a/8*6.283)*7,hy-2+Math.sin(a/8*6.283)*7,K.blue[4],57)},
 pavise:(P,hx,hy,s)=>{fill(P,[[hx-8,hy-22],[hx+9,hy-23],[hx+10,hy+16],[hx-7,hy+17]],K.steel,55,{v:.75});fill(P,[[hx-1,hy-22],[hx+3,hy-22],[hx+4,hy+16],[hx],[hy+16]].filter(p=>p.length===2),K.steel,56,{v:.95});fill(P,[[hx-4,hy-6],[hx+6,hy-6],[hx+6,hy-2],[hx-4,hy-2]],K.crim,57);fill(P,[[hx-1,hy-13],[hx+3,hy-13],[hx+3,hy+5],[hx-1,hy+5]],K.crim,57)},
};
// les armes d'origine ont été déclarées dans X : on les rend accessibles via W
for(const k in X)if(!(k in W))W[k]=X[k];
/* ---------- silhouette ---------- */
// Proxy de dessin : les coordonnées du kit (gabarit 80×84) sont projetées à l'échelle k avant rastérisation.
function scaled(P0,k){let cur=[0,0];return{w:P0.w,h:P0.h,d:P0.d,
 set:(x,y,c,z)=>P0.set(x*k,y*k,c,z),
 ramp:(r,v,x,y)=>P0.ramp(r,v,cur[0],cur[1]),
 poly:(pts,fn,z)=>P0.poly(pts.map(([x,y])=>[x*k,y*k]),(x,y)=>{cur=[x,y];return fn(x/k,y/k)},z),
 line:(x0,y0,x1,y1,col,z)=>P0.line(x0*k,y0*k,x1*k,y1*k,col,z)}}
function figure(s,t=0,k=1){const P0=new Px(Math.ceil(80*k),Math.ceil(84*k),true),P=k===1?P0:scaled(P0,k),B=s.bulk||1,cx=30,R=rng(s.seed||1);if(s.under)for(const f of s.under)X[f](P,{cx,B},s,t);
 // marche : s.walk = phase du cycle dans [0,1[ ; chaque jambe oscille en opposition, le pied se lève en phase de retour
 const WK=s.walk!=null,ph=WK?s.walk*Math.PI*2:0,sw=sd=>WK?Math.sin(ph+(sd>0?Math.PI:0)):0,lift=sd=>WK?Math.max(0,Math.cos(ph+(sd>0?Math.PI:0)))*2.4:0,flow=WK?Math.sin(ph*2)*2.4:0;
 if(s.cape)fill(P,[[cx-10*B,31],[cx+10*B,31],[cx+15*B-flow,79],[cx-14*B-flow*1.4,79]],s.cape,1,{v:.45,fold:1});
 for(const sd of[-1,1]){const x=cx+sd*4.5*B,dx=sw(sd)*5,ly=lift(sd),kx=x+dx*.45+(ly>0?1.5:0);
  fill(P,[[x-3.5*B,50],[x+3.5*B,50],[kx+3.2,61-ly*.4],[kx-3.2,61-ly*.4]],s.legs||K.gun,5,{v:sd<0?.7:.55,tex:3});fill(P,[[kx-3.2,60-ly*.4],[kx+3.2,60-ly*.4],[x+dx+3,72-ly],[x+dx-3,72-ly]],s.legs||K.gun,5,{v:sd<0?.66:.5,tex:3});
  fill(P,[[x+dx-4,71-ly],[x+dx+4,71-ly],[x+dx+(sd>0?6:3),80-ly],[x+dx-4,80-ly]],s.boots||K.gun,6,{v:sd<0?.6:.45});if(s.knee)ell(P,kx+.5,61-ly*.4,3.2,2.6,s.pr||K.steel,7,{v:.8})}
 if(s.robe)fill(P,[[cx-8*B,45],[cx+8*B,45],[cx+13*B+flow,s.robeY||79],[cx-12*B+flow,s.robeY||79]],s.robe,8,{v:.66,lx:.5,fold:1});
 // sous une robe, seuls les bouts de pieds dépassent de l'ourlet pendant la marche
 if(WK&&s.robe)for(const sd of[-1,1]){const x=cx+sd*4.5*B+sw(sd)*5,ly=lift(sd);fill(P,[[x-3,77-ly],[x+5,77-ly],[x+6,81-ly],[x-3,81-ly]],s.boots||K.leath,9,{v:sd<0?.6:.45})}
 if(s.skirt)fill(P,[[cx-9*B,46],[cx+9*B,46],[cx+11*B+flow*.6,62],[cx-10*B+flow*.6,62]],s.skirt,9,{v:.6,fold:1});
 fill(P,[[cx-10*B,29],[cx+10*B,29],[cx+7*B,48],[cx-7*B,48]],s.torso||K.steel,10,{v:.7,tex:s.mail?5:0});
 if(s.chest)ell(P,cx+1,36,7*B,6,s.chest,11,{v:.8});
 if(s.tabard){fill(P,[[cx-5*B,33],[cx+5*B,33],[cx+6*B,s.tabY||70],[cx-5*B,s.tabY||70]],s.tabard,12,{v:.74,fold:1});if(s.cross)(s.cross)(P,cx,46)}
 if(s.sash)seg(P,[cx-8*B,31],[cx+7*B,47],4,s.sash,13,{v:.75});
 fill(P,[[cx-8*B,45],[cx+8*B,45],[cx+8*B,48],[cx-8*B,48]],K.leath,14);P.set(cx+1,46,K.gold[4],15);P.set(cx+2,46,K.gold[3],15);
 if(s.belt)s.belt(P,cx,B);
 let sR=[cx-9.5*B,32],eR=[cx-12.5*B,42],hR=[cx-11*B,50],sL=[cx+9.5*B,32],eL=[cx+13*B,40],hL=[cx+12*B,47];
 // bras libre (sans objet, pose neutre) : balance en opposition à la jambe du même côté
 if(WK&&!s.left&&!s.pose){eL=[eL[0]-sw(-1)*2,eL[1]];hL=[hL[0]-sw(-1)*4.5,hL[1]-Math.abs(sw(-1))]}
 if(WK&&!s.right&&!s.pose){eR=[eR[0]-sw(1)*2,eR[1]];hR=[hR[0]-sw(1)*4.5,hR[1]-Math.abs(sw(1))]}
 if(s.pose==='twohand'){eR=[cx-12*B,44];hR=[cx-5,52];eL=[cx+12*B,38];hL=[cx+7,41]}
 if(s.pose==='guard'){eR=[cx-12*B,40];hR=[cx-6,44]}
 if(s.pose==='xbow'){eR=[cx-6*B,40];hR=[cx+1,44];eL=[cx+12*B,36];hL=[cx+12,43]}
 if(s.pose==='aim'){const d=s.loosed?0:(s.draw??1);eL=[cx+16*B,30];hL=[cx+22,32];hR=[cx+15-13*d,32+(1-d)];eR=[cx-6*B+(1-d)*7,38-(1-d)*2]}
 if(s.eRo)eR=s.eRo;if(s.hRo)hR=s.hRo;if(s.eLo)eL=s.eLo;if(s.hLo)hL=s.hLo;
 for(const[a,b,c]of[[sR,eR,hR],[sL,eL,hL]]){seg(P,a,b,5*B,s.arms||K.steel,16,{v:.65});seg(P,b,c,4.5*B,s.fore||s.arms||K.steel,16,{v:.6});ell(P,c[0],c[1],2.6,2.4,s.hands||K.gun,17,{v:.6})}
 if(s.pauld)for(const sd of[-1,1]){const x=cx+sd*10.5*B;for(let i=s.lames||1;i>=1;i--)ell(P,x+sd*i*.6,31+i*2.2,(5.5+i)*s.pauld,(3.6+i*.4)*s.pauld,i%2?(s.pr||K.steel):(s.pr2||K.gun),18+(3-i),{v:sd<0?.82:.6});if(s.rivets)P.set(x,30,K.gold[4],22)}
 if(s.gorget)ell(P,cx+1,28,5,3,s.pr||K.steel,24,{v:.75});
 HEAD[s.head](P,cx+1,19,s);
 if(s.right)W[s.right](P,hR[0],hR[1],s,t);if(s.left)W[s.left](P,hL[0],hL[1],s,t);if(s.over)for(const f of s.over)X[f](P,{cx,B,hR,hL},s,t);
 outlineAll(P0);if(s.shine&&k>=1)X.shine(P,{cx,B},s);P0.flush();return P0.c}
const crossC=(P,cx,y)=>{fill(P,[[cx-1,y-9],[cx+2,y-9],[cx+2,y+12],[cx-1,y+12]],K.crim,13);fill(P,[[cx-4,y-4],[cx+5,y-4],[cx+5,y-1],[cx-4,y-1]],K.crim,13)};
const crossG=(P,cx,y)=>{fill(P,[[cx-1,y-9],[cx+2,y-9],[cx+2,y+10],[cx-1,y+10]],K.gold,13);fill(P,[[cx-4,y-4],[cx+5,y-4],[cx+5,y-2],[cx-4,y-2]],K.gold,13)};
const sunB=(P,cx,y)=>{ell(P,cx+.5,y-2,3,3,K.gold,13,{v:.85});for(let a=0;a<8;a++)P.set(cx+.5+Math.cos(a/8*6.283)*5,y-2+Math.sin(a/8*6.283)*5,K.blue[4],13)};
const vials=(P,cx,B)=>{for(let i=0;i<4;i++){fill(P,[[cx-7+i*4,45],[cx-5+i*4,45],[cx-5+i*4,51],[cx-7+i*4,51]],[K.green[4],K.amber[3],K.violet[4],K.crim[4]].map(c=>[c,c,c])[i],15,{v:.6});P.set(cx-6+i*4,44,K.white[3],15)}};
const pouches=(P,cx,B)=>{for(const sd of[-1,1])fill(P,[[cx+sd*6-2,46],[cx+sd*6+3,46],[cx+sd*6+3,53],[cx+sd*6-2,53]],K.leath,15,{v:.6})};

const PAL={hr:K.polish,torso:K.polish,arms:K.polish,legs:K.polish,pr:K.polish,pr2:K.steel,boots:K.polish,shine:1,gorget:1,knee:1};
const UNITS=[
 {title:'PALADIN · Gardien Saurus',list:[
  {name:'P1 · Lame d’aube',desc:'Acier gris lustré, plaques brutes et épaisses, épée pulsant d’une lumière dorée, pavois cramoisi.',
   s:{...PAL,head:'saurus',pauld:1.25,lames:3,tabard:K.crim,tabY:66,cross:crossG,right:'holySword',glow:'eGold',left:'tower',bulk:1.15,seed:21}},
  {name:'P2 · Lame d’orage',desc:'Même armure, lame à la lueur blanc-bleu et garde haute. Sans tabard : l’acier nu domine.',
   s:{...PAL,head:'saurus',pauld:1.3,lames:3,chest:K.polish,skirt:K.gun,right:'holySword',glow:'eBlue',pose:'guard',left:'tower',sh:K.polish,bulk:1.18,seed:22}},
  {name:'P3 · Lame de l’Ancre',desc:'Lueur violette, celle de l’Ancre du sanctuaire. Cape cramoisie et écu en amande.',
   s:{...PAL,head:'saurus',pauld:1.2,lames:2,tabard:K.crim,cross:crossG,cape:K.crim,right:'holySword',glow:'eViolet',left:'kite',sh:K.polish,emblem:false,bulk:1.12,seed:23}},
  {name:'P4 · Colosse',desc:'Gabarit maximal, épaulières à trois lames très larges, épée longue lumineuse portée basse.',
   s:{...PAL,head:'saurus',pauld:1.45,lames:3,rivets:1,chest:K.polish,skirt:K.leath,right:'holySword',glow:'eWhite',blade:34,left:'pavise',bulk:1.28,seed:24}},
  {name:'P5 · Exécuteur',desc:'Sans bouclier, épée à deux mains inclinée, lueur dorée intense. Version offensive.',
   s:{...PAL,head:'saurus',pauld:1.25,lames:2,tabard:K.crim,tabY:64,cross:crossG,cape:K.gun,right:'holySword',glow:'eGold',swing:.45,blade:36,bulk:1.15,seed:25}},
 ]},
 {title:'SOIGNEUR · Prêtre de l’Ancre armé',list:[
  {name:'S1 · Gardien de l’Ancre',desc:'Capuche violette sur armure lustrée, bâton à deux mains surmonté d’un éclat crépitant, tire des orbes violettes.',
   s:{head:'hood',hc:K.violet,face:1,torso:K.polish,arms:K.polish,fore:K.polish,pr:K.polish,pr2:K.steel,pauld:1,lames:2,robe:K.ivory,sash:K.violet,cape:K.violet,pose:'twohand',over:['staffEnergy'],energy:'eViolet',shine:1,gorget:1,seed:31}},
  {name:'S2 · Sœur-canon',desc:'Voile blanc et cuirasse, bâton doré, projectiles de lumière ambrée. Plus lumineuse, plus « sainte ».',
   s:{head:'veil',hc:K.white,band:K.crim,torso:K.polish,arms:K.polish,fore:K.polish,pr:K.polish,pauld:.9,lames:1,robe:K.ivory,tabard:K.crim,tabY:74,cross:crossG,pose:'twohand',over:['staffEnergy'],energy:'eGold',shaft:K.gold,shine:1,seed:32}},
  {name:'S3 · Thaumaturge d’orage',desc:'Casque ouvert, armure complète, robe courte, bâton à éclairs bleus et traits d’énergie.',
   s:{head:'open',hr:K.polish,torso:K.polish,arms:K.polish,fore:K.polish,legs:K.polish,pr:K.polish,pr2:K.steel,pauld:1.1,lames:2,knee:1,skirt:K.violet,sash:K.violet,pose:'twohand',over:['staffEnergy'],energy:'eBlue',shine:1,gorget:1,seed:33}},
  {name:'S4 · Inquisiteur de l’Ancre',desc:'Casque saurus comme le Paladin, robe violette sous l’armure, orbe violette. Cohérent avec l’escouade.',
   s:{head:'saurus',hr:K.polish,torso:K.polish,arms:K.polish,fore:K.polish,pr:K.polish,pr2:K.steel,pauld:1.05,lames:2,robe:K.violet,sash:K.ivory,pose:'twohand',over:['staffEnergy'],energy:'eViolet',shine:1,gorget:1,seed:34}},
  {name:'S5 · Druide-chevalier',desc:'Capuche ivoire, armure plus sombre, bâton de bois à énergie verte : le soin vient de la jungle.',
   s:{head:'hood',hc:K.ivory,face:1,torso:K.steel,arms:K.steel,fore:K.steel,pr:K.steel,pauld:1,lames:1,robe:K.green,sash:K.leath,pose:'twohand',over:['staffEnergy'],energy:'eGreen',shaft:K.leath,gorget:1,seed:35}},
 ]},
 {title:'ESCOUADES D’INDRA · Archers',list:[
  {name:'I1 · Archer à capuche',desc:'Camail de mailles, capuche safran, brigandine de cuir, arc long bandé. Médiéval, sobre.',
   s:{head:'coif',hc:K.saff,torso:K.leath,arms:K.leath,fore:K.leath,hands:K.leath,skirt:K.saff,legs:K.gun,boots:K.leath,pose:'aim',over:['bowDraw'],under:['quiverBack','cloak'],cloakC:K.saff,seed:41}},
  {name:'I2 · Arbalétrier de la foudre',desc:'Chapel de fer à bandeau bleu, cotte de mailles, flèche chargée d’éclairs. Plus martial.',
   s:{head:'kettle',band:K.blue,torso:K.steel,mail:1,arms:K.steel,fore:K.leath,hands:K.leath,tabard:K.blue,tabY:64,cross:sunB,legs:K.gun,boots:K.leath,pose:'aim',over:['bowDraw'],under:['quiverBack'],charged:1,energy:'eBlue',seed:42}},
  {name:'I3 · Rôdeur de jungle',desc:'Cape verte, masque safran, arc sombre. Éclaireur fantastique qui se fond dans la végétation.',
   s:{head:'hoodMask',hc:K.green,mask:K.saff,torso:K.leath,arms:K.green,fore:K.leath,hands:K.leath,skirt:K.green,legs:K.leath,boots:K.leath,pose:'aim',over:['bowDraw'],under:['quiverBack','cloak'],cloakC:K.green,bow:K.gun,seed:43}},
  {name:'I4 · Archer-vétéran',desc:'Camail, épaulières de bronze, tabard safran au soleil bleu, flèche crépitante.',
   s:{head:'coif',band:K.bronze,torso:K.steel,mail:1,arms:K.steel,fore:K.leath,hands:K.leath,pauld:.9,pr:K.bronze,pr2:K.bronze,tabard:K.saff,tabY:66,cross:sunB,legs:K.gun,boots:K.bronze,pose:'aim',over:['bowDraw'],under:['quiverBack'],charged:1,energy:'eBlue',seed:44}},
  {name:'I5 · Tireur d’élite d’Indra',desc:'Capuche bleu nuit sur camail, cape safran, arc de bronze et flèche d’orage. Le plus « fantasy ».',
   s:{head:'coif',hc:K.blue,band:K.gold,torso:K.leath,arms:K.blue,fore:K.leath,hands:K.leath,skirt:K.blue,sash:K.saff,legs:K.gun,boots:K.leath,pose:'aim',over:['bowDraw'],under:['quiverBack','cloak'],cloakC:K.saff,bow:K.bronze,charged:1,energy:'eBlue',seed:45}},
 ]},
];

const TIREUR={head:'saurus',hr:K.gun,torso:K.gun,arms:K.gun,fore:K.gun,legs:K.gun,boots:K.gun,pr:K.steel,pr2:K.gun,pauld:1.05,lames:2,knee:1,gorget:1,
 tabard:K.ivory,tabY:60,cross:crossC,under:['strips'],over:['crossbow'],pose:'xbow',belt:pouches,seed:51};
return{figure,UNITS,TIREUR,K,HEAD,W,X,fill,ell,seg,line,outlineAll,glowDots,scaled,OUT}})();
