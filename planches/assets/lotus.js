// Puits des Âmes · Lotus de pierre (piste 5 retenue). Partagé par planches/puits-ames-lotus.html et
// planches/puits-export.html. Requiert decor.js (Px, BAYER, hash, hex) et units.js (UnitKit).
// Toutes les animations bouclent sur 6 s (export du sprite du jeu : 72 images à 12 i/s).
'use strict';
const LOTUS=(()=>{
const {fill}=UnitKit;
const G=['#0a2412','#0f3a1a','#1f6a2a','#3fa83a','#7ae070','#b8f0a0','#e8ffe0'];
const STONE=['#232a35','#313a47','#424d5b','#55626f','#6b7885','#86929e','#a2acb6'];
const MOSS=['#1e3a22','#2c5230','#41703c','#5c8c48','#78a85a'];
const LEAF=['#0f2a18','#163a20','#1f4c28','#2b6131','#3b783b','#529248','#71ac58'];
const LOOP=6,W1=2*Math.PI/LOOP;
const H3=(a,b,s)=>hash(a|0,b|0,s|0),mix=(a,b,t)=>a+(b-a)*t;
function ellP(P,cx,cy,rx,ry,fn,z){for(let y=Math.floor(cy-ry);y<=cy+ry;y++)for(let x=Math.floor(cx-rx);x<=cx+rx;x++){const nx=(x+.5-cx)/rx,ny=(y+.5-cy)/ry;if(nx*nx+ny*ny<=1){const c=fn(x,y,nx,ny);if(c)P.set(x,y,c,z)}}}
function sideP(P,cx,cy,rx,ry,h,fn,z){for(let x=Math.floor(cx-rx);x<=cx+rx;x++){const dx=(x+.5-cx)/rx;if(Math.abs(dx)>1)continue;const e=Math.sqrt(1-dx*dx);
 for(let y=Math.round(cy-h+e*ry);y<=Math.round(cy+e*ry);y++)P.set(x,y,fn(x,y,dx,(y-(cy-h+e*ry))/h),z)}}
const blocks=(R,x,y,dx,vy,seed,o={})=>{const row=Math.floor(vy*(o.rows||3)),bx=Math.floor((x+row*3)/(o.bw||6));let v=.62-dx*.28-vy*.18+(H3(bx,row,seed)-.5)*.16;
 const ly=vy*(o.rows||3)-row;if(ly<.18||((x+row*3)%(o.bw||6)+6)%(o.bw||6)===0)v-=.22;return Px.prototype.ramp(R,v,x,y)};
const openness=(t,act=0)=>.85+.06*Math.sin(t*W1)+act*.3;
// Lotus dans un Px, centre au sol de l'emprise en (cx, cy). act ∈ [0, 1] : éveil (rappel d'une âme).
function draw(P,cx,cy,t,act=0){const o=openness(t,act),bcy=cy-5,N=8;
 const petal=i=>{const a=i/N*6.283+.2,ca=Math.cos(a),sa=Math.sin(a),bx=cx+ca*15,by=bcy+sa*8,tx=cx+ca*(25+o*6),ty=bcy+sa*(13+o*3)-(17-o*9),lx=-sa*6.8,ly=ca*3.6,z=sa<0?2:7+sa;
  fill(P,[[bx-lx*.9,by-ly*.9],[bx+(tx-bx)*.5-lx,by+(ty-by)*.5-ly],[tx,ty],[bx+(tx-bx)*.5+lx,by+(ty-by)*.5+ly],[bx+lx*.9,by+ly*.9],[bx,by+3]],STONE,z,{v:.7-ca*.1+(sa<0?-.08:.05),tex:9,lx:.3});
  for(let k=0;k<5;k++){const q=.3+k*.14;P.set(mix(bx,tx,q),mix(by,ty,q),STONE[sa<0?2:3],z+.05)}
  P.set(tx,ty,MOSS[4],z+.1);P.set(mix(bx,tx,.85),mix(by,ty,.85),MOSS[3],z+.1)};
 for(let i=0;i<N;i++)if(Math.sin(i/N*6.283+.2)<0)petal(i);
 sideP(P,cx,cy,16,8.5,6,(x,y,dx,vy)=>blocks(STONE,x,y,dx,vy,17,{rows:2,bw:4}),3);
 ellP(P,cx,bcy,17,9,(x,y,nx,ny)=>{const r=Math.hypot(nx,ny);if(r>.86)return STONE[2];let v=.45+(1-r)*.2+act*.2+.08*Math.sin(r*12-t*W1*4);if(H3(x,y,Math.floor(t*6))>.96)v=.95;return Px.prototype.ramp(G,v,x,y)},4);
 ellP(P,cx,bcy-1,5,3,(x,y,nx,ny)=>Px.prototype.ramp(MOSS,.75-nx*.3-ny*.3,x,y),5);for(let i=0;i<5;i++){const a=i/5*6.283;P.set(cx+Math.cos(a)*2.6,bcy-2+Math.sin(a)*1.3,G[4],5.1)}
 for(let i=0;i<N;i++)if(Math.sin(i/N*6.283+.2)>=0)petal(i);
 for(let i=0;i<5;i++)P.set(cx+22+i*2,cy+8-(i%2),LEAF[4+(i%2)],9)}
const jetH=(t,act=0)=>9+Math.sin(t*W1*5)+act*9;
// Jet et gouttes ; F : {px(x,y,c), dpx(x,y,c,a)} ; (cx, cy) : centre au sol de l'emprise.
function fountain(F,cx,cy,t,act=0){const jt=jetH(t,act),top=cy-9;for(let y=0;y<jt;y++){F.px(cx,top-y,y>jt-2?G[6]:G[5]);if(y<jt-2)F.dpx(cx+((y+Math.floor(t*12))%2?1:-1),top-y,G[4],.7)}
 for(let j=0;j<10;j++){const ph=((t+j*.1)%1),an=j/10*6.283,x=cx+Math.cos(an)*9*ph,y=top-jt+ph*(jt+3)-Math.sin(Math.PI*ph)*4+Math.sin(an)*ph*3;F.dpx(x,y,ph<.5?G[6]:G[5],1-ph*.5)}}
return{G,STONE,MOSS,LEAF,LOOP,draw,fountain,jetH,openness}})();
