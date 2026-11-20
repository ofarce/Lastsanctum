// ---------- Atelier : les pièces de bois prennent la forme de l'objet fabriqué ----------
// Injecté dans le moteur BAT par tools/atelier-morph/build.py, à la place des cinq madriers de la Table d'énonciation.
// Une pièce cible = [x0, y0, x1, y1, matière, épaisseur], en pixels autour du point d'assemblage (y vers le bas).
// Toutes partent du même bout de bois (longueur 16, épaisseur 2) et changent de longueur, d'épaisseur puis de matière.
const MO_MAT={
 W:[WOOD[4],WOOD[3],WOOD[2]],B:[BARK[3],BARK[2],BARK[1]],I:[IRON[5],IRON[4],IRON[2]],R:[SLATE[4],SLATE[3],SLATE[1]],
 F:[CANVAS[4],CANVAS[3],CANVAS[1]],G:[CANVAS[2],CANVAS[1],CANVAS[0]],L:R_(['#d8584a','#b03c34','#7a2424'])};
const MO_FLAME=['#ffe9a0','#ffb030','#e86a18'].map(E);
const caltrop=(x,y)=>[[x,y-5,x,y,'I',2],[x,y,x-4,y+4,'I',2],[x+1,y,x+5,y+4,'I',2]];
const arrow=(dx,dy)=>[[-9+dx,10+dy,7+dx,-8+dy,'W',2],[7+dx,-8+dy,9+dx,-11+dy,'I',3],[-9+dx,10+dy,-11+dx,13+dy,'L',3]];
const MO_SHAPES={
 torch:[[-7,12,-2,3,'W',3],[-2,3,2,-4,'W',3],[2,-4,5,-9,'G',5]],
 pickaxe:[[-8,12,-1,1,'W',3],[-1,1,5,-8,'W',3],[-9,-8,0,-11,'I',3],[0,-11,8,-9,'I',3],[8,-9,12,-3,'I',2]],
 arrows:[...arrow(-4,-3),...arrow(0,0),...arrow(4,3)],
 chest:[[-11,-8,11,-8,'W',4],[-11,-3,11,-3,'W',4],[-11,2,11,2,'W',4],[-11,7,11,7,'W',4],[-8,-8,-8,10,'I',2],[7,-8,7,10,'I',2],[-1,-3,-1,0,'I',3]],
 wood_fiber:[[-11,-7,11,-7,'F',3],[-11,-2,11,-2,'F',3],[-11,3,11,3,'F',3],[-11,8,11,8,'F',3],[-6,-9,-6,11,'G',2],[4,-9,4,11,'G',2]],
 firing_post:[[-12,-10,-12,10,'W',4],[-7,-7,-7,10,'W',4],[-2,-10,-2,10,'W',4],[3,-7,3,10,'W',4],[8,-10,8,10,'W',4],[-12,-3,11,-3,'B',2],[-12,5,11,5,'B',2]],
 barricade:[[-7,9,-1,9,'R',4],[1,8,7,8,'R',5],[-12,-9,12,7,'W',4],[-12,7,12,-9,'W',4],[-13,1,13,1,'W',3]],
 fishing_rod:[[-10,12,-3,3,'W',2],[-3,3,5,-7,'W',2],[5,-7,9,-12,'W',1],[-10,9,-8,11,'I',4],[9,-12,10,5,'F',1],[10,5,8,8,'I',2]],
 bow:[[-5,-12,2,-7,'W',3],[2,-7,4,0,'W',3],[4,0,2,7,'W',3],[2,7,-5,12,'W',3],[-5,-12,-5,12,'F',1]],
 caltrops:[...caltrop(-6,6),...caltrop(6,6),...caltrop(0,-6)]};
// MO : objet en cours, « figé » montre la silhouette assemblée sans la boucle, « icone » bascule sur l'icône du jeu après l'éclat.
const MO={id:'barricade',hold:0,icon:1,icons:{}};
function moBar(F,x0,y0,x1,y1,m,w){const flat=Math.abs(x1-x0)>=Math.abs(y1-y0);for(let k=0;k<w;k++){const c=m[k===0?0:k===w-1&&w>1?2:1];F.line(x0+(flat?0:k),y0+(flat?k:0),x1+(flat?0:k),y1+(flat?k:0),c)}}
function morphDraw(F,t,cx,cy){
 const S=MO_SHAPES[MO.id]||MO_SHAPES.barricade,n=S.length;
 if(!K){S.forEach((s,k)=>{const x=(hash(k,2,3)-.5)*30,y=20+(k%3)*2;moBar(F,cx+x-7,cy+y,cx+x+7,cy+y,MO_MAT.W,2)});return}
 if(MO.id==='none'){motes(cx,cy+18,14,22,['#5a5cff','#9aa0ff','#e0e4ff'],6,2)(F,t);return} // export vers le jeu : les pièces y sont dessinées par BuildingView
 const u=MO.hold?.56:(t%6)/6,rise=ease(clamp(u/.1)),shown=MO.icon&&u>=.62,flash=!MO.hold&&u>.56&&u<.68;
 if(!shown)S.forEach(([ax,ay,bx,by,mat,w],k)=>{
  const p=ease(clamp((u-.1-.14*k/n)/.3)),tx=(ax+bx)/2,ty=(ay+by)/2,ta=Math.atan2(by-ay,bx-ax),tl=Math.hypot(bx-ax,by-ay)/2;
  const a0=ta+(hash(k,1,3)-.5)*5+(1-p)*t*TAU/6,x0=(hash(k,2,3)-.5)*46,ys=(hash(k,3,3)-.5)*16-4+Math.sin(t*Math.PI+k)*2,y0=20+(ys-20)*rise;
  const x=x0+(tx-x0)*p,y=y0+(ty-y0)*p,a=a0+(ta-a0)*p,L=8+(tl-8)*p,ww=Math.max(1,Math.round(2+(w-2)*p)),dx=Math.cos(a)*L,dy=Math.sin(a)*L;
  moBar(F,cx+x-dx,cy+y-dy,cx+x+dx,cy+y+dy,MO_MAT[p>.6?mat:'W'],ww)});
 if(!shown&&MO.id==='torch'&&u>.5)for(let j=0;j<5;j++)for(let i=-1-(j<3?1:0);i<=1+(j<3?1:0);i++)if(hash(i,j+Math.floor(t*8),5)>.25)F.set(cx+5+i,cy-10-j,MO_FLAME[j>3?2:Math.abs(i)>1?2:j>1?1:0]);
 if(shown){const I=MO.icons[MO.id],fall=u>.82?ease((u-.82)/.18):0,bob=fall?0:Math.round(Math.sin(t*3)*1.2);
  if(I)for(let j=0;j<32;j++)for(let i=0;i<32;i++){const v=I[j*32+i];if(v>=0&&!(fall>.55&&(i+j)%2)&&fall<.95)F.set(cx-16+i,cy-16+j+bob+Math.round(fall*22),v|0x1000000)}}
 if(flash)for(let k=0;k<40;k++){const a=k*TAU/40,r=8+(u-.56)*170;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.7),AEC[k%2?3:2])}
 motes(cx,cy+18,14,22,['#5a5cff','#9aa0ff','#e0e4ff'],6,2)(F,t)}
