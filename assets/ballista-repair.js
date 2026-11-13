/* Proposition : restauration gratuite par l’ingénieur, puis essai automatique NE. */
'use strict';
const BallistaRepair=(()=>{
const DURATION=8,END=12,clamp=x=>Math.max(0,Math.min(1,x)),smooth=x=>{x=clamp(x);return x*x*(3-2*x)},mix=(a,b,k)=>a+(b-a)*k;
const STAGES=[{at:0,end:1,name:'Approche de l’ingénieur',desc:'L’ingénieur rejoint la tourelle et prépare ses outils.'},{at:1,end:2.6,name:'Déblaiement',desc:'Les gravats et le lierre sont retirés ; la trappe est dégagée.'},{at:2.6,end:5.1,name:'Relevage de la charpente',desc:'Le treuil de chantier relève le rail et redresse ses montants.'},{at:5.1,end:7,name:'Remontage du mécanisme',desc:'L’ingénieur remonte les bras, retend la corde et contrôle l’élévateur.'},{at:7,end:8,name:'Remise en service',desc:'Les ferrures sont fixées, la bannière restaurée et le sceau rallumé.'},{at:8,end:12,name:'Essai automatique vers le nord-est',desc:'L’ingénieur se retire ; la tourelle charge un pieu par le bas puis tire.'}];
function stageAt(t){return STAGES.find(s=>t<s.end)||STAGES[STAGES.length-1]}
function layer(g,a,fn){g.save();const proxy=new Proxy(g,{get:(o,p)=>typeof o[p]==='function'?o[p].bind(o):o[p],set:(o,p,v)=>{o[p]=p==='globalAlpha'?v*a:v;return true}});proxy.globalAlpha=1;fn(proxy);g.restore()}
function draw(g,t,{x=210,y=220,scale=1.35,orientation='NE',background=true}={}){
t=Math.max(0,t);if(background){g.fillStyle='#142223';g.fillRect(0,0,420,290)}
const progress=clamp((t-1)/7),finish=smooth((progress-.90)/.10),def=BallistaRuins.DESIGNS.find(d=>d.id==='04-enfouie');
if(t<8){layer(g,1-finish,ctx=>BallistaRuins.draw(ctx,def,{x,y,scale,orientation,repair:progress}));if(finish>0)layer(g,finish,ctx=>BallistaKit.draw(ctx,BallistaKit.GUARD,{x,y,scale,orientation,phase:0,time:0,projectile:false}));}
else BallistaKit.draw(g,BallistaKit.GUARD,{x,y,scale,orientation,time:t-8,mode:'cycle'});
// Ingénieur en tabard bleu et cuir, générateur de laiton et crochet dorsal.
const arrive=smooth(t),leave=smooth((t-8)/1.25),ex=x+mix(-102,-65,arrive)*scale-leave*50*scale,ey=y+21*scale,work=t>=1&&t<8,hit=work?Math.max(0,Math.sin((t-1)*Math.PI*4)):0;
g.save();g.translate(ex,ey);g.scale(scale,scale);
const poly=(p,c)=>{g.beginPath();p.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();g.fillStyle=c;g.fill();g.strokeStyle='#172020';g.lineWidth=1;g.stroke()},line=(p,c,w=1)=>{g.beginPath();p.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.strokeStyle=c;g.lineWidth=w;g.stroke()};
if(leave<1){const step=t<1||t>=8?Math.sin(t*13)*2:0;g.fillStyle='#0a1110aa';g.beginPath();g.arc(0,1,11,0,Math.PI*2);g.fill();poly([[-8,-29],[7,-29],[9,-10],[-9,-10]],'#254966');poly([[-7,-25],[3,-24],[7,-9],[-7,-9]],'#665039');line([[-6,-9],[-6-step,0]],'#777e6b',5);line([[5,-9],[6+step,0]],'#777e6b',5);poly([[-11,-31],[-4,-34],[-4,-18],[-12,-17]],'#9b7e43');line([[-9,-34],[-9,-44],[4,-44],[7,-36]],'#b69b61',2);poly([[-6,-38],[3,-40],[7,-35],[5,-29],[-4,-29]],'#69776a');g.fillStyle='#b39b75';g.fillRect(1,-34,5,4);line([[-5,-26],[-10,-15]],'#7d8572',4);const hand=[13,-23-hit*12];line([[4,-25],hand],'#7d8572',4);line([hand,[hand[0]+5,hand[1]-9]],'#a48e60',2);poly([[hand[0],hand[1]-10],[hand[0]+10,hand[1]-10],[hand[0]+10,hand[1]-5],[hand[0],hand[1]-5]],'#a3aaa0');}
g.restore();
// Câble de levage visible durant le redressement, ancré au crochet de chantier.
if(t>=2.6&&t<5.1){g.strokeStyle='#b49a60';g.lineWidth=1;g.beginPath();g.moveTo(ex-9*scale,ey-44*scale);g.lineTo(x-5*scale,y-(58+smooth((t-2.6)/2.5)*20)*scale);g.stroke();}
if(work&&hit>.88){g.strokeStyle=t>7?'#f3c567':'#b6a370';g.lineWidth=1;for(let i=0;i<3;i++){g.beginPath();g.moveTo(x-37*scale,y-39*scale);g.lineTo(x-(40+i*3)*scale,y-(43+i*2)*scale);g.stroke();}}
// Petits nuages bas de déblaiement ; jamais d’explosion ni de flash masquant la restauration.
if(t>=1&&t<2.6){const q=(t-1)/1.6;for(let i=0;i<5;i++){g.fillStyle=`rgba(133,130,104,${.22*(1-q)})`;g.beginPath();g.arc(x+(-32+i*15)*scale,y+(i%2*4)*scale,(3+q*9)*scale,0,Math.PI*2);g.fill();}}
return{progress,stage:stageAt(t),free:true,actor:'engineer',functional:t>=8};
}
return{DURATION,END,STAGES,stageAt,draw};})();
if(typeof module!=='undefined')module.exports=BallistaRepair;
