'use strict';
// Étincelle de réactivation de l'Ancre (planche etincelle-ancre-propositions.html, variante B « Fil d'éclair »).
// Quand l'Ancre s'éveille, une étincelle noir-argent quitte la sphère, traverse la caverne et le tunnel jusqu'à
// l'entrée, s'y divise, et chaque branche s'éteint devant une baliste, qui s'arme à cet instant.
// La caméra suit l'étincelle. Traînée en éclair brisé ; halo lumineux en paliers tramés (fort sur l'étincelle,
// plus faible sur la traînée). Palette noir / acier / argent / blanc : le pourpre reste réservé à la sphère.
// Coordonnées internes : pixels natifs du monde (1 unité = 8 px), x = monde.x*8, y = monde.z*8.
const AnchorSpark=(()=>{
 const T1=.7,T2=3.7,T3=3.95,T4=4.75,LIFE=1.9,END=T4+LIFE+.3,CAM_END=T4+1.2,UNIT=8;
 const K0='#07070a',K1='#1c1d24',K2='#3a3c47',S1='#6f7482',S2='#a8aebb',S3='#d9dde6',WH='#ffffff';
 const hash=(i,j)=>{const s=Math.sin(i*12.9898+j*78.233)*43758.5453;return s-Math.floor(s)};
 const ease=u=>{u=Math.max(0,Math.min(1,u));return u*u*(3-2*u)*.35+u*.65};
 let S=null; // séquence en cours : {t0, main, branches:[{pts,turret,done}], sphere, split, camOn}

 function catmull(ctrl){const raw=[];for(let i=0;i<ctrl.length-1;i++){const p0=ctrl[Math.max(0,i-1)],p1=ctrl[i],p2=ctrl[i+1],p3=ctrl[Math.min(ctrl.length-1,i+2)];
   for(let k=0;k<40;k++){const u=k/40,u2=u*u,u3=u2*u,f=(a,b,c,d)=>.5*(2*b+(-a+c)*u+(2*a-5*b+4*c-d)*u2+(-a+3*b-3*c+d)*u3);raw.push([f(p0[0],p1[0],p2[0],p3[0]),f(p0[1],p1[1],p2[1],p3[1])])}}
  raw.push(ctrl[ctrl.length-1]);
  const pts=[{x:raw[0][0],y:raw[0][1],s:0}];let acc=0,next=1;
  for(let i=1;i<raw.length;i++){const a=raw[i-1],b=raw[i],l=Math.hypot(b[0]-a[0],b[1]-a[1]);while(acc+l>=next){const u=(next-acc)/l;pts.push({x:a[0]+(b[0]-a[0])*u,y:a[1]+(b[1]-a[1])*u,s:next});next++}acc+=l}
  for(let i=0;i<pts.length;i++){const a=pts[Math.max(0,i-2)],b=pts[Math.min(pts.length-1,i+2)],dx=b.x-a.x,dy=b.y-a.y,l=Math.hypot(dx,dy)||1;pts[i].nx=-dy/l;pts[i].ny=dx/l}
  return pts}
 function stamp(pts,ta,tb){const L=pts[pts.length-1].s;let j=0;for(let k=0;k<=4000&&j<pts.length;k++){const t=ta+(tb-ta)*k/4000,s=L*ease(k/4000);while(j<pts.length&&pts[j].s<=s){pts[j].tp=t;j++}}for(;j<pts.length;j++)pts[j].tp=tb}
 function along(pts,ta,tb,t){const L=pts[pts.length-1].s,i=Math.min(pts.length-1,Math.max(0,Math.round(L*ease((t-ta)/(tb-ta)))));return pts[i]}

 // Tracé : sphère → devant l'autel → sinusoïde dans la caverne (amortie dans le tunnel) → entrée → pied de chaque baliste.
 function build(){
  const cx=core.x*UNIT,cy=core.z*UNIT,sphere={x:cx,y:cy-35},split={x:0,y:(mountainEdge(0)+3.5)*UNIT};
  const ctrl=[[sphere.x,sphere.y],[cx+7,cy-8],[cx,cy+28]],OFF=[-16,13,-11,11,-6,3,-3,1],y0=cy+28,n=OFF.length+1;
  for(let k=1;k<n;k++){const y=y0+(split.y-y0)*k/n,inT=y/UNIT>CAVE.z1;ctrl.push([OFF[k-1]*(inT?.25:1),y])}
  ctrl.push([split.x,split.y]);const main=catmull(ctrl);stamp(main,T1,T2);
  const branches=turrets.map(b=>{const d=Math.sign(b.x-split.x)||1,ex=b.x*UNIT-d*UNIT,ey=(b.z+4)*UNIT,
   pts=catmull([[split.x,split.y],[split.x+d*18,split.y+14],[split.x+(ex-split.x)*.6,split.y+30],[ex,ey]]);stamp(pts,T3,T4);return{pts,turret:b,done:false}});
  return{main,branches,sphere,split}}

 function start(){S={t0:currentTime,...build(),camOn:true};
  // la caméra est rendue au joueur s'il la déplace lui-même
  S.cam={x:cam.x,z:cam.z}}
 function reset(){S=null}
 const active=()=>!!S;
 const tt=()=>S?currentTime-S.t0:0;
 function heads(t){if(t<T1||t>=T4)return[];if(t<T2)return[along(S.main,T1,T2,t)];if(t<T3)return[S.split];return S.branches.map(b=>along(b.pts,T3,T4,t))}

 function camTarget(t){const ty=S.branches.length?S.branches[0].pts.at(-1).y-10:S.split.y;
  if(t<T1)return{x:S.sphere.x,y:S.sphere.y+29};if(t<T2){const h=along(S.main,T1,T2,t);return{x:h.x*.5,y:h.y+34}}if(t<T3)return{x:S.split.x,y:S.split.y};
  if(t<T4){const u=(t-T3)/(T4-T3);return{x:S.split.x,y:S.split.y+(ty-S.split.y)*u}}return{x:S.split.x,y:ty}}
 function update(dt){if(!S)return;const t=tt();
  for(const b of S.branches)if(!b.done&&t>=T4){b.done=true;if(typeof activateTurret==='function')activateTurret(b.turret)}
  if(S.camOn&&t<CAM_END){
   // si le joueur a bougé la caméra depuis la dernière image, on lui rend la main
   if(Math.abs(cam.x-S.cam.x)>.01||Math.abs(cam.z-S.cam.z)>.01)S.camOn=false;
   else{const g=camTarget(t),r=1-Math.exp(-6*dt);cam.x+=(g.x/UNIT-cam.x)*r;cam.z+=(g.y/UNIT-cam.z)*r;if(typeof clampCam==='function')clampCam();S.cam={x:cam.x,z:cam.z}}}
  if(t>END)S=null}

 // ---------- dessin (pixels natifs à l'écran, blocs de PX) ----------
 let ox=0,oy=0,PASS=0,GL=null,NW=0,NH=0,box=null;
 const px=(x,y,c)=>{if(PASS)return;ctx.fillStyle=c;ctx.fillRect(Math.round(x+ox)*PX,Math.round(y+oy)*PX,PX,PX)};
 function light(x,y,r,s){if(!PASS||s<=0)return;const X=Math.round(x+ox),Y=Math.round(y+oy),R=Math.ceil(r);
  for(let dy=-R;dy<=R;dy++){const yy=Y+dy;if(yy<0||yy>=NH)continue;for(let dx=-R;dx<=R;dx++){const xx=X+dx;if(xx<0||xx>=NW)continue;const d=Math.hypot(dx,dy);if(d>r)continue;
   const v=s*Math.pow(1-d/r,1.4),k=yy*NW+xx;if(v>GL[k]){GL[k]=v;if(xx<box[0])box[0]=xx;if(xx>box[2])box[2]=xx;if(yy<box[1])box[1]=yy;if(yy>box[3])box[3]=yy}}}}
 function lightSeg(a,b,r,s){if(!PASS)return;const n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])/2));for(let k=0;k<=n;k++)light(a[0]+(b[0]-a[0])*k/n,a[1]+(b[1]-a[1])*k/n,r,s)}
 const GSTEP=[[.6,.78],[.38,.56],[.2,.36],[.07,.2]];
 function composeLight(){if(box[2]<box[0])return;ctx.save();ctx.globalCompositeOperation='screen';
  for(const[j,[th,al]]of GSTEP.entries()){ctx.fillStyle=`rgba(222,228,242,${al})`;const hi=j?GSTEP[j-1][0]:9;
   for(let y=box[1];y<=box[3];y++)for(let x=box[0];x<=box[2];x++){const v=GL[y*NW+x];if(v<=th||v>hi)continue;if(j===3&&((x+y)&1))continue;ctx.fillRect(x*PX,y*PX,PX,PX)}}
  ctx.restore()}
 function line(x0,y0,x1,y1,c,thick){const n=Math.max(1,Math.ceil(Math.hypot(x1-x0,y1-y0)));for(let k=0;k<=n;k++){const x=x0+(x1-x0)*k/n,y=y0+(y1-y0)*k/n;if(thick){px(x-1,y,c);px(x+1,y,c);px(x,y-1,c);px(x,y+1,c)}else px(x,y,c)}}
 function ring(x,y,rx,ry,cols,step=1){const n=Math.max(8,Math.ceil(rx*2*Math.PI/step));for(let k=0;k<n;k++){const a=k/n*Math.PI*2;px(x+Math.cos(a)*rx,y+Math.sin(a)*ry,cols[k%cols.length])}}
 function head(x,y,t,big=0){const f=Math.floor(t*14),r=9+big*4+(f%3===0?1:0);light(x,y,r+13,1.05);
  for(let dy=-3;dy<=3;dy++)for(let dx=-3;dx<=3;dx++){const d=Math.abs(dx)+Math.abs(dy);if(d===3||d===4&&Math.abs(dx)<3&&Math.abs(dy)<3)px(x+dx,y+dy,K0);else if(d===2)px(x+dx,y+dy,((dx+dy+f)&1)?S1:K1)}
  const diag=f%2,arm=4+(f%4===1?2:0)+big*2;
  for(let k=-arm-1;k<=arm+1;k++){if(!k)continue;const c=Math.abs(k)>arm?K0:Math.abs(k)===arm?S2:S3;if(diag){px(x+k*.75,y+k*.75,c);px(x+k*.75,y-k*.75,c)}else{px(x+k,y,c);px(x,y+k,c)}}
  for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++)px(x+dx,y+dy,dx&&dy?S3:WH);if(f%3===1){px(x+arm+2,y-arm-1,S3);px(x-arm-1,y+arm,S2)}}
 function mote(x,y,k){px(x,y,k&1?WH:S3);px(x+1,y,K0);px(x-1,y,K0);px(x,y+1,K0);px(x,y-1,K0)}
 // traînée « fil d'éclair » : ligne brisée qui crépite, se fragmente et se tord en s'éteignant
 function trail(t){const fr=Math.floor(t*16),glow=[],core=[];
  for(const[pi,pts]of[S.main,...S.branches.map(b=>b.pts)].entries()){let prev=null;
   for(let i=0;i<pts.length;i+=5){const p=pts[i];if(p.tp>t)break;const a=t-p.tp,I=1-a/LIFE;if(I<=0){prev=null;continue}
    const amp=i?1+(1-I)*3.5:0,o=(hash(i+pi*999,fr)-.5)*2*amp,pt=[p.x+p.nx*o,p.y+p.ny*o];
    if(prev&&hash(i+pi*999,fr+7)>(1-I)*.85){core.push([prev,pt,a<.12?WH:I>.6?S3:I>.35?S2:K2]);if(I>.45)glow.push([prev,pt]);lightSeg(prev,pt,a<.3?6:4.5,(a<.3?.7:.5)*I)}
    if(i%45===0&&a<.7&&i){const ang=Math.atan2(p.ny,p.nx)+(hash(i,fr+3)>.5?0:Math.PI)+(hash(i,fr+5)-.5),l=3+hash(i,fr+9)*6*(1-a);core.push([pt,[pt[0]+Math.cos(ang)*l,pt[1]+Math.sin(ang)*l],S1])}
    prev=pt}}
  for(const[a,b]of glow)line(a[0],a[1],b[0],b[1],K0,true);for(const[a,b,c]of core)line(a[0],a[1],b[0],b[1],c,false)}
 function events(t){const{sphere:SP,split:SL}=S;
  if(t<T1+.35){const u=Math.min(1,t/T1);
   if(t<T1){light(SP.x,SP.y,8+14*u,.55*u);const R=6+26*(1-u*u);ring(SP.x,SP.y,R,R*.9,[S3,S3,K0]);ring(SP.x,SP.y,R+1,R*.9+1,[K0]);if(u>.3)ring(SP.x,SP.y,R*.6,R*.55,[S2,K0],2);
    for(let k=0;k<8;k++){const a=k*.785+t*3*(k&1?1:-1),d=6+34*(1-u)*(1+.2*(k%3));mote(SP.x+Math.cos(a)*d,SP.y+Math.sin(a)*d*.9,k)}if(u>.75)head(SP.x,SP.y,t,(u-.75)*2)}
   else{const v=(t-T1)/.35;light(SP.x,SP.y,18,.7*(1-v));ring(SP.x,SP.y,8+v*26,8+v*23,v<.5?[WH,WH,K0]:[S1,K0])}}
  if(t>=T2&&t<T3+.5){if(t<T3)head(SL.x,SL.y,t,1);if(t>=T3-.05){const v=(t-T3+.05)/.55,rx=4+v*30;light(SL.x,SL.y,22*(1-v*.5),.75*(1-v));ring(SL.x,SL.y,rx,rx*.45,v<.4?[S3,K0]:[S1,K0,K0]);if(v<.3)ring(SL.x,SL.y,rx*.6,rx*.27,[K0],2)}}
  if(t>=T4&&t<T4+.6){const u=(t-T4)/.6;for(const b of S.branches){const e=b.pts.at(-1);light(e.x,e.y-6,16*(1-u*.5),.85*(1-u));
   if(u<.55){const h=30*(1-u/.55);for(let y=0;y<h;y++){px(e.x,e.y-y,y<4||u<.2?WH:S3);if(y<h*.7){px(e.x-1,e.y-y,K0);px(e.x+1,e.y-y,K0)}}}
   const rx=3+u*22;ring(e.x,e.y,rx,rx*.42,u<.5?[S3,K0]:[S1]);if(u<.25)head(e.x,e.y,t,0)}}}
 function draw(){if(!S||!PIXEL)return;const t=tt(),o=project(0,0,0),k=Z()*.86/PX/UNIT;if(Math.abs(k-1)>.01)return; // échelle native attendue : 8 px par unité
  ox=o.x/PX;oy=o.y/PX;NW=Math.ceil(W/PX);NH=Math.ceil(H/PX);if(!GL||GL.length!==NW*NH)GL=new Float32Array(NW*NH);else GL.fill(0);box=[NW,NH,-1,-1];
  const fx=()=>{trail(t);events(t);for(const h of heads(t))head(h.x,h.y,t,0)};
  PASS=1;fx();PASS=0;composeLight();fx()}
 // sources pour le calque d'éclairage d'ambiance (creusent l'obscurité autour de l'étincelle)
 function lights(){if(!S)return[];const t=tt(),L=heads(t).map(h=>({x:h.x/UNIT,z:h.y/UNIT,r:5}));if(t>=T4&&t<T4+.6)for(const b of S.branches){const e=b.pts.at(-1);L.push({x:e.x/UNIT,z:e.y/UNIT,r:6})}return L}
 return{start,reset,update,draw,active,lights}})();
