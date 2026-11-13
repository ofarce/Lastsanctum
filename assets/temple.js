/* TempleKit — independent concept renderer. Coordinates in native canvas pixels. */
(function(global){
'use strict';
const DESIGNS=[
{name:'01 · Le Sceau astral',desc:'Un grand anneau de Sigil suspendu entre quatre obélisques. La silhouette la plus proche de la référence.',kind:0},
{name:'02 · Le Sanctuaire des flèches',desc:'Une chapelle verticale, une nef ouverte et deux hautes tours de pierre blanche.',kind:1},
{name:'03 · La Source des esprits',desc:'Un sanctuaire circulaire ouvert : les bassins convergent vers un cristal vivant.',kind:2},
{name:'04 · Le Cloître de Sigil',desc:'Des arcades protectrices autour d’un autel central. Une silhouette large et ordonnée.',kind:3},
{name:'05 · L’Astre ascendant',desc:'Un temple en terrasses dominé par une flèche cristalline et trois anneaux orbitaux.',kind:4}];
const clamp=v=>Math.max(0,Math.min(1,v)),ease=v=>{v=clamp(v);return v*v*(3-2*v)};
function poly(g,pts,fill,stroke){g.beginPath();pts.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();if(fill){g.fillStyle=fill;g.fill()}if(stroke){g.strokeStyle=stroke;g.stroke()}}
function line(g,pts,color,w=1){g.beginPath();pts.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.strokeStyle=color;g.lineWidth=w;g.stroke();g.lineWidth=1}
function ellipse(g,x,y,rx,ry,color){g.fillStyle=color;g.beginPath();g.ellipse(x,y,rx,ry,0,0,Math.PI*2);g.fill()}
function crystal(g,x,y,s,t){g.save();g.shadowColor='#61eaff';g.shadowBlur=9+3*Math.sin(t*2);poly(g,[[x,y-s],[x+s*.4,y],[x,y+s*.6],[x-s*.4,y]],'#77deef','#e1fcff');poly(g,[[x,y-s],[x,y+s*.6],[x-s*.4,y]],'#3595b4');g.restore()}
function seal(g,x,y,r,t,tilt=1){g.save();g.translate(x,y);g.scale(1,tilt);g.shadowColor='#6ddfff';g.shadowBlur=5;g.strokeStyle='#c7ac62';for(const a of [r,r-3]){g.beginPath();g.arc(0,0,a,0,Math.PI*2);g.stroke()}const pts=Array.from({length:7},(_,i)=>{let a=-Math.PI/2+i*6*Math.PI/7+t*.08;return[Math.cos(a)*(r-5),Math.sin(a)*(r-5)]});line(g,[...pts,pts[0]],'#f0d88f');g.restore()}
// Ground footprint: a fixed circle with a continuously rotating seven-point star.
function footprint(g,time,{color='#e5cf8e'}={}){g.save();g.translate(160,186);g.scale(1,.32);g.strokeStyle=color;g.shadowColor=color;g.shadowBlur=4;g.lineWidth=1.2;for(const r of[96,92]){g.beginPath();g.arc(0,0,r,0,Math.PI*2);g.stroke()}const pts=Array.from({length:7},(_,i)=>{const a=-Math.PI/2+i*6*Math.PI/7+time*.35;return[Math.cos(a)*86,Math.sin(a)*86]});line(g,[...pts,pts[0]],color,1.2);g.restore()}
function pillar(g,x,y,h,w=9){poly(g,[[x-w,y],[x,y+4],[x+w,y],[x+w,y-h],[x,y-h-4],[x-w,y-h]],'#d5d3c2','#666e6e');poly(g,[[x,y+4],[x+w,y],[x+w,y-h],[x,y-h-4]],'#8e9997');poly(g,[[x-w,y-h],[x,y-h-17],[x+w,y-h],[x,y-h+4]],'#ede6cf','#c0a261');line(g,[[x,y-h+7],[x,y-7]],'#e7c574',2);g.fillStyle='#213646';g.fillRect(x-4,y-h+10,3,Math.max(2,h-22));}
function basin(g,x,y,t){ellipse(g,x,y+3,17,7,'#626e6e');ellipse(g,x,y,17,7,'#c1b89c');ellipse(g,x,y-1,13,4,'#3d9eaf');g.save();g.shadowColor='#61efff';g.shadowBlur=7;for(let i=0;i<3;i++){let pts=[];for(let j=0;j<18;j++){let yy=j*1.3;pts.push([x+Math.sin(yy*.17+t*2+i*2)*4,y-yy])}line(g,pts,'#8deeff',.8)}g.restore()}
function priest(g,x,y,t,mode='pray',scale=1){g.save();g.translate(x,y);g.scale(scale,scale);ellipse(g,0,1,8,2,'#07141699');const walk=mode==='walk',p=walk?0:(Math.sin(t*1.6)*.5+.5),bob=walk?Math.abs(Math.sin(t*8)):.7*Math.sin(t*1.6);g.translate(0,-bob);if(!walk)g.rotate(-.025-.035*p);if(walk){line(g,[[-3,-6],[-3+Math.sin(t*8)*3,0]],'#b8b6ad',3);line(g,[[3,-6],[3-Math.sin(t*8)*3,0]],'#6f7d80',3)}poly(g,[[-4,-19],[4,-19],[7,-2],[-7,-2]],'#e3e0cd','#86918d');poly(g,[[0,-19],[4,-18],[7,-2],[1,-3]],'#8a989b');poly(g,[[-3,-18],[2,-18],[3,-4],[-1,-5]],'#172d40');line(g,[[0,-16],[0,-7]],'#d6b96f');poly(g,[[-5,-20],[-4,-26],[0,-29],[5,-24],[5,-19]],'#dddccc','#a7aaa1');poly(g,[[-3,-23],[2,-25],[3,-20],[-2,-19]],'#1d2930');const arm=walk?Math.sin(t*8)*2:p*3;line(g,[[-4,-17],[-8,-12-arm],[-2,-13-arm]],'#dedac9',3);line(g,[[4,-17],[7,-12-arm],[0,-13-arm]],'#c6c8bc',3);if(!walk){ellipse(g,-1,-14-arm,1.7,1.5,'#eacb9e');g.save();g.globalAlpha=.2+.4*p;seal(g,0,-36,7,t,.6);g.restore()}g.restore()}
function building(g,D,t){const k=D.kind;for(let i=0;i<4;i++){let y=181-i*5,w=92-i*9;poly(g,[[160-w,y],[160,y+25],[160+w,y],[160,y-26]],i%2?'#a0aaa3':'#d2d0bd','#6d7c77')}
for(let i=0;i<8;i++){let y=191-i*3;poly(g,[[141,y],[160,y+6],[179,y],[160,y-7]],i%2?'#bec2b3':'#7e8f8d')}
if(k===0){pillar(g,103,164,62);pillar(g,216,164,73);pillar(g,128,143,87,7);pillar(g,191,143,96,7);seal(g,161,90,40,t);crystal(g,161,102,23,t)}
if(k===1){poly(g,[[124,160],[160,175],[195,158],[195,99],[160,59],[124,99]],'#c6cebf','#7f8d88');poly(g,[[134,156],[160,166],[182,155],[182,108],[160,84],[134,108]],'#1a3440','#d1b574');pillar(g,117,170,101,10);pillar(g,205,166,115,10);seal(g,160,107,22,t);crystal(g,160,139,18,t)}
if(k===2){ellipse(g,160,162,62,22,'#c6c8b7');ellipse(g,160,160,51,16,'#4b9daa');seal(g,160,158,44,t,.3);for(const[x,y,h]of[[111,151,51],[207,151,51],[160,132,67]])pillar(g,x,y,h,7);crystal(g,160,134+Math.sin(t)*2,32,t);basin(g,117,176,t);basin(g,205,176,t+1)}
if(k===3){for(const x of[112,144,176,208])pillar(g,x,141,59,7);poly(g,[[101,82],[199,82],[220,95],[122,96]],'#e5ddc2','#ae9969');for(const x of[103,216])pillar(g,x,175,48,8);poly(g,[[94,122],[207,122],[227,134],[114,135]],'#ded9c3','#af9b67');seal(g,161,112,22,t);crystal(g,161,153,17,t)}
if(k===4){pillar(g,160,156,96,14);for(let i=0;i<3;i++)seal(g,160,76+i*22,29-i*3,t*(i%2?-1:1),.38);crystal(g,160,52+Math.sin(t)*2,27,t);pillar(g,114,173,48,8);pillar(g,209,173,48,8)}
if(k!==2){basin(g,106,183,t);basin(g,217,183,t+1)}for(const x of[85,235]){line(g,[[x,170],[x,134]],'#ba9c58',2);poly(g,[[x+2,137],[x+14,141],[x+14,158],[x+2,154]],'#192e41','#bfa360');line(g,[[x+8,142],[x+8,151]],'#e8cf87')}
}
// Feedback is drawn on a high-resolution overlay, independently of pixel sprites.
function spiritIcon(g,x,y,size=14){g.save();g.translate(x,y);g.scale(size/24,size/24);poly(g,[[0,-12],[2,-4],[10,-1],[2,1],[0,10],[-2,1],[-10,-1],[-2,-4]],'#baf5ff');line(g,[[-8,-9],[-3,-4]],'#baf5ff');line(g,[[3,3],[8,8]],'#baf5ff');g.restore()}
function feedback(g,{progress=0,age=Infinity,active=true}={}){
 if(!active)return;
 g.save();g.translate(161,90);g.lineWidth=2.5;g.strokeStyle='#142d38';g.beginPath();g.arc(0,0,44,0,Math.PI*2);g.stroke();
 // Fixed gold rim surrounds an astral channel filling clockwise from the top.
 g.lineWidth=.7;g.strokeStyle='#bfa66c';for(const r of[41.8,46.2]){g.beginPath();g.arc(0,0,r,0,Math.PI*2);g.stroke()}
 const p=clamp(progress);if(p>0){g.strokeStyle='#91efff';g.lineWidth=2.5;g.lineCap='round';g.shadowColor='#52d8f6';g.shadowBlur=4;g.beginPath();g.arc(0,0,44,-Math.PI/2,-Math.PI/2+p*Math.PI*2);g.stroke();ellipse(g,Math.sin(p*Math.PI*2)*44,-Math.cos(p*Math.PI*2)*44,1.7,1.7,'#f0ffff')}
 if(age>=0&&age<.4){g.globalAlpha=1-ease(age/.4);g.strokeStyle='#e9ffff';g.lineWidth=3;g.beginPath();g.arc(0,0,44,0,Math.PI*2);g.stroke()}g.restore();
 if(age<0||age>=1.8)return;
 g.save();g.globalAlpha=age<.3?ease(age/.3):age<1.3?1:1-ease((age-1.3)/.5);g.translate(160,35-16*ease(age/1.8));g.shadowColor='#10282e';g.shadowBlur=3;g.font='bold 17px Georgia';g.textAlign='left';g.textBaseline='middle';const width=g.measureText('+10').width,total=width+21;spiritIcon(g,-total/2+7,0,15);g.fillStyle='#d4faff';g.fillText('+10',-total/2+21,0);g.restore();
}
function render(g,D,time,{still=false,showFeedback=true}={}){let t=still?time:time%20;g.clearRect(0,0,320,240);ellipse(g,160,187,115,36,'#07110f88');seal(g,160,186,100,time,.32);if(t<2){g.save();g.globalAlpha=.25+.75*ease(t/2);g.beginPath();g.rect(0,210-180*ease(t/2),320,240);g.clip();building(g,D,time);g.restore();line(g,[[96,218],[96+128*clamp(t/2),218]],'#d6bb77',2)}else building(g,D,time);
if(t>=2){const u=clamp((t-2)/5);priest(g,160+6*u,268-58*u,time,t<7?'walk':'pray')}
// Foreground jungle conceals the visitor until he steps out of its southern edge.
for(let i=0;i<19;i++){const x=i*18-2,h=9+(i*13%12);poly(g,[[x-12,240],[x-7,240-h],[x-2,238],[x+2,240-h-5],[x+7,237],[x+14,240]],i%2?'#1d3c30':'#254d3a');line(g,[[x+2,240],[x+2,240-h+1]],'#48674a')}
if(t>=7){g.save();g.globalAlpha=.3+.2*Math.sin(time*2);for(let i=0;i<9;i++){let f=(time*.3+i/9)%1;ellipse(g,161+Math.sin(i*4+time)*13,163-f*48,1,1,'#91f5ff')}g.restore()}
const elapsed=Math.max(0,t-7),gains=Math.floor(elapsed/4),age=gains?elapsed-gains*4:Infinity,progress=(elapsed%4)/4;
if(showFeedback)feedback(g,{progress,age,active:t>=7});
return {phase:t<2?'Construction':t<7?'Le prêtre sort de la jungle et rejoint le temple':'Prière · canalisation de l’Esprit',spirit:gains*10,progress,popupAge:age,producing:t>=7};}
global.TempleKit={DESIGNS,render,priest,building,feedback,spiritIcon,footprint};
})(window);
