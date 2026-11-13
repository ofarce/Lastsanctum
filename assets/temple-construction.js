/* Five material assembly studies, all using the approved Astral Seal temple. */
(function(global){
'use strict';
const clamp=v=>Math.max(0,Math.min(1,v)),ease=v=>{v=clamp(v);return v*v*(3-2*v)};
const DESIGNS=[
{name:'01 · Les assises de la Parole',desc:'Les pierres s’arrachent au sol et s’empilent de bas en haut. Chaque assise répond à une syllabe de l’Ingénieur.',kind:0},
{name:'02 · La spirale d’Énonciation',desc:'Un courant hélicoïdal extrait les matériaux autour du chantier, les élève puis les distribue à leur place.',kind:1},
{name:'03 · Les mains invisibles',desc:'Deux flux latéraux soulèvent des blocs de pierre et les assemblent symétriquement, comme guidés par des mains.',kind:2},
{name:'04 · La litanie des piliers',desc:'Chaque phrase érige une partie du temple : socle, obélisques, autel puis sceau. Les matériaux suivent des arcs tendus.',kind:3},
{name:'05 · Le plan suspendu',desc:'Tous les fragments émergent, flottent en une vue éclatée puis convergent vers le temple à la dernière Énonciation.',kind:4}];
const source=document.createElement('canvas');source.width=320;source.height=240;
TempleKit.building(source.getContext('2d'),TempleKit.DESIGNS[0],0);
const pixels=source.getContext('2d').getImageData(0,0,320,240).data,parts=[];
for(let y=24;y<208;y+=8)for(let x=64;x<256;x+=8){let occupied=false;for(let j=y;j<y+8&&!occupied;j++)for(let i=x;i<x+8;i++)if(pixels[(j*320+i)*4+3]){occupied=true;break}if(occupied)parts.push({x,y,id:parts.length})}
function stroke(g,pts,c,w=1){g.beginPath();pts.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.strokeStyle=c;g.lineWidth=w;g.stroke();g.lineWidth=1}
function oval(g,x,y,rx,ry,color){g.beginPath();g.ellipse(x,y,rx,ry,0,0,Math.PI*2);g.fillStyle=color;g.fill()}
function engineer(g,t,active){g.save();g.translate(47,210);g.drawImage(UnitKit.figure(UnitKit.ENGINEERS[0].s,t,.5),-17,-39);if(active){const lift=Math.sin(t*3)*2;stroke(g,[[5,-20],[13,-24-lift],[18,-24-lift]],'#d8cbaa',3);oval(g,18,-24-lift,2,2,'#f4d1a3');g.shadowColor='#ffd983';g.shadowBlur=8;for(let i=0;i<4;i++){let r=8+(t*14+i*9)%36;g.globalAlpha=(1-r/45)*.7;g.beginPath();g.ellipse(63,-35,r,r*.5,0,-.8,1);g.strokeStyle='#f3d497';g.stroke()}g.globalAlpha=1;g.fillStyle='#f0d8a4';g.font='8px Georgia';g.fillText('✦',20,-35-lift)}g.restore()}
function render(g,D,time,{showEngineer=true,voiceOrigin=[65,186],showFeedback=true,ritualTime=time,showFootprint=true}={}){let t=((time%28)+26)%28;
if(t>=8){let state=TempleKit.render(g,TempleKit.DESIGNS[0],t-6,{still:true,showFeedback});if(showEngineer)engineer(g,t,false);return state}
g.clearRect(0,0,320,240);oval(g,160,187,115,36,'#07110f88');if(showFootprint)TempleKit.footprint(g,ritualTime);
// Soil fissures and glowing site geometry precede the first rising material.
g.save();g.globalAlpha=Math.sin(Math.PI*clamp(t/8))*.7;g.strokeStyle='#d3b275';g.beginPath();g.ellipse(160,185,96,30,0,0,Math.PI*2);g.stroke();for(let i=0;i<12;i++){let a=i*Math.PI/6,x=160+Math.cos(a)*90,y=185+Math.sin(a)*27;stroke(g,[[x-7,y+2],[x,y],[x+3,y-4],[x+9,y-5]],'#e3c277')}g.restore();
const moving=[];
for(const p of parts){let nx=(p.x-160)/96,height=(200-p.y)/168,seed=((p.id*73)%101)/101,start,duration=2.1;
if(D.kind===0)start=.6+height*4.2;
if(D.kind===1){start=.5+((Math.atan2(p.y-130,p.x-160)+Math.PI)/(Math.PI*2))*3.6;duration=3}
if(D.kind===2){start=.6+height*3.6+Math.abs(nx)*.3;duration=2.5}
if(D.kind===3){let group=p.y>155?0:Math.abs(p.x-160)>24?1:p.y>110?2:3;start=.5+group*1.25+seed*.25;duration=2}
if(D.kind===4){start=.5+seed*.7;duration=5.6}
let u=clamp((t-start)/duration);if(t<start)continue;
let e=ease(u),sx=160+nx*1.05*90+Math.sin(p.id*2.1)*14,sy=187+Math.sin(p.id*1.7)*23,x=sx+(p.x-sx)*e,y=sy+(p.y-sy)*e;
if(D.kind===0){x+=Math.sin(u*Math.PI)*nx*12;y-=Math.sin(u*Math.PI)*12}
if(D.kind===1){let a=(1-u)*Math.PI*2; x=p.x+(1-e)*Math.cos(a+p.id*.05)*75;y-=Math.sin(u*Math.PI)*45}
if(D.kind===2){x+=Math.sin(u*Math.PI)*Math.sign(nx||1)*38;y-=Math.sin(u*Math.PI)*38}
if(D.kind===3){x+=Math.sin(u*Math.PI)*nx*25;y-=Math.sin(u*Math.PI)*55}
if(D.kind===4){let lift=ease(u/.35),lock=ease((u-.6)/.4);x=sx+(p.x+nx*20-sx)*lift+( -nx*20)*lock;y=sy+(p.y-18-sy)*lift+18*lock+Math.sin(t*2+p.id)*2*Math.sin(u*Math.PI)}
if(u<1){oval(g,sx+4,sy+6,5*(1-e),1.5,'#0a1114');if(u<.3){g.save();g.globalAlpha=(1-u/.3)*.6;oval(g,sx,sy+3,6+u*15,2+u*5,'#a19170');g.restore()}moving.push([x+4,y+4,u,p.id]);}
g.save();g.translate(x+4,y+4);g.rotate(Math.sin(u*Math.PI)*Math.sin(p.id)*.3);g.beginPath();g.rect(-4,-4+8*(1-ease(u/.15)),8,8);g.clip();g.drawImage(source,p.x,p.y,8,8,-4,-4,8,8);g.restore();
}
// The voice is visibly linked to the pieces under manipulation.
g.save();g.shadowColor='#f7cf7b';g.shadowBlur=5;for(const[x,y,u,id]of moving){if(id%17!==0)continue;g.globalAlpha=.22*Math.sin(u*Math.PI);g.beginPath();g.moveTo(...voiceOrigin);g.quadraticCurveTo(100,y-35,x,y);g.strokeStyle='#f6d38b';g.stroke();g.globalAlpha=.7*Math.sin(u*Math.PI);oval(g,x,y,1.2,1.2,'#fff0b7')}g.restore();if(showEngineer)engineer(g,t,true);
if(t>0){g.fillStyle='#c6b98e';g.fillRect(96,225,128,2);g.fillStyle='#f5df9c';g.fillRect(96,225,128*clamp(t/8),2)}
return{phase:t<.5?'Énonciation · éveil du sol':t<6.8?'Extraction · assemblage des matériaux':'Scellement · fin de l’Énonciation',spirit:0};
}
global.TempleConstructionKit={DESIGNS,render,duration:28,parts:parts.length};
})(window);
