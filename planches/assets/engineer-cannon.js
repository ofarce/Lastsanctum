// Arbalestrie (piste A · tube runique) et casque de combat de l'Ingénieur, planches/ingenieur-canon-planche.html.
// Dépend de engineer-colosse.js et engineer-exile.js. Expose cannonBody(), helmetLayer().
'use strict';
if(!R.wood){R.wood=['#1a0e08','#4a2a16','#7a4a26','#a8703a','#d09a5a'];MAT.push('wood')}
// u = long du tir depuis la main (px), v = travers (négatif = dessus).
function cannonA(u,v){if(u>=-4&&u<-1&&v>=0&&v<=2)return['wood',.5-u*.04];if(u>=-1&&u<=11&&Math.abs(v+.5)<=2){
 if(u>=10.4)return['iron',.25];if(Math.abs(u-1)<.6||Math.abs(u-7)<.7)return['brz',v<0?.85:.5];if(u>8.5&&u<10.4&&v<-.5)return['cy',.8];return['iron',v<-1.5?.85:v>.8?.3:.6]}return null}
// Templier de profil (vers la droite), canon en main, dans un cadre w × h où le gabarit 32 × 34 est posé en (ox, oy).
function cannonBody({ang=0,rec=0,flash=false,pose='idle',f=0,ub=0}={},w=48,h=48,ox=8,oy=15){
 const D=Math.PI/180,b0=exile({v:'B',dir:'s',pose,f,ub,aim:{ang:ang*D,rec,pulse:flash}}),b=buf(w,h);
 for(let y=0;y<b0.h;y++)for(let x=0;x<b0.w;x++){const X=x+ox,Y=y+oy;if(X<w&&Y<h){b.m[Y*w+X]=b0.m[y*b0.w+x];b.s[Y*w+X]=b0.s[y*b0.w+x]}}
 const bob=pose==='walk'?(f%2?-1:0):0,c=Math.cos(ang*D),s=Math.sin(ang*D),sx=17+ox,sy=15+oy+bob+ub,L=6-rec,hx=sx+L*c,hy=sy+L*s;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const dx=x+.5-hx,dy=y+.5-hy,r=cannonA(dx*c+dy*s,-dx*s+dy*c);if(r)px(b,x,y,r[0],r[1])}
 blob(b,hx,hy,1.6,1.5,'iron',.15);px(b,hx,hy,'cy',flash?1:.7);
 if(flash){const mx=hx+11.5*c,my=hy+11.5*s;
  for(const[a,bb,l]of[[0,0,1],[1,0,1],[2,0,.85],[1,-1,.8],[1,1,.8],[3,0,.6],[2,-2,.5],[2,2,.5]])px(b,mx+a*c-bb*s,my+a*s+bb*c,'cy',l)}
 return b}
// Casque seul (calque), p = 0 relevé → 1 fermé : les plaques montent du col ; dy = décalage vertical de la tête.
function helmetLayer(p,dy=0,w=48,h=48,ox=8,oy=15){const b=buf(w,h);if(p<=0)return b;const hx=17+ox,hy=6+oy+dy,top=hy+6-p*11.5;
 blob(b,hx,hy-.3,5.3,5.3,'iron',.12,(x,y)=>y>=top);
 rect(b,hx-5,hy+2,9,3,'iron',-.05);
 for(const y of[hy-3,hy+1])if(y>=top)for(let x=hx-4;x<=hx+3;x++)px(b,x,y,'iron',.35);
 if(p>=.75)for(let x=hx;x<=hx+5;x++)px(b,x,hy,'cy',p>=1?(x===hx+4?1:.75):.45);
 if(top<=hy-5)px(b,hx-1,hy-5,'cy',.8);
 for(let x=hx-4;x<=hx+3;x++)if(hy+5>=top)px(b,x,hy+5,'brz',.6);
 return b}
