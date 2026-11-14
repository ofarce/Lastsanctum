'use strict';
// Éclairage d'ambiance inspiré de Core Keeper : obscurité générale, halos chauds
// autour des personnages, bâtiments et sources magiques. Calculé à 1/4 de résolution
// puis étiré (le flou bilinéaire donne des bords de halo doux).
const LIGHTING={on:true,ambient:'rgba(12,7,4,.28)',k:4,c:document.createElement('canvas')};
LIGHTING.c.id='lighting';Object.assign(LIGHTING.c.style,{position:'fixed',left:'0',top:'0',pointerEvents:'none',zIndex:'1',display:'none'});
const LIGHT_WARM='255,176,92',LIGHT_FORGE='255,128,48',LIGHT_ARCANE='184,132,255',LIGHT_FROST='110,200,230';
function collectLights(){
 const L=[],push=(x,z,r,rgb,glow=.16)=>L.push({x,z,r,rgb,glow}),flick=(i,a=.06)=>1+Math.sin(currentTime*9+i*1.7)*a+Math.sin(currentTime*23+i)*a*.5;
 for(const u of units)if(u.hp>0&&!u.hidden)push(u.x,u.z,8*flick(u.id||0),LIGHT_WARM,.14);
 for(const b of buildings){const t=b.type;if(t==='sigil'||t==='library')push(b.x,b.z,8,LIGHT_ARCANE,.12);else if(t==='aether'||t==='forge'||t==='workshop')push(b.x,b.z,8.5*flick(b.x,.08),LIGHT_FORGE,.2);else push(b.x,b.z,7.5,LIGHT_WARM,.12)}
 for(const t of turrets)push(t.x,t.z,5,LIGHT_WARM,.1);
 if(ORB.active)push(core.x,core.z,10*flick(1,.04),LIGHT_ARCANE,.22);else push(core.x,core.z,4+ORB.progress/ORB.time*5,LIGHT_ARCANE,.08);
 push(PORTAL.x,PORTAL.z,9,LIGHT_FROST,.18);
 for(const p of GAL.portals)if(p.active)push(p.x,p.z+1,8*flick(p.id+3,.08),'255,70,40',.22);
 if(typeof DEITY_PORTALS!=='undefined')for(const d of DEITY_PORTALS)push(d.x,PORTAL.z+1,5.5*flick(d.x),LIGHT_WARM,.16);
 for(const o of PW.objs)if(o.light)push(o.x,o.z,4.5,LIGHT_FROST,.14);
 for(const e of effects)if(e.type==='xboom'&&e.age>=0&&e.x!==undefined)push(e.x,e.z,4,LIGHT_FORGE,.3);
 return L}
function drawLighting(){
 if(!LIGHTING.on){LIGHTING.c.style.display='none';return}
 const k=LIGHTING.k,c=LIGHTING.c,w=Math.ceil(W/k),h=Math.ceil(H/k);
 if(!w||!h)return;
 if(c.width!==w||c.height!==h){c.width=w;c.height=h;c.style.width=w*k+'px';c.style.height=h*k+'px';LIGHTING.g=null}
 const g=LIGHTING.g||(LIGHTING.g=c.getContext('2d')),s=Z()*.86,lights=collectLights().map(l=>{const p=project(l.x,0,l.z);return{...l,px:p.x,py:p.y,pr:l.r*s}}).filter(l=>l.px>-l.pr&&l.px<W+l.pr&&l.py>-l.pr&&l.py<H+l.pr);
 g.globalCompositeOperation='source-over';g.clearRect(0,0,w,h);g.fillStyle=LIGHTING.ambient;g.fillRect(0,0,w,h);
 // creuse l'obscurité autour de chaque source
 g.globalCompositeOperation='destination-out';
 for(const l of lights){const x=l.px/k,y=l.py/k,r=l.pr/k,gr=g.createRadialGradient(x,y,0,x,y,r);gr.addColorStop(0,'rgba(0,0,0,1)');gr.addColorStop(.45,'rgba(0,0,0,.8)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(x-r,y-r,r*2,r*2)}
 // vignette sombre sur les bords, calculée dans le calque basse résolution (16× moins de pixels qu'en plein écran)
 g.globalCompositeOperation='source-over';
 const v=g.createRadialGradient(w/2,h*.48,Math.min(w,h)*.35,w/2,h*.48,Math.max(w,h)*.75);v.addColorStop(0,'rgba(6,3,2,0)');v.addColorStop(1,'rgba(6,3,2,.3)');g.fillStyle=v;g.fillRect(0,0,w,h);
 // Le calque d'ombre est un canvas superposé en CSS : c'est le compositeur du navigateur qui l'agrandit (×4, lissé),
 // au lieu d'un drawImage plein écran qui coûtait plus de 10 ms par image en rendu logiciel.
 const ref=(typeof decorRenderer!=='undefined'&&decorRenderer&&decorRenderer.canvas)||canvas;if(c.previousSibling!==ref)ref.after(c);c.style.display='block';
 ctx.save();
 // lueur colorée additive, à la manière des flammes de Core Keeper
 ctx.globalCompositeOperation='lighter';
 for(const l of lights){const gr=ctx.createRadialGradient(l.px,l.py,0,l.px,l.py,l.pr*.8);gr.addColorStop(0,`rgba(${l.rgb},${l.glow})`);gr.addColorStop(1,`rgba(${l.rgb},0)`);ctx.fillStyle=gr;ctx.fillRect(l.px-l.pr*.8,l.py-l.pr*.8,l.pr*1.6,l.pr*1.6)}
 ctx.restore()}
