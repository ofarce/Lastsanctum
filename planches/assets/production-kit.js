'use strict';
// Coffres de production · piste A retenue (Coffrets d'ardoise émaillés, coffres-production-propositions.html)
// et caisse portée devant (port 2). Utilisé par planches/production-export.html.
// ProdKit.chest(kind, o) : Pix du coffre, kind 'in' (bleu) ou 'out' (grenat), o = ouverture 0..1.
// ProdKit.crate() : Pix de la caisse portée (sans contenu : le jeu dessine le lot dessus).
const ProdKit=(()=>{
const ci=c=>typeof c==='number'?c:parseInt(c.slice(1),16),R_=a=>a.map(ci);
const hh=(x,y,s=0)=>{let h=(Math.imul(x|0,374761393)+Math.imul(y|0,668265263)+Math.imul(s|0,982451653))|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967296};
function vn(x,y,s){const xi=Math.floor(x),yi=Math.floor(y),xf=x-xi,yf=y-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf),a=hh(xi,yi,s),b=hh(xi+1,yi,s),c=hh(xi,yi+1,s),d=hh(xi+1,yi+1,s);return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+.5)/16),bay=(x,y)=>BAY[(y&3)*4+(x&3)];
const rp=(R,v,x,y)=>{const n=R.length-1,i=Math.floor(v*n+bay(x,y));return R[i<0?0:i>n?n:i]};
const cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),eio=t=>.5-.5*Math.cos(Math.PI*cl(t));
const OUTL=ci('#0b0a0e');
class Pix{constructor(w,h){this.w=w;this.h=h;this.c=new Int32Array(w*h).fill(-1)}
 set(x,y,c){x=Math.floor(x);y=Math.floor(y);if(x<0||y<0||x>=this.w||y>=this.h||c==null)return;c=ci(c);if(c<0)return;this.c[y*this.w+x]=c}
 rect(x,y,w,h,c){for(let j=y;j<y+h;j++)for(let i=x;i<x+w;i++)this.set(i,j,c)}
 outline(col=OUTL){const{w,h,c:s}=this,n=new Int32Array(s);for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=y*w+x;if(s[i]!==-1)continue;if((x>0&&s[i-1]!==-1)||(x<w-1&&s[i+1]!==-1)||(y>0&&s[i-w]!==-1)||(y<h-1&&s[i+w]!==-1))n[i]=col}this.c=n}
 blit(s,dx=0,dy=0){for(let y=0;y<s.h;y++)for(let x=0;x<s.w;x++){const v=s.c[y*s.w+x];if(v!==-1)this.set(x+dx,y+dy,v)}}}
const part=(host,fn)=>{const L=new Pix(host.w,host.h);fn(L);L.outline();host.blit(L)};
const SL=R_(['#161b24','#1e2430','#2a3240','#3a4454','#4c5868','#5e6c7e','#7a8898','#98a6b4']);
const WD=R_(['#24160c','#3a2416','#52341f','#6b4629','#835a36','#9c6e44','#b48454']);
const BLUE=R_(['#0b1430','#13244e','#1d3872','#2a5199','#3f6fbf','#6b97dc','#a4c2f0']);
const RED=R_(['#1e070a','#360c12','#53131b','#731d23','#93292b','#b0433a','#cc6a55']);
const PAL={in:BLUE,out:RED};
// Repère : 26 × 30, milieu du bas de la face avant en (13, 27).
const W=26,H=30,AX=13,AY=27,BW=14,BD=5,BH=7,X0=AX-7,TY=AY-BH-BD+1,FY=AY-BH+1;
const each=(w,h,fn)=>{for(let j=0;j<h;j++)for(let i=0;i<w;i++)fn(i,j)};
function chest(k,o){const P=new Pix(W,H),pal=PAL[k];
 part(P,L=>{each(BW,BD,(i,j)=>{const x=X0+i,y=TY+j;L.set(x,y,(i===0||i===BW-1||j===0||j===BD-1)?SL[3]:j<2?SL[1]:SL[0])});
  each(BW,BH,(i,j)=>{const x=X0+i,y=FY+j,n=vn(x*.5,y*.5,3)-.5;let c;
   if(i===0||i===BW-1)c=rp(SL,.72+n*.1,x,y);else if(j===0)c=rp(SL,.8,x,y);else if(j===BH-1)c=rp(SL,.25,x,y);
   else if(j>=2&&j<=4&&i>=2&&i<=BW-3)c=rp(pal,.55+(j===2?.3:0)-(j===4?.22:0)+n*.12,x,y);else c=rp(SL,.48+n*.15,x,y);L.set(x,y,c)})});
 const lift=Math.round(2*eio(o/.4)),slide=Math.round(5*eio((o-.4)/.6));
 part(P,L=>{const y0=TY-lift-slide;each(BW+2,BD,(i,j)=>{const x=X0-1+i,y=y0+j;let c=rp(SL,.68+(vn(x*.5,y*.5,4)-.5)*.2,x,y);if(i===0||i===BW+1||j===0)c=rp(SL,.82,x,y);
   if(i>=4&&i<=BW-3&&j>=1&&j<=3)c=rp(pal,j===1?.8:.5,x,y);L.set(x,y,c)});each(BW+2,2,(i,j)=>L.set(X0-1+i,y0+BD+j,j?SL[2]:SL[5]))});
 return P}
// Caisse portée : 12 × 8, repère au milieu du bas en (6, 7). Le contenu (2 rangées au-dessus) est dessiné par le jeu.
const CRW=12,CRH=8,CRX=6,CRY=7;
function crate(){const P=new Pix(CRW,CRH);part(P,L=>{const x=1,y=1;L.rect(x,y,10,6,WD[4]);L.rect(x,y,10,1,WD[6]);L.rect(x,y+5,10,1,WD[2]);L.rect(x+3,y+1,1,4,WD[3]);L.rect(x+7,y+1,1,4,WD[3])});return P}
function toImage(P,g){const img=g.createImageData(P.w,P.h),d=img.data;for(let i=0;i<P.c.length;i++){const v=P.c[i];if(v===-1)continue;d[i*4]=v>>16&255;d[i*4+1]=v>>8&255;d[i*4+2]=v&255;d[i*4+3]=255}return img}
return{W,H,AX,AY,CRW,CRH,CRX,CRY,chest,crate,toImage,eio}})();
