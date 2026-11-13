/* Ruines de la Garde tyrienne : géométrie immobile par défaut ; option repair pour le relevage de proposition. */
'use strict';
const BallistaRuins=(()=>{
const DESIGNS=[
{id:'01-abandon',name:'Sentinelle abandonnée',tag:'Réactivation rapide',desc:'Charpente encore debout, corde détendue, treuil grippé et trappe bloquée par des gravats. Bannière effilochée et sceau éteint.',repair:'Dégager la trappe, remettre le treuil en état et réveiller le sceau.',kind:0},
{id:'02-arc-rompu',name:'Arc rompu',tag:'Dégâts immédiatement lisibles',desc:'Un bras brisé pend près du socle. La corde est rompue ; le rail, le pivot et l’élévateur restent reconnaissables.',repair:'Restaurer le bras, remplacer la corde et libérer le mécanisme.',kind:1},
{id:'03-affaissee',name:'Charpente affaissée',tag:'Ruine structurelle',desc:'Le rail s’est incliné sur un montant cassé. Le tambour détaché et les poutres au sol indiquent une tourelle hors service.',repair:'Relever le châssis, réparer les supports et remonter le treuil.',kind:2},
{id:'04-enfouie',name:'Vestige envahi',tag:'Retenue · abandon ancien',desc:'Mousse, lierre et éboulis recouvrent une charpente raccourcie. La trappe reste visible sous une dalle déplacée.',repair:'Déblayer le socle, dégager l’élévateur et reconstruire la partie haute.',kind:3}
];
function draw(g,D,{x=96,y=155,scale=1.1,orientation='NE',repair=0}={}){
g.save();g.translate(x,y);g.scale(scale,scale);
const a=BallistaKit.DIRECTIONS.find(d=>d.id===orientation)?.angle??0,c=Math.cos(a),s=Math.sin(a),P=(u,v,z)=>{const U=u*c-v*s,V=u*s+v*c;return[U*.84-V*.64,U*.29+V*.38-z]};
const poly=(ps,col,edge='#202623')=>{g.beginPath();ps.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();g.fillStyle=col;g.fill();if(edge){g.strokeStyle=edge;g.lineWidth=1;g.stroke()}},line=(ps,col,w=1)=>{g.beginPath();ps.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.strokeStyle=col;g.lineWidth=w;g.stroke()},circle=(p,r,col,stroke)=>{g.beginPath();g.arc(...p,r,0,Math.PI*2);g.fillStyle=col;g.fill();if(stroke){g.strokeStyle=stroke;g.stroke()}};
function beam(A,B,w,h=5,col='#514a37'){const [u,v,z]=A,[U,V,Z]=B,du=U-u,dv=V-v,l=Math.hypot(du,dv)||1,nu=-dv/l*w/2,nv=du/l*w/2;const cs=[[u+nu,v+nv,z],[U+nu,V+nv,Z],[U-nu,V-nv,Z],[u-nu,v-nv,z]],q=cs.map(p=>P(...p)),low=cs.map(([x,y,z])=>P(x,y,z-h));for(let i=0;i<4;i++){const j=(i+1)%4;if(q[j][0]<q[i][0])poly([q[i],q[j],low[j],low[i]],'#33352d')}poly(q,col);line([q[0],q[1]],'#857451')}
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x)},r=Math.max(0,Math.min(1,repair)),clear=smooth(r/.23),frame=smooth((r-.23)/.36),arms=smooth((r-.58)/.25);
const k=D.kind,top=(k===3?53:k===2?62:78)+(k===3?25*frame:0);
g.save();g.scale(1,.4);circle([0,8],58,'#080e0dbb');g.restore();
// Même emprise octogonale que la tourelle réparée, avec joints fissurés.
for(let tier=0;tier<3;tier++){const r=45-tier*7,z=5+tier*9,q=[],low=[];for(let j=0;j<8;j++){const ang=(j+.5)*Math.PI/4;q.push(P(Math.cos(ang)*r,Math.sin(ang)*r,z));low.push(P(Math.cos(ang)*r,Math.sin(ang)*r,z-9))}for(let j=0;j<8;j++){let n=(j+1)%8;if((q[j][1]+q[n][1])/2>-z)poly([q[j],q[n],low[n],low[j]],j%2?'#3d443b':'#4a5044')}poly(q,['#5b6153','#656857','#6c6b58'][tier]);for(let j=0;j<8;j++){const ang=(j+.5)*Math.PI/4;line([P(Math.cos(ang)*(r-7),Math.sin(ang)*(r-7),z),q[j]],'#353d33')}}
// Trappe noire obstruée : toujours à sa place, aucun élévateur en mouvement.
poly([P(-38,-9,24),P(23,-9,24),P(23,9,24),P(-38,9,24)],'#101719','#655e43');beam([-36,-13,26],[24,-13,26],8,3,'#50574a');beam([-36,15,27],[22,9,29],8,3,'#4f584d');
for(const [u,v] of [[-20,-24],[20,-24],[-20,24],[20,24]]){const broken=k>=2&&u===20;beam([u,v,29],[u*.55,v*.55,broken?42+(top-52)*frame:top-10],9,7);circle(P(u,v,31),1.6,'#7c704c')}
// Le rail reste orienté dans la direction de tir future ; affaissement suivant u.
const railZ=u=>top+(k===2?-u*.26:k===3?-u*.10*(1-frame):0);
beam([-44,0,railZ(-44)],[k===3?29+39*frame:68,0,railZ(k===3?29+39*frame:68)],12,8);for(let u=-32;u<50;u+=24){if(k===3&&u>20&&frame<.8)continue;beam([u,-8,railZ(u)+2],[u,8,railZ(u)+2],5,3,'#555b50');circle(P(u,6,railZ(u)+3),1.3,'#8c7a50')}
for(const sign of [-1,1]){const broken=(k===1&&sign===-1)||k===3;beam([21,0,railZ(21)],[12,sign*(broken?19+7*arms:26),railZ(12)],8,5);if(!broken)beam([12,sign*26,railZ(12)],[5,sign*49,railZ(5)],6,4);else{poly([P(12,sign*19,railZ(12)),P(10,sign*25,railZ(12)-2),P(16,sign*21,railZ(12)-5)],'#9b8357');beam([5,sign*30,top-15+(15*arms)],[-7+12*arms,sign*(44+5*arms),30+(top-30)*arms],6,4)}
const tip=P(5,sign*(broken?20+29*arms:49),railZ(5));if(k!==3||arms>.6)line([tip,P(-3,sign*18,top-14),P(-10,sign*9,top-23)],'#77715a',1);circle(P(20,sign*7,railZ(20)+3),4,'#3b443b','#85734e')}
const drum=k===2?P(-30,30,28):P(-32,11,top-2);circle(drum,8,'#303a33','#7c704d');for(let j=0;j<5;j++){const a=j*Math.PI*.4;line([[drum[0]+Math.cos(a)*2,drum[1]+Math.sin(a)*2],[drum[0]+Math.cos(a)*7,drum[1]+Math.sin(a)*7]],'#817650')}
// Étoffe déchirée, emblème terni et discontinu.
const penn=P(-16,27,top-12);poly([[penn[0]-8,penn[1]],[penn[0]+8,penn[1]],[penn[0]+6,penn[1]+24],[penn[0]+2,penn[1]+20],[penn[0]-1,penn[1]+31],[penn[0]-4,penn[1]+24],[penn[0]-8,penn[1]+33]],'#283d49','#7b7251');line([[penn[0]-4,penn[1]+12],[penn[0]+4,penn[1]+12]],'#8b815c');line([[penn[0],penn[1]+7],[penn[0],penn[1]+17]],'#8b815c');
const seal=P(-20,-27,24);circle(seal,6,'#24302b','#6e674a');circle(seal,2,'#454d3a');line([[seal[0]-3,seal[1]-4],[seal[0]+1,seal[1]],[seal[0]-1,seal[1]+4]],'#171f1a');
// Gravats déterministes : aucune poussière animée ni effet de feu.
g.save();g.globalAlpha=1-clear;
const debris=k===0?5:k===1?7:k===2?10:16;for(let i=0;i<debris;i++){const u=((i*23+11)%75)-37,v=((i*31+7)%71)-35,z=i<4?26:5;const p=P(u,v,z),r=2+i%3;poly([[p[0]-r,p[1]],[p[0]-1,p[1]-r],[p[0]+r,p[1]-1],[p[0]+r-1,p[1]+r]],i%2?'#676b58':'#4a5446')}
line([P(8,-28,24),P(3,-20,24),P(8,-13,24),P(1,-6,24)],'#2f382e',1.5);
if(k===1)beam([-30,-32,10],[-4,-46,7],6,4);
if(k>=2){beam([-35,31,8],[23,38,6],5,4);beam([-30,-34,6],[-7,-31,9],7,4)}
if(k===3||k===0){const n=k===3?18:6;for(let i=0;i<n;i++){const u=(i*17)%53-25,v=(i*19)%49-24,z=i%3===0?24:5;const p=P(u,v,z);poly([[p[0]-4,p[1]],[p[0],p[1]-2],[p[0]+4,p[1]+1],[p[0]-1,p[1]+2]],i%2?'#465b35':'#384e32',null)}if(k===3)for(let sign of [-1,1]){line([P(-15,sign*20,top-8),P(-20,sign*21,40),P(-23,sign*24,24)],'#48653a',2);for(let i=0;i<5;i++)circle(P(-17-i,sign*22,top-10-i*5),2,'#536b3c')}}
g.restore();g.restore();
}
return{DESIGNS,SELECTED_ID:'04-enfouie',draw};})();
if(typeof module!=='undefined')module.exports=BallistaRuins;
