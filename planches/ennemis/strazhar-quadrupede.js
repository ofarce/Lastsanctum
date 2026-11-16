'use strict';
(() => {
const {K,fill,ell,seg,line,outlineAll}=ProjectUnitKit;
const variants=[
 {name:'01 · Marche lourde',desc:'Épaules dominantes, bassin bas et réception tassée. Le mouvement le plus proche d’un gorille.',duration:1.2,stride:30,height:0,bounce:2,reach:0},
 {name:'02 · Bondissement',desc:'Poussée arrière plus ample, brève suspension et jambes ramenées sous le ventre.',duration:.85,stride:45,height:0,bounce:7,reach:4},
 {name:'03 · Rampée basse',desc:'Coudes et genoux fléchis, silhouette proche du sol, progression discrète par paires.',duration:1.4,stride:24,height:9,bounce:1,reach:2},
 {name:'04 · Charge bestiale',desc:'Corps projeté vers l’avant, grande allonge et cadence rapide. Impacts secs sur les poings.',duration:.65,stride:58,height:3,bounce:5,reach:8},
 {name:'05 · Démarche royale',desc:'Tête relevée, appuis mesurés et mouvement contenu. La silhouette conserve son port de champion.',duration:1.1,stride:32,height:-3,bounce:2,reach:-2}
];
const $=id=>document.getElementById(id),mix=(a,b,t)=>a+(b-a)*t;
let time=0,playing=true,last=0,ready=false;const images={},cache=new Map();
for(const v of variants){const card=document.createElement('article');card.innerHTML=`<h2>${v.name}</h2><p>${v.desc}</p><canvas width="640" height="280" aria-label="${v.name}, animation sur le terrain"></canvas><output></output>`;$('cards').append(card);v.canvas=card.querySelector('canvas');v.label=card.querySelector('output');v.buffer=document.createElement('canvas');v.buffer.width=320;v.buffer.height=140;}
// Contact phases shared by both limbs in each pair: no alternating bipedal steps.
function pose(v,q){
 const keys=[{hand:[65+v.reach,69],foot:[19,66],hip:[29,48],shoulder:[49,43]}, {hand:[54,69],foot:[31,56],hip:[30,43-v.bounce],shoulder:[48,46]}, {hand:[62,53],foot:[37,69],hip:[30,47],shoulder:[51,43]}, {hand:[73+v.reach,58],foot:[23,69],hip:[28,46-v.bounce*.5],shoulder:[51,41]}, {hand:[65+v.reach,69],foot:[19,66],hip:[29,48],shoulder:[49,43]}];
 const phase=q*4,i=Math.floor(phase),u=phase-i,s=u*u*(3-2*u),a=keys[i],b=keys[i+1],r={};
 for(const k of Object.keys(a))r[k]=a[k].map((x,j)=>mix(x,b[k][j],s));
 r.hip[1]+=v.height;r.shoulder[1]+=v.height;r.hand[1]+=v.height*.06;r.foot[1]+=v.height*.06;return r;
}
function sprite(index,frame){const key=index+':'+frame;if(cache.has(key))return cache.get(key);const v=variants[index],q=frame/32,r=pose(v,q),P=new Px(96,84,true),gold=K.gold,pink=['#3a0820','#7a1040','#c8206a','#ff5aa0','#ffd0e4'];
 const {hip:H,shoulder:S,hand:A,foot:F}=r;
 // Sheathed blade and cape follow the back; individual limbs are articulated.
 fill(P,[[H[0]-4,H[1]-6],[S[0]-4,S[1]-10],[S[0]-17,S[1]-6],[H[0]-17,H[1]+5+Math.sin(q*6.28)*2]],K.crim,4,{fold:1,v:.7});
 line(P,H[0]-15,H[1]+3,S[0]-15,S[1]-6,gold[3],5);
 function leg(back){const dx=back?-3:2,dy=back?-2:0,z=back?7:24,knee=[H[0]+9+dx,H[1]+10],foot=[F[0]+dx,F[1]+dy];seg(P,[H[0]+dx,H[1]],knee,6,gold,z,{v:back?.4:.7});seg(P,knee,foot,4.5,gold,z+1,{v:back?.4:.7});ell(P,...knee,3,3,gold,z+2);fill(P,[[foot[0]-3,foot[1]-3],[foot[0]+4,foot[1]-3],[foot[0]+6,foot[1]],[foot[0]-3,foot[1]]],gold,z+2);}
 function arm(back){const dx=back?-3:2,dy=back?-2:0,z=back?10:37,root=[S[0]+dx,S[1]],hand=[A[0]+dx,A[1]+dy],elbow=[mix(root[0],hand[0],.5)-3,mix(root[1],hand[1],.5)+4];seg(P,root,elbow,7,gold,z);ell(P,...root,5,4,gold,z+1);seg(P,elbow,hand,5,gold,z+1);ell(P,hand[0]+1,hand[1]-1,4,2.5,gold,z+2);for(let j=0;j<3;j++)P.set(hand[0]+j*2,hand[1],gold[4],z+3);
 if(!back){const x=elbow[0]+1,y=elbow[1]-3;fill(P,[[x-6,y-5],[x+2,y-7],[x+8,y],[x+4,y+7],[x-3,y+2]],gold,44,{v:.8});fill(P,[[x-3,y],[x+1,y-2],[x+5,y],[x+1,y+2]],pink,45,{v:.85});line(P,x+1,y-1,x+1,y+1,K.gun[0],46);}}
 leg(true);arm(true);seg(P,H,S,14,gold,18,{v:.7});ell(P,...H,7,6,gold,20);line(P,H[0],H[1]-6,S[0],S[1]-7,gold[4],21);leg(false);
 seg(P,[H[0]-5,H[1]-8],[S[0]-3,S[1]-10],2,K.ivory,26);line(P,H[0]-5,H[1]-10,H[0]-4,H[1]-5,gold[4],27);
 const hx=S[0]+9,hy=S[1]-9-(index===4?3:0);fill(P,[[hx-6,hy-7],[hx+4,hy-8],[hx+8,hy-2],[hx+5,hy+7],[hx-4,hy+6]],gold,30,{v:.8});for(let j=0;j<3;j++)fill(P,[[hx-6+j*4,hy-5],[hx-7+j*4,hy-14-j%2*2],[hx-2+j*4,hy-7]],gold,31,{v:.9});line(P,hx,hy,hx+6,hy-1,pink[3],33);line(P,hx+3,hy+1,hx+3,hy+5,gold[1],33);
 for(let j=0;j<22;j++){const a=j/22*6.28;P.set(hx-7+Math.cos(a)*10,hy-6+Math.sin(a)*11,j%3===0?gold[5]:gold[3],8);}
 ell(P,S[0]+1,S[1]+3,3,3,gold,34);ell(P,S[0]+1,S[1]+3,1.5,2,pink,35,{v:.85});line(P,S[0]-8,S[1]-3,S[0]-3,S[1]+2,pink[1],25);arm(false);outlineAll(P);P.flush();cache.set(key,P.c);return P.c;
}
function draw(index,t){const v=variants[index],g=v.buffer.getContext('2d'),w=320,h=140,q=(t/v.duration)%1,scale=Number($('zoom').value)*.5,moving=$('move').checked,x=moving?48+(t*v.stride/v.duration)%(w-112):150,y=103;g.imageSmoothingEnabled=false;g.fillStyle='#2a303e';g.fillRect(0,0,w,h);g.drawImage(images.floor,0,0,Math.min(w,images.floor.width),Math.min(h,images.floor.height),0,0,w,h);g.drawImage(images.face,0,-20);g.drawImage(images.face,270,-15);
 // A standing game unit provides a stable scale reference.
 const a=images.reference;g.drawImage(a,0,0,40,42,260,61,40,42);
 g.save();g.translate(Math.round(x),y);g.scale(scale,scale);g.fillStyle='#080e1888';g.beginPath();g.ellipse(0,0,18,4,0,0,Math.PI*2);g.fill();g.drawImage(sprite(index,Math.floor(q*32)),-48,-69);
 if($('guides').checked){const r=pose(v,q);for(const [p,c,on] of [[r.hand,'#f1c46b',q<.5],[r.foot,'#75d9c0',q>=.5]]){g.strokeStyle=c;g.lineWidth=1;g.beginPath();g.ellipse(p[0]-48,0,6,on?2:1,0,0,Math.PI*2);g.stroke();}g.strokeStyle='#ffffff55';g.beginPath();g.moveTo(-42,0);g.lineTo(42,0);g.stroke();}
 g.restore();const out=v.canvas.getContext('2d');out.imageSmoothingEnabled=false;out.drawImage(v.buffer,0,0,640,280);v.label.textContent=`${v.duration.toLocaleString('fr')} s / cycle · ${q<.5?'Appui des deux membres avant':'Appui des deux membres arrière'}`;
}
function render(){if(ready)variants.forEach((v,i)=>draw(i,time));}
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pause':'Lecture';};$('step').onclick=()=>{playing=false;$('play').textContent='Lecture';time+=1/24;render();};for(const id of ['zoom','guides','move'])$(id).onchange=render;
window.StrazharPreview={variants,pose,sprite,renderAt(t){time=t;render();},get time(){return time;}};
async function load(key,url){const im=new Image();im.src=url;await im.decode();images[key]=im;}
Promise.all([load('floor','../assets/ardoise/world/tiles/floor.png'),load('face','../assets/ardoise/world/runtime/face5_0.png'),load('reference','../assets/imported/enemies/strazhar_walk.png')]).then(()=>{ready=true;$('state').textContent='5 boucles · textures et primitives du jeu';render();}).catch(e=>{$('state').textContent='Erreur de chargement : '+e.message;});
function loop(now){const dt=last?Math.min((now-last)/1000,.06):0;last=now;if(playing)time+=dt*Number($('speed').value);render();requestAnimationFrame(loop);}requestAnimationFrame(loop);
})();
