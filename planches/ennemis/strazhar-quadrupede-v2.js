'use strict';
(() => {
const $=id=>document.getElementById(id),names=['E','SE','S','SO','O','NO','N','NE'],vectors=[[1,0],[.71,.5],[0,.7],[-.71,.5],[-1,0],[-.71,-.5],[0,-.7],[.71,-.5]];
const variants=[
 {id:'01-lourde',name:'01 · Marche lourde',desc:'Appuis lourds, épaules tassées et petits bonds. Les deux poings puis les deux pieds.',duration:1.2,stride:30},
 {id:'02-bond',name:'02 · Bondissement',desc:'Arrière-train ramené sous le corps, suspension plus ample et cape entraînée par le bond.',duration:.85,stride:45},
 {id:'03-basse',name:'03 · Rampée basse',desc:'Coudes et genoux fléchis, silhouette proche du sol, progression discrète par paires.',duration:1.4,stride:24},
 {id:'04-charge',name:'04 · Charge bestiale',desc:'Corps projeté vers l’avant, grande allonge et cadence rapide. Poussée des deux jambes.',duration:.65,stride:58},
 {id:'05-royale',name:'05 · Démarche royale',desc:'Tête relevée, appuis mesurés et mouvement contenu. Le casque et la cape gardent leur place.',duration:1.1,stride:32}
];
let time=0,playing=true,last=0,ready=false;const images={};
for(const v of variants){const card=document.createElement('article');card.innerHTML=`<h2>${v.name}</h2><p>${v.desc}</p><canvas class="scene" width="640" height="320" aria-label="${v.name}, animation sur le terrain"></canvas><output></output><div class="directions" aria-label="Huit directions de ${v.name}">${names.map((n,i)=>`<button data-dir="${i}" aria-label="${v.name}, ${n}"><canvas width="80" height="80" aria-label="Animation ${n}"></canvas>${n}</button>`).join('')}</div>`;$('cards').append(card);v.canvas=card.querySelector('.scene');v.label=card.querySelector('output');v.thumbs=[...card.querySelectorAll('.directions canvas')];v.buttons=[...card.querySelectorAll('[data-dir]')];v.buttons.forEach((b,i)=>b.onclick=()=>{$('direction').value=String(i);render();});v.buffer=document.createElement('canvas');v.buffer.width=320;v.buffer.height=160;}
function direction(){return $('direction').value==='auto'?Math.floor(time/3)%8:Number($('direction').value);}
function sprite(g,v,dir,frame,x,y,scale){const a=images[v.id],fw=a.width/6,fh=a.height/8;g.imageSmoothingEnabled=false;g.drawImage(a,frame*fw,dir*fh,fw,fh,Math.round(x-24*scale),Math.round(y-41*scale),48*scale,48*scale);}
function draw(v){const dir=direction(),q=(time/v.duration)%1,frame=Math.floor(q*6),g=v.buffer.getContext('2d'),scale=Number($('zoom').value),w=320,h=160;g.imageSmoothingEnabled=false;g.fillStyle='#29313f';g.fillRect(0,0,w,h);g.drawImage(images.floor,0,0,w,h,0,0,w,h);g.drawImage(images.face,0,-20);g.drawImage(images.face,270,-15);
 const moving=$('move').checked,vec=vectors[dir],travel=((time*v.stride/v.duration)%120)-60,x=150+(moving?vec[0]*travel:0),y=105+(moving?vec[1]*travel*.55:0);
 g.fillStyle='#070d1880';g.beginPath();g.ellipse(x,y,13*scale,3*scale,0,0,Math.PI*2);g.fill();sprite(g,v,dir,frame,x,y,scale);
 // Existing in-game atlas at native 40×42 dimensions, never the entire atlas.
 g.drawImage(images.reference,0,0,40,42,270,63,40,42);
 const out=v.canvas.getContext('2d');out.imageSmoothingEnabled=false;out.drawImage(v.buffer,0,0,640,320);v.label.textContent=`${names[dir]} · ${v.duration.toLocaleString('fr')} s / cycle · image ${frame+1}/6`;
 v.thumbs.forEach((c,i)=>{const ctx=c.getContext('2d');ctx.clearRect(0,0,80,80);ctx.fillStyle='#232b38';ctx.fillRect(0,0,80,80);sprite(ctx,v,i,frame,40,65,1);v.buttons[i].classList.toggle('active',i===dir);});}
function render(){if(ready)variants.forEach(draw);}
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pause':'Lecture';};$('step').onclick=()=>{playing=false;$('play').textContent='Lecture';time+=1/24;render();};for(const id of ['zoom','direction','move'])$(id).onchange=render;
async function load(key,url){const im=new Image();im.src=url;await im.decode();images[key]=im;}
Promise.all([load('floor','../assets/ardoise/world/tiles/floor.png'),load('face','../assets/ardoise/world/runtime/face5_0.png'),load('reference','../assets/imported/enemies/strazhar_walk.png'),...variants.map(v=>load(v.id,`ennemis/strazhar-${v.id}-8directions.png`))]).then(()=>{ready=true;$('state').textContent='5 propositions · 8 directions · 240 images';render();}).catch(e=>{$('state').textContent='Erreur de chargement : '+e.message;});
function loop(now){const dt=last?Math.min((now-last)/1000,.06):0;last=now;if(playing)time+=dt*Number($('speed').value);render();requestAnimationFrame(loop);}requestAnimationFrame(loop);
})();
