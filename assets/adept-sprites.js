'use strict';
// Sprites pixel des quatre adeptes (planche adeptes-planche.html, pistes A) avec boucles de travail en 4 images.
// AdeptArt.draw(g,x,y,role,t,mode,scale) : pieds en (x,y), mode 'idle' | 'walk' | 'work'.
const AdeptArt=(()=>{const W=24,H=28,FPS=6;
 const LOOK={
  // couleurs de la charte : Sigil érudit en toge grise (lueur blanche), Medeina vert, Aether bleu-violet, Indra orange
  sigil:{work:'scribe',p:['#b4b6be','#e4e8f0','#c89a78'],hat:'band'},
  medeina:{work:'wood',p:['#4c5a30','#7ae070','#8a6a48'],hat:'leaves'},
  aether:{work:'forge',p:['#2e2a3a','#7a80ff','#c89070'],hat:'halo'},
  indra:{work:'drum',p:['#5a3a20','#ff8a2a','#c89070'],hat:'crest'},
  // adeptes combattants de la caserne
  // disciples d'Indra formés à la caserne : orange et bronze
  flammes:{work:'flame',p:['#5a3a20','#ff8a2a','#c89070'],hat:'hood'},
  archer:{work:'bow',p:['#5a4a2a','#ff8a2a','#c89070'],hat:'hoodg'},
  lame:{work:'blade',p:['#6a6e78','#ff8a2a','#c89070'],hat:'helm'}};
 const sh=(hex,k)=>{const n=parseInt(hex.slice(1),16),f=v=>Math.max(0,Math.min(255,Math.round(k<0?v*(1+k):v+(255-v)*k)));return'#'+[n>>16,n>>8&255,n&255].map(f).map(v=>v.toString(16).padStart(2,'0')).join('')};
 const cache={};
 // f : image de travail (0-3) ; walk : -1 aucune marche, sinon phase de pas (0-1)
 function build(v,f,walk){const g=[...Array(H)].map(()=>Array(W).fill(null)),fx=[];
  const R=(x,y,w,h,c,glow)=>{for(let j=y;j<y+h;j++)for(let i=x;i<x+w;i++)if(i>=0&&i<W&&j>=0&&j<H){if(glow)fx.push([i,j,c]);else g[j][i]=c}};
  const work=v.work,[robe,acc,skin]=v.p,dk=sh(robe,-.3),lt=sh(robe,.22),O=work==='wood'||work==='forge'||work==='flame'||work==='bow'?1:2;
  const y0=walk>=0?walk:(work==='forge'&&f===2)||(work==='drum'&&f%2)?1:0;
  const B=(x,y,w,h,c,gl)=>R(x+O,y+y0,w,h,c,gl);
  if(walk>=0){R(7+O-walk,25,2,2,'#3a2a20');R(11+O+walk,25,2,2,'#3a2a20')}else{R(7+O,25,2,2,'#3a2a20');R(11+O,25,2,2,'#3a2a20')}
  B(6,13,8,12-y0,robe);B(6,13,2,12-y0,lt);B(12,13,2,12-y0,dk);B(6,19,8,1,acc);
  if(work==='wood'){for(let k=0;k<5;k++)B(7+(k*3)%6,14+k*2,1,1,sh(robe,-.4));B(8,15+(f%2),1,1,acc,1);B(11,20,1,1,acc,1)}
  if(work==='forge'){B(7,14,6,11-y0,'#6a4a30');B(7,14,6,1,'#4a3020')}
  B(7,6,6,6,skin);
  if(work==='wood'){B(8,8,1,1,acc,1);B(11,8,1,1,acc,1)}else{B(8,8,1,1,'#201810');B(11,8,1,1,'#201810')}
  B(9,10,2,1,sh(skin,-.25));
  const h=v.hat;
  if(h==='cap'){B(7,4,6,2,acc);B(6,5,8,1,sh(acc,-.2))}
  if(h==='bald')B(7,6,6,1,sh(skin,.15));
  if(h==='leaves'){B(6,5,8,1,acc);for(const x of[6,8,10,12])B(x,4,1,1,acc);B(7,3,1,1,acc);B(12,3,1,1,acc)}
  if(h==='feather'){B(7,5,6,1,acc);B(9,1,1,4,'#e04040');B(11,2,1,3,'#f0f0f0')}
  if(h==='crest'){B(7,4,6,3,'#9aa0a8');B(7,4,6,1,'#c8ced6');B(6,6,1,4,'#7a8088');B(13,6,1,4,'#7a8088');B(8,2,5,2,acc);B(12,3,1,3,sh(acc,-.25))}
  if(h==='band'){B(7,5,6,1,'#8a8278');B(7,6,6,1,acc);B(6,6,1,3,'#8a8278')}
  if(h==='halo'){B(7,6,6,1,sh(skin,.15));for(const[x,y]of[[6,3],[7,2],[8,2],[9,2],[10,2],[11,2],[12,2],[13,3]])R(x+O,y+y0,1,1,acc,1)}
  if(h==='hood'){B(6,4,8,2,dk);B(7,3,6,1,dk);B(6,6,1,5,dk);B(13,6,1,5,dk);B(7,8,6,1,'#3a3e46');B(8,8,1,1,acc,1);B(11,8,1,1,acc,1)}
  if(h==='hoodg'){B(6,4,8,2,robe);B(7,3,6,1,robe);B(12,2,2,1,robe);B(6,6,1,4,dk);B(13,6,1,3,dk)}
  if(h==='helm'){B(7,4,6,3,'#b8bcc8');B(7,4,6,1,'#e8ecf4');B(6,6,8,1,'#8a8e9a');B(9,7,2,2,'#8a8e9a');B(9,2,2,2,acc);B(11,3,1,1,acc)}
  const busy=walk<0&&f>=0,F=busy?f:0;
  if(work==='flame'){// réservoir dans le dos, lance tenue à deux mains, flamme pilote
   B(2,13,4,8,'#5a5e66');B(2,13,4,1,'#9aa0a8');B(3,15,2,4,'#7a2e18');B(5,20,2,1,'#3a3e46');
   B(4,14,2,6,robe);B(12,16,3,2,dk);B(8,17,4,2,robe);B(13,17,7,2,'#4a4e56');B(13,17,7,1,'#6a6e76');B(20,17,1,2,'#2a2e36');B(15,19,1,2,'#3a3e46');
   if(busy){const L=[2,3,3,2][f];for(let k=0;k<L;k++){const y=17+((f+k)&1)-(k>1?1:0);R(20+O+k,y,1,2,k===0?'#fff4a0':k===1?'#ffc040':'#ff7a20',1)}R(20+O,16,1,1,'#ff9a2a',1)}
   else B(20,19,1,1,acc,1)}
  if(work==='bow'){// carquois dans le dos, arc tenu devant
   B(3,11,2,9,'#7a4a20');B(3,10,1,2,'#e8e0c8');B(4,10,1,2,acc);B(4,14,2,6,robe);
   const pull=busy?[1,3,0,0][f]:0,bw='#8a5a2a';
   B(17,10,1,13,bw);B(16,9,1,2,bw);B(16,22,1,2,bw);B(13,15,4,2,robe);
   for(let y=10;y<=22;y++){const x=16-Math.round(pull*(1-Math.abs(y-16)/6.5));B(Math.min(16,x),y,1,1,'#e8e0c8')}
   if(busy&&f<2){B(13-pull,16,6+pull,1,'#6c4c2e');B(19,16,1,1,'#d6d9dc')}
   if(busy&&f===2){R(19+O,16,4,1,'#6c4c2e');R(23,16,1,1,'#d6d9dc')}}
  if(work==='blade'){// bouclier à gauche, épée à droite
   const lift=busy?[0,0,1,0][f]:0;B(2,13,5,9,'#e07028');B(2,13,5,1,'#a87a3a');B(2,21,5,1,sh('#e07028',-.3));B(3,16,3,3,'#a87a3a');B(4,17,1,1,'#e2c27a');
   if(!busy||f===3){B(14,15,2,4,robe);B(15,6,1,9,'#d0d4dc');B(16,7,1,7,'#9aa0a8');B(14,15,3,1,'#c89050');B(15,16,1,2,'#6a4020')}
   else if(f===0){B(14,10,2,5,robe);B(14,1,1,9,'#d0d4dc');B(15,2,1,7,'#9aa0a8');B(13,10,3,1,'#c89050')}
   else if(f===1){B(14,14,3,2,robe);R(17+O,14,6,1,'#e8ecf4');B(16,13,1,3,'#c89050');R(18+O,12,4,1,acc,1);R(19+O,16,3,1,acc,1)}
   else{B(14,15+lift,3,2,robe);for(let k=0;k<6;k++)B(16+k,16+k+lift-1,1,1,'#d0d4dc');B(15,15+lift,2,1,'#c89050')}}
  if(work==='scribe'){B(4,15,2,4,robe);B(14,15,2,4,dk);B(6,16,8,3,'#7a3a20');B(6,16,8,1,'#f0e8d0');B(10,16,1,3,'#5a2a10');
   const qx=[7,8,9,8][F];B(qx,13,1,3,'#f4f0e8');B(qx,16,1,1,acc);B(4,19,2,1,skin);
   if(busy){for(let k=0;k<=f;k++)B(7+k,17,1,1,'#3a2a20');const gy=[4,2,0,-2][f];if(f>0){B(16,gy+6,3,1,acc,1);B(17,gy+5,1,3,acc,1);if(f>1){B(15,gy+4,1,1,acc,1);B(19,gy+8,1,1,acc,1)}}}}
  if(work==='wood'){if(busy){R(18,22,5,4,'#6a4020');R(18,22,5,1,'#c8a060');R(19,22,3,1,'#e0c080')}
   B(4,14,2,7,robe);const arm=busy?[[14,9,2,5],[14,11,3,3],[15,15,4,2],[14,13,3,3]][f]:[14,14,2,7];B(...arm,robe);
   if(busy){const hx=[14,16,19,17][f],hy=[6,8,18,12][f];B(hx-O,hy,2,3,'#c0c4cc');
    if(f===2){R(17,19,1,1,'#e0c080');R(22,18,1,1,'#e0c080');R(20,17,1,1,acc,1);R(23,20,1,1,acc,1)}
    if(f===3){R(16,16,1,1,'#e0c080');R(23,15,1,1,'#e0c080')}}else B(14,19,2,4,'#c0c4cc')}
  if(work==='forge'){B(4,14,2,7,robe);
   if(busy){R(16,21,7,2,'#4a4e56');R(17,23,5,1,'#3a3e46');R(18,24,3,2,'#3a3e46');R(17,20,4,1,sh(acc,.1));
    const hp=[[15,6],[16,9],[17,15],[16,10]][f];R(hp[0],hp[1],1,6,'#6a4020');R(hp[0]-1,hp[1]-2,3,3,'#5a5e66');B(13,13,2,3,skin);
    if(f===2){for(const[a,b]of[[15,18],[21,17],[22,19],[14,16],[20,15],[23,17]])R(a,b,1,1,acc,1);R(18,19,2,1,'#fff',1)}
    if(f===3){R(14,14,1,1,acc,1);R(22,15,1,1,acc,1)}}
   else{B(14,14,2,7,dk);B(15,19,1,5,'#6a4020');B(14,23,3,2,'#5a5e66')}}
  if(work==='drum'){B(8,17,5,4,'#c89050');B(8,17,5,1,'#f0e0c0');B(8,20,5,1,acc);B(9,18,1,2,'#7a4a20');B(11,18,1,2,'#7a4a20');
   const L=F===0||F===3?[4,13]:[5,16],Rr=F===1||F===2?[14,13]:[13,16];
   B(L[0],L[1],2,3,robe);B(Rr[0],Rr[1],2,3,dk);B(L[0]+1,L[1]-1,1,1,'#e8e0c8');B(Rr[0],Rr[1]-1,1,1,'#e8e0c8');
   if(busy&&(f===1||f===3)){const z=f===1?17:1;R(z+1,0,2,1,acc,1);R(z+1,1,1,3,acc,1);R(z+2,4,2,1,acc,1);R(z+3,5,1,3,acc,1);R(z+2,8,1,1,'#fff',1)}}
  const o=g.map(r=>r.slice());for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(!g[y][x]&&[[1,0],[-1,0],[0,1],[0,-1]].some(([a,b])=>g[y+b]?.[x+a]))o[y][x]='#14100c';
  const S=2,cv=document.createElement('canvas');cv.width=W*S;cv.height=H*S;const c=cv.getContext('2d');
  o.forEach((r,y)=>r.forEach((col,x)=>{if(col){c.fillStyle=col;c.fillRect(x*S,y*S,S,S)}}));
  c.globalCompositeOperation='lighter';for(const[x,y,col]of fx){c.fillStyle=col+'55';c.fillRect((x-.5)*S,(y-.5)*S,2*S,2*S);c.fillStyle=col;c.fillRect(x*S,y*S,S,S)}
  return{c:cv,cx:10+O}}
 function frame(role,mode,t){const v=LOOK[role];if(!v)return null;
  const f=Math.floor(t*FPS)&3,key=role+mode+(mode==='walk'?f&1:mode==='work'?f:0);
  return cache[key]||(cache[key]=build(v,mode==='work'?f:-1,mode==='walk'?f&1:-1))}
 function draw(g,x,y,role,t,mode='idle',scale=1){const fr=frame(role,mode,t);if(!fr)return;
  g.save();g.translate(x,y);g.scale(scale,scale);g.fillStyle='#07141699';g.beginPath();g.ellipse(0,0,8,2,0,0,Math.PI*2);g.fill();
  const sm=g.imageSmoothingEnabled;g.imageSmoothingEnabled=false;g.drawImage(fr.c,-fr.cx,-H+1,W,H);g.imageSmoothingEnabled=sm;g.restore()}
 return{draw,LOOK}})();
