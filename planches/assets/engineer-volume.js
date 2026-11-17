// Ingénieur exilé modélisé en volume puis tramé en pixels (planche ingenieur-sans-armure-10-propositions.html).
// Repère du gabarit 80×84, pieds en (40, 80). Expose PAL, Fig, pose, drawFigure (+ équipement O.gear) et la scène de l’Ancre (FLOOR, PED, orb, shadowAt).
// Dépend de assets/decor.js et assets/units.js.
'use strict';
const UK=UnitKit.K,TAU=Math.PI*2;
const cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),mix=(a,b,t)=>a+(b-a)*t,H=(a,b,s)=>hash(a|0,b|0,s|0);
const add=(a,b)=>[a[0]+b[0],a[1]+b[1],a[2]+b[2]],sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]],mul=(a,k)=>[a[0]*k,a[1]*k,a[2]*k],dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],nrm=a=>{const l=Math.hypot(...a)||1;return[a[0]/l,a[1]/l,a[2]/l]};
const lerp3=(a,b,t)=>[mix(a[0],b[0],t),mix(a[1],b[1],t),mix(a[2],b[2],t)];

// ================= PALETTES =================
const PAL={
 skin:UK.skin,
 hair:['#120c08','#1e150e','#2e2016','#46321f','#5e4630'],
 slate:['#141a22','#1c2530','#273342','#344558','#455a70','#5a7088'],
 dusk:['#181b20','#242931','#323943','#424b57','#56606d','#6e7986'],
 ash:['#141417','#1e1e22','#2a2a30','#38383f','#4a4a53','#60606b'],
 char:['#08080b','#0f0f13','#16161b','#1f1f26','#2a2a33','#373742'],
 linen:['#2c271f','#463f32','#655b49','#887c63','#ab9f82','#cbc1a2'],
 bone:['#3a3830','#58554a','#7a766a','#9e998a','#c2bdac','#e2ddcc'],
 leath:['#170f09','#26190f','#382616','#4e3720','#684a2c','#86603c'],
 crim:UK.crim,
 olive:['#13160d','#1e2314','#2b331d','#3a4428','#4d5934','#647244'],
 navy:['#0c111d','#131a2c','#1b253e','#253250','#334366','#465a82'],
 khaki:['#1a1811','#29261a','#3a3626','#4f4a34','#676045','#817a58'],
 ochre:['#24170b','#3a2511','#553617','#734a1f','#93612a','#b07b3a'],
 steel:UK.steel,
 stone:['#14171c','#1b1f25','#23282f','#2c323a','#373e47','#444c56','#535c67','#66707b'],
 rope:['#2a2216','#423522','#5e4c31','#7c6643','#9a8156'],
 cy:['#0a2a33','#12596b','#1f9fb8','#5ce8ff','#c8fbff'],
};
const PUR=['#14061c','#2a0c3a','#4a1666','#6a2088','#9a3ab8','#c060e0','#e6b8ff'];
const QZ=['#7c7a72','#a8a498','#d0ccc0','#eeeae0'];
const BURN=['#140c08'],SCR=['#5a2418','#7a2e22'],EYE='#16100c',OUTC='#0a0a0c';
const PK={};const pack=c=>PK[c]??(PK[c]=(()=>{const h=hex(c);return((255<<24)|(h[2]<<16)|(h[1]<<8)|h[0])>>>0})());
const dark32=(u,k)=>((255<<24)|(((u>>16&255)*k)<<16)|(((u>>8&255)*k)<<8)|((u&255)*k))>>>0;
const rampAt=(r,v,x,y)=>{v=cl(v,0,.999)*(r.length-1);let i=Math.floor(v);if(v-i>BAYER[((y%4)+4)%4][((x%4)+4)%4])i++;return r[Math.min(i,r.length-1)]};

// ================= RENDU EN VOLUME, TRAMÉ EN PIXELS =================
// Repère local du personnage : X vers sa droite, Y vers le haut (pieds en Y = 0), Z vers l'avant. Unités = pixels du gabarit (×1).
// Camére orthographique en ¾ plongeant (PITCH) ; th = orientation (0 = face caméra, 90° = tourné vers la droite de l'écran).
const PITCH=.42,CA=Math.cos(PITCH),SA=Math.sin(PITCH),LT=nrm([-.55,.62,.58]);
class Fig{
 constructor(w,h,k,ox,oy,th){Object.assign(this,{w,h,k,ox,oy});this.c=Math.cos(th);this.s=Math.sin(th);this.col=new Uint32Array(w*h);this.z=new Float32Array(w*h).fill(-1e9);this.pid=new Uint8Array(w*h);this.part=0}
 W(p){return[-p[0]*this.c+p[2]*this.s,p[1],p[0]*this.s+p[2]*this.c]}
 proj(p){const w=this.W(p);return{x:Math.floor(this.ox+w[0]*this.k),y:Math.floor(this.oy+(-w[1]*CA+w[2]*SA)*this.k),d:w[2]*CA+w[1]*SA}}
 splat(p,n,r,off=0,bias=0){if(p[1]<-.3)return;const w=this.W(p),nw=this.W(n),vis=nw[1]*SA+nw[2]*CA;if(vis<-.04)return;
  const x=Math.floor(this.ox+w[0]*this.k),y=Math.floor(this.oy+(-w[1]*CA+w[2]*SA)*this.k);if(x<0||y<0||x>=this.w||y>=this.h)return;
  const d=w[2]*CA+w[1]*SA+bias,i=y*this.w+x;if(d<=this.z[i])return;const l=dot(nw,LT);
  this.z[i]=d;this.col[i]=pack(rampAt(r,.48+.44*l+off-(vis<.22?.1:0),x,y));this.pid[i]=this.part}
 // tube entre A et B, section elliptique ; s.phi = 0 devant (Z+), > 0 vers la droite (X+)
 tube(A,B,rA,rB,mat,o={}){const d0=sub(B,A),L=Math.hypot(...d0)||.01,d=mul(d0,1/L),F=o.front||[0,0,1];let v=sub(F,mul(d,dot(F,d)));if(Math.hypot(...v)<.05)v=[0,1,0];v=nrm(v);const u=cross(v,d);
  const R=t=>o.rf?o.rf(t):(()=>{const a=typeof rA==='number'?[rA,rA]:rA,b=typeof rB==='number'?[rB,rB]:rB;return[mix(a[0],b[0],t),mix(a[1],b[1],t)]})();
  const r0=R(0),r1=R(1),rm=Math.max(r0[0],r0[1],r1[0],r1[1]),n=Math.ceil(L*this.k*2.4)+1,m=Math.ceil(TAU*rm*this.k*2.6)+8;
  for(let i=0;i<=n;i++){const t=i/n,c=add(A,mul(d,L*t)),[rx,rz]=R(t);
   for(let j=0;j<m;j++){const ph=j/m*TAU,cs=Math.cos(ph),sn=Math.sin(ph),p=[c[0]+v[0]*cs*rz+u[0]*sn*rx,c[1]+v[1]*cs*rz+u[1]*sn*rx,c[2]+v[2]*cs*rz+u[2]*sn*rx];
    const s={t,phi:ph>Math.PI?ph-TAU:ph,cs,sn,P:p},r=mat(s);if(!r)continue;
    this.splat(p,nrm([v[0]*cs/rz+u[0]*sn/rx,v[1]*cs/rz+u[1]*sn/rx,v[2]*cs/rz+u[2]*sn/rx]),r[0],r[1]||0,r[2]||0)}}}
 // ellipsoïde ; s.th = 0 en haut, s.phi = 0 devant
 ell(c,rx,ry,rz,mat,o={}){const rmx=Math.max(rx,ry,rz)*(o.rmax||1),n=Math.ceil(Math.PI*rmx*this.k*2.6)+4,m=Math.ceil(TAU*rmx*this.k*2.6)+8;
  for(let i=0;i<=n;i++){const th=i/n*Math.PI,st=Math.sin(th),ct=Math.cos(th);
   for(let j=0;j<m;j++){const ph=j/m*TAU,phi=ph>Math.PI?ph-TAU:ph,g=o.rm?o.rm(th,phi):1,q=[st*Math.sin(ph)*rx*g,ct*ry*g,st*Math.cos(ph)*rz*g],p=add(c,q);
    const s={th,ct,phi,P:p,q},r=mat(s);if(!r)continue;this.splat(p,nrm([q[0]/(rx*rx),q[1]/(ry*ry),q[2]/(rz*rz)]),r[0],r[1]||0,r[2]||0)}}}
 path(pts,r0,r1,mat){for(let i=1;i<pts.length;i++){const a=mix(r0,r1,(i-1)/(pts.length-1)),b=mix(r0,r1,i/(pts.length-1));this.tube(pts[i-1],pts[i],a,b,mat,{front:[0,1,0]});if(i<pts.length-1)this.ell(pts[i],b,b,b,mat)}}
 // motif collé à la surface (yeux, rivets, glyphes…) : visible seulement si la face regarde la caméra
 dec(p,n,col,sz=1,bias=.7){const nw=this.W(n);if(nw[1]*SA+nw[2]*CA<.12)return;const q=this.proj(p),s=Math.max(1,Math.round(sz*this.k));
  for(let dy=0;dy<s;dy++)for(let dx=0;dx<s;dx++){const x=q.x+dx,y=q.y+dy;if(x<0||y<0||x>=this.w||y>=this.h)continue;const i=y*this.w+x;if(this.z[i]>-1e8&&q.d+bias<this.z[i])continue;this.col[i]=pack(col);if(this.z[i]<-1e8)this.z[i]=q.d}}
 finish(){const{w,h}=this,c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d'),img=g.createImageData(w,h),d=new Uint32Array(img.data.buffer),has=i=>this.z[i]>-1e8;
  for(let i=0;i<w*h;i++)if(has(i))d[i]=this.col[i];const out=d.slice(),N=[[1,0],[-1,0],[0,1],[0,-1]],thr=2.2;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;
   if(has(i)){for(const[dx,dy]of N){const xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=w||yy>=h)continue;const j=yy*w+xx;if(has(j)&&this.pid[j]!==this.pid[i]&&this.z[j]-this.z[i]>thr){out[i]=dark32(d[i],.42);break}}}
   else for(const[dx,dy]of N){const xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=w||yy>=h)continue;if(has(yy*w+xx)){out[i]=pack(OUTC);break}}}
  new Uint32Array(img.data.buffer).set(out);g.putImageData(img,0,0);return c}}

// ================= POSE (repos qui respire, ou marche ; ph dans [0,1[) =================
// cinématique inverse à deux segments ; pole = direction vers laquelle plie le coude / genou
function ik3(S,T,l1,l2,pole){let d=sub(T,S),L=Math.hypot(...d)||.01;if(L>l1+l2-.1){d=mul(d,(l1+l2-.1)/L);L=l1+l2-.1}const u=mul(d,1/L),a=(l1*l1+L*L-l2*l2)/(2*L),h=Math.sqrt(Math.max(0,l1*l1-a*a));
 let q=sub(pole,mul(u,dot(pole,u)));q=nrm(q);return{E:add(S,add(mul(u,a),mul(q,h))),W:add(S,d)}}
const ARM=(sd,Y,W,pole)=>{const S=[sd*10.3,Y,0],k=ik3(S,W,10.4,9.4,pole);return{sd,S,E:k.E,W:k.W}};
// poses du jeu, toutes en coordonnées absolues (pieds au sol en Y = 0)
const POSES={
 // à genoux, souffle court (surcharge de l'Ancre) : genou gauche au sol, mains sur le genou levé, tente de se relever (3,6 s)
 kneel(t){const br=(per,inh)=>{const ph=(t%per)/per;return ph<inh?1-Math.pow(1-ph/inh,3):.5+.5*Math.cos(Math.PI*(ph-inh)/(1-inh))},b=br(1.8,.35),c=(t%3.6)/3.6,
   e=x=>.5-.5*Math.cos(Math.PI*cl(x)),rise=c<.4?e(c/.4)*3.2:c<.62?3.2:c<.82?3.2*(1-Math.pow(cl((c-.62)/.2),3)):0,tr=c>.3&&c<.66?Math.sin(t*50)*.35:0,hy=20+rise,shift=hy-35,up=b*.9;
  const legs=[{sd:-1,H:[-4.2,hy,0],K:[-4.4,3,-1.5],A:[-4.5,3.4,-16]},{sd:1,H:[4.2,hy,0],K:[4.6,19+rise*.4,14],A:[4.7,4,15]}];
  const Y=53.4+up+shift,arms=[ARM(-1,Y,[2.6+tr,23.5+rise,12.5],[-1,0,-1]),ARM(1,Y,[6.4+tr,22.5+rise,12.5],[1,0,-1])];
  return{legs,arms,b,up,shift,head:[tr*.5,66.6+up*.8+shift-1.6,1.8]}},
 // agenouillé, mains jointes devant la poitrine (incantation)
 pray(t){const b=.5-.5*Math.cos(t/2.4*TAU),up=b*.5,shift=19-35;
  const legs=[-1,1].map(sd=>({sd,H:[sd*4.2,19,0],K:[sd*4.4,3,1.5],A:[sd*4.5,3.4,-14]}));
  const Y=53.4+up+shift,arms=[-1,1].map(sd=>ARM(sd,Y,[sd*1,45.5+shift,8.6],[sd,-.4,-.4]));
  return{legs,arms,b,up,shift,head:[0,66.6+up*.8+shift-.6,1.2],closed:1}},
 crouch(){const shift=19-35,legs=[-1,1].map(sd=>({sd,H:[sd*4.2,19,0],K:[sd*5.4,19.5,14],A:[sd*5.2,4,10]})),Y=53.4+shift,arms=[-1,1].map(sd=>ARM(sd,Y,[sd*6.4,20.5,13],[sd,0,-1]));
  return{legs,arms,b:0,up:0,shift,head:[0,66.6+shift,1]}},
 // en tailleur, mains posées sur les genoux, yeux clos (méditation ; la lévitation est ajoutée en jeu)
 lotus(t){const b=.5+.5*Math.sin(t/2.4*TAU),up=b*.6,shift=8.5-35;
  const legs=[-1,1].map(sd=>({sd,H:[sd*4.2,8.5,0],K:[sd*11,4.6,7],A:[-sd*4.2,3.4,11.5]})),Y=53.4+up+shift,arms=[-1,1].map(sd=>ARM(sd,Y,[sd*10,10.5+up*.3,7],[sd,0,-1]));
  return{legs,arms,b,up,shift,head:[0,66.6+up*.8+shift,.6],closed:1}},
 // visée du lance-pitons : bras droit tendu dans la direction écran d (angle en degrés, 0 = droite, + = bas) pour th donné
 aim(deg,rc,glow,th){const P0=pose('idle',.25),a=deg*Math.PI/180,c=Math.cos(th),s=Math.sin(th),wx=Math.cos(a),wy=-Math.sin(a)/CA,v=nrm([-wx*c,wy,wx*s]);
  const S=[-10.3,53.4+P0.up,0],Wt=add(S,mul(v,19.6-rc)),k=ik3(S,Wt,10.4,9.4,[0,-1,-.4]),aimArm={sd:-1,S,E:k.E,W:k.W},arms=[aimArm,P0.arms[1]];
  return{...P0,arms,aimArm,launcher:{dir:v,glow},aimDir:v}}};
function lerpPose(A,B,t){const L=(a,b)=>lerp3(a,b,t),out={...A,shift:mix(A.shift,B.shift,t),up:mix(A.up,B.up,t),b:mix(A.b,B.b,t),head:L(A.head,B.head),closed:t>.55?B.closed:A.closed};
 out.legs=A.legs.map((l,i)=>({sd:l.sd,H:L(l.H,B.legs[i].H),K:L(l.K,B.legs[i].K),A:L(l.A,B.legs[i].A)}));out.arms=A.arms.map((r,i)=>({sd:r.sd,S:L(r.S,B.arms[i].S),E:L(r.E,B.arms[i].E),W:L(r.W,B.arms[i].W)}));return out}
function drawLauncher(F,P){const r=P.aimArm,d=nrm(sub(r.W,r.E));let up=sub([0,1,0],mul(d,d[1]));up=nrm(add(up,[r.sd*.35,0,0]));const o=mul(up,1.9),a=add(lerp3(r.E,r.W,.2),o),b=add(lerp3(r.E,r.W,1.05),o),g=P.launcher.glow;
 F.part=r.sd>0?5:4;F.tube(a,b,1.5,1.4,s=>[IRON,s.t>.94?-.3:0]);F.ell(b,1.5,1.5,1.5,s=>[IRON,-.15]);
 for(let i=0;i<4;i++){const p=add(lerp3(a,b,.15+i*.22),mul(up,1.5));F.dec(p,up,i<2||g>.7?PAL.cy[g>.7?4:3]:PAL.cy[2],1,1)}
 for(const t of[.3,.75]){const p=lerp3(r.E,r.W,t);F.tube(add(p,mul(up,-1.9)),add(p,mul(up,.4)),.5,.5,M(PAL.leath,.05))}}
function pose(mode,ph){const a=ph*TAU,walk=mode==='walk',b=walk?0:.5-.5*Math.cos(a),up=walk?0:b*.6;
 const legs=[-1,1].map(sd=>{const q=a+(sd>0?Math.PI:0),ang=walk?Math.sin(q)*.44:0,bend=walk?Math.max(0,Math.cos(q))*.8:0,Hh=[sd*4.2,35,0],
  K=[Hh[0]+(walk?0:sd*.2),Hh[1]-16*Math.cos(ang),16*Math.sin(ang)],a2=ang-bend,A=[K[0]+(walk?0:sd*.4),K[1]-15*Math.cos(a2),K[2]+15*Math.sin(a2)];return{sd,H:Hh,K,A}});
 const shift=walk?4-Math.min(legs[0].A[1],legs[1].A[1]):0;
 const arms=[-1,1].map(sd=>{const q=a+(sd>0?Math.PI:0),sw=walk?-Math.sin(q)*.4:0,S=[sd*10.3,53.4+up,0],E=[S[0]+sd*1.3,S[1]-10.4*Math.cos(sw),10.4*Math.sin(sw)],s2=sw+(walk?.32:.14),
  W=[E[0]+sd*.3,E[1]-9.4*Math.cos(s2),E[2]+9.4*Math.sin(s2)];return{sd,S,E,W}});
 const sY=p=>[p[0],p[1]+shift,p[2]];for(const l of legs){l.H=sY(l.H);l.K=sY(l.K);l.A=sY(l.A)}for(const r of arms){r.S=sY(r.S);r.E=sY(r.E);r.W=sY(r.W)}
 return{legs,arms,b,up,shift,walk,head:[0,66.6+up*.8+shift,.6]}}

// ================= PERSONNAGE =================
const TRT=[[29,7.4,4.9],[33,8.1,5.3],[37,8,5.2],[41,7.3,4.9],[46,7.7,5.3],[50,8.6,5.8],[54,9.1,5.5],[57.5,8.2,4.8]];
const M=(r,o=0)=>()=>[r,o];
const nz=(s,P,sc=1)=>(H(Math.floor(P[0]*sc+50),Math.floor(P[1]*sc+50)*7+Math.floor(P[2]*sc+50),s)-.5);
function drawFigure(F,O,P){
 const sh=P.shift,SK=PAL.skin,up=P.up,yTop=57.5+up,seed=O.seed||7;
 const uy=Y=>Y-sh;
 const trR=(Y,e=0)=>{let y=uy(Y);if(y>44)y-=up*(y-44)/13.5;let i=0;while(i<TRT.length-2&&y>TRT[i+1][0])i++;const A=TRT[i],B=TRT[i+1],t=cl((y-A[0])/(B[0]-A[0]));
  let rx=mix(A[1],B[1],t),rz=mix(A[2],B[2],t);if(y>44){rx+=P.b*.25;rz+=P.b*.35}return[rx+e,rz+e]};
 const trunk=(e,y0,y1,mat)=>F.tube([0,y1+sh,0],[0,y0+sh,0],0,0,mat,{rf:t=>trR(mix(y1,y0,t)+sh,e)});
 const cap=(e,mat)=>F.ell([0,56.6+up+sh,0],8.6+e,2.3+e*.6,4.9+e,mat);
 const onTrunk=(y,e,side)=>{const r=trR(y+sh,e);return side==='back'?[[0,y+sh,-r[1]],[0,0,-1]]:side==='front'?[[0,y+sh,r[1]],[0,0,1]]:[[side*r[0],y+sh,0],[side,0,0]]};
 const T=O.top||{},PA=O.pants,FT=O.feet||{type:'bare'};

 // ---------- jambes ----------
 for(const l of P.legs){F.part=l.sd>0?2:1;
  const skinM=M(SK,l.sd<0?-.04:0);
  F.tube(l.H,l.K,3.8,3.0,skinM);F.ell(l.K,3,3,3,skinM);F.tube(l.K,l.A,3.0,2.1,skinM);F.ell(l.A,2.1,2.1,2.1,skinM);
  if(PA){const len=PA.len??3,e=PA.tight?.45:.8;
   const pm=s=>{const y=uy(s.P[1]);let jag=PA.torn?H(Math.floor((s.phi+4)*4),l.sd+3,seed)*2.8:0;if(y<len+jag)return null;
    if(PA.rips&&PA.rips.includes('knee')&&l.sd>0){const kd=Math.hypot(s.P[0]-l.K[0],s.P[1]-l.K[1]-.5,s.P[2]-(l.K[2]+3.4));if(kd<1.9)return null;if(kd<2.6)return[PA.ramp,.22]}
    let off=0;if(PA.roll&&y<len+jag+2)off+=.16;if(PA.cargo&&s.sn*l.sd>.55&&y>22&&y<29.5)off-=y>28.5?.3:.14;if(PA.seam&&Math.abs(s.sn)>.96)off-=.25;
    if(PA.seam&&y>17.5&&y<21.5&&s.cs>.35)off+=.12;if(PA.tex)off+=nz(seed,s.P,.7)*.16;return[PA.ramp,off+(l.sd<0?-.04:0)]};
   F.tube(l.H,l.K,3.8+e,3+e,pm);F.ell(l.K,3+e,3+e,3+e,pm);F.tube(l.K,l.A,3+e,2.1+e,pm)}
  // pieds et chaussures
  const fc=add(l.A,[l.sd*.2,-2.3,2.0]);
  if(FT.type==='boots'){F.tube(l.K,l.A,3.1,3.1,s=>uy(s.P[1])<(FT.top||12)?[FT.ramp,s.cs>.6&&uy(s.P[1])>6&&((uy(s.P[1])|0)%2)?.18:0]:null);
   F.tube(l.A,add(l.A,[0,-1.6,0]),3.1,3.2,M(FT.ramp));F.ell(fc,2.7,2.0,4.4,s=>[FT.ramp,uy(s.P[1])<.9?-.45:0])}
  else if(FT.type==='socks'){F.tube(l.K,l.A,2.6,2.6,s=>uy(s.P[1])<9?[FT.ramp,uy(s.P[1])>7.6?.15:0]:null);F.ell(fc,2.4,1.7,4,s=>[FT.ramp,uy(s.P[1])<.8?-.35:0])}
  else if(FT.type==='wraps'){F.tube(l.K,l.A,3.0+.4,2.1+.9,s=>{const y=uy(s.P[1]);if(y>(FT.top||13)+H(Math.floor((s.phi+4)*3),l.sd,9)*1.5)return null;return[FT.ramp,(Math.floor(y*1.1+s.phi*1.3)&1)?-.14:.06]});
   F.ell(fc,2.5,1.8,4.1,s=>[FT.ramp,(Math.floor(s.P[2]*1.1+s.P[1])&1)?-.12:.04])}
  else{F.ell(fc,2.2,1.6,3.8,M(SK,l.sd<0?-.04:0));
   if(FT.type==='sandals'){F.ell(fc,2.35,1.4,3.9,s=>s.q[1]<-1.05?[FT.ramp,-.2]:(Math.abs(s.P[2]-fc[2]-.5)<.8||Math.abs(s.P[2]-fc[2]+2)<.7)?[FT.ramp,0]:null);
    F.tube(l.K,l.A,2.6,2.4,s=>{const y=19-15*s.t;if(y>13)return null;const k=((y*1.5+s.phi*2.4)%4+4)%4,k2=((y*1.5-s.phi*2.4)%4+4)%4;return k<.8||k2<.8?[FT.ramp,0]:null})}}
 }

 // ---------- tronc ----------
 F.part=3;trunk(0,29,yTop,M(SK));cap(0,M(SK));
 // cicatrices, plaque, bandages (torse nu)
 if(PA)trunk(PA.tight?.45:.6,29,PA.waist??39.5,s=>{const y=uy(s.P[1]);let off=y>(PA.waist??39.5)-.9?-.14:0;if(PA.seam&&Math.abs(s.sn)>.96)off-=.25;if(PA.tex)off+=nz(seed,s.P,.7)*.16;
  if(PA.cargo&&s.cs<-.3&&y>31&&y<35&&Math.abs(s.P[0])>1.5&&Math.abs(s.P[0])<6)off-=.14;return[PA.ramp,off]});
 const topTypes=['tee','tank','shirt','long','tunic'];
 if(topTypes.includes(T.type)){
  const e=T.type==='tank'?.5:.75,hem=T.hemY??34;
  const tm=(s,isCap)=>{const y=uy(s.P[1]),x=s.P[0],z=s.P[2];
   if(!isCap){let jag=T.hem==='torn'?H(Math.floor((s.phi+4)*5),3,seed)*2.6+((Math.floor((s.phi+4)*5))%2):0;if(y<hem+jag)return null}
   if(T.type==='tank'||T.type==='tunic'){const sw=T.type==='tunic'?[2.2,6.6]:[2.8,5.2];if((isCap||y>49.5)&&!(z<0&&y<53&&!isCap)&&(Math.abs(x)<sw[0]||Math.abs(x)>sw[1])){if(!(T.type==='tunic'&&x<0&&Math.abs(x)<sw[1]))return null}}
   if(isCap&&Math.hypot(x,z)<3.7)return null;
   if(isCap&&T.type!=='shirt'&&z>1&&Math.hypot(x,z*.75)<4.6)return null;
   if(T.type==='shirt'&&Math.abs(s.phi)<.2&&y>50.5)return null;
   if(T.holes){const n=fbm(s.phi*2.4+40,y/2.6+40,seed);if(n>T.holes)return null;if(n>T.holes-.06)return[BURN,0]}
   let off=nz(seed+2,s.P,.8)*.1;if(T.rib&&(Math.floor((s.phi+4)*7)&1))off-=.1;if(T.type==='shirt'&&Math.abs(s.phi)<.07&&y<50.5)off-=.2;
   if(T.type==='tunic'&&z>0){const dl=Math.abs((y-55)+(x+6)*1.15);if(dl<.8)off-=.22;else if(dl<2.4)off+=.08}
   return[T.ramp,off]};
  trunk(e,Math.min(hem,40)-3,yTop+.3,s=>tm(s,false));cap(e,s=>tm(s,true));
  if(T.type==='tunic'){F.tube([0,31+sh,0],[0,21.5+sh,0],0,0,s=>{const y=uy(s.P[1]);if(Math.abs(s.sn)>.9&&y<28)return null;if(y<22.6+H(Math.floor((s.phi+4)*5),2,seed)*1.4)return null;return[T.ramp,(Math.floor((s.phi+4)*6)&1)?-.08:.04]},{rf:t=>[mix(8.7,10.4,t),mix(5.9,7.2,t)]})}
  if(T.type==='shirt'){for(const y of[48.5,45.5,42.5,39.5]){const[p,n]=onTrunk(y,e+.1,'front');F.dec(p,n,PAL.bone[4])}
   const ring=[];for(let i=0;i<=14;i++){const a=.55+i/14*(TAU-1.1);ring.push([Math.sin(a)*4.3,57.4+up+sh+(Math.cos(a)>0?-.3:.2),Math.cos(a)*3.8])}F.path(ring,1,1,M(T.ramp,.12))}}
 // veste ouverte
 if(O.jacket){const J=O.jacket,jm=(s,isCap)=>{const y=uy(s.P[1]);if(!isCap&&y<(J.hemY??33))return null;if(isCap&&Math.hypot(s.P[0],s.P[2])<4.2)return null;
   if(Math.abs(s.phi)<.45&&y<55.5)return null;let off=Math.abs(s.phi)<.78&&y>46.5?.16:0;if(!isCap&&y>36.5&&y<40&&Math.abs(Math.abs(s.P[0])-4.6)<1.6&&s.cs>0)off-=.16;return[J.ramp,off+nz(seed+5,s.P)*.08]};
  trunk(1.5,J.hemY??33,yTop+.5,s=>jm(s,false));cap(1.5,s=>jm(s,true));
  const ring=[];for(let i=0;i<=14;i++){const a=.7+i/14*(TAU-1.4);ring.push([Math.sin(a)*4.8,58+up+sh,Math.cos(a)*4.1])}F.path(ring,1.2,1.2,M(J.ramp,.08))}
 // gilet matelassé
 if(O.vest){const V=O.vest,vm=(s,isCap)=>{const y=uy(s.P[1]);if(isCap?Math.abs(s.P[0])>6.2:(y>48.5&&Math.abs(s.P[0])>6.4))return null;if(isCap&&Math.hypot(s.P[0],s.P[2])<4)return null;if(Math.abs(s.phi)<.13)return null;
   return[V.ramp,((Math.floor(y*1.05))%3===0?-.2:0)+(Math.abs(s.phi)<.22?.12:0)]};trunk(1.6,35.5,yTop+.4,s=>vm(s,false));cap(1.6,s=>vm(s,true))}
 // bandages croisés
 if(O.bandage){const BD=O.bandage,band=(x,y,a,b)=>{const dx=b[0]-a[0],dy=b[1]-a[1],t=cl(((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy));return Math.hypot(x-a[0]-dx*t,y-a[1]-dy*t)};
  trunk(.45,38.5,56.5,s=>{const y=uy(s.P[1]),x=s.P[0],z=s.P[2];let hit=y>39.5&&y<44;const d=z>0?band(x,y,[7.5,55.5],[-8,40]):band(x,y,[-7.5,55.5],[8,40]);if(d<1.3)hit=true;if(!hit)return null;
   return[BD.ramp,((Math.floor(y*1.6+x*.3))%3===0?-.14:.04)+(H(x|0,y|0,4)>.93?-.3:0)]});
  {const[p,n]=onTrunk(42,.6,'front');F.dec(add(p,[2.6,0,0]),n,SCR[1]);F.dec(add(p,[3.4,-.4,0]),n,SCR[0])}}
 // ceintures, pagne, tablier…
 if(O.belt){const B=O.belt;trunk(1.25,B.y??36.8,(B.y??36.8)+(B.h??2.2),s=>[B.ramp,B.braid?((Math.floor((s.phi+4)*8+uy(s.P[1])*2))&1?-.15:.1):0]);
  if(B.buckle){const[p,n]=onTrunk((B.y??36.8)+1.1,1.4,'front');F.dec(add(p,[-.5,-.5,0]),n,B.buckle,2)}}
 if(O.sash){const S=O.sash,sm=s=>[S.ramp,(Math.floor((s.phi+4)*5+uy(s.P[1])*.7)&1)?-.1:.05];trunk(1.3,33.5,38.8,sm);
  F.part=3;F.tube([0,34.5+sh,0],[0,22+sh,0],0,0,s=>{if(Math.abs(s.phi)>.8)return null;if(uy(s.P[1])<22.8+H(Math.floor((s.phi+4)*6),5,seed)*3)return null;return sm(s)},{rf:t=>[mix(8.8,9.6,t),mix(6.3,7.2,t)]});
  F.part=9;const kn=[-8.6,36+sh,1.6];F.ell(kn,1.7,1.5,1.7,sm);F.tube(kn,[-9.6,25.5+sh,2.6],1.4,.9,sm)}
 if(O.apron){const A=O.apron;F.part=10;
  F.tube([0,46.5+sh+up*.5,0],[0,16.5+sh,0],0,0,s=>{const y=uy(s.P[1]);if(s.cs<.56)return null;if(y>38&&Math.abs(s.P[0])>5.3)return null;
   let off=nz(seed+8,s.P,.6)*.12;if(y>28.5&&y<33.5&&Math.abs(s.P[0])<4.2)off-=y>32.6?.3:.14;if(y<17.4)off-=.12;return[A.ramp,off]},
   {rf:t=>{const y=mix(46.5,16.5,t);if(y>30){const r=trR(y+sh,1.4);return r}return[8.8+(30-y)*.06,6.3+(30-y)*.05]}});
  F.part=3;trunk(1.1,45,yTop,s=>s.cs>0&&Math.abs(Math.abs(s.P[0])-4.6)<.8?[A.ramp,.1]:null);trunk(1.2,38.4,39.6,M(A.ramp,-.05));
  const kn=onTrunk(39,1.6,'back')[0];F.ell(kn,1.3,1.1,1.1,M(A.ramp));F.tube(kn,add(kn,[-1.2,-5,-.4]),.7,.5,M(A.ramp));F.tube(kn,add(kn,[1.3,-4.4,-.4]),.7,.5,M(A.ramp))}
 if(O.tiedSleeves){const TS=O.tiedSleeves,ring=[];for(let i=0;i<=20;i++){const a=i/20*TAU,r=trR(38.4+sh,1.3);ring.push([Math.sin(a)*r[0],38.4+sh+(Math.cos(a)<0?.6:0),Math.cos(a)*r[1]])}
  F.part=9;F.path(ring,1.4,1.4,M(TS.ramp,-.04));const kn=[0,38+sh,6.5];F.ell(kn,2.1,1.7,1.5,M(TS.ramp,.06));F.tube(kn,[-2,29.5+sh,6.9],1.6,1.25,M(TS.ramp));F.tube(kn,[2.4,30.5+sh,6.8],1.6,1.25,M(TS.ramp,-.05));
  F.dec([-2,30+sh,8.1],[0,0,1],TS.ramp[3]);F.dec([2.4,31+sh,8],[0,0,1],TS.ramp[3])}
 if(O.rag){F.part=9;F.tube([5.2,35+sh,-5.4],[5.9,28+sh,-6.3],1.5,1.1,s=>[O.rag,(Math.floor(uy(s.P[1])*1.4)&1)?-.1:.06])}
 if(O.ports){const pts=[];for(const y of[53,49,45,41])pts.push(onTrunk(y,.6,'back'));pts.push(onTrunk(36.5,.7,1),onTrunk(36.5,.7,-1));
  for(const l of P.legs)pts.push([add(l.K,[0,.5,3.5]),[0,0,1]]);
  for(const[p,n]of pts){if(F.k<1)F.dec(p,n,PAL.cy[2],1);else{F.dec(add(p,[-1,1,0]),n,PAL.steel[2],3,.8);F.dec(p,n,PAL.cy[3],1,1.2)}}
  const[p,n]=onTrunk(51,.6,'back');for(let y=40;y<=53;y+=1){const q=onTrunk(y,.6,'back');if(y%4)F.dec(q[0],q[1],PAL.cy[1],1,.6)}}

 // ---------- bras ----------
 for(const r of P.arms){F.part=r.sd>0?5:4;const S=O.armIn?add(r.S,[-r.sd*2.2,0,0]):r.S,sk=M(SK,r.sd<0?-.05:0),hc=add(r.W,[r.sd*.2,-1.9,.4]);
  F.ell(S,2.9,2.9,2.9,sk);F.tube(S,r.E,2.6,2.2,sk);F.ell(r.E,2.2,2.2,2.2,sk);F.tube(r.E,r.W,2.2,1.8,sk);
  F.ell(hc,1.75,2.4,2.0,O.gloves?M(O.gloves,r.sd<0?-.05:0):sk);
  const arm=(e,uMax,mat,uMin=0)=>{const g=(s,seg)=>{const u=seg?.5+s.t*.5:s.t*.5;if(u>uMax||u<uMin)return null;return mat(s,u)};
   F.ell(S,2.9+e,2.9+e,2.9+e,s=>uMin>0?null:mat(s,0));F.tube(S,r.E,2.6+e,2.2+e,s=>g(s,0));F.ell(r.E,2.2+e,2.2+e,2.2+e,s=>.5>uMax||.5<uMin?null:mat(s,.5));F.tube(r.E,r.W,2.2+e,1.8+e,s=>g(s,1))};
  const sl=(T.sleeve||0);
  if(sl>0&&topTypes.includes(T.type)){const jag=T.hem==='torn';arm(T.type==='long'?.55:.85,sl,(s,u)=>{if(jag&&u>sl-H(Math.floor((s.phi+4)*4),r.sd,seed)*.1)return null;
   if(T.holes&&r.sd>0&&fbm(s.phi*2+60,s.t*4+(u>.5?9:0),seed)>T.holes+.04)return null;return[T.ramp,(T.roll&&u>sl-.07)?.16:(T.type==='long'&&u>.92?-.12:0)]});}
  if(O.jacket)arm(1.25,O.jacket.sleeve,(s,u)=>[O.jacket.ramp,u>O.jacket.sleeve-.07?.14:0]);
  if(O.bracers){F.part=r.sd>0?5:4;arm(.7,.9,(s,u)=>[PAL.stone,(Math.abs(u-.7)<.012||Math.abs(u-.86)<.012)?-.25:.02],.64);
   for(let i=0;i<3;i++){const p=lerp3(r.E,r.W,.42+i*.13),n=nrm([r.sd*.5,0,1]);F.dec(add(p,mul(n,2.6)),n,i===1?PAL.cy[3]:PAL.cy[2],1,1)}}
  if(O.gloves)arm(.45,1,(s,u)=>[O.gloves,u>.96?.12:0],.88);
  if(O.armBandage&&r.sd<0)arm(.4,.86,(s,u)=>[PAL.bone,(Math.floor(u*60)&1)?-.12:.05],.66);
  if(O.scars&&r.sd>0){const p=lerp3(r.E,r.W,.35);F.dec(add(p,[.6,0,2.1]),[0,0,1],SCR[1]);F.dec(add(p,[1.2,-1,2.0]),[0,0,1],SCR[0])}}

 // ---------- cou et tête ----------
 F.part=6;const hc=P.head,HR=[5.3,6.3,5.6];
 F.tube([0,55.5+up+sh,0],[0,61.5+up+sh,.4],2.5,2.4,M(SK,-.05));
 F.ell(hc,HR[0],HR[1],HR[2],s=>{let off=0;if(s.th>1.88&&Math.cos(s.phi)>-.1&&H(Math.round(s.P[0]*2),Math.round(s.P[1]*2),3)>.5)off-=.22;if(s.th>2.25)off-=.1;return[SK,off]});
 for(const sd of[-1,1])F.ell(add(hc,[sd*5.1,-.4,-.2]),.9,1.6,1.3,M(SK,-.05));
 F.ell(add(hc,[0,-.9,5.4]),.9,1.3,1.0,M(SK,.05));
 const onHead=(th,ph,k=1)=>{const q=[Math.sin(th)*Math.sin(ph)*HR[0]*k,Math.cos(th)*HR[1]*k,Math.sin(th)*Math.cos(ph)*HR[2]*k];return[add(hc,q),nrm([q[0]/HR[0]**2,q[1]/HR[1]**2,q[2]/HR[2]**2])]};
 for(const sd of[-1,1]){if(P.closed){for(const a of[.32,.46]){const[p,n]=onHead(1.56,sd*a);F.dec(p,n,SK[1])}}else{const[p,n]=onHead(1.5,sd*.42);F.dec(p,n,EYE);if(F.k>=1){const[p2,n2]=onHead(1.6,sd*.42);F.dec(p2,n2,EYE)}}
  for(const a of[.24,.4,.56]){const[q,m]=onHead(1.3,sd*a);F.dec(q,m,PAL.hair[1],1,.6)}}
 for(const a of[-.18,0,.18]){const[q,m]=onHead(2.02,a);F.dec(q,m,SK[1],1,.6)}
 // coiffures
 const HS={tousled:{f:.45,s:.1,b:-.45,g:(th,ph)=>1.1+.1*Math.max(0,Math.cos(th))+(H(Math.floor(th*7),Math.floor((ph+4)*6),5)-.5)*.17,j:.12},
  crop:{f:.55,s:.22,b:-.25,g:th=>1.06+.04*Math.cos(th),j:.04,shave:1},
  bun:{f:.52,s:.12,b:-.38,g:th=>1.07+.03*Math.cos(th),j:.03,bun:1},
  shaggy:{f:.36,s:-.25,b:-.78,g:(th,ph)=>1.12+.08*Math.max(0,Math.cos(th))+(H(Math.floor(th*6),Math.floor((ph+4)*5),6)-.5)*.2,j:.16},
  swept:{f:.6,s:.12,b:-.55,g:th=>1.08+.07*Math.max(0,Math.cos(th)),j:.05,streak:1}}[O.hair||'tousled'];
 F.ell(hc,HR[0],HR[1],HR[2],s=>{const ch=Math.cos(s.phi),lim=(ch>=0?mix(HS.s,HS.f,ch):mix(HS.s,HS.b,-ch))+(H(Math.floor((s.phi+4)*7),2,11)-.5)*HS.j*2;if(s.ct<lim)return null;
  let off=(H(Math.floor((s.phi+4)*14),Math.floor(s.th*5),13)-.5)*.28;if(HS.shave&&Math.abs(Math.sin(s.phi))>.62&&s.ct<.55)off-=.32;if(HS.streak&&(Math.floor((s.phi+4)*9)&1))off+=.1;return[PAL.hair,off+.04]},{rm:HS.g,rmax:1.3});
 if(HS.bun)F.ell(add(hc,[0,3.4,-5.7]),2.6,2.4,2.4,s=>[PAL.hair,(Math.floor((s.phi+4)*5)&1)?-.12:.04]);
 if(O.bandana){F.ell(hc,HR[0],HR[1],HR[2],s=>s.ct>.3&&s.ct<.66?[O.bandana,(Math.floor(s.phi*6)&1)?-.06:.05]:null,{rm:()=>1.22});
  const kn=add(hc,[0,2.6,-6.6]);F.part=9;F.ell(kn,1.4,1.2,1.1,M(O.bandana));F.tube(kn,add(kn,[-1.4,-5.2,-.8]),.9,.6,M(O.bandana,-.05));F.tube(kn,add(kn,[1.2,-4.4,-.6]),.9,.6,M(O.bandana))}
 if(O.lamp){F.ell(hc,HR[0],HR[1],HR[2],s=>s.ct>.36&&s.ct<.54?[PAL.leath,0]:null,{rm:()=>1.2});const lp=add(hc,[0,.45*HR[1],HR[2]*1.12]);F.part=9;F.ell(lp,1.7,1.3,1.1,M(PAL.steel,.08));
  F.dec(add(lp,[-.4,.2,1.2]),[0,0,1],PAL.cy[4],F.k>=1?2:1,1);F.part=6}
 // écharpe
 if(O.scarf){F.part=8;const S=O.scarf,ring=[];for(let i=0;i<=16;i++){const a=i/16*TAU;ring.push([Math.sin(a)*5.3,56.9+up+sh+(Math.cos(a)>0?-.9:.5),Math.cos(a)*5.2])}
  const sm=s=>[S,(Math.floor(s.t*4)&1)?-.08:.04];F.path(ring,1.5,1.5,sm);const kn=[-2.2,55.4+up+sh,6.2];F.ell(kn,2,1.7,1.6,M(S,.08));
  F.tube(kn,[-3.6,47.5+sh,7.2],1.5,1.1,sm);F.tube([2.6,56+up+sh,-4.4],[4.4,46+sh,-6.4],1.25,.9,sm)}
 // poncho et capuche
 if(O.poncho){const PO=O.poncho;F.part=7;F.tube([0,58.6+up+sh,0],[0,31.5+sh,0],0,0,s=>{if(s.t<.05&&Math.hypot(s.P[0],s.P[2])<3.4)return null;
   if(s.t>.86-H(Math.floor((s.phi+4)*6),7,seed)*.12)return null;let off=(Math.floor((s.phi+4)*5)&1)?-.08:.04;if(Math.abs(s.phi)<.08&&s.t>.3)off-=.22;return[PO.ramp,off+nz(seed+3,s.P,.8)*.1]},
   {rf:t=>[mix(6.2,16.2,Math.pow(t,.35)),mix(5.4,10,Math.pow(t,.5))]});
  if(PO.hood)F.ell([0,58.2+up+sh,-5.4],5.2,3.1,3,s=>[PO.ramp,s.q[1]<-1?-.15:.05]);
  const ring=[];for(let i=0;i<=14;i++){const a=i/14*TAU;ring.push([Math.sin(a)*3.9,58.6+up+sh,Math.cos(a)*3.6])}F.path(ring,.7,.7,M(PAL.rope))}
 // sacs
 if(O.strap){F.part=3;const st=O.strap,dl=(x,y)=>{const a=[6.8,57.5],b=[-8.6,34],dx=b[0]-a[0],dy=b[1]-a[1],t=cl(((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy));return Math.hypot(x-a[0]-dx*t,y-a[1]-dy*t)};
  const sm=s=>dl(s.P[0],uy(s.P[1]))<1.15?[st.ramp,0]:null;trunk(1.9,33,yTop+.4,sm);cap(1.9,sm);
  F.part=9;const bc=[-9.8,33+sh,.8];F.ell(bc,2.5,3.4,4.0,s=>[st.ramp,s.q[1]>1.2&&s.q[0]<0?.12:0]);F.dec(add(bc,[-2.4,1,0]),[-1,0,0],PAL.steel[4])}
 if(O.pack){const pk=O.pack;F.part=3;const sm=s=>s.P[2]>-1&&Math.abs(Math.abs(s.P[0])-4.4)<1&&uy(s.P[1])>41?[PAL.rope,0]:null;trunk(1.7,40,yTop+.4,sm);cap(1.7,s=>Math.abs(Math.abs(s.P[0])-4.4)<1?[PAL.rope,0]:null);
  F.part=9;const bc=[0,46.5+sh+up*.5,-8];F.ell(bc,5.6,6.8,3,s=>[pk.ramp,(Math.floor(s.q[1]*.9+s.q[0]*.3)&1)?-.06:.05]);
  F.ell(add(bc,[0,6.6,0]),3.4,1.4,2.2,M(pk.ramp,-.05));const ring=[];for(let i=0;i<=10;i++){const a=i/10*TAU;ring.push(add(bc,[Math.sin(a)*3.2,5.4,Math.cos(a)*2.1]))}F.path(ring,.6,.6,M(PAL.rope))}
 if(O.tools){F.part=9;F.ell([8.9,34+sh,1.8],2.1,2.8,2.6,M(PAL.leath,.04));F.tube([-9.2,36.5+sh,2.4],[-9.8,28.6+sh,3],.7,.7,M(PAL.steel,.1));F.ell([-9.8,28+sh,3],1.3,1.1,.8,M(PAL.steel))}
 if(O.tag){const pts=[[-2.4,56+up+sh,3.4],[-1.4,53+up+sh,5],[0,50.8+sh+up,5.6],[1.4,53+up+sh,5],[2.4,56+up+sh,3.4]];
  for(let i=1;i<pts.length;i++)for(let k=0;k<4;k++){const p=lerp3(pts[i-1],pts[i],k/4);F.dec(p,[0,0,1],PAL.steel[3],1,.9)}const[p,n]=onTrunk(49+up,.6,'front');F.dec(add(p,[-.5,0,0]),n,PAL.steel[5],2,1)}
 if(O.scars){const[p,n]=onTrunk(51,.1,'front');for(let i=0;i<4;i++)F.dec(add(p,[3+i*.9,-i*.9,0]),n,SCR[i&1])}
 if(P.launcher)drawLauncher(F,P);
 if(O.gear)drawGear(F,O,P,{sh,up,yTop,uy,trR,trunk,cap,onTrunk,hc,HR,onHead,seed});
}

// ================= SCÈNE : ARDOISE TYRIENNE ET ANCRE (résolution du jeu) =================
const SW=120,SH=84,AX=80,PBY=62,PTY=50,PRX=10,PRY=4,ORY=35;
const bay=(x,y)=>BAYER[(y%4+4)%4][(x%4+4)%4];
const FLOOR=(()=>{const c=document.createElement('canvas');c.width=SW;c.height=SH;const g=c.getContext('2d'),img=g.createImageData(SW,SH),d=img.data,S=PAL.stone;
 for(let y=0;y<SH;y++)for(let x=0;x<SW;x++){let v=.22+fbm(x/11,y/7,4)*.42+(H(x,y,5)-.5)*.06;const u=((x*.5+y)%12+12)%12,w=((x*.5-y)%12+12)%12;if(u<1||w<1)v-=.2;else if(u<2||w<2)v+=.06;
  let col=rampc(S,v,x,y);if(H(x,y,9)>.992)col=QZ[1];if(fbm(x/3+9,y/2+3,7)>.78&&H(x,y,2)>.5)col=QZ[0];
  const e=Math.hypot((x-AX)/24,(y-PBY-1)/9.5);if(Math.abs(e-1)<.05&&((Math.atan2(y-PBY,x-AX)*12/Math.PI+40|0)%3))col=bay(x,y)<.6?PUR[3]:PUR[2];else if(e<1&&bay(x,y)<.18*(1-e))col=PUR[1];
  const h=hex(col),i=(y*SW+x)*4;d[i]=h[0];d[i+1]=h[1];d[i+2]=h[2];d[i+3]=255}
 g.putImageData(img,0,0);return c})();
function rampc(r,v,x,y){return Px.prototype.ramp(r,v,x,y)}
const PED=(()=>{const c=document.createElement('canvas');c.width=SW;c.height=SH;const g=c.getContext('2d'),img=g.createImageData(SW,SH),d=img.data,S=PAL.stone,m=new Uint8Array(SW*SH);
 const put=(x,y,col)=>{if(x<0||y<0||x>=SW||y>=SH)return;const h=hex(col),i=(y*SW+x)*4;d[i]=h[0];d[i+1]=h[1];d[i+2]=h[2];d[i+3]=255;m[y*SW+x]=1};
 for(let y=PTY-PRY;y<=PBY+PRY;y++)for(let x=AX-PRX;x<=AX+PRX;x++){const nx=(x+.5-AX)/PRX,ex=Math.sqrt(Math.max(0,1-nx*nx))*PRY;if(Math.abs(nx)>1)continue;
  if(y>=PTY-ex&&y<=PTY+ex){let v=.62-nx*.18-(y-PTY)/PRY*.08;const rr=Math.hypot(nx,(y-PTY)/PRY);if(Math.abs(rr-.7)<.12&&((Math.atan2(y-PTY,x-AX)*8/Math.PI+40|0)%2))put(x,y,PUR[3]);else put(x,y,rampc(S,v+(H(x,y,3)-.5)*.08,x,y))}
  else if(y>PTY&&y<=PBY+ex){let v=.42-nx*.3-(y-PTY)/(PBY-PTY)*.12;if(y>PBY+ex-1.5)v-=.15;if(Math.abs(Math.sin(nx*5.5))<.12)v-=.12;let col=rampc(S,v,x,y);if(fbm(x/2,y/5,17)>.74)col=QZ[nx<0?1:0];put(x,y,col)}}
 const m0=m.slice();for(let y=0;y<SH;y++)for(let x=0;x<SW;x++){if(m0[y*SW+x])continue;if((x>0&&m0[y*SW+x-1])||(x<SW-1&&m0[y*SW+x+1])||(y>0&&m0[(y-1)*SW+x])||(y<SH-1&&m0[(y+1)*SW+x]))put(x,y,OUTC)}
 g.putImageData(img,0,0);return c})();
function orb(g,t){const r=8,y0=ORY+Math.round(Math.sin(t*1.6)*1.2),x0=AX,fr=Math.floor(t*12),px=(x,y,c)=>{g.fillStyle=c;g.fillRect(x,y,1,1)},dpx=(x,y,c,a)=>{x=Math.round(x);y=Math.round(y);if(a>=1||a>bay(x,y))px(x,y,c)};
 for(let j=-r-1;j<=r+1;j++)for(let i=-r-1;i<=r+1;i++){const dd=Math.hypot(i,j);if(dd>r+.9)continue;if(dd>r+.2){px(x0+i,y0+j,OUTC);continue}
  const nx=i/r,ny=j/r;let v=.42-(nx*.5+ny*.7)*.3+(fbm((i+40)/3+t*.3,(j+40)/3,11)-.5)*.15;if(dd>r-1.4&&nx+ny>-.2)v=dd>r-.7?.95:.8;px(x0+i,y0+j,rampc(C.orb,Math.min(v,dd>r-1.4?1:.7),x0+i,y0+j))}
 px(x0-3,y0-4,C.orb[5]);px(x0-2,y0-4,C.orb[5]);px(x0-3,y0-3,C.orb[4]);
 // ombre portée sur le socle
 for(let i=-5;i<=5;i++)for(let j=-1;j<=1;j++)if(bay(x0+i,PTY+j)<.5-Math.abs(i)/14)px(x0+i,PTY+j,PAL.stone[1]);
 // éclairs noirs-pourpres
 for(let k=0;k<3;k++){if(H(k,fr>>1,3)<.45)continue;const a=H(k,fr>>1,4)*TAU,len=4+H(k,fr>>1,5)*6;let x=x0+Math.cos(a)*r,y=y0+Math.sin(a)*r;const R=rng(fr*13+k);R();
  for(let s=0;s<len;s+=1.3){x+=Math.cos(a)*1.3+(R()-.5)*1.6;y+=Math.sin(a)*1.3+(R()-.5)*1.6;dpx(x,y,s<2?PUR[5]:R()<.5?PUR[4]:'#0a0410',1);dpx(x+1,y,PUR[2],.5)}}}
function shadowAt(g,x,y,k){const rx=Math.round(8*k*2),ry=Math.round(2.6*k*2);for(let j=-ry;j<=ry;j++)for(let i=-rx;i<=rx;i++){const dd=(i/rx)**2+(j/ry)**2;if(dd<1&&bay(x+i,y+j)<.8-dd*.55){g.fillStyle='rgba(0,0,0,.45)';g.fillRect(x+i,y+j,1,1)}}}


// ================= ÉQUIPEMENT VISIBLE (une couche par emplacement, id de calque = GEAR[slot].id) =================
// O.gear = {head, eye, chest, hands, feet, back, rhand, lhand} ; chaque pièce n'habille que sa partie du corps.
const IRON=['#121418','#1f2228','#2e323a','#424750','#5c626b','#7f868f','#aab1b8'];
const GEAR={
 head:{label:'Tête',id:20,opts:[['','Rien'],['helm','Casque de fer'],['hood','Capuche de toile'],['circlet','Bandeau tyrien']]},
 eye:{label:'Capteur oculaire',id:21,opts:[['','Rien'],['lens','Monocle-capteur']]},
 chest:{label:'Torse',id:22,opts:[['','Rien'],['iron','Plastron de fer'],['mail','Cotte de mailles'],['leather','Cuirasse de cuir']]},
 hands:{label:'Gants',id:23,opts:[['','Rien'],['gauntlets','Gantelets de fer'],['gloves','Gants de cuir']]},
 feet:{label:'Bottes',id:24,opts:[['','Rien (sandales)'],['greaves','Grèves de fer'],['boots','Bottes de cuir']]},
 back:{label:'Dos',id:25,opts:[['','Rien'],['cape','Cape'],['pack','Sac de toile']]},
 rhand:{label:'Main droite',id:26,opts:[['','Rien'],['hammer','Marteau de forge'],['blade','Lame courte']]},
 lhand:{label:'Main gauche',id:27,opts:[['','Rien'],['shield','Bouclier rond'],['lantern','Lanterne à quartz']]}};
function drawGear(F,O,P,X){const G=O.gear,{sh,up,yTop,uy,trunk,cap,onTrunk,hc,HR,onHead,seed}=X,handC=r=>add(r.W,[r.sd*.2,-1.9,.4]);
 const armShell=(r,e,mat)=>{F.tube(r.S,r.E,2.6+e,2.2+e,s=>mat(s,s.t*.5));F.ell(r.E,2.2+e,2.2+e,2.2+e,s=>mat(s,.5));F.tube(r.E,r.W,2.2+e,1.8+e,s=>mat(s,.5+s.t*.5))};
 // ---- tête ----
 if(G.head){F.part=GEAR.head.id;
  if(G.head==='helm'){F.ell(hc,HR[0],HR[1],HR[2],s=>{const ch=Math.cos(s.phi),lim=ch>=0?mix(-.05,.3,ch):mix(-.05,-.35,-ch);if(s.ct<lim)return null;
    let off=.04;if(Math.abs(Math.sin(s.phi))<.1&&s.ct>.4)off+=.22;if(s.ct<lim+.14)off-=.2;return[IRON,off]},{rm:()=>1.2});
   F.tube(add(onHead(1.25,0,1.2)[0],[0,0,.1]),onHead(1.72,0,1.24)[0],.6,.5,M(IRON,.1));F.ell(add(hc,[0,3.2,-5.9]),3.1,2.9,2.9,s=>[IRON,s.q[1]>1?.1:-.05])}
  else if(G.head==='hood'){F.ell(hc,HR[0],HR[1],HR[2],s=>{if(Math.cos(s.phi)>.42&&s.ct<.6&&s.ct>-.8)return null;return[PAL.khaki,(Math.floor((s.phi+4)*5)&1)?-.06:.04]},{rm:(th)=>1.2+(th>2?.15:0)});F.ell(add(hc,[0,3.2,-5.9]),3.2,3,3,M(PAL.khaki,-.02));
   trunk(1.4,50.5,yTop+.8,s=>Math.abs(s.P[0])<8.2?[PAL.khaki,uy(s.P[1])<51.4?-.18:0]:null);cap(1.4,s=>Math.abs(s.P[0])<7.6?[PAL.khaki,0]:null)}
  else if(G.head==='circlet'){F.ell(hc,HR[0],HR[1],HR[2],s=>s.ct>.4&&s.ct<.56?[PAL.stone,.1]:null,{rm:()=>1.18});const[p,n]=onHead(1.12,0,1.2);F.dec(p,n,PAL.cy[3],F.k>=1?2:1,1)}}
 // ---- capteur oculaire ----
 if(G.eye==='lens'){F.part=GEAR.eye.id;const[p,n]=onHead(1.5,.42,1.1);F.ell(p,1.1,1.1,.8,M(IRON,.05));F.dec(add(p,mul(n,.9)),n,PAL.cy[4],1,1.2);
  for(let i=1;i<6;i++){const[q,m]=onHead(1.5+i*.01,.42+i*.2,1.03);F.dec(q,m,IRON[2],1,.8)}}
 // ---- torse ----
 if(G.chest){F.part=GEAR.chest.id;
  if(G.chest==='iron'){const pm=(s,isCap)=>{const y=uy(s.P[1]);if(isCap&&(Math.hypot(s.P[0],s.P[2])<4.5||Math.abs(s.P[0])>7.4))return null;
    let off=.04;if(Math.abs(s.phi)<.12)off+=.22;if(!isCap&&y<39.2)off-=.2;if(Math.abs(Math.sin(s.phi))>.92)off-=.12;return[IRON,off]};
   trunk(1.9,37.6,yTop+.3,s=>pm(s,false));cap(1.9,s=>pm(s,true));
   for(const y of[54,47,40])for(const sd of[-1,1]){const[p,n]=onTrunk(y,2,'front');F.dec(add(p,[sd*5.2,0,-1]),n,IRON[6],1,1);const[q,m]=onTrunk(y,2,'back');F.dec(add(q,[sd*5.2,0,1]),m,IRON[5],1,1)}
   for(const sd of[-1,1]){const p=[sd*7,56.5+up+sh,0];F.dec(add(p,[0,1.2,2.8]),[0,0,1],PAL.leath[4],2,1.2);F.dec(add(p,[0,1.2,-2.8]),[0,0,-1],PAL.leath[3],2,1.2)}}
  else if(G.chest==='mail'){const mm=(s,y)=>[IRON,((Math.floor((s.phi+4)*12)+Math.floor(y*1.6))&1)?-.2:.08];
   trunk(1.3,30.5,yTop+.3,s=>{const y=uy(s.P[1]);if(y<30.5+H(Math.floor((s.phi+4)*6),1,seed)*2)return null;return mm(s,y)});cap(1.3,s=>Math.hypot(s.P[0],s.P[2])<4.2?null:mm(s,uy(s.P[1])));
   for(const r of P.arms)armShell(r,1.1,(s,u)=>u<.27?mm(s,uy(s.P[1])):null)}
  else if(G.chest==='leather'){const lm=(s,isCap)=>{const y=uy(s.P[1]);if(isCap&&(Math.hypot(s.P[0],s.P[2])<4.4||Math.abs(s.P[0])>7))return null;const row=Math.floor((y-36)/2.4);
    let off=((Math.floor((s.phi+4)*5+row*.5))&1)?.05:-.05;if(((y-36)%2.4)<.6)off-=.25;return[PAL.leath,off+.08]};trunk(1.7,35.6,yTop+.3,s=>lm(s,false));cap(1.7,s=>lm(s,true))}}
 // ---- mains ----
 if(G.hands){F.part=GEAR.hands.id;for(const r of P.arms){const hc2=handC(r);
  if(G.hands==='gauntlets'){F.tube(r.E,r.W,3.2,2.9,s=>s.t<.45?null:[IRON,s.t>.92?.16:((Math.floor(s.t*10))&1)?-.08:.06]);F.ell(hc2,2.1,2.7,2.4,s=>[IRON,s.q[1]>1?.1:0])}
  else{F.tube(r.E,r.W,2.8,2.5,s=>s.t<.8?null:[PAL.leath,.12]);F.ell(hc2,1.95,2.6,2.2,M(PAL.leath,.02))}}}
 // ---- pieds ----
 if(G.feet){F.part=GEAR.feet.id;for(const l of P.legs){const fc=add(l.A,[l.sd*.2,-2.3,2.0]);
  if(G.feet==='greaves'){F.tube(l.K,l.A,4.2,3.4,s=>19-15*s.t>17?null:[IRON,s.cs>.6?.12:0]);F.ell(add(l.K,[0,-.4,2]),2.5,2.5,2,M(IRON,.14));F.ell(fc,2.8,2.0,4.5,s=>[IRON,s.q[1]<-1.2?-.45:.02])}
  else{F.tube(l.K,l.A,3.6,3.3,s=>19-15*s.t>12.5?null:[PAL.leath,19-15*s.t>11.4?.16:0]);F.ell(fc,2.7,2.0,4.4,s=>[PAL.leath,s.q[1]<-1.2?-.45:0])}}}
 // ---- dos ----
 if(G.back==='cape'){F.part=GEAR.back.id;F.tube([0,57.4+up+sh,-.6],[0,9+sh,-3.4],0,0,s=>{if(s.cs>-.05)return null;if(s.t>.97-H(Math.floor((s.phi+4)*6),3,seed)*.05)return null;
   return[PAL.slate,(Math.floor((s.phi+4)*5)&1)?-.07:.04]},{rf:t=>[mix(9.8,12.6,t),mix(6,8.8,t)]});
  for(const sd of[-1,1])F.dec([sd*6.6,57.2+up+sh,3.4],[0,0,1],IRON[5],F.k>=1?2:1,1)}
 if(G.back==='pack'){F.part=GEAR.back.id;const sm=s=>s.P[2]>-1&&Math.abs(Math.abs(s.P[0])-4.4)<1&&uy(s.P[1])>41?[PAL.rope,0]:null;trunk(2.4,40,yTop+.4,sm);cap(2.4,s=>Math.abs(Math.abs(s.P[0])-4.4)<1?[PAL.rope,0]:null);
  const bc=[0,46.5+sh+up*.5,-8.4];F.ell(bc,5.6,6.8,3,s=>[PAL.linen,(Math.floor(s.q[1]*.9+s.q[0]*.3)&1)?-.06:.05]);F.ell(add(bc,[0,6.6,0]),3.4,1.4,2.2,M(PAL.linen,-.05))}
 // ---- mains droite / gauche ----
 const R=P.arms.find(r=>r.sd>0),L=P.arms.find(r=>r.sd<0);
 if(G.rhand){F.part=GEAR.rhand.id;const c=handC(R);
  if(G.rhand==='hammer'){F.tube(add(c,[0,2.2,-.4]),add(c,[0,-10.5,2.2]),.75,.75,M(PAL.leath,.1));F.ell(add(c,[0,-11,2.3]),1.7,1.7,3.4,s=>[IRON,s.q[2]>2.6?.15:0])}
  else{F.tube(add(c,[0,1.6,-.3]),add(c,[0,-1.4,.6]),.8,.8,M(PAL.leath));F.ell(add(c,[0,-1.8,.7]),2.4,.6,.9,M(IRON,.05));F.tube(add(c,[0,-2,.8]),add(c,[0,-12.5,3.4]),1,.35,s=>[IRON,s.sn>0?.2:-.05])}}
 if(G.lhand){F.part=GEAR.lhand.id;const c=handC(L);
  if(G.lhand==='shield'){const sc=add(lerp3(L.E,L.W,.55),[-3.4,0,.8]);F.ell(sc,1.1,6.4,6.4,s=>{const d=Math.hypot(s.q[1],s.q[2]);if(d<1.7)return[IRON,.2];if(d>5.4)return[IRON,-.02];return[PAL.leath,((Math.floor((s.q[2]+8)*.7))&1)?.06:-.04]})}
  else{F.tube(c,add(c,[0,-2.2,.3]),.35,.35,M(IRON));const lc=add(c,[0,-5.2,.5]);F.ell(lc,1.8,2.6,1.8,s=>[Math.abs(s.q[1])>1.9||((Math.floor((s.phi+4)*2.2))&1)===0&&Math.abs(Math.sin(s.phi*2))<.25?IRON:QZ,.1]);F.dec(add(lc,[0,0,1.9]),[0,0,1],QZ[3],1,1)}}}
