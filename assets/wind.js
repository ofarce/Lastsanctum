'use strict';
const WIND_TREES={big:{amplitude:1.5,height:40},cyp:{amplitude:1.05,height:48},palm:{amplitude:2.2,height:44},bush:{amplitude:.65,height:7}};
// Deux ondes spatiales lentes : une même brise traverse le décor, sans synchroniser les arbres.
function windAt(x,z,t=currentTime){
 const phase=x*.047+z*.031;
 return Math.sin(t*1.05-phase)*.72+Math.sin(t*1.83+phase*1.7)*.28;
}
function windTreeSprite(kind,s,R){
 const trunk=new Px(96,120,true),leaves=new Px(96,120,true);
 if(kind==='big')treeBig(trunk,48,112,R,0,s,leaves);
 else if(kind==='cyp')cypress(trunk,48,112,R,0,leaves);
 else if(kind==='palm')palm(trunk,48,112,R,0,leaves);
 else bushDraw(trunk,48,112,R,0,leaves);
 const spr={...trimWindLayer(trunk),foliage:trimWindLayer(leaves)};
 return spr;
}
// Réduire les surfaces transparentes une fois, au chargement : les milliers d'arbres
// partagent ces petits calques au lieu de recopier des rectangles 96 × 120 à chaque image.
function trimWindLayer(layer){
 let x0=layer.w,y0=layer.h,x1=0,y1=0;
 for(let y=0;y<layer.h;y++)for(let x=0;x<layer.w;x++)if(layer.d.data[(y*layer.w+x)*4+3]){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y)}
 if(x0>x1){x0=0;y0=0;x1=0;y1=0}
 const c=document.createElement('canvas');c.width=x1-x0+1;c.height=y1-y0+1;
 c.getContext('2d').putImageData(layer.d,-x0,-y0);
 return {c,ax:48-x0,ay:112-y0};
}
// Déformation continue du feuillage seulement, sans poses ni arrondi de phase.
function drawWindTree(o,nx,ny){
 const spec=WIND_TREES[o.wind],shear=-windAt(o.x,o.z)*spec.amplitude/spec.height;
 if(!decorRenderer){const v=treeVariant(o.spr,shear);if(v){ctx.drawImage(v.c,nx*PX-v.ox,ny*PX-v.oy);return}}
 drawDecorSprite(o.spr,nx,ny);
 drawDecorSprite(o.spr.foliage,nx,ny,shear,true);
}
function drawWindBanner(o,nx,ny){
 const f=o.flag,s=f.spr,phase=o.x*.11+o.z*.07;
 const breeze=.8+.2*Math.sin(currentTime*.65-phase);
 // La hampe et les deux premières rangées restent fixes ; l'ondulation grandit vers la pointe.
 for(let row=0;row<s.c.height;row++){
  const u=Math.max(0,(row-2)/(s.c.height-3));
  const flutter=u*u*breeze*(Math.sin(currentTime*2.2-u*4.5+phase)*1.7+Math.sin(currentTime*3.8-u*7+phase)*.4);
  drawDecorSlice(s,row,(nx+f.x+flutter)*PX,(ny+f.y+row)*PX,true);
 }
}
