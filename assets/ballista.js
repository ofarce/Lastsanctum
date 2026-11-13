/* Ballistes tyriennes — cinq modèles et cycles mécaniques interpolés. Sans dépendance. */
'use strict';
const BallistaKit=(()=>{
const DESIGNS=[
{id:'01-garde-tyrienne',name:'Garde tyrienne',tag:'La plus fidèle à la référence',mechanism:'Magasin vertical · treuil à double tambour',desc:'Chêne cerclé de fer, bras larges et bannière bleue. Un trait descend du magasin ; le treuil ramène la corde et le poussoir verrouille la munition.',role:'Défense initiale polyvalente',cycle:3.6,kind:0},
{id:'02-sentinelle-a-barillet',name:'Sentinelle à barillet',tag:'La mécanique la plus lisible',mechanism:'Barillet à six logements · indexation par engrenage',desc:'Le barillet tourne d’un sixième de tour, présente un trait au rail puis se verrouille. La corde se retend indépendamment du magasin.',role:'Tirs réguliers sur cibles isolées',cycle:3.3,kind:1},
{id:'03-jumelle-du-rempart',name:'Jumelle du rempart',tag:'La meilleure lecture des tirs alternés',mechanism:'Deux rails · deux treuils indépendants',desc:'Deux balistes compactes sur un même pivot. Chaque bras recharge pendant que l’autre tire ; l’alternance produit une défense continue et lisible.',role:'Couverture des premières vagues',cycle:4.4,kind:2},
{id:'04-aiguille-du-sanctum',name:'Aiguille du sanctum',tag:'La silhouette de précision',mechanism:'Contrepoids · élévateur de traits',desc:'Un long rail sur une embase haute. Le contrepoids descend pour retendre la corde ; l’élévateur dépose ensuite un grand trait dans la glissière.',role:'Tir puissant, cadence lente',cycle:4.6,kind:3},
{id:'05-egide-a-chaine',name:'Égide à chaîne',tag:'La variante fortifiée',mechanism:'Chaîne à godets · poussoir mécanique',desc:'Une chaîne transporte les traits depuis un râtelier latéral. Un poussoir les engage dans le rail protégé par deux joues de fer rivetées.',role:'Défense rapprochée du sanctum',cycle:3.8,kind:4}
];
// Directions écran : N en haut, E à droite. La géométrie tourne en 3D, jamais l’image finie.
const DIRECTIONS=[['N',0,-1],['NE',1,-1],['E',1,0],['SE',1,1],['S',0,1],['SO',-1,1],['O',-1,0],['NO',-1,-1]].map(([id,x,y])=>({id,x,y,angle:Math.atan2(-.29*x+.84*y,.38*x+.64*y)}));
const GUARD={...DESIGNS[0],bottomFeed:true,name:'Garde tyrienne · élévateur de socle',mechanism:'Réserve souterraine · trappe de socle · élévateur automatique',desc:'Les pieux montent horizontalement depuis une trappe dans le socle, puis sont engagés sur le rail. Aucun magasin supérieur.'};
const clamp=x=>Math.max(0,Math.min(1,x)),ease=x=>{x=clamp(x);return x*x*(3-2*x)},lerp=(a,b,t)=>a+(b-a)*t;
// Un cycle commence avec une arme vide. Lâcher à 76 %, puis retour amorti.
function state(p){p=((p%1)+1)%1;return{p,feed:ease((p-.05)/.2),draw:ease((p-.22)/.44),shot:p>=.76,flight:clamp((p-.76)/.18),recoil:p>=.76?Math.sin(clamp((p-.76)/.14)*Math.PI)*5:0,lock:ease((p-.64)/.1)}}
function label(p){return p<.05?'Retour au repos':p<.25?'Alimentation automatique':p<.64?'Mise en tension du treuil':p<.76?'Verrouillage · prêt au tir':p<.9?'Tir · recul amorti':'Retour du chariot'}
function draw(g,D,opts={}){
const {x=160,y=185,scale=1,time=0,mode='cycle',phase,active=1,flip=false,orientation=null,projectile=true}=opts;
g.save();g.globalAlpha=.55+.45*active;g.translate(x,y);g.scale(flip?-scale:scale,scale);
const poly=(pts,fill,stroke='#191b18',w=1)=>{g.beginPath();pts.forEach(([a,b],i)=>i?g.lineTo(a,b):g.moveTo(a,b));g.closePath();g.fillStyle=fill;g.fill();if(stroke){g.strokeStyle=stroke;g.lineWidth=w;g.stroke()}},line=(pts,c,w=1)=>{g.beginPath();pts.forEach(([a,b],i)=>i?g.lineTo(a,b):g.moveTo(a,b));g.strokeStyle=c;g.lineWidth=w;g.stroke()},circ=(a,b,r,c,s)=>{g.beginPath();g.arc(a,b,r,0,Math.PI*2);g.fillStyle=c;g.fill();if(s){g.strokeStyle=s;g.stroke()}},rect=(a,b,w,h,c)=>{g.fillStyle=c;g.fillRect(a,b,w,h)};
// Isométrie : u le long du rail, v transversal, z hauteur.
const heading=DIRECTIONS.find(d=>d.id===orientation)?.angle??0,ca=Math.cos(heading),sa=Math.sin(heading);
const P=(u,v,z)=>{const U=u*ca-v*sa,V=u*sa+v*ca;return[U*.84-V*.64,U*.29+V*.38-z]};
function beam(a,b,width,height,color='#705333'){
const [u,v,z]=a,[U,V,Z]=b,du=U-u,dv=V-v,l=Math.hypot(du,dv)||1,nu=-dv/l*width/2,nv=du/l*width/2;
const coords=[[u+nu,v+nv,z],[U+nu,V+nv,Z],[U-nu,V-nv,Z],[u-nu,v-nv,z]],q=coords.map(c=>P(...c)),low=coords.map(([x,y,z])=>P(x,y,z-height));
// Faces latérales visibles par leur orientation projetée, puis dessus.
for(let i=0;i<4;i++){let j=(i+1)%4;if(q[j][0]<q[i][0])poly([q[i],q[j],low[j],low[i]],i%2?'#4a3827':'#382b20')}
poly(q,color);line([q[0],q[1]],'#b29661');}
function bolt(u,V,Z,alpha=1){g.save();g.globalAlpha=alpha;line([P(u-24,V,Z),P(u+23,V,Z)],'#d5bc88',2);poly([P(u+29,V,Z),P(u+20,V-3,Z),P(u+20,V+3,Z)],'#c6cfca','#59655e');line([P(u-20,V-3,Z),P(u-16,V+3,Z)],'#6a8e9e',2);g.restore()}
const basePhase=phase??(time/D.cycle)%1;
const chooseState=(offset)=>{if(active<1)return state(0);if(mode==='base')return state(.73);if(mode==='reload')return state(.03+(((basePhase+offset)%1)*.70));if(mode==='fire')return state(.68+((basePhase+offset)%1)*.32);return state((basePhase+offset)%1)};

const k=D.kind,tall=k===3,wide=k===2,R=wide?58:k===4?49:45,H=tall?101:78;
// Ombre, embase à gradins et blocs lisibles.
g.save();g.scale(1,.4);circ(0,8,R*1.3,'#080e0dbb');g.restore();
for(let tier=0;tier<3;tier++){let r=R-tier*7,z=5+tier*9;const top=[],bot=[];for(let j=0;j<8;j++){let a=(j+.5)*Math.PI/4;top.push(P(Math.cos(a)*r,Math.sin(a)*r,z));bot.push(P(Math.cos(a)*r,Math.sin(a)*r,z-9))}for(let j=0;j<8;j++){let n=(j+1)%8;if((top[j][1]+top[n][1])/2>-z)poly([top[j],top[n],bot[n],bot[j]],j%2?'#41443c':'#53564a','#282d28')}poly(top,['#64695a','#737464','#7c7a67'][tier]);for(let j=0;j<8;j++){let a=(j+.5)*Math.PI/4;line([P(Math.cos(a)*(r-7),Math.sin(a)*(r-7),z+.1),top[j]],'#454a40')}}
// Trappe dans le dessus du socle : panneaux coulissants, puits sombre et rails d’élévation.
if(D.bottomFeed){const S=chooseState(0),open=ease((S.p-.015)/.035)*(1-ease((S.p-.38)/.08)),top=24;
poly([P(-38,-9,top),P(23,-9,top),P(23,9,top),P(-38,9,top)],'#090f11','#b79957',1.4);
for(let sign of [-1,1]){const v=sign*(5+open*11);beam([-38,v,top+1],[23,v,top+1],8,3,'#596259')}
for(let u of [-29,18]){beam([u,-8,top],[u,-8,H-1],3,2,'#58625b');line([P(u,-8,top+2),P(u,-8,H-2)],'#b89b5d',1)}
if(!S.shot&&S.feed>0&&S.p<.40){const lift=S.feed*(1-ease((S.p-.27)/.10)),z=lerp(24,H+7,lift);beam([-26,0,z-3],[12,0,z-3],9,3,'#626c62');if(S.feed<.995)bolt(-8,0,z);}
}
for(const v of [-24,24])for(const u of [-20,20]){beam([u,v,29],[u*.55,v*.55,H-10],9,7,'#514332');const p=P(u,v,31);circ(...p,2,'#b39b61')}
beam([-23,0,H-10],[25,0,H-10],30,9,'#555c54');
// Pivot de la tourelle, sceau qui s’éveille.
const glow=clamp(active),seal=P(-20,-27,24);circ(...seal,6,'#202b2b','#9f8751');circ(...seal,3,`rgba(255,190,76,${.12+.88*glow})`);line([[seal[0]-8,seal[1]],[seal[0]+8,seal[1]]],glow>.5?'#f4cd79':'#6b644a');
const penn=P(-16,27,H-12),sway=active*Math.sin(time*2.3)*1.2;poly([[penn[0]-8,penn[1]],[penn[0]+8,penn[1]],[penn[0]+8+sway,penn[1]+36],[penn[0]+sway,penn[1]+44],[penn[0]-8+sway,penn[1]+36]],active>.2?'#173b67':'#25333b','#b89b58');circ(penn[0]+sway*.5,penn[1]+19,5,'#244570','#d7b969');line([[penn[0]-7,penn[1]+19],[penn[0]+7,penn[1]+19]],'#d7b969');line([[penn[0],penn[1]+12],[penn[0],penn[1]+26]],'#d7b969');
const rails=k===2?[-17,17]:[0];
function weapon(v,S){
g.save();const recoil=P(-S.recoil,0,0);g.translate(...recoil);
let len=tall?104:k===4?69:83,bw=k===2?28:tall?38:49,z=H+(k===2?4:0),stringBack=S.draw*42*(1-(S.shot?ease((S.p-.76)/.035):0));
// Corps du rail et renforts métalliques.
beam([-44,v,z],[len-15,v,z],12,8);beam([-41,v-7,z+1],[len-20,v-7,z+1],2,3,'#727b76');beam([-41,v+7,z+1],[len-20,v+7,z+1],2,3,'#727b76');
for(let u=-34;u<len-15;u+=24){beam([u,v-8,z+3],[u,v+8,z+3],5,3,'#606b67');for(let side of [-1,1]){let p=P(u,v+side*6,z+4);circ(...p,1.2,'#cfaf69')}}
// Bras : flexion continue avec la mise en tension ; corde couplée au chariot.
let tension=S.draw*(1-(S.shot?ease((S.p-.76)/.035):0));for(let sign of [-1,1]){beam([21,v,z],[12-8*tension,v+sign*bw*.52,z+1],8,5,'#7b5c37');beam([12-8*tension,v+sign*bw*.52,z+1],[5-12*tension,v+sign*bw,z],6,4,'#625038');let tip=P(5-12*tension,v+sign*bw,z+1),center=P(16-stringBack,v,z+3);line([tip,center],active>.2?'#ddc898':'#807561',1.1);let socket=P(20,v+sign*7,z+3);circ(...socket,4,'#444f4a','#bf9e5d')}
// Tambour du treuil animé.
let winch=P(-32,v+11,z-2);circ(...winch,8,'#2b3432','#ad925a');for(let j=0;j<6;j++){let a=j*Math.PI/3-S.draw*Math.PI*4;line([[winch[0]+Math.cos(a)*3,winch[1]+Math.sin(a)*3],[winch[0]+Math.cos(a)*7,winch[1]+Math.sin(a)*7]],'#c7ae75')}
let carriage=P(16-stringBack,v,z+4);rect(carriage[0]-3,carriage[1]-2,6,4,'#b3b8a9');
// Magasins différents : l’alimentation n’apparaît que pour le rail concerné.
if((k===0&&!D.bottomFeed)||k===2){let mv=v-12;beam([-23,mv,z+29],[-5,mv,z+29],4,25,'#4f5a50');for(let i=0;i<4;i++)bolt(-8,mv,z+12+i*5-S.feed*4,.75);line([P(-28,mv,z+35),P(1,mv,z+35)],'#a88a50',3);if(S.feed<1&&!S.shot)bolt(-8,lerp(mv,v,S.feed),lerp(z+12,z+6,S.feed))}
if(k===1){let center=P(-8,v-19,z+11);circ(...center,16,'#363e37','#b4985d');const a=S.feed*Math.PI/3;for(let j=0;j<6;j++){let A=j*Math.PI/3+a,cx=center[0]+Math.cos(A)*10,cy=center[1]+Math.sin(A)*10;circ(cx,cy,3,'#171f20','#a9915f')}circ(...center,4,'#bb9d5e');beam([-35,v-19,z+11],[8,v-19,z+11],4,3,'#69736a');if(S.feed<1&&!S.shot)bolt(-8,lerp(v-19,v,S.feed),lerp(z+11,z+6,S.feed))}
if(k===3){beam([-29,v-20,43],[-29,v-20,z+8],5,3,'#737866');let w=P(-29,v-20,lerp(78,44,S.draw*(1-ease((S.p-.89)/.11))));rect(w[0]-7,w[1]-4,14,16,'#555c54');line([P(-29,v-20,44),P(-29,v-20,z+12),P(-12,v,z+8)],'#a99364');for(let i=0;i<3;i++)bolt(-8,v-12,z-23-i*6,.75);if(S.feed<1&&!S.shot)bolt(-8,lerp(v-12,v,S.feed),lerp(z-23,z+6,S.feed))}
if(k===4){let a=P(-13,v-23,z-29),b=P(-13,v-23,z+17);line([a,b],'#353d3b',9);line([a,b],'#bc9d5f',2);for(let j=0;j<8;j++){let u=((j/8+S.feed/8)%1);circ(lerp(a[0],b[0],u),lerp(a[1],b[1],u),2,'#a98b50')}for(let i=0;i<3;i++)bolt(-13,v-23,z-25+i*12+S.feed*10,.7);for(let sign of [-1,1]){beam([-23,v+sign*13,z+6],[39,v+sign*13,z+6],4,19,'#4a5552');for(let u=-16;u<39;u+=13){let pt=P(u,v+sign*14,z+5);circ(...pt,1.4,'#bd9d5e')}}if(S.feed<1&&!S.shot)bolt(-8,lerp(v-23,v,S.feed),lerp(z+17,z+6,S.feed))}
// Trait chargé jusqu’au lâcher, projectile unique et sans flash de poudre.
if(S.feed>=.95&&!S.shot)bolt(lerp(-8,-20,S.draw),v,z+7);if(projectile&&S.shot&&S.flight<1){let u=-20+S.flight*250;bolt(u,v,z+7,1-S.flight*.75);line([P(u-36,v,z+7),P(u-72,v,z+7)],`rgba(232,211,162,${(1-S.flight)*.5})`,1)}
g.restore();}
// Rail arrière puis avant pour conserver l’occlusion.
rails.forEach((v,i)=>weapon(v,chooseState(i*.5)));

g.restore();const p=chooseState(0).p;return D.bottomFeed?(p<.05?'Ouverture de la trappe du socle':p<.25?'Montée du pieu depuis le socle':p<.40?'Retour de l’élévateur · mise en tension':p<.46?'Fermeture de la trappe · mise en tension':label(p)):label(p);
}
function sanctuary(g,w,h,D,t,reactivation=true,options={}){
g.clearRect(0,0,w,h);let sx=w/1000,sy=h/330;g.save();g.scale(sx,sy);g.fillStyle='#111e1e';g.fillRect(0,0,1000,330);
const poly=(ps,c)=>{g.fillStyle=c;g.beginPath();ps.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();g.fill();g.strokeStyle='#27332e';g.stroke()};
poly([[25,245],[500,100],[975,245],[500,365]],'#303b32');for(let i=0;i<9;i++){g.strokeStyle='#445044';g.beginPath();g.moveTo(65+i*100,258);g.lineTo(500+i*38,123+i*12);g.stroke()}
// Sanctum central, murs en pierre et porte sacrée.
poly([[402,185],[500,218],[500,85],[402,54]],'#4e564b');poly([[500,218],[598,185],[598,54],[500,85]],'#39473f');poly([[402,54],[500,22],[598,54],[500,85]],'#77816b');
for(let j=0;j<6;j++){g.strokeStyle='#29372f';g.beginPath();g.moveTo(403,76+j*21);g.lineTo(500,107+j*21);g.lineTo(597,76+j*21);g.stroke()}
poly([[454,199],[482,209],[482,135],[468,119],[454,127]],'#132423');g.strokeStyle='#c5a566';g.lineWidth=2;g.strokeRect(462,143,10,33);g.lineWidth=1;
let at=reactivation?t%15:15;let a=clamp((at-2)/1.3),b=clamp((at-5.6)/1.3);
draw(g,D,{x:292,y:249,scale:1.18,time:Math.max(0,t-3.3),active:a,mode:'cycle',flip:!options.orientation,orientation:options.orientation});draw(g,D,{x:708,y:249,scale:1.18,time:Math.max(0,t-6.9)+D.cycle*.5,active:b,mode:'cycle',orientation:options.orientation});
// Le prêtre se déplace de l’entrée vers chaque sceau ; aucune équipe de tir.
let px=at<2?lerp(473,325,ease(at/2)):at<3.3?325:at<5.6?lerp(325,674,ease((at-3.3)/2.3)):at<6.9?674:lerp(674,480,ease((at-6.9)/2));let py=at<2?lerp(225,252,ease(at/2)):at<6.9?252:lerp(252,228,ease((at-6.9)/2));
poly([[px,py-29],[px-8,py-15],[px-10,py],[px+9,py],[px+6,py-16]],'#b8bca6');poly([[px,py-29],[px-5,py-20],[px+5,py-20]],'#333d36');g.fillStyle='#dac397';g.fillRect(px-2,py-21,4,5);g.strokeStyle='#b69b5d';g.beginPath();g.moveTo(px+9,py-22);g.lineTo(px+9,py+1);g.stroke();
if((at>=2&&at<3.3)||(at>=5.6&&at<6.9)){g.strokeStyle='#f1c778';g.beginPath();g.arc(px,py-5,18+Math.sin(t*6)*3,0,Math.PI*2);g.stroke()}
g.font='12px system-ui';g.textAlign='center';g.fillStyle='#b4c1ac';g.fillText(a===1?'TOURELLE I · ACTIVE':'TOURELLE I · EN SOMMEIL',270,309);g.fillText(b===1?'TOURELLE II · ACTIVE':'TOURELLE II · EN SOMMEIL',730,309);g.fillStyle='#dfc487';g.fillText(at<2?'Le prêtre rejoint le premier sceau':at<3.3?'Réactivation de la tourelle I':at<5.6?'Le prêtre rejoint le second sceau':at<6.9?'Réactivation de la tourelle II':'Défense automatique · les deux balistes tirent en décalé',500,27);g.restore();
}
return{DESIGNS,GUARD,DIRECTIONS,draw,state,label,sanctuary};})();
if(typeof module!=='undefined')module.exports=BallistaKit;
