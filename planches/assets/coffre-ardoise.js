'use strict';
// Coffre antique · piste A retenue (Reliquaire d'ardoise tyrienne), extraite de coffre-antique-propositions.html.
// ChestKit.frame(o, t) : image du coffre seul (fond transparent), o = ouverture 0..1, t = temps (s).
// Repère : milieu du bas de la face avant au pixel (AX, AY) de l'image W × H.
const ChestKit=(()=>{
const EM=0x1000000,ci=c=>typeof c==='number'?c:parseInt(c.slice(1),16),E=c=>ci(c)|EM,R_=a=>a.map(ci);
const hh=(x,y,s=0)=>{let h=(Math.imul(x|0,374761393)+Math.imul(y|0,668265263)+Math.imul(s|0,982451653))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296};
function vn(x,y,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf),a=hh(xi,yi,s),b=hh(xi+1,yi,s),c=hh(xi,yi+1,s),d=hh(xi+1,yi+1,s);return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+.5)/16),bay=(x,y)=>BAY[(y&3)*4+(x&3)];
const rp=(R,v,x,y)=>{const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]};
const cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),eio=t=>.5-.5*Math.cos(Math.PI*cl(t));
const OUTL=ci('#0b0a0e');
class Pix{constructor(w,h){this.w=w;this.h=h;this.c=new Int32Array(w*h).fill(-1)}
 set(x,y,c){x=Math.floor(x);y=Math.floor(y);if(x<0||y<0||x>=this.w||y>=this.h||c==null)return;c=ci(c);if(c<0)return;this.c[y*this.w+x]=c}
 outline(col=OUTL){const{w,h,c:s}=this,n=new Int32Array(s);for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;if(s[i]!==-1)continue;if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}this.c=n}
 blit(s){for(let i=0;i<s.c.length;i++)if(s.c[i]!==-1)this.c[i]=s.c[i]}}
const SL=R_(['#161b24','#1e2430','#2a3240','#3a4454','#4c5868','#5e6c7e','#7a8898','#98a6b4']);
const CY=['#0a2a33','#12596b','#1f9fb8','#5ce8ff','#c8fbff'];
const W=56,H=72,AX=28,AY=64;
function face(L,O,A,B,fn){const ax=A[0]-O[0],ay=A[1]-O[1],bx=B[0]-O[0],by=B[1]-O[1],det=ax*by-ay*bx;if(Math.abs(det)<.5)return;const wl=Math.hypot(ax,ay),hl=Math.hypot(bx,by);
 const xs=[O[0],A[0],B[0],A[0]+bx],ys=[O[1],A[1],B[1],A[1]+by];
 for(let y=Math.floor(Math.min(...ys));y<Math.ceil(Math.max(...ys));y++)for(let x=Math.floor(Math.min(...xs));x<Math.ceil(Math.max(...xs));x++){const px=x+.5-O[0],py=y+.5-O[1],u=(px*by-py*bx)/det,v=(ax*py-ay*px)/det;
  if(u<0||u>=1||v<0||v>=1)continue;const c=fn(u,v,x,y,wl,hl);if(c!=null&&c>=0)L.set(x,y,c)}}
function ctxFor(w,d){const OX=AX-Math.round(w/2),OY=AY-d;return{W:w,D:d,OX,OY,pr:(x,y,z)=>[OX+x,OY+z-y]}}
function boxF(L,c,x0,x1,y0,y1,z0,z1,top,front){if(top)face(L,c.pr(x0,y1,z0),c.pr(x1,y1,z0),c.pr(x0,y1,z1),top);if(front)face(L,c.pr(x0,y1,z1),c.pr(x1,y1,z1),c.pr(x0,y0,z1),front)}
const rimTop=(w,rim,inner)=>(u,v,x,y,wl,hl)=>{const iu=Math.floor(u*wl),iv=Math.floor(v*hl);if(iu<w||iu>=wl-w||iv<w||iv>=hl-w)return rim(iu,iv,x,y,wl,hl);return inner(iu-w,iv-w,wl-2*w,hl-2*w,x,y)};
const floorY=(c,y,w,back)=>[c.pr(0,y,w)[1]+back,c.pr(0,y,c.D-w)[1]-1];
const MINI=[{p:[' ab ','abcb','bbbb'],m:{a:'#7a8898',b:'#4c5868',c:'#eef1f4'}},{p:['cddd','cddd'],m:{c:'#b48454',d:'#6b4629'}},{p:[' e','ee','ef'],m:{e:'#d8dde2',f:'#8a9096'}},
 {p:['g g','ghg','g g'],m:{g:'#9da2a9',h:'#3e414a'}},{p:['ii ','iji'],m:{i:'#41703c',j:'#78a85a'}}];
function pile(L,x0,x1,y,seed){const R=k=>hh(seed,k,31);let x=x0,k=0;while(x<x1-2){const m=MINI[Math.floor(R(k)*MINI.length)],w=m.p[0].length,hgt=m.p.length,yy=y-hgt+1-(k&1);
 if(x+w>x1)break;m.p.forEach((row,j)=>[...row].forEach((ch,i)=>{if(ch!==' ')L.set(x+i,yy+j,m.m[ch])}));x+=w+(R(k+50)>.5?1:0);k++}}

// Rendu (même dessin que la planche, piste A). Renvoie un Pix ; les pixels émissifs portent EM.
function frame(o,t){const CH=new Pix(W,H),fx=[],part=fn=>{const L=new Pix(W,H);fn(L);L.outline();CH.blit(L)};
 const Wd=36,Dp=14,Hb=13,T=7,c=ctxFor(Wd,Dp),gl=k=>cl(.32+.22*Math.sin(t*2.2-k*.8)+o*.9),
  glyph=(gx,gy)=>{const cell=Math.floor(gx/5),cx=gx%5;if(cx===0||cx===4||gy<=0||gy>=4)return-1;return hh(cell,cx*7+gy,17)>.42||(cx===2&&gy===2)?cell:-1},
  gcol=g=>g>.85?E(CY[4]):g>.55?E(CY[3]):g>.32?E(CY[2]):ci(CY[1]);
 part(L=>{boxF(L,c,0,Wd,0,Hb,0,Dp,rimTop(2,(iu,iv,x,y)=>rp(SL,.7+(iv===0?.1:0)+(vn(x*.4,y*.4,3)-.5)*.2,x,y),(ix,iy,iw,ih,x,y)=>{const back=5;
    if(iy<back){if(iy===2&&ix%4===1)return gcol(gl(ix>>2)*o);return rp(SL,.42-iy*.05,x,y)}return rp(SL,.2-(iy-back)/Math.max(1,ih-back)*.16,x,y)}),
  (u,v,x,y,wl,hl)=>{const iu=Math.floor(u*wl),iv=Math.floor(v*hl),n=vn(x*.4,y*.4,3)-.5;
   if(iu<3||iu>=wl-3){let b=.56+n*.15;if(iu===0||iu===wl-3)b+=.14;if(iu===2||iu===wl-1)b-=.16;if(iv===0)b+=.15;if(iv>=hl-2)b-=.18;return rp(SL,b,x,y)}
   if(iv>=hl-2)return rp(SL,.28+n*.1,x,y);
   if(iv>=4&&iv<9){const gy=iv-4,k=glyph(iu-3,gy);if(gy===0)return SL[1];if(k>=0)return gcol(gl(k));return rp(SL,.22,x,y)}
   let b=.5+n*.18;if(iv===0)b+=.2;if(iv===9)b+=.12;if(iv===3)b-=.1;if((iu-3)%10===0&&iv>9)b-=.25;return rp(SL,b,x,y)});
  const[,fy]=floorY(c,Hb,2,5);if(o>.05)pile(L,c.OX+4,c.OX+Wd-4,fy,3)});
 const lift=4*eio(o/.4),slide=11*eio((o-.4)/.6);
 part(L=>boxF(L,c,-1,Wd+1,Hb+lift,Hb+lift+T,-slide,Dp-slide,(u,v,x,y,wl,hl)=>{const iu=Math.floor(u*wl),iv=Math.floor(v*hl),n=vn(x*.4,y*.4,4)-.5;
   if(iu<1||iu>=wl-1||iv<1||iv>=hl-1)return rp(SL,.8,x,y);if(iu===2||iu===wl-3||iv===2||iv===hl-3)return SL[2];
   const dx=iu-wl/2+.5,dy=(iv-hl/2+.5)*1.25,d=Math.hypot(dx,dy);if(Math.abs(d-3.6)<.6)return gcol(gl(Math.floor(Math.atan2(dy,dx)*1.3+4)));if(d<1.1)return gcol(gl(9)+.2);return rp(SL,.62+n*.2,x,y)},
  (u,v,x,y,wl,hl)=>{const iu=Math.floor(u*wl),iv=Math.floor(v*hl);let b=iv===0?.88:iv===1?.7:.52-iv*.03;if(iu===0)b+=.1;if(iu===wl-1)b-=.15;if(iv===hl-1)b=.25;
   if(Math.abs(iu-wl/2+.5)<2.5&&iv>=2&&iv<=4)b=.3;return rp(SL,b+(vn(x*.4,y*.4,4)-.5)*.15,x,y)}));
 if(o>.3)for(let i=0;i<6;i++){const p=(t*.7+i/6)%1,x=Math.floor(c.OX+5+hh(i,Math.floor(t*.7+i/6),5)*(Wd-10)),y=Math.floor(AY-Hb-6-p*16);if(bay(x,y)<(1-p)*o)CH.set(x,y,E(p<.4?CY[4]:CY[3]))}
 return CH}

// Image RGBA (ImageData) : ombre portée trame sous le coffre, puis le coffre.
function image(o,t,g){const P=frame(o,t),img=g.createImageData(W,H),d=img.data;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){const dd=((x+.5-AX-1)/21)**2+((y+.5-AY-1)/3.4)**2;if(dd<1&&bay(x,y)<.95-dd*.5){const o4=(y*W+x)*4;d[o4]=8;d[o4+1]=10;d[o4+2]=12;d[o4+3]=110}}
 for(let i=0;i<W*H;i++){const v=P.c[i];if(v===-1)continue;d[i*4]=v>>16&255;d[i*4+1]=v>>8&255;d[i*4+2]=v&255;d[i*4+3]=255}return img}
return{W,H,AX,AY,frame,image,eio}})();
