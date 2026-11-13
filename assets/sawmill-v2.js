/* Medeina painted atlas, articulated display layers; simulation uses seconds. */
(function(global){
'use strict';
const old=global.SawmillKit, atlas=new Image(), tiles=[];
const ease=v=>{v=Math.max(0,Math.min(1,v));return v*v*(3-2*v)};
atlas.src='design/scierie/medeina-atlas-v2.png';
atlas.onload=()=>{for(let i=0;i<6;i++){
 const c=document.createElement('canvas'); c.width=512;c.height=512;const g=c.getContext('2d');g.drawImage(atlas,(i%3)*512,Math.floor(i/3)*512,512,512,0,0,512,512);
 // Remove only background pixels connected to cell edges, preserving dark timber interiors.
 const im=g.getImageData(0,0,512,512),p=im.data,seen=new Uint8Array(512*512),queue=[];
 const add=n=>{if(n<0||n>=seen.length||seen[n])return;seen[n]=1;const j=n*4;if(p[j]<35&&p[j+1]<57&&p[j+2]<48){queue.push(n);p[j+3]=0}};
 for(let j=0;j<512;j++){add(j);add(511*512+j);add(j*512);add(j*512+511)}
 for(let j=0;j<queue.length;j++){const n=queue[j];if(n%512)add(n-1);if(n%512<511)add(n+1);add(n-512);add(n+512)}
 g.putImageData(im,0,0);tiles.push(c);
}};
function disc(g,img,x,y,rx,ry,angle){g.save();g.translate(x,y);g.scale(1,ry/rx);g.beginPath();g.arc(0,0,rx,0,Math.PI*2);g.clip();g.rotate(angle);g.drawImage(img,x-rx,y-ry,rx*2,ry*2,-rx,-rx,rx*2,rx*2);g.restore()}
function paintedBuilding(g,D,t,active){const img=tiles[D.kind];if(!img)return;g.save();g.translate(14,5);g.scale(.57,.42);g.drawImage(img,0,0);
 if(active){
 const a=t*2.8;
 // Perspective-correct animated inner discs leave teeth, frames and log occlusion intact.
 const centers=[[316,294,30,47],[284,286,18,24],[339,297,18,25],[322,317,21,26],[293,357,17,20]];
 const [x,y,rx,ry]=centers[D.kind];disc(g,img,x,y,rx,ry,a);
 if(D.kind===1)disc(g,img,407,277,41,76,-t*.7);
 if(D.kind===3)disc(g,img,208,327,23,42,-a*.5);
 if(D.kind===4){g.save();g.beginPath();g.rect(206,160,142,88);g.clip();g.clearRect(206,160,142,88);g.drawImage(img,206,160,142,88,206,160+Math.sin(t*1.2)*4,142,88);g.restore()}
 // Warm lantern light and fine sawdust use continuous time, independent of frame rate.
 g.globalCompositeOperation='screen';for(const [lx,ly] of [[180,260],[420,300]]){const glow=g.createRadialGradient(lx,ly,0,lx,ly,18);glow.addColorStop(0,'#ffc76b35');glow.addColorStop(1,'#ffc76b00');g.fillStyle=glow;g.globalAlpha=.65+.2*Math.sin(t*5);g.fillRect(lx-18,ly-18,36,36)}g.globalAlpha=1;
 for(let n=0;n<22;n++){const f=(t*.8+n/22)%1;g.fillStyle=`rgba(229,190,112,${1-f})`;g.fillRect(x+f*45,y+38-f*12+f*f*35,1.3,1.3)}
 }g.restore()}
function worker(g,x,y,t,mode='work',scale=1){if(!tiles[5])return;g.save();g.translate(x,y);g.scale(scale,scale);const img=tiles[5],walk=mode==='walk'||mode==='carry',step=Math.sin(t*7),work=Math.sin(t*2.8);g.translate(0,walk?-Math.abs(step)*.7:work*.25);
 // Segmented painting: articulated legs and upper body rather than whole-sprite bobbing.
 const drawPart=(sx,sy,sw,sh,dx,dy,dw,dh)=>g.drawImage(img,sx,sy,sw,sh,dx,dy,dw,dh);
 for(let leg=0;leg<2;leg++){g.save();g.translate(leg?3:-3,-12);g.rotate(walk?step*(leg?-.16:.16):0);drawPart(leg?300:126,325,leg?114:174,174,leg?-1:-9,0,leg?11:17,17);g.restore()}
 g.save();g.translate(0,-15);g.rotate(walk?step*.018:work*.012);drawPart(121,8,307,335,-15,-31,30,33);g.restore();
 if(mode==='work'){g.strokeStyle='#c0a16c';g.lineWidth=1.4;g.beginPath();g.moveTo(-9,-2);g.lineTo(-15-work,-27);g.stroke();g.fillStyle='#e4c58b';g.beginPath();g.arc(-15-work,-27,1.7,0,Math.PI*2);g.fill()}
 if(mode==='carry')old.woodIcon(g,-14,-24);g.restore()}
function forest(g,t){g.save();for(let i=0;i<7;i++){const x=271+i*9,y=236+i%2*5;g.fillStyle=i%2?'#2c4930':'#1b3528';g.beginPath();g.ellipse(x+Math.sin(t*.7+i),y-7,8,18,-.4,0,Math.PI*2);g.fill()}g.restore()}
function render(g,D,time){const t=((time%28)+28)%28;g.clearRect(0,0,320,240);
 if(!tiles.length){g.fillStyle='#ddc796';g.font='12px Georgia';g.fillText('Préparation des modèles…',85,120);return{phase:'Chargement',wood:0,progress:0,popupAge:Infinity,producing:false}}
 // A soft ground plane anchors all five distinct silhouettes.
 g.fillStyle='#06100d66';g.beginPath();g.ellipse(160,205,140,23,0,0,Math.PI*2);g.fill();
 if(t<8){global.TempleKit.footprint(g,t,{color:'#d9c293'});g.save();const u=ease(t/8);g.beginPath();g.rect(0,225*(1-u),320,240);g.clip();g.globalAlpha=Math.min(1,t/2);paintedBuilding(g,D,0,false);g.restore()}
 else{paintedBuilding(g,D,t,t>=13);const u=Math.min(1,(t-8)/5);worker(g,300-102*u,255-43*u,t,t<13?'walk':'work',.8)}
 forest(g,t);
 // Temple witness is deliberately separate from the production building.
 g.save();g.translate(-36,149);g.scale(.32,.32);global.TempleKit.building(g,global.TempleKit.DESIGNS[0],t);g.restore();
 g.fillStyle='#b3b8a0';g.font='7px Georgia';g.fillText('TEMPLE',3,221);
 const elapsed=Math.max(0,t-13),gains=Math.floor(elapsed/4);return{phase:t<8?'Construction de la scierie':t<13?'Arrivée de l’artisan · lisière sud-est':'Machine en service · production de bois',wood:gains*10,progress:elapsed%4/4,popupAge:gains?elapsed-gains*4:Infinity,producing:t>=13};
}
function feedback(g,s){if(!s.producing)return;g.save();g.fillStyle='#17291d';g.fillRect(105,229,110,2);g.fillStyle='#d8b66d';g.fillRect(105,229,110*s.progress,2);g.restore();const a=s.popupAge;if(a<0||a>=1.8)return;g.save();g.globalAlpha=a<.3?ease(a/.3):a<1.3?1:1-ease((a-1.3)/.5);g.translate(23,155-16*ease(a/.3));old.woodIcon(g,-10,0);g.font='bold 13px Georgia';g.fillStyle='#ffe1a1';g.shadowColor='#000';g.shadowBlur=4;g.fillText('+10',1,4);g.restore()}
global.SawmillKit={...old,nativeWorker:old.worker,render,feedback,worker,building:paintedBuilding};
})(window);
