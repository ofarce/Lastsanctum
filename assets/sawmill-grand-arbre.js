/* Selected Grand Arbre: same Px, bark/leaf ramps and seeded foliage as the game. */
(function(global){
'use strict';
const base=global.SawmillKit,ease=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x)};
const layers=[];
function layer(draw){const p=new Px(320,240,true);draw(p);p.flush();return p.c}
function wood(p,pts,z=5){p.poly(pts,(x,y)=>p.ramp(C.bark,.55+fbm(x/17,y/3,41)*.3+(hash(x,y,7)-.5)*.17,x,y),z)}
function beam(p,x,y,X,Y,w,z=5){const a=Math.atan2(Y-y,X-x),dx=Math.sin(a)*w/2,dy=-Math.cos(a)*w/2;wood(p,[[x+dx,y+dy],[X+dx,Y+dy],[X-dx,Y-dy],[x-dx,y-dy]],z);p.line(x+dx,y+dy,X+dx,Y+dy,C.bark[4],z+.1)}
const tree=layer(p=>{trunkDraw(p,125,194,103,20,rng(43),1);beam(p,125,112,90,68,10,2);beam(p,128,101,164,54,8,2);beam(p,121,130,75,102,8,2);canopy(p,112,49,64,28,rng(29),3,C.leaf,105);canopy(p,65,74,34,23,rng(73),4,C.leaf,40);canopy(p,171,64,39,25,rng(13),4,C.leaf,40);for(let i=0;i<6;i++)beam(p,125,182,87+i*15,198+Math.sin(i)*5,6,5)});
layers.push(layer(p=>{wood(p,[[90,180],[191,158],[269,182],[171,213],[77,193]],6);for(let i=0;i<16;i++)p.line(87+i*7,183-i*1.4,171+i*5.7,210-i*1.8,C.bark[4],7);for(const x of[150,180,224,253])beam(p,x,196,x,209,5,8)}));
layers.push(layer(p=>{for(const [x,y] of [[151,187],[236,182],[200,161]]){beam(p,x,y,x,y-65,6,10);beam(p,x,y-35,x+21,y-54,4,11)}beam(p,134,123,238,113,7,12);beam(p,236,181,236,112,6,12)}));
layers.push(layer(p=>{wood(p,[[123,119],[185,83],[263,114],[202,144]],14);for(let i=0;i<16;i++)p.line(126+i*4,118-i*2.2,203+i*3.7,141-i*1.6,C.bark[4],15);for(let i=0;i<26;i++){const x=132+i*4.6,y=116-Math.sin(i/8)*20;canopy(p,x,y,6,3,rng(i+93),16,C.moss,3)}for(const[x,y]of[[147,122],[206,137],[247,118]])vine(p,x,y,18,rng(x),17)}));
layers.push(layer(p=>{beam(p,149,182,237,168,6,20);beam(p,150,182,150,199,4,20);beam(p,229,172,229,191,4,20);for(let i=0;i<5;i++){wood(p,[[233,193-i*4],[253,187-i*4],[258,190-i*4],[238,197-i*4]],21)}for(const [x,y]of[[148,164],[233,161]]){p.poly([[x-2,y],[x+3,y],[x+3,y+6],[x-2,y+6]],()=>C.gold[2],22);p.set(x,y+2,'#ffe0a0',23)}}));
layers.push(layer(p=>{beam(p,249,177,249,88,6,24);beam(p,249,88,206,99,5,24);beam(p,249,111,226,96,3,24);p.line(213,98,213,132,C.gold[1],25);for(let i=0;i<3;i++)beam(p,204,137+i*3,229,131+i*3,4,25);for(let i=0;i<4;i++)beam(p,256,198-i*5,276,193-i*5,5,25);wood(p,[[151,132],[164,132],[164,157],[158,153],[151,157]],26);p.poly([[152,133],[163,133],[163,153],[158,150],[152,153]],()=>C.moss[2],27);p.line(158,139,158,149,C.gold[3],28);p.line(158,144,154,139,C.gold[3],28);p.line(158,144,162,139,C.gold[3],28)}));
function disc(g,t){g.save();g.translate(198,166);g.scale(.6,1);g.rotate(t*2.8);g.beginPath();for(let i=0;i<64;i++){const a=i*Math.PI/32,r=i%2?17:19;g.lineTo(Math.cos(a)*r,Math.sin(a)*r)}g.closePath();g.fillStyle='#85826d';g.fill();g.strokeStyle='#dad4b8';g.stroke();for(let i=0;i<6;i++){g.rotate(Math.PI/3);g.fillStyle='#3d3d35';g.fillRect(3,-1,11,2)}g.restore();g.fillStyle='#c09a48';g.fillRect(196,164,4,4)}
function building(g,D,t,active=true,construction=8){const growth=ease((construction-.35)/3.25);g.save();g.beginPath();g.rect(0,0,320,202);g.clip();g.translate(125,196);g.scale(.6+.4*growth,Math.max(.001,growth));g.drawImage(tree,-125,-196);g.restore();
 for(let i=0;i<layers.length;i++){const u=ease((construction-(3+i*.6))/.95);if(!u)continue;g.save();g.translate(125,155);g.scale(u,u);g.translate(-125,-155);g.globalAlpha=Math.min(1,u*3);g.drawImage(layers[i],0,0);g.restore()}
 const machine=ease((construction-5)/1.2);if(machine){g.save();g.globalAlpha=machine;disc(g,active?t:0);g.fillStyle='#644c34';g.fillRect(156+(active?Math.sin(t*1.1)*5:0),174,65,7);g.fillStyle='#93805a';g.fillRect(156+(active?Math.sin(t*1.1)*5:0),174,6,7);g.restore()}
 if(active)for(let i=0;i<18;i++){const f=(t*.9+i/18)%1;g.globalAlpha=1-f;g.fillStyle=C.gold[2];g.fillRect(204+f*20,180+f*f*12,1,1)}g.globalAlpha=1;
}
function render(g,D,time){const t=((time%28)+28)%28;g.clearRect(0,0,320,240);g.imageSmoothingEnabled=false;g.fillStyle='#07110f88';g.beginPath();g.ellipse(169,197,111,25,0,0,Math.PI*2);g.fill();
 if(t<8){g.save();g.globalAlpha=Math.sin(Math.PI*t/8)*.6;g.strokeStyle=C.gold[2];g.beginPath();g.ellipse(125,195,25+10*ease(t/2),9,0,0,Math.PI*2);g.stroke();g.restore()}
 building(g,D,t,t>=13,Math.min(t,8));if(t>=8){const u=Math.min(1,(t-8)/5);(base.nativeWorker||base.worker)(g,302-80*u,254-51*u,t,t<13?'walk':'work',1)}
 g.save();g.translate(-39,149);g.scale(.32,.32);TempleKit.building(g,TempleKit.DESIGNS[0],t);g.restore();
 const elapsed=Math.max(0,t-13),gains=Math.floor(elapsed/4);return{phase:t<.35?'Éveil du sol':t<3?'L’arbre émerge du sol':t<4?'Les racines forment le plancher':t<5?'La charpente pousse depuis le tronc':t<6?'Le feuillage couvre l’atelier':t<8?'Formation des machines et du treuil':t<13?'L’artisan rejoint la scierie':'Sciage · production de bois',wood:gains*10,progress:elapsed%4/4,popupAge:gains?elapsed-gains*4:Infinity,producing:t>=13}}
const feedback=global.SawmillKit.feedback;
global.SawmillKit={...base,worker:base.nativeWorker||base.worker,DESIGNS:[{kind:2,name:'03 · Le Grand Arbre',desc:'Un arbre vivant émerge de la terre. Racines, plancher, charpente et toit se déploient depuis son tronc ; la scierie prend forme autour de lui.'}],render,building,feedback};
})(window);
