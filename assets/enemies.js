// Kit de sprites ennemis (Forces de la Bête). Dépend de assets/decor.js et assets/units.js.
'use strict';
const EnemyKit=(()=>{const{K,fill,ell,seg,line,outlineAll,glowDots,scaled,figure,OUT}=UnitKit;
const Q={
 tyr:['#081a22','#0e2c38','#16425a','#22607a','#36809a','#5aa4b8'],tyrB:['#1e2a2a','#33443e','#526656','#7a8c72'],
 ichor:['#0a0a0a','#1a0f14','#2e1424','#4a1a36'],acid:['#1a3a08','#3a7a12','#7ac81e','#c8ff5a','#f4ffc8'],
 flesh:['#2a1418','#4a2228','#6e3a3a','#966058','#b88a7a','#d8b4a0'],void:['#050208','#120818','#22102c','#3a1846'],mag:['#3a0820','#7a1040','#c8206a','#ff5aa0','#ffd0e4'],
 bark:['#140e08','#24180e','#3a2816','#543a20','#6e5030'],moss:['#142a14','#22401e','#365a2a','#4e783a'],rot:['#3a1a04','#7a3a08','#c86a10','#ffaa30','#ffe6a0'],
 cryst:['#0a1422','#18304a','#2e5a80','#5a92b8','#a8d4ec','#ecfaff'],gl:['#103040','#2a7ab0','#6ad0ff','#d0f4ff','#ffffff'],
 gold:['#3a280c','#6a4a16','#a07424','#d0a038','#f0cc66','#fff2b0'],robe:['#4a4438','#7a725e','#a89e84','#d0c6a8','#ece4cc'],eyeB:['#0a2a5a','#2a6ad0','#7ac0ff','#e0f4ff'],
};
function veins(P,cx,cy,rx,ry,col,n,seed,t){const R=rng(seed+Math.floor(t*4));for(let k=0;k<n;k++){let x=cx+(R()-.5)*rx*1.4,y=cy+(R()-.5)*ry*1.4;for(let j=0;j<5+R()*5;j++){x+=(R()-.5)*2.4;y+=(R()-.3)*1.6;P.set(x,y,col[2+(j%2)],60)}}}
const eye=(P,x,y,c,z=62)=>{P.set(x,y,c[3]||c[2],z);P.set(x+1,y,c[2],z)};

/* ---------- archétypes ---------- */
// Corrompu : bête rampante basse et rapide
function crawler(P,s,t){const sk=s.skin,R=rng(s.seed),b=Math.sin(t*6)*.6;
 seg(P,[24,68],[12,62],6,sk,10,{v:.5});seg(P,[12,62],[3,58+b],3,sk,10,{v:.45});
 for(const[x,back]of[[28,1],[34,0],[46,1],[52,0]]){const z=back?8:30;seg(P,[x,66],[x-4,72],back?4:4.5,sk,z,{v:back?.4:.65});seg(P,[x-4,72],[x-1,80],3,sk,z,{v:back?.35:.6});for(let c=0;c<3;c++)P.set(x-3+c,80,(s.claw||Q.tyrB)[3],z+1)}
 ell(P,38,63,16,9,sk,20,{v:.66});if(s.belly)ell(P,40,68,11,3.5,s.belly,21,{v:.75});
 const hx=62,hy=55+b*.5;seg(P,[48,60],[hx-4,hy+1],8,sk,22,{v:.65});
 HEADS[s.head](P,hx,hy,s,t);
 if(s.spikes)for(let i=0;i<6;i++){const x=24+i*5,y=55-Math.sin(i/5*3.1)*2;fill(P,[[x-2,y+1],[x+2,y+1],[x-1+(s.spikeLean||-1)*2,y-5-(i%2)*2]],s.spikes,23,{v:.7})}
 if(s.shards)for(let i=0;i<5;i++){const x=26+i*6;fill(P,[[x-2,58],[x+2,58],[x+1+R()*2,47-R()*6]],s.shards,23,{v:.85})}
 if(s.vines)for(let i=0;i<4;i++)seg(P,[26+i*7,57],[24+i*7+R()*4,64+R()*6],1.6,s.vines,24,{v:.6});
 if(s.mouths)for(let i=0;i<3;i++){const x=28+i*8,y=62+(i%2)*3;fill(P,[[x-2,y],[x+2,y],[x,y+2]],Q.void,25);P.set(x-1,y,'#e8e0d0',26);P.set(x+1,y,'#e8e0d0',26)}
 if(s.vein)veins(P,38,62,14,7,s.vein,4,s.seed,t);if(s.ghost)ghost(P,s,t)}
// Brute : colosse voûté aux bras démesurés
function brute(P,s,t){const sk=s.skin,R=rng(s.seed),WK=s.walk!=null,ph=WK?s.walk*Math.PI*2:0,br=Math.sin(t*2.5)*.8+(WK?Math.abs(Math.sin(ph))*4:0);
 // démarche lourde : grand pas lent, pied levé bas, tassement du corps à chaque appui
 for(const[a,b0,z,o]of[[[34,64],[31,80],8,0],[[48,64],[51,80],30,Math.PI]]){const sw=WK?Math.sin(ph+o):0,ly=WK?Math.max(0,Math.cos(ph+o))*2:0,b=[b0[0]+sw*4,b0[1]-ly];
  seg(P,a,b,9,s.legs||sk,z,{v:z>10?.6:.45});fill(P,[[b[0]-6,b[1]-3],[b[0]+6,b[1]-3],[b[0]+7,b[1]+1],[b[0]-6,b[1]+1]],s.feet||sk,z+1,{v:.5})}
 ell(P,40,50+br*.3,19,17,sk,20,{v:.68});ell(P,36,36+br*.3,15,9,sk,21,{v:.75});
 if(s.belly)ell(P,43,56,11,7,s.belly,22,{v:.7});
 seg(P,[24,38],[16,56],11,sk,9,{v:.45});seg(P,[16,56],[18,70],9,sk,9,{v:.42});ell(P,18,72,6,5,s.fist||sk,10,{v:.45});
 seg(P,[54,40],[64,54],11,sk,40,{v:.7});seg(P,[64,54],[62,68],9,sk,40,{v:.68});
 if(s.club){seg(P,[62,70],[70,44],4,s.club,41,{v:.6});ell(P,71,40,6,7,s.club,42,{v:.7});for(let i=0;i<4;i++)P.set(66+i*3,36+(i%2)*6,s.clubSpike||Q.tyrB[3],43)}else ell(P,62,70,7,6,s.fist||sk,41,{v:.7});
 HEADS[s.head](P,54,38+br*.3,s,t,1);
 if(s.plates)for(const[x,y]of[[30,32],[46,33],[38,42]])fill(P,[[x-6,y-3],[x+6,y-4],[x+5,y+3],[x-5,y+4]],s.plates,26,{v:.75});
 if(s.core){const a=.5+.5*Math.sin(t*4);ell(P,42,50,5,5,s.core,30,{v:.7+a*.3});glowDots(P,42,50,9,s.core[3],8+a*8,rng(Math.floor(t*8)))}
 if(s.spikes)for(let i=0;i<5;i++){const x=24+i*6;fill(P,[[x-2,30],[x+2,29],[x-2,21-(i%2)*3]],s.spikes,27,{v:.7})}
 if(s.shards)for(let i=0;i<5;i++){const x=22+i*7;fill(P,[[x-3,32],[x+3,31],[x+R()*3,16-R()*8]],s.shards,27,{v:.85})}
 if(s.vines)for(let i=0;i<6;i++)seg(P,[22+i*6,30+R()*6],[20+i*6+R()*5,48+R()*14],2,s.vines,28,{v:.6});
 if(s.mouths){fill(P,[[34,50],[48,49],[47,58],[35,58]],Q.void,29);for(let i=0;i<7;i++){P.set(35+i*2,51,'#e8e0d0',30);P.set(36+i*2,57,'#e8e0d0',30)}}
 if(s.vein)veins(P,40,48,16,14,s.vein,6,s.seed,t);if(s.ghost)ghost(P,s,t)}
// Cracheur : sac gonflé sur pattes grêles, cou dressé, crachat lancé vers l'avant
function spitter(P,s,t){const sk=s.skin,a=.5+.5*Math.sin(t*5),R=rng(s.seed);
 for(const[x,d,z]of[[30,-1,8],[36,1,30],[46,-1,8],[52,1,30]]){seg(P,[x,64],[x+d*6,70],2.6,sk,z,{v:z>10?.6:.4});seg(P,[x+d*6,70],[x+d*4,80],2,sk,z,{v:z>10?.55:.35})}
 ell(P,40,58,15,13,sk,20,{v:.62});ell(P,41,60,8+a,7+a,s.sac,21,{v:.7+a*.25});glowDots(P,41,60,10,s.sac[3],6+a*6,rng(Math.floor(t*8)+s.seed));
 seg(P,[48,50],[56,36],7,sk,22,{v:.66});HEADS[s.head](P,60,33,s,t);
 const ph=(t*.9+s.seed*.31)%1,px=66+ph*16,py=32+ph*ph*14;if(px<79){ell(P,px,py,2.6,2.2,s.sac,64,{v:1});for(let i=1;i<6;i++)P.set(px-i*1.4,py-i*.6,s.sac[2],63)}
 for(let i=0;i<3;i++)P.set(64+i,38+i*2+a*2,s.sac[2],61);
 if(s.spikes)for(let i=0;i<4;i++){const x=30+i*6;fill(P,[[x-2,47],[x+2,47],[x-1,40-(i%2)*3]],s.spikes,23,{v:.7})}
 if(s.shards)for(let i=0;i<4;i++){const x=30+i*6;fill(P,[[x-2,48],[x+2,48],[x+R()*2,36-R()*6]],s.shards,23,{v:.85})}
 if(s.vines)for(let i=0;i<4;i++)seg(P,[30+i*6,48],[28+i*6+R()*4,58+R()*8],1.6,s.vines,24,{v:.6});
 if(s.vein)veins(P,40,58,12,10,s.vein,3,s.seed,t);if(s.ghost)ghost(P,s,t)}
// double désynchronisé (Fractures d'Énonciation) : silhouette décalée et pointillée
function ghost(P,s,t){const dx=Math.round(Math.sin(t*3)*3)+4,R=rng(Math.floor(t*6));for(let k=0;k<70;k++){const x=20+R()*44,y=30+R()*48;if(R()<.5)P.set(x+dx,y,s.ghost[1+(k%2)],5)}}

/* ---------- têtes ---------- */
const HEADS={
 lizard:(P,x,y,s,t,big)=>{const k=big?1.1:1;fill(P,[[x-7*k,y-4],[x+3,y-6],[x+10*k,y-2],[x+11*k,y+1],[x+4,y+3],[x-6*k,y+4]],s.skin,40,{v:.75});fill(P,[[x-2,y+2],[x+10*k,y+1],[x+8*k,y+5],[x-1,y+5]],s.belly||s.skin,39,{v:.55});
  for(let i=0;i<4;i++)P.set(x+1+i*2,y+3,'#e8e0d0',41);eye(P,x+1,y-3,s.eye);for(let i=0;i<3;i++)fill(P,[[x-6+i*3,y-4],[x-4+i*3,y-4],[x-7+i*3,y-9-(i===1?2:0)]],s.spikes||s.skin,41,{v:.7})},
 maw:(P,x,y,s,t)=>{ell(P,x,y,8,7,s.skin,40,{v:.7});const o=2+Math.sin(t*6)*1.5;fill(P,[[x+1,y-4],[x+9,y-1-o],[x+9,y+1+o],[x+1,y+4]],Q.void,41);for(let i=0;i<4;i++){P.set(x+3+i*1.6,y-2-o*.5,'#e8e0d0',42);P.set(x+3+i*1.6,y+2+o*.5,'#e8e0d0',42)}
  for(const[a,b]of[[-4,-4],[-1,-6],[-5,1],[2,-5]])eye(P,x+a,y+b,s.eye)},
 mask:(P,x,y,s,t)=>{fill(P,[[x-7,y+7],[x-6,y-5],[x,y-9],[x+6,y-6],[x+7,y+7]],s.hood||Q.robe,40,{v:.6,fold:1});ell(P,x+3,y,5,6,Q.gold,41,{v:.85});for(let a=0;a<8;a++)P.set(x+3+Math.cos(a/8*6.283)*7,y+Math.sin(a/8*6.283)*7,Q.gold[4],39);eye(P,x+2,y-1,Q.eyeB);eye(P,x+5,y-1,Q.eyeB);line(P,x+1,y+3,x+6,y+3,Q.ichor[1],42);for(let i=0;i<4;i++)P.set(x+2+i,y+4+i%2,Q.ichor[2],42)},
 automaton:(P,x,y,s,t)=>{fill(P,[[x-6,y-5],[x+6,y-6],[x+8,y+4],[x-5,y+5]],Q.gold,40,{v:.85});line(P,x-4,y-1,x+7,y-1,Q.gold[1],41);const a=.5+.5*Math.sin(t*4);eye(P,x+1,y-2,Q.eyeB);eye(P,x+5,y-2,Q.eyeB);if(a>.5)glowDots(P,x+3,y-2,4,Q.eyeB[2],4,rng(Math.floor(t*8)));
  for(let i=0;i<3;i++)P.set(x-3+i*4,y+3,Q.gold[1],41);line(P,x+2,y-6,x-1,y+5,Q.ichor[2],42)},
 skull:(P,x,y,s,t)=>{ell(P,x+1,y,7,6,Q.bark,40,{v:.7});fill(P,[[x+2,y+2],[x+10,y+1],[x+9,y+5],[x+2,y+6]],Q.bark,40,{v:.5});const a=.5+.5*Math.sin(t*4);P.set(x+2,y-1,Q.rot[3+(a>.6)],42);P.set(x+5,y-1,Q.rot[3],42);P.set(x+3,y-1,Q.rot[2],42);
  for(let i=0;i<3;i++)P.set(x+4+i*2,y+4,'#d8c8a0',42);for(let i=0;i<3;i++)seg(P,[x-5+i*3,y-4],[x-8+i*4,y-11],1.5,Q.moss,41)},
 shard:(P,x,y,s,t)=>{fill(P,[[x-6,y+3],[x-3,y-7],[x+3,y-9],[x+10,y-1],[x+6,y+5]],Q.cryst,40,{v:.8});line(P,x-3,y-7,x+6,y+5,Q.cryst[5],41);const a=.5+.5*Math.sin(t*7);P.set(x+3,y-2,Q.gl[3+(a>.5)],42);P.set(x+4,y-2,Q.gl[3],42);
  if(a>.4)fill(P,[[x+8,y-6],[x+12,y-8],[x+11,y-3]],Q.cryst,43,{v:.9})},
};

/* ---------- 5 familles ---------- */
const FAM=[
 {name:'1 · Tyriens déchus',desc:'Descendants dégénérés des Tyriens, les sauriens bâtisseurs du Sanctum : écailles bleues ternies, yeux jaunes, veines noires et acides de la Bête. Lien direct avec le lieu et le casque saurus des Exilés.',
  c:{head:'lizard',skin:Q.tyr,belly:Q.tyrB,eye:['','#a07a10','#ffd040','#fff0a0'],spikes:Q.tyrB,vein:Q.acid,seed:1},
  b:{head:'lizard',skin:Q.tyr,belly:Q.tyrB,eye:['','#a07a10','#ffd040','#fff0a0'],spikes:Q.tyrB,plates:K.bronze,club:K.bronze,vein:Q.acid,seed:2},
  s:{head:'lizard',skin:Q.tyr,belly:Q.tyrB,eye:['','#a07a10','#ffd040','#fff0a0'],sac:Q.acid,spikes:Q.tyrB,vein:Q.acid,seed:3}},
 {name:'2 · Le Credo souillé',desc:'Agents de Laetan corrompus par la Bête qu’il sert en secret. Fanatique en robe ivoire trempée d’ichor noir, larmes noires sous le masque solaire ; automate d’or de Byrsa fêlé, aux yeux de lueur bleue (Fortuna) ; thuriféraire en noir et or, plus grand, qui projette une lumière souillée.',
  fig:{c:{head:'hood',hc:Q.robe,mask:Q.gold,torso:Q.robe,arms:Q.robe,fore:Q.robe,hands:Q.ichor,robe:Q.robe,robeY:76,sash:Q.ichor,right:'talwar',pose:'guard',over:['ichor'],seed:4},
       s:{head:'hood',hc:Q.gold,mask:Q.gold,torso:Q.ichor,arms:Q.ichor,fore:Q.ichor,hands:Q.gold,robe:Q.ichor,cape:Q.gold,sash:Q.gold,tabard:Q.gold,tabY:74,cross:(P,cx,y)=>{},bulk:1.12,pose:'twohand',over:['staffEnergy','ichor'],ichorGold:1,energy:'eGold',shaft:Q.gold,seed:6}},
  b:{head:'automaton',skin:Q.gold,legs:Q.gold,feet:Q.gold,fist:Q.gold,core:Q.eyeB,vein:Q.ichor,seed:5}},
 {name:'3 · Chair du Dévoreur',desc:'Aberrations nées de la captation du Fleuve des Limbes : chair pâle, plaques de néant, gueules multiples et lueur magenta. Le plus organique et le plus dérangeant.',
  c:{head:'maw',skin:Q.flesh,belly:Q.void,eye:['','#7a1040','#ff5aa0','#ffd0e4'],mouths:1,vein:Q.mag,seed:7},
  b:{head:'maw',skin:Q.flesh,belly:Q.void,eye:['','#7a1040','#ff5aa0','#ffd0e4'],mouths:1,vein:Q.mag,seed:8},
  s:{head:'maw',skin:Q.flesh,eye:['','#7a1040','#ff5aa0','#ffd0e4'],sac:Q.mag,vein:Q.mag,seed:9}},
 {name:'4 · Fléau végétal',desc:'La jungle du Sanctum elle-même, dévitalisée par la magie pure et animée par la corruption : bois mort, mousse, épines, champignons à spores ambrées. Se fond dans le décor, se lit à sa lueur.',
  c:{head:'skull',skin:Q.bark,belly:Q.moss,spikes:Q.bark,vines:Q.moss,vein:Q.rot,claw:Q.bark,seed:10},
  b:{head:'skull',skin:Q.bark,belly:Q.moss,vines:Q.moss,club:Q.bark,clubSpike:Q.rot[3],vein:Q.rot,seed:11},
  s:{head:'skull',skin:Q.bark,vines:Q.moss,sac:Q.rot,vein:Q.rot,seed:12}},
 {name:'5 · Fractures d’Énonciation',desc:'Créatures prises dans un dérèglement local de la réalité autour de l’Ancre : corps de cristal, éclats en suspension, double désynchronisé qui traîne derrière elles. Le plus « science-fantasy ».',
  c:{head:'shard',skin:Q.cryst,belly:Q.void,shards:Q.cryst,ghost:Q.gl,claw:Q.cryst,seed:13},
  b:{head:'shard',skin:Q.void,belly:Q.cryst,shards:Q.cryst,core:Q.gl,ghost:Q.gl,fist:Q.cryst,seed:14},
  s:{head:'shard',skin:Q.cryst,sac:Q.gl,shards:Q.cryst,ghost:Q.gl,seed:15}},
];
function draw(kind,spec,t,k){if(kind==='fig')return figure(spec,t,k);const P0=new Px(Math.ceil(80*k),Math.ceil(84*k),true),P=k===1?P0:scaled(P0,k);({c:crawler,b:brute,s:spitter})[kind](P,spec,t);outlineAll(P0);P0.flush();return P0.c}
return{FAM,Q,draw}})();
