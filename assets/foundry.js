/* Aether foundry concept renderer: native art + display-resolution feedback. */
(function(global){
'use strict';
const DESIGNS=[
{name:'01 · Le Puits astral',desc:'Un puits monumental, un astrolabe de laiton et une grue à minerai : la silhouette la plus proche de la référence.',kind:0},
{name:'02 · La Halle des creusets',desc:'Une fonderie basse à trois fours, soufflets alternés et convoyeur de lingots.',kind:1},
{name:'03 · La Tour d’Aether',desc:'Un condensateur vertical alimente le creuset ; ses anneaux canalisent une énergie bleu-blanc.',kind:2},
{name:'04 · Les Forges jumelles',desc:'Deux cheminées encadrent une presse centrale et un marteau mécanique à contrepoids.',kind:3},
{name:'05 · Le Grand Balancier',desc:'Un portique ouvert domine le puits ; un balancier entraîne la pompe et le levage du minerai.',kind:4}];
const clamp=v=>Math.max(0,Math.min(1,v)),ease=v=>{v=clamp(v);return v*v*(3-2*v)};
function poly(g,p,c,s){g.beginPath();p.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();if(c){g.fillStyle=c;g.fill()}if(s){g.strokeStyle=s;g.stroke()}}
function line(g,p,c,w=1){g.beginPath();p.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.strokeStyle=c;g.lineWidth=w;g.stroke();g.lineWidth=1}
function oval(g,x,y,rx,ry,c){g.fillStyle=c;g.beginPath();g.ellipse(x,y,rx,ry,0,0,Math.PI*2);g.fill()}
function beam(g,x,y,x2,y2,w=5){line(g,[[x,y],[x2,y2]],'#3c2a21',w+2);line(g,[[x,y],[x2,y2]],'#997349',w);line(g,[[x-1,y],[x2-1,y2]],'#c39b61',1)}
function gear(g,x,y,r,t,wood=false){g.save();g.translate(x,y);g.rotate(t);poly(g,Array.from({length:48},(_,i)=>{let a=i*Math.PI/24,R=r*(i%4<2?1:.85);return[Math.cos(a)*R,Math.sin(a)*R]}),wood?'#8c7048':'#929a92','#d0c49c');oval(g,0,0,r*.6,r*.6,wood?'#57462e':'#505f5c');for(let i=0;i<6;i++){let a=i*Math.PI/3;line(g,[[Math.cos(a)*r*.17,Math.sin(a)*r*.17],[Math.cos(a)*r*.64,Math.sin(a)*r*.64]],'#c0a574',2)}oval(g,0,0,3,3,'#cfb57b');g.restore()}
function star(g,x,y,r){for(let i=0;i<4;i++){let a=i*Math.PI/4;line(g,[[x-Math.cos(a)*r,y-Math.sin(a)*r],[x+Math.cos(a)*r,y+Math.sin(a)*r]],'#e9cf86',i===0?2:1)}}
function ingot(g,x,y){poly(g,[[x-7,y],[x+3,y-5],[x+10,y-3],[x,y+3]],'#c7d7df','#f0f5ee');poly(g,[[x-7,y],[x,y+3],[x,y+7],[x-7,y+3]],'#657987');poly(g,[[x,y+3],[x+10,y-3],[x+10,y+1],[x,y+7]],'#8d9faa')}
// Masonry is drawn in two lit planes, with individual courses and metal fittings.
function block(g,x,y,w,d,h){
poly(g,[[x,y-h],[x+w,y-h+d],[x+w,y+d],[x,y]],'#525966','#a19374');
poly(g,[[x+w,y-h+d],[x+w+d,y-h],[x+w+d,y],[x+w,y+d]],'#252e3b','#766e5c');
poly(g,[[x,y-h],[x+d,y-h-d],[x+w+d,y-h],[x+w,y-h+d]],'#747c84','#b5a585');
for(let j=7;j<h;j+=7){line(g,[[x,y-h+j],[x+w,y-h+d+j]],'#252d36',.5);for(let i=0;i<w;i+=10){let xx=x+i+(j%2)*4;if(xx<x+w)line(g,[[xx,y-h+j],[xx,y-h+j+6]],'#343c47',.5)}}
for(let xx of[x+2,x+w-2])line(g,[[xx,y-h+3],[xx,y-1]],'#ba9b58',1.2);
}
function arch(g,x,y,w,h,t){g.save();g.translate(x,y);g.beginPath();g.moveTo(-w/2,0);g.lineTo(-w/2,-h+w/2);g.arc(0,-h+w/2,w/2,Math.PI,0);g.lineTo(w/2,0);g.closePath();g.fillStyle='#0c131e';g.fill();g.strokeStyle='#c2a268';g.lineWidth=4;g.stroke();g.lineWidth=1;
const glow=g.createRadialGradient(0,-4,1,0,-8,h);glow.addColorStop(0,'#fff0ad');glow.addColorStop(.25,'#e88530');glow.addColorStop(1,'#211c21');g.fillStyle=glow;g.fill();for(let i=0;i<5;i++){const f=(t*.8+i*.2)%1;line(g,[[Math.sin(i*7)*w*.3,-4],[Math.sin(i*7+f)*w*.3,-5-f*h*.65]],'#f8bd63',1)}for(let i=-w/2+3;i<w/2;i+=5)line(g,[[i,-h*.63],[i,0]],'#303443',1.5);g.restore()}
function banner2(g,x,y,t){line(g,[[x-2,y],[x+18,y]],'#d1b474',2);poly(g,[[x,y+1],[x+16,y+1],[x+16+Math.sin(t)*1.3,y+44],[x+8,y+39],[x,y+44]],'#163956','#c8aa65');line(g,[[x+3,y+3],[x+3,y+35]],'#617789',.5);star(g,x+8,y+18,7)}
function tower(g,x,y,h,t){block(g,x-9,y,14,7,h);g.save();const grad=g.createLinearGradient(x-5,0,x+5,0);grad.addColorStop(0,'#174254');grad.addColorStop(.5,'#a3edff');grad.addColorStop(1,'#276a8a');g.fillStyle=grad;g.fillRect(x-5,y-h+9,8,h-20);for(let i=0;i<3;i++){let f=(t*.3+i/3)%1;line(g,[[x-5,y-11-f*(h-20)],[x+2,y-15-f*(h-20)]],'#e0ffff',.6)}g.restore();for(let yy of[y-h+6,y-9])line(g,[[x-7,yy],[x+6,yy]],'#d4b572',3);poly(g,[[x-9,y-h],[x,y-h-10],[x+12,y-h+1]],'#8f774b','#dfc485')}
function astrolabe(g,x,y,r,t){g.save();g.translate(x,y);g.scale(1,.95);for(let rad of[r,r-4,r*.64]){g.beginPath();g.arc(0,0,rad,0,Math.PI*2);g.strokeStyle=rad===r?'#d0ac60':'#a0834b';g.lineWidth=rad===r?2.8:.8;g.stroke()}for(let i=0;i<24;i++){let a=i*Math.PI/12;line(g,[[Math.cos(a)*(r-5),Math.sin(a)*(r-5)],[Math.cos(a)*r,Math.sin(a)*r]],'#f0d49a',1)}g.rotate(t*.2);for(let i=0;i<8;i++){let a=i*Math.PI/4;line(g,[[0,0],[Math.cos(a)*(r-6),Math.sin(a)*(r-6)]],'#ba9e66',.7)}g.shadowColor='#73daff';g.shadowBlur=10;star(g,0,0,r*.4);oval(g,0,0,3,3,'#e6ffff');g.restore()}
function crane2(g,x,y,t){block(g,x,y,7,4,68);beam(g,x+2,y-64,x-38,y-81,4);beam(g,x+2,y-42,x-25,y-76,2);const lift=Math.sin(t*1.2)*8;line(g,[[x-32,y-78],[x-32,y-26+lift]],'#aaac9f',1);poly(g,[[x-44,y-22+lift],[x-23,y-26+lift],[x-18,y-14+lift],[x-39,y-9+lift]],'#464a50','#b2955e');line(g,[[x-32,y-30+lift],[x-44,y-22+lift]],'#cab77d');gear(g,x+4,y-37,7,t)}
function building(g,D,t,working=true){const k=D.kind,a=working?t:0;
// Terraced foundation, stair courses and ore fragments.
block(g,65,185,119,50,9);for(let i=0;i<3;i++)block(g,120-i*4,204+i*3,28+i*8,7,3);
for(let i=0;i<16;i++){let x=74+(i*37)%158,y=179+(i*11)%20;poly(g,[[x,y],[x+3,y-5],[x+8,y-3],[x+10,y+1]],i%2?'#3d4652':'#606975','#7e8790')}
if(k===0){block(g,92,170,64,32,78);arch(g,125,178,27,45,a);block(g,92,96,64,32,7);for(let i=0;i<5;i++)block(g,94+i*13,93+i*6.5,7,4,9);tower(g,100,110,57,a);tower(g,191,151,57,a);astrolabe(g,165,76,37,a);banner2(g,94,111,a);banner2(g,160,140,a);crane2(g,231,174,a)}
if(k===1){block(g,83,174,103,27,49);for(let i=0;i<3;i++){arch(g,100+i*30,180+i*2,21,33,a+i);block(g,94+i*30,130,10,8,29+i*4);g.fillStyle='#121b24';g.fillRect(96+i*30,99-i*4,7,3)}tower(g,207,168,50,a);beam(g,173,191,229,176,4);for(let i=0;i<4;i++){ingot(g,178+i*12+(a*4%12),191-i*3)}gear(g,97,181,14,a);banner2(g,155,126,a)}
if(k===2){block(g,126,173,42,24,97);arch(g,145,180,23,37,a);tower(g,148,107,67,a);for(let i=0;i<3;i++){g.beginPath();g.ellipse(148,54+i*14,27,7,Math.sin(a+i)*.13,0,Math.PI*2);g.strokeStyle='#d4b575';g.stroke()}block(g,86,176,25,17,39);arch(g,100,181,16,25,a);tower(g,205,175,69,a);banner2(g,129,103,a);line(g,[[112,139],[130,123],[194,139],[205,120]],'#6fc9e0',2)}
if(k===3){for(let x of[91,190]){block(g,x,170,20,15,94);block(g,x-3,80,26,17,7);banner2(g,x+3,100,a)}block(g,117,180,61,17,37);arch(g,133,186,20,28,a);beam(g,116,114,194,111,7);let hit=Math.pow((Math.sin(a*3)+1)/2,4)*18;line(g,[[167,112],[167,151+hit]],'#b9c5c9',4);block(g,158,158+hit,19,9,10);block(g,156,185,26,11,10);gear(g,190,142,18,a*1.5);tower(g,100,103,42,a)}
if(k===4){block(g,102,177,66,29,30);oval(g,144,160,31,12,'#101c28');oval(g,144,161,22,7,'#73bdd0');for(let x of[93,198]){block(g,x,168,12,8,102)}g.save();g.translate(151,62);g.rotate(Math.sin(a*1.7)*.14);beam(g,-55,0,61,0,6);line(g,[[-46,0],[-46,75]],'#c1b897',2);line(g,[[48,0],[48,82]],'#c1b897',2);g.restore();astrolabe(g,152,96,25,a);tower(g,87,168,52,a);crane2(g,228,186,a);banner2(g,196,85,a)}
for(let i=0;i<3;i++)ingot(g,204+i*9,204-i*4);
if(working){g.save();for(let i=0;i<18;i++){let f=(a*.6+i/18)%1;g.globalAlpha=1-f;oval(g,142+Math.sin(i*8)*f*22,173-f*42,.5,.8,i%3?'#ffc16c':'#baf0ff')}g.restore()}
}
function worker(g,x,y,t,mode='work',scale=1){g.save();g.translate(x,y);g.scale(scale,scale);const walk=mode!=='work',step=walk?Math.sin(t*7):0,arm=walk?step*2:Math.sin(t*3)*3;oval(g,0,1,8,2,'#050b1399');g.translate(0,-Math.abs(step)*.65);
for(let side of[-1,1]){let foot=side*3+step*side*2;line(g,[[side*3,-9],[foot,-2]],'#526075',3);poly(g,[[foot-2,-3],[foot+2,-3],[foot+3,0],[foot-2,0]],'#292b31','#988975')}
poly(g,[[-6,-23],[5,-23],[7,-6],[2,-3],[-7,-5]],'#d6d6c6','#eee9d0');poly(g,[[-5,-22],[-1,-18],[0,-5],[-8,-5]],'#204469','#758aa0');poly(g,[[-2,-18],[4,-18],[5,-5],[-2,-5]],'#74604b','#b39c74');line(g,[[-5,-12],[6,-12]],'#b49b62',1.5);star(g,-4,-17,2.5);
poly(g,[[-5,-24],[-4,-29],[0,-32],[5,-29],[6,-23],[2,-20]],'#dce0d8','#f7f1da');poly(g,[[-2,-28],[3,-27],[4,-23],[0,-22]],'#aa9173');poly(g,[[-2,-28],[3,-27],[2,-25],[-2,-25]],'#283442');
line(g,[[-5,-21],[-8,-15],[-5,-11]],'#d6d9d0',3);line(g,[[5,-21],[8,-17-arm],[11,-15-arm]],'#d6d9d0',3);oval(g,11,-15-arm,2,2,'#8e704c');oval(g,-5,-11,2,2,'#8e704c');
if(mode==='carry')ingot(g,-3,-11);if(mode==='work'){block(g,12,0,9,5,7);line(g,[[16,-7],[11,-15-arm]],'#a6b8c2',1.5);oval(g,11,-15-arm,1.5,1.5,'#e4c78b')}g.restore()}
const sources=new Map();function source(D){if(sources.has(D.kind))return sources.get(D.kind);const c=document.createElement('canvas');c.width=1280;c.height=960;const cg=c.getContext('2d');cg.scale(4,4);building(cg,D,0,false);sources.set(D.kind,c);return c}
function jungle(g){for(let i=0;i<7;i++){let x=250+i*13,y=241+(i%3)*3,h=20+(i*7)%14;line(g,[[x,y],[x,y-h]],'#444532',2);for(let j=0;j<3;j++)poly(g,[[x-10+j*2,y-j*6-5],[x,y-h-8-j*2],[x+10-j*2,y-j*6-5]],j%2?'#213e3c':'#294b44','#33564a')}}
function render(g,D,time){const t=((time%28)+28)%28;g.clearRect(0,0,320,240);oval(g,160,187,112,33,'#07110f88');if(t<8){TempleKit.footprint(g,t,{color:'#cecf8d'});const c=source(D);for(let y=24;y<216;y+=8)for(let x=56;x<272;x+=8){const start=.5+(208-y)/184*4.6,u=clamp((t-start)/2.2);if(t<start)continue;const sy=186+Math.sin(x*1.2+y)*19,e=ease(u),dx=Math.sin(u*Math.PI)*(x-160)*.12;g.save();g.translate(x+dx,sy+(y-sy)*e);g.beginPath();g.rect(0,8*(1-ease(u/.2)),8,8);g.clip();g.drawImage(c,x*4,y*4,32,32,0,0,8,8);g.restore()}g.drawImage(UnitKit.figure(UnitKit.ENGINEERS[4].s,t,.5),30,177);g.save();g.globalAlpha=.4+.2*Math.sin(t*4);for(let i=0;i<3;i++){g.beginPath();g.ellipse(64,184,8+(t*12+i*10)%32,3+(t*4+i*3)%12,0,-1,1);g.strokeStyle='#e1c98d';g.stroke()}line(g,[[58,183],[112,155],[162,125]],'#e1c98d');g.restore()}
else{building(g,D,t,t>=13);const u=ease((t-8)/5);worker(g,294-109*u,228-23*u,t,t<13?'walk':'work')}
jungle(g);g.save();g.translate(-43,122);g.scale(.4,.4);TempleKit.building(g,TempleKit.DESIGNS[0],time);g.restore();g.font='8px Georgia';g.fillStyle='#b7c7bf';g.fillText('TEMPLE',7,213);const elapsed=Math.max(0,t-13),gains=Math.floor(elapsed/4);return{phase:t<8?'Énonciation · assemblage':t<13?'Le forgeron rejoint la fonderie':'Fonte · production de Fer',iron:gains*10,progress:(elapsed%4)/4,popupAge:gains?elapsed-gains*4:Infinity,producing:t>=13}}
function ironIcon(g,x,y){ingot(g,x,y)}
function feedback(g,s){if(!s.producing)return;g.save();g.fillStyle='#15212b';g.fillRect(123,222,92,2);g.fillStyle='#bca471';g.fillRect(123,222,92*s.progress,2);g.restore();const a=s.popupAge;if(a<0||a>=1.8)return;g.save();g.globalAlpha=a<.3?ease(a/.3):a<1.3?1:1-ease((a-1.3)/.5);g.translate(30,139-16*ease(a/.3));ironIcon(g,-20,0);g.font='bold 17px Georgia';g.textBaseline='middle';g.fillStyle='#f8e5b7';g.fillText('+10',-1,0);g.restore()}
global.FoundryKit={DESIGNS,render,feedback,building,worker,ironIcon};
})(window);
