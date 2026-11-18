'use strict';
// Armes du Creuset des Exilés : dessins en pixels (style A « Objet franc », contour #0b090b, lumière en haut à gauche)
// et poses d'attaque de l'Ingénieur tyrien. Repris de planches/armes-creuset.html et planches/armes-attaques.html,
// utilisé par planches/tyrien-export.html (calques d'armes, animations slash1 / slash2 / shoot, icônes 32 px).
// Dépend de engineer-volume.js (Fig, pose, ARM, PAL, add, mul, nrm, sub, lerp3, mix).
const ARM_OUTL='#0b090b';
const ACU=['#3a1c0d','#7a3f1f','#b0623a','#d98c4f','#f6bb85'],AFE=['#1c1f25','#40454e','#6b737d','#a2abb5','#e2e8ee'];
const ALE=['#26190f','#4e3720','#6e4d2d','#8d6640'],AWD=['#2a1a0e','#56371d','#7a5130','#a06c42'],AVG=['#2f5446','#5e9c80','#8fd0b0'];
const ahsh=(a,b)=>{let h=(a*374761393+b*668265263)|0;h=(h^(h>>>13))*1274126177;return((h^(h>>>16))>>>0)/4294967296};
const ametal=(R,v,hw)=>v<-hw+.75?R[4]:v>hw-.75?R[1]:Math.abs(v)<.45?R[2]:R[3];
// ---- formes : (u le long de l'arme depuis la main, vers la pointe ; v en travers) → couleur ou null ----
function aSword(o){const R=o.cu?ACU:AFE;return(u,v)=>{
 if(u<-o.grip-1.6)return null;
 if(u<-o.grip)return Math.hypot(u+o.grip+.8,v)<1.25?(v<0?R[4]:R[2]):null;
 if(u<0)return Math.abs(v)<.95?(((Math.floor(u*1.3))&1)?ALE[2]:ALE[1]):null;
 if(u<1.3){const g=o.guard/2;if(Math.abs(v)>g)return null;if(o.quill&&Math.abs(v)>g-1.2&&u<.5)return null;return v<0?R[4]:R[1]}
 const L=o.blade,t=(u-1.3)/L;if(t>1)return null;
 let hw=o.leaf?mix(o.w,o.w*1.35,Math.sin(Math.min(t/.75,1)*Math.PI*.6)):mix(o.w,o.w*.85,t);if(t>o.tip)hw*=(1-t)/(1-o.tip);
 if(Math.abs(v)>hw)return null;if(o.cu&&ahsh(Math.floor(u*1.2),Math.floor(v+5))>.9)return AVG[1];
 if(!o.cu&&Math.abs(v)<.4&&t<.75)return R[1];return ametal(R,v,hw)}}
function aRoundShield(R){return(u,v)=>{const d=Math.hypot(u,v);if(d>5.6)return null;if(d<1.5)return v+u<0?R[4]:R[2];
 if(d>4.5)return(u+v)<-1?R[4]:(u+v)>2?R[1]:R[3];const a=Math.atan2(v,u);if(Math.abs(d-3)<.5&&((Math.floor((a+4)*2.2))&1))return R[3];
 return((Math.floor(v+20))&1)?AWD[2]:AWD[1]}}
function aKiteShield(R){return(u,v)=>{const y=u,w=y<-2?4.8:4.8*Math.max(0,(8.5-y)/10.5);if(y<-6||y>8.5||Math.abs(v)>w)return null;
 if(Math.abs(v)>w-1.1||y<-5)return v<0||y<-5?R[4]:R[1];if(Math.abs(v)<.7||Math.abs(y+2)<.7)return R[3];return v<0?R[3]:R[2]}}
function aCannon(){return(u,v)=>{
 if(u>-1.5&&u<4.5&&v<-2.2&&v>-5.2){const hw=1.6-(-2.2-v)*.15;if(Math.abs(u-1.5)<hw+1)return v<-4.4?AFE[1]:u<1?ACU[4]:ACU[2]}
 if(u<-4.5||u>12)return null;const r=u<-3?2.4:2.6;if(Math.abs(v)>r)return null;
 if(u>11)return Math.abs(v)<1.2?ARM_OUTL:AFE[2];
 if(Math.abs(u)<.9||Math.abs(u-7.5)<.9)return v<0?ACU[4]:v>r-.8?ACU[1]:ACU[3];
 if(u<-3.4)return ALE[2];return v<-r+.8?AFE[4]:v>r-.8?AFE[1]:Math.abs(v)<.5?AFE[3]:AFE[2]}}
// ---- armes (clé = calque du Tyrien, item = data/gear_items.gd) ----
const WEAPONS=[
 {key:'coppersword',item:'copper_sword',slot:'rhand',label:'Épée en cuivre',hold:'sword',len:9,f:aSword({cu:1,grip:2.4,guard:4.6,blade:6.8,w:1.4,leaf:1,tip:.72})},
 {key:'ironsword',item:'iron_sword',slot:'rhand',label:'Épée en fer',hold:'sword',len:11.5,f:aSword({grip:2.6,guard:5.6,blade:9.4,w:1.15,tip:.8})},
 {key:'coppergreat',item:'copper_greatsword',slot:'rhand',label:'Épée à deux mains en cuivre',hold:'great',len:14,f:aSword({cu:1,grip:4.2,guard:6,blade:11.5,w:1.9,leaf:1,tip:.78})},
 {key:'irongreat',item:'iron_greatsword',slot:'rhand',label:'Épée à deux mains en fer',hold:'great',len:17,f:aSword({grip:4.6,guard:8.4,quill:1,blade:14.5,w:1.6,tip:.84})},
 {key:'cannon',item:'cannon',slot:'rhand',label:'Canon à projection',hold:'cannon',len:12,f:aCannon()},
 {key:'coppershield',item:'copper_shield',slot:'lhand',label:'Bouclier en cuivre',hold:'shield',len:12,f:aRoundShield(ACU)},
 {key:'ironshield',item:'iron_shield',slot:'lhand',label:'Bouclier en fer',hold:'shield',len:15,f:aKiteShield(AFE)}];
// tramage à l'angle `deg`, échelle `s`, raccourci `su` le long de l'arme ; main (u = 0) au pixel (ax, ay) ; contour
function aRaster(g,f,deg,s,ax,ay,w,h,su=1){const a=deg*Math.PI/180,du=[Math.cos(a),Math.sin(a)],dv=[-Math.sin(a),Math.cos(a)];
 const img=g.getImageData(0,0,w,h),d=img.data,m=new Uint8Array(w*h),hx=c=>[parseInt(c.slice(1,3),16),parseInt(c.slice(3,5),16),parseInt(c.slice(5,7),16)];
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const px=(x+.5-ax)/s,py=(y+.5-ay)/s,u=(px*du[0]+py*du[1])/su,v=px*dv[0]+py*dv[1],c=f(u,v);if(!c)continue;const k=(y*w+x)*4,[r,gg,b]=hx(c);d[k]=r;d[k+1]=gg;d[k+2]=b;d[k+3]=255;m[y*w+x]=1}
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){if(m[y*w+x])continue;const n=(x>0&&m[y*w+x-1])||(x<w-1&&m[y*w+x+1])||(y>0&&m[(y-1)*w+x])||(y<h-1&&m[(y+1)*w+x]);if(n){const k=(y*w+x)*4;d[k]=11;d[k+1]=9;d[k+2]=11;d[k+3]=255}}
 g.putImageData(img,0,0)}
// icône 32 px : arme en diagonale, au plus grand qui tient (échelle ≤ 2,3 pour garder les tailles relatives)
const A_ICON_DEG={sword:-45,great:-45,shield:90,cannon:-20};
function aIcon(wp,size){const c=document.createElement('canvas');c.width=c.height=size;const g=c.getContext('2d');
 for(let s=2.3;s>.5;s-=.05){const t=document.createElement('canvas');t.width=t.height=size*3;const tg=t.getContext('2d');aRaster(tg,wp.f,A_ICON_DEG[wp.hold],s,size*1.5,size*1.5,size*3,size*3);
  const D=tg.getImageData(0,0,size*3,size*3).data;let x0=1e9,y0=1e9,x1=-1,y1=-1;for(let i=0;i<D.length/4;i++)if(D[i*4+3]){const x=i%(size*3),y=i/(size*3)|0;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y)}
  if(x1-x0+1<=size-2&&y1-y0+1<=size-2){g.drawImage(t,x0,y0,x1-x0+1,y1-y0+1,Math.floor((size-(x1-x0+1))/2),Math.floor((size-(y1-y0+1))/2),x1-x0+1,y1-y0+1);break}}
 return c}
// ---- poses d'attaque (repère du personnage : X sa droite, Y haut, Z avant ; main droite sd = +1) ----
const aKeyAt=(K,t)=>{for(let i=1;i<K.length;i++)if(t<=K[i].t){const a=K[i-1],b=K[i],u=(t-a.t)/(b.t-a.t||1),e=b.ease?.5-.5*Math.cos(Math.PI*u):u;
  const o={};for(const k in b)if(k!=='t'&&k!=='ease')o[k]=Array.isArray(b[k])?lerp3(a[k],b[k],e):b[k];return o}return K[K.length-1]};
function aArmPose(right,left){const P0=pose('idle',.25),Y=53.4+P0.up,arms=P0.arms.map(r=>{const T=r.sd>0?right:left;if(!T)return r;return ARM(r.sd,Y,T,[r.sd*.9,-1,-.5])});return{...P0,arms}}
// taille à une main : horizontale devant le corps, de sa droite vers sa gauche
const A_ONE=[{t:0,a:[-.1,42,0]},{t:.18,a:[-.55,50,0],ease:1},{t:.3,a:[-.6,51,0]},{t:.36,a:[.5,46,0]},{t:.43,a:[1.55,42,0]},{t:.5,a:[2.55,39,0]},{t:.57,a:[3.15,37,0]},{t:.7,a:[3.2,37,0]},{t:1,a:[-.1,42,0],ease:1}];
const aOneAt=t=>{const k=aKeyAt(A_ONE,t),th=k.a[0],y=k.a[1];return{hand:[Math.cos(th)*12,y,Math.sin(th)*11+2.5],dir:nrm([Math.cos(th),.1-(y-42)*.04,Math.sin(th)*.9+.25])}};
// taille à deux mains : de l'épaule gauche à la taille côté droit
const A_TWO=[{t:0,g:[2,38,7],d:[.15,-.35,1]},{t:.2,g:[-6,60,3],d:[-.45,.85,-.3],ease:1},{t:.32,g:[-7,62,2],d:[-.5,.85,-.35]},
 {t:.4,g:[-3,52,10],d:[-.1,.2,1]},{t:.48,g:[3,42,11],d:[.45,-.45,.75]},{t:.56,g:[8,33,8],d:[.6,-.8,.25]},{t:.7,g:[8,32,7],d:[.55,-.85,.2]},{t:1,g:[2,38,7],d:[.15,-.35,1],ease:1}];
const aTwoAt=t=>{const k=aKeyAt(A_TWO,t),dir=nrm(k.d);return{hand:k.g,dir,left:add(k.g,mul(dir,-2.6))}};
// tir du canon : un coup (0,5 s à 12 i/s), recul puis retour
const A_SHOOT_RC=[2.2,1.2,.4,0,0,0];
const aShootAt=i=>{const rc=A_SHOOT_RC[i],hand=[3.5,41,8.5-rc];return{hand,dir:nrm([.05,-.05,1]),left:[-4,40,9-rc*.6],rc}};
// animations ajoutées à la planche du Tyrien : pose du corps + main/direction de l'arme pour chaque image
const A_ANIMS={
 slash1:{count:14,cols:14,fps:21,at:i=>aOneAt(i/14),note:'taille à une main (épées), 21 i/s'},
 slash2:{count:16,cols:16,fps:18,at:i=>aTwoAt(i/16),note:'taille à deux mains (épées à deux mains), 18 i/s'},
 shoot:{count:6,cols:6,fps:12,at:aShootAt,note:'tir du canon à projection (0,5 s), 12 i/s'}};
for(const n in A_ANIMS){const A=A_ANIMS[n];A.pose=i=>{const k=A.at(i);return aArmPose(k.hand,k.left||null)}}
// tenue au repos / à la marche : angle écran fixe à la main (sword, great, cannon : main droite ; shield : avant-bras gauche)
const A_HOLD={sword:{arm:1,deg:112},great:{arm:1,deg:98},cannon:{arm:1,deg:8},shield:{arm:-1,deg:90}};
// image d'une arme sur le corps : main et direction 3D (animations d'attaque) ou tenue fixe ; derrière le corps si la main l'est
function aWeaponOn(F,body,wp,P,att,W,H){const c=document.createElement('canvas');c.width=W;c.height=H;const g=c.getContext('2d'),l=document.createElement('canvas');l.width=W;l.height=H;
 let q0,deg,su=1,behind=false;
 if(att&&wp.hold!=='shield'){const q1=F.proj(add(att.hand,mul(att.dir,10)));q0=F.proj(att.hand);const vx=q1.x-q0.x,vy=q1.y-q0.y;su=Math.max(.3,Math.min(1,Math.hypot(vx,vy)/5));deg=Math.atan2(vy,vx)*180/Math.PI;behind=q0.d<F.proj([0,45,0]).d-1.5}
 else{const h=A_HOLD[wp.hold],r=P.arms.find(a=>Math.sign(a.sd)===h.arm),at=h.arm<0?lerp3(r.E,r.W,.55):add(r.W,[r.sd*.2,-1.9,.4]);q0=F.proj(at);deg=h.deg}
 aRaster(l.getContext('2d'),wp.f,deg,1,q0.x+.5,q0.y+.5,W,H,su);
 if(behind){g.drawImage(l,0,0);g.drawImage(body,0,0)}else{g.drawImage(body,0,0);g.drawImage(l,0,0)}
 return c}
