// ================= BÂTIMENTS SECONDAIRES v2 : Bibliothèque, Atelier, Forge, Entrepôt =================
// Assemblé avec le moteur de creuset-planches.js par tools/batiments-v2/build.py (voir batiments-v2-planches.js).
const AEC=['#34327a','#5a5cff','#9aa0ff','#e0e4ff'].map(E);
const WHC=['#8e8c94','#c8ccd8','#eef0f6','#ffffff'].map(E);
const BLUEC=R_(['#16244e','#20387c','#3054aa','#5a80d4','#9ab4ee']);
const REDC=R_(['#3e1010','#6a1a1a','#962828','#c44444','#e88080']);
const PARCH=R_(['#6e6250','#968a70','#bcb092','#ddd3b6','#f0e9d4']);
const PLASTER=R_(['#4e4a44','#6a645a','#868072','#a29a8a','#bab2a0']);
const VERDI=R_(['#17302c','#23463d','#305e4e','#427863','#5c937a']);
const CANVAS=R_(['#4a4234','#6a604a','#8a7e62','#a89c7c','#c4b896']);
const EARTH=R_(['#2a2018','#3a2c1e','#4c3a26','#5e4a30']);
const SPINE=R_(['#2e3a4c','#3e4c38','#5a4230','#4c3a3e','#6c6656','#3c4450','#5e5444']);
const WINW=E('#d6dae6'),WINV=E('#8c90f0');
const TERRE=R_(['#2c261e','#3a3228','#4a4032','#5a4e3c','#6a5c46']);

// ---------- heightfield : toits à pans, dômes, voûtes, cylindres couchés ----------
// o: {x,z,hw,hd,y0,ym,hf(lx,lz)->y|null,mat,th}
function hprism(L,o){const cx=o.x||0,cz=o.z||0,lo=o.y0-(o.th??.06),ym=o.ym,hf=o.hf,m=o.mat,st=.5/T,ep=.025;
 const sx0=Math.floor(OX+(cx-o.hw)*T)-1,sx1=Math.ceil(OX+(cx+o.hw)*T)+1,sy0=Math.floor(OY+(cz-o.hd-ym)*T)-1,sy1=Math.ceil(OY+(cz+o.hd-lo)*T)+1;
 const H=(lx,lz)=>Math.abs(lx)>o.hw||Math.abs(lz)>o.hd?null:hf(lx,lz);
 for(let sy=sy0;sy<=sy1;sy++)for(let sx=sx0;sx<=sx1;sx++){const lx=(sx+.5-OX)/T-cx;if(Math.abs(lx)>o.hw)continue;const s=(sy+.5-OY)/T-cz;let front=false,py=null;
  for(let y=ym;y>=lo-1e-6;y-=st){const lz=s+y;if(lz>o.hd){front=true;py=y;continue}if(lz<-o.hd)break;const h=H(lx,lz);
   if(h==null||h<y){front=false;py=y;continue}
   if(front&&h-y>.9/T){L.set(sx,sy,m({f:'side',x:lx,z:lz,y,v:(y-lo)/(ym-lo),b:.66,lip:h-y<1.6/T,foot:y<lo+1.2/T,n:[0,1],sx,sy,rad:Math.hypot(lx,lz),ang:Math.atan2(lz,lx)}));break}
   let hy=y;if(py!=null){let A=py,B=y;for(let k=0;k<7;k++){const mid=(A+B)/2,hm=H(lx,s+mid);if(hm!=null&&hm>=mid)B=mid;else A=mid}hy=B}
   const hz=s+hy,hh=H(lx,hz)??h,g=(dx,dz)=>{const p=H(lx+dx,hz+dz),q=H(lx-dx,hz-dz);return p==null||q==null?0:(p-q)/(2*(dx+dz))},gx=g(ep,0),gz=g(0,ep);
   if(Math.abs(gz)>9||Math.abs(gx)>9){L.set(sx,sy,m({f:'side',x:lx,z:hz,y:hy,v:(hy-lo)/(ym-lo),b:.66,lip:false,foot:false,n:[0,1],sx,sy,rad:Math.hypot(lx,hz),ang:Math.atan2(hz,lx)}));break}
   const nl=Math.hypot(gx,1,gz),d=(.5*gx+.75-.45*gz)/nl/1.007;
   L.set(sx,sy,m({f:'top',x:lx,z:hz,y:hh,gx,gz,b:.3+.62*Math.max(0,d),rim:false,eave:hh<o.y0+.04,ridge:hh>ym-.05,sx,sy,rad:Math.hypot(lx,hz),ang:Math.atan2(hz,lx)}));break}}}
const RF={
 gx:(hw,hd,y0,h)=>(lx,lz)=>y0+h*(1-Math.abs(lz)/hd),          // faîtage parallèle à x
 gz:(hw,hd,y0,h)=>(lx,lz)=>y0+h*(1-Math.abs(lx)/hw),          // faîtage parallèle à z (pignon en façade)
 hip:(hw,hd,y0,h)=>(lx,lz)=>y0+h*Math.min(hw-Math.abs(lx),hd-Math.abs(lz))/Math.min(hw,hd),
 pyr:(hw,hd,y0,h)=>(lx,lz)=>y0+h*Math.min(1-Math.abs(lx)/hw,1-Math.abs(lz)/hd),
 cone:(hw,hd,y0,h)=>(lx,lz)=>{const r=Math.hypot(lx/hw,lz/hd);return r>1?null:y0+h*(1-r)},
 dome:(hw,hd,y0,h)=>(lx,lz)=>{const r=Math.hypot(lx/hw,lz/hd);return r>1?null:y0+h*Math.sqrt(1-r*r)},
 bell:(hw,hd,y0,h)=>(lx,lz)=>{const r=Math.hypot(lx/hw,lz/hd);return r>1?null:y0+h*(1-r*r*r)},
 shed:(hw,hd,y0,h)=>(lx,lz)=>y0+h*(hd-lz)/(2*hd),             // monte vers le fond
 vault:(hw,hd,y0,h)=>(lx,lz)=>y0+h*Math.sqrt(Math.max(0,1-(lz/hd)**2)),
 logz:(hw,hd,y0)=>(lx,lz)=>{const r=hw;return Math.abs(lx)>r?null:y0+r+Math.sqrt(r*r-lx*lx)},
};
function roof(kind,x,z,hw,hd,y0,h,mat,o={}){return{key:o.key??z+hd,draw(L,S){if(o.shadow!==false&&!o.noShadow)S.shadowShape(rect(-hw,-hd,hw,hd),x,z,y0+h,o.shadow??.55);
 hprism(L,{x,z,hw,hd,y0,ym:y0+h+.02,hf:o.hf||RF[kind](hw,hd,y0,h,o.r),mat,th:o.th});return{lights:projL(o.lights)}}}}
// tuiles / bardeaux : rangs horizontaux (même hauteur), joints décalés
function shingle(R,o={}){const cw=o.cw??.15,jw=o.jw??.2,ax=o.axis||'x';return q=>{if(o.inlay){const c=o.inlay(q);if(c!=null)return c}
 if(q.f==='side')return o.side?o.side(q):rp(R,.5+(q.foot?-.2:.1),q.sx,q.sy);
 let b=q.b+(q.eave?.14:0)+(q.ridge?.12:0);const r=q.y/cw,row=Math.floor(r),f=r-row;if(f<.24)b-=.2;
 const w=ax==='x'?q.x:ax==='z'?q.z:q.ang*1.1,u=w/jw+(row&1)*.5;if(((u%1)+1)%1<.9/(T*jw))b-=.14;
 b+=(hash(Math.floor(u),row,o.seed||5)-.5)*.12;
 if(o.moss&&vnoise(q.x*2.5,q.z*2.5+q.y,61)>1-o.moss)return rp(MOSS,b*.85,q.sx,q.sy);return rp(R,b,q.sx,q.sy)}}
// bois : planches, poutres
function woodMat(R=WOOD,o={}){const w=o.w??.17;return q=>{if(o.inlay){const c=o.inlay(q);if(c!=null)return c}let b=q.f==='top'?.8+(q.rim?.1:0):q.b+(q.lip?.12:0)-(q.foot?.15:0);
 const u=q.f==='top'?(o.along==='z'?q.x:q.z):(o.horiz?q.y:q.x),f=((u/w)%1+1)%1;if(f<1/(T*w))b-=.24;
 b+=(hash(Math.floor(u/w),3,o.seed||2)-.5)*.16+(vnoise(q.x*11,q.y*4+q.z*11,5)-.5)*.1;return rp(R,b,q.sx,q.sy)}}
const frontI=fn=>q=>q.f==='side'&&q.n[1]>.5?fn(q):null;
// ouvertures en façade (coordonnées locales x, hauteur absolue y)
const archI=(cx,w,y0,y1,fill)=>frontI(q=>{const dx=q.x-cx;if(Math.abs(dx)>w||q.y<y0)return null;const top=y1-w+Math.sqrt(Math.max(0,w*w-dx*dx));if(q.y>top)return null;
 if(q.y>top-1.1/T||Math.abs(dx)>w-1.1/T)return rp(MARBLE,.9,q.sx,q.sy);return typeof fill==='function'?fill(q,dx):fill});
const rectI=(cx,w,y0,y1,fill)=>frontI(q=>{const dx=q.x-cx;if(Math.abs(dx)>w||q.y<y0||q.y>y1)return null;return typeof fill==='function'?fill(q,dx):fill});
const winFill=(c,mull=true)=>(q,dx)=>mull&&(Math.abs(dx)<.6/T)?rp(IRON,.3,q.sx,q.sy):c;
const doorFill=(R=WOOD)=>(q,dx)=>{let b=.5;if(((dx*T/3)%1+1)%1<.34)b-=.2;if(Math.abs(q.y%.3)<.04)b-=.1;return rp(R,b,q.sx,q.sy)};
// rayonnage de livres (ou de caisses) sur une façade : x0..x1 locaux, y0..y1 absolus
function booksI(x0,x1,y0,y1,rows,seed=1,o={}){return frontI(q=>{if(q.x<x0||q.x>x1||q.y<y0||q.y>y1)return null;const r=(q.y-y0)/(y1-y0)*rows,row=Math.floor(r),lv=r-row;
 if(lv<.16||Math.abs(q.x-x0)<1.2/T||Math.abs(q.x-x1)<1.2/T)return rp(o.frame||WOOD,lv<.08?.35:.62,q.sx,q.sy);
 const u=Math.floor((q.x-x0)*T/(o.w||2)+row*1.7),k=hash(u,row,seed),top=.16+.72*(.6+.4*hash(u,row+9,seed));
 if(o.crates){const cu=Math.floor((q.x-x0)*T/6+row*.5),ck=hash(cu,row,seed),lx=((q.x-x0)*T/6+row*.5)-cu;if(ck<.2||lv>.86)return rp(DSTONE,.15,q.sx,q.sy);const R=ck>.86?BLUEC:ck>.76?REDC:WOOD;
  return rp(R,(lx<.17||lx>.83||lv<.24||lv>.78)?.75:.45+(Math.abs(lx-.5)-Math.abs(lv-.5)<.05&&Math.abs(lx-.5)-Math.abs(lv-.5)>-.05&&R===WOOD?.15:0),q.sx,q.sy)}
 if(lv>top||k<.08)return rp(DSTONE,.12,q.sx,q.sy);if(o.scrolls)return rp(PARCH,.55+(Math.hypot(((q.x-x0)*T/3)%1-.5,(lv-.5)*2)<.3?.3:0),q.sx,q.sy);
 const c=SPINE[Math.floor(k*SPINE.length)];const fx=((q.x-x0)*T/(o.w||2))%1;return sh(c,fx<.5?.12:-.12)})}

// ---------- accessoires ----------
function box(x,z,hw,hd,y0,y1,mat,o={}){return slab(rect(-hw,-hd,hw,hd),y0,y1,mat,{x,z,...o})}
function post(x,z,y1,R=WOOD,w=.06,y0=0){return slab(square(w),y0,y1,woodMat(R),{x,z,key:z+.001})}
function crateMat(s,R=WOOD){return q=>{const b=q.f==='top'?.84:q.b,a=q.x/s,c=q.f==='top'?q.z/s:(q.v-.5)*2;if(Math.abs(a)>.74||Math.abs(c)>.74)return rp(R,b+.1,q.sx,q.sy);
 if(Math.abs(a-c)<.14)return rp(R,b+.04,q.sx,q.sy);return rp(R,b-.16+(hash(q.sx,q.sy>>1,4)-.5)*.1,q.sx,q.sy)}}
function crate(x,z,s=.17,y0=0,R=WOOD){return slab(square(s),y0,y0+s*1.7,crateMat(s,R),{x,z})}
function chestMat(R){return q=>{const b=q.f==='top'?.82:q.b;if(q.f==='side'){if(Math.abs(q.x)>.15||Math.abs(q.x)<.025)return rp(IRON,b+.1,q.sx,q.sy);if(Math.abs(q.v-.62)<.06)return rp(IRON,.3,q.sx,q.sy);if(Math.abs(q.x)<.06&&q.v>.38&&q.v<.58)return rp(SILVER,.8,q.sx,q.sy)}
 else if(Math.abs(q.x)>.15||Math.abs(q.x)<.025)return rp(IRON,b,q.sx,q.sy);return rp(R,b,q.sx,q.sy)}}
function chest(x,z,R){return slab(rect(-.19,-.12,.19,.12),0,.27,chestMat(R),{x,z})}
function barrel(x,z,R=WOOD,o={}){return slab(circle(o.r||.15),o.y0||0,(o.y0||0)+(o.h||.42),q=>{if(q.f==='top')return o.water?(q.rad<(o.r||.15)*.75?rp(WATER,.6+(hash(q.sx,q.sy,2)-.5)*.4,q.sx,q.sy):rp(R,.8,q.sx,q.sy)):rp(R,q.rim?.9:.62,q.sx,q.sy);
 if(Math.abs(q.v-.2)<.06||Math.abs(q.v-.8)<.06)return rp(IRON,q.b+.1,q.sx,q.sy);return rp(R,q.b+(Math.abs(q.v-.5)<.3?.06:0)+(((q.ang*6/Math.PI)%1+1)%1<.15?-.15:0),q.sx,q.sy)},{x,z})}
function planks(x,z,n=4,len=.5,o={}){return{key:z,draw(L,S){S.shadowShape(rect(-len,-.14,len,.14),x,z,n*.05,.6);for(let k=0;k<n;k++){const dx=(hash(k,1,o.seed||3)-.5)*.08;
 prism(L,rect(-len+dx,-.13,len+dx,.13),{x,z,y0:k*.055,y1:k*.055+.05,mat:woodMat(o.R||WOOD,{along:'x'})})}return{}}}}
function logs(x,z,n=3,len=.4){const objs=[];for(let k=0;k<n;k++){const lx=x+(k-(n-1)/2)*.2,y0=0;objs.push(roof('logz',lx,z,.1,len,y0,.2,logMat,{key:z+len+k*.001,noShadow:1,th:0}))}
 if(n>2)objs.push(roof('logz',x,z-.02,.1,len,.17,.2,logMat,{key:z+len+.01,noShadow:1,th:0}));return objs}
const logMat=q=>{if(q.f==='side'){const r=Math.hypot(q.x,q.y-(q.y>0?0:0));return rp(SAND,.5+((Math.floor(q.x*T*.6+q.y*T*.6)&1)?.12:-.05),q.sx,q.sy)}return rp(BARK,q.b-.05+(hash(q.sx,q.sy>>1,7)>.7?.15:0),q.sx,q.sy)};
function lectern(x,z,o={}){return{key:z,draw(L,S){const[a,b]=P3(x,o.y0||0,z);S.shadowEll(a+3,b,6,2,.7);prism(L,square(.05),{x,z,y0:o.y0||0,y1:(o.y0||0)+.42,mat:woodMat(WOOD)});
 prism(L,rect(-.16,-.1,.16,.1),{x,z,y0:(o.y0||0)+.42,y1:(o.y0||0)+.5,mat:woodMat(WOOD)});const[c,d]=P3(x,(o.y0||0)+.5,z);const C_=Math.round(c),D=Math.round(d);
 for(let j=-2;j<=1;j++)for(let i=-4;i<=4;i++)if(i)L.set(C_+i,D+j,rp(PARCH,.85-Math.abs(i)*.05-(j+2)*.04,i,j));L.set(C_,D-2,PARCH[1]);L.set(C_,D-1,PARCH[1]);return{}}}}
function sawhorse(x,z){return{key:z,draw(L,S){const[a,b]=P3(x,0,z);S.shadowEll(a+3,b,10,3,.6);const A=Math.round(a),B=Math.round(b);
 for(const s of[-7,6]){L.line(A+s-2,B,A+s,B-7,WOOD[2]);L.line(A+s+2,B,A+s,B-7,WOOD[3])}L.rect(A-9,B-9,19,2,WOOD[4]);L.rect(A-9,B-7,19,1,WOOD[1]);return{}}}}
function lanternHang(x,y,z,c=WHC,lc=WHITEC,R=IRON){return{key:z+.02,draw(L){const[a,b]=P3(x,y,z),A=Math.round(a),B=Math.round(b);L.rect(A,B,1,3,R[2]);L.rect(A-1,B+3,3,4,c[2]);L.set(A,B+4,c[3]);L.rect(A-1,B+3,3,1,R[3]);L.rect(A-1,B+7,3,1,R[2]);
 return{lights:[{x:A,y:B+5,r:34,i:.75,c:lc,fl:.08}]}}}}
function candleDyn(x,y,z,kind='white'){const[a,b]=P3(x,y,z);return flameDyn(Math.round(a),Math.round(b),kind,.6)}

// ---------- animations ----------
const sparkC=(cx,cy,cols,n=10,seed=1,up=14,spread=9,period=0,win=.5)=>{const c=cols.map(E);return(F,t)=>{if(period&&(t%period)>win*period)return;for(let k=0;k<n;k++){const per=period||6/Math.round(6/(.9+hash(k,3,seed)*.7)),p=period?(t%period)/(win*period):((t+hash(k,1,seed)*per)%per)/per,vx=(hash(k,2,seed)-.5)*spread*2,vy=up*(.6+hash(k,4,seed)*.6);
 const x=Math.round(cx+vx*p),y=Math.round(cy-vy*p+vy*1.4*p*p);if(p<.85)F.set(x,y,c[p<.25?c.length-1:p<.55?c.length-2:c.length-3])}}};
function wheelDyn(cx,cy,r,n,speed,R=WOOD,o={}){return(F,t)=>{const a0=t*speed;for(let k=0;k<n;k++){const a=a0+k*2*Math.PI/n;for(let s=2;s<r-1;s++)F.set(Math.round(cx+Math.cos(a)*s),Math.round(cy+Math.sin(a)*s*(o.sq||1)),R[3])}
 for(let k=0;k<72;k++){const a=k*2*Math.PI/72,x=Math.round(cx+Math.cos(a)*r),y=Math.round(cy+Math.sin(a)*r*(o.sq||1));F.set(x,y,Math.sin(a)<-.2?R[4]:R[2]);if(o.thick){F.set(Math.round(cx+Math.cos(a)*(r-1)),Math.round(cy+Math.sin(a)*(r-1)*(o.sq||1)),R[1])}
  if(o.teeth&&k%6===0)F.set(Math.round(cx+Math.cos(a+a0)*(r+1)),Math.round(cy+Math.sin(a+a0)*(r+1)*(o.sq||1)),R[3])}
 F.set(Math.round(cx),Math.round(cy),IRON[5]);F.set(Math.round(cx)+1,Math.round(cy),IRON[3])}}
function bladeDyn(cx,cy,r,speed){return(F,t)=>{for(let k=0;k<40;k++){const a=k*2*Math.PI/40;F.set(Math.round(cx+Math.cos(a)*r),Math.round(cy+Math.sin(a)*r*.45),SILVER[(k+Math.floor(t*speed))%4<2?4:2])}
 for(let i=-r+1;i<r;i++)F.set(Math.round(cx+i),Math.round(cy),SILVER[2]);F.set(Math.round(cx),Math.round(cy),IRON[1])}}
// marteau à bascule : pivot (px,py), tête au bout du bras ; frappe toutes les `per` s
function hammerDyn(px,py,len,per=1.1,dir=1,o={}){return(F,t)=>{const rest=o.rest??.12,amp=o.amp??.8,u=(t%per)/per,ang=u<.7?rest-amp*Math.sin(u/.7*Math.PI/2):rest-amp+amp*Math.min(1,(u-.7)/.12),c=Math.cos(ang),s=Math.sin(ang);
 const ex=px+dir*c*len,ey=py+s*len;F.line(Math.round(px),Math.round(py),Math.round(ex),Math.round(ey),WOOD[4]);F.line(Math.round(px),Math.round(py)+1,Math.round(ex),Math.round(ey)+1,WOOD[2]);
 for(let j=-2;j<=3;j++)for(let i=-2;i<=2;i++)F.set(Math.round(ex)+i,Math.round(ey)+j,j<0?IRON[5]:i<0?IRON[4]:IRON[2]);
 if(u>.82&&u<.95){const k=(u-.82)/.13;for(let m=0;m<8;m++){const a=-Math.PI*(.1+.8*hash(m,1,7)),r=2+k*9*hash(m,2,7);F.set(Math.round(ex+Math.cos(a)*r),Math.round(ey+4+Math.sin(a)*r*.7),(o.cols||MOLT)[m%2?3:4])}}}}
function hoistDyn(ax,ay,len,per=6,o={}){return(F,t)=>{const u=(t%per)/per,p=u<.4?u/.4:u<.5?1:u<.9?1-(u-.5)/.4:0,e=p*p*(3-2*p),y=Math.round(ay+(1-e)*len),sw=Math.round(Math.sin(t*2.3)*(o.sway||0));
 for(let j=ay;j<y-4;j++)F.set(ax+(j>ay+len*.6?sw:0),j,IRON[1]);const cx=ax+sw;for(let j=0;j<6;j++)for(let i=-3;i<=3;i++){const edge=Math.abs(i)===3||j===0||j===5;F.set(cx+i,y-4+j,o.cargo?o.cargo[edge?3:1]:edge?WOOD[4]:(i===j-2||i===2-j)?WOOD[3]:WOOD[2])}}}
function pageDyn(cx,cy,n=5,seed=3,h=26){return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.22+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*22+Math.sin(t*1.7+k*2)*4),y=Math.round(cy-p*h),fl=Math.floor(t*6+k)%3;
 if(p>.9)continue;const C_=p>.7?PARCH[2]:PARCH[4];if(fl===0){F.set(x-1,y,C_);F.set(x,y,C_);F.set(x+1,y,C_)}else if(fl===1){F.set(x-1,y-1,C_);F.set(x,y,C_);F.set(x+1,y-1,C_)}else{F.set(x,y,C_);F.set(x,y-1,C_)}}}}
function dustDyn(cx,cy,n=6,seed=4){return(F,t)=>{for(let k=0;k<n;k++){const p=((t*.5+hash(k,1,seed))%1),x=Math.round(cx+(hash(k,2,seed)-.5)*12+p*4),y=Math.round(cy-p*7+p*p*9);if(p<.8)F.set(x,y,SAND[k%2?5:4])}}}
function steamDyn(cx,cy,h=18,seed=5){const G=R_(['#8a8e98','#a8acb6','#c4c8d0']);return(F,t)=>{for(let k=0;k<6;k++){const p=((t*.4+hash(k,1,seed))%1),x=Math.round(cx+Math.sin(t*1.4+k)*2+(hash(k,3,seed)-.5)*6),y=Math.round(cy-p*h);if(p<.85&&hash(k,Math.floor(t*3),seed)>.2)F.set(x,y,G[p<.3?2:p<.6?1:0])}}}
const at=(x,y,z)=>{const[a,b]=P3(x,y,z);return[Math.round(a),Math.round(b)]};
const fx=(key,fn)=>({key,draw(){return fn()}});

// matériaux de base
const mMat=o=>stone(MARBLE,{veins:1,noise:.06,...o});
const sMat=o=>stone(SLATE,{courses:.2,joint:.6,noise:.1,...o});
const dMat=o=>stone(DSTONE,{courses:.18,joint:.45,noise:.12,...o});
const pMat=o=>stone(PLASTER,{noise:.1,...o});
const plinth=(R=SLATE,h=.12,s=1.28)=>slab(square(s),0,h,stone(R,{noise:.08}),{key:-9});

const GROUPS=[
 {id:'library',name:'Bibliothèque',staff:'Sigil',note:'Servie par les Livres ailés de Sigil : marbre gris veiné peu éclatant, ardoise, parchemin, lumière blanche. On y fait les recherches (Sceau de minage, Minicarte, Poste de tir, Arbalestrie).'},
 {id:'workshop',name:'Atelier',staff:'Aether',note:'Servi par les Orrery d’Aether : bois de charpente, fer, outils ; lueur bleu-violet. On y fabrique les défenses (poste de tir, barricade, chausse-trappes) et les pièces.'},
 {id:'forge',name:'Forge',staff:'Aether',note:'Servie par les Orrery d’Aether : pierre noircie, fer, feu bleu-violet (le feu d’Aether, comme la forge actuelle) ; le métal chauffé reste orangé.'},
 {id:'warehouse',name:'Entrepôt logistique',staff:'Sigil',note:'Servi par les Livres ailés de Sigil : caisses, coffres bleus et rouges, marbre et ardoise. Les adeptes y prennent et y déposent les objets.'}];

const ITEMS=[
// ======================= BIBLIOTHÈQUE =======================
 {g:'library',name:'Rotonde des rouleaux',desc:'Un tambour de marbre veiné coiffé d’un dôme d’ardoise et d’une lanterne de quartz. Entre les pilastres, des alvéoles garnies de rouleaux ; porte en arc au centre, pupitre devant. Des feuillets s’échappent de la lanterne.',
  build(){const drum=q=>{if(q.f!=='side')return null;const a=((q.ang*8/Math.PI)%2+2)%2;if(Math.abs(q.ang-Math.PI/2)<.32){return null}
    if(a<.22)return rp(MARBLE,q.b+.2,q.sx,q.sy);if(q.v>.25&&q.v<.78){const r=(q.v-.25)/.53*4,lv=r-Math.floor(r);if(lv<.18)return rp(WOOD,.5,q.sx,q.sy);return rp(PARCH,.5+(((q.sx*3+q.sy*7)%5)<2?.28:0),q.sx,q.sy)}return null};
   const door=q=>q.f==='side'&&Math.abs(q.ang-Math.PI/2)<.32?(q.y<.98&&Math.abs(q.ang-Math.PI/2)<.24-(q.y>.82?(q.y-.82)*1.3:0)?doorFill()(q,(q.ang-Math.PI/2)*.9):rp(MARBLE,q.b+.15,q.sx,q.sy)):null;
   const objs=[slab(poly(8,1.32,Math.PI/8),0,.14,stone(MARBLE,{noise:.06}),{key:-9}),slab(circle(.98),.14,.22,mMat(),{key:-8}),
    slab(circle(.9),.22,1.38,mMat({inlay:anyI(door,drum),trim:{R:MARBLE,v0:.9,v1:1}}),{key:-1}),
    roof('dome',0,0,1.0,1.0,1.38,.55,shingle(SLATE,{axis:'r',cw:.12}),{key:1,noShadow:1}),
    slab(circle(.17),1.86,2.14,stone(QZ,{noise:.05,inlay:q=>q.f==='side'&&((q.ang*4/Math.PI)%1+1)%1<.3?rp(MARBLE,.8,q.sx,q.sy):(q.f==='side'?WHC[2]:null)}),{key:2,lights:[{x:0,y:2.0,z:0,r:46,i:.8,c:WHITEC}]}),
    slab(circle(.2),2.14,2.26,stone(SLATE),{key:2.1,taper:[1,.2]}),
    slab(rect(-.3,-.12,.3,.12),.14,.2,stone(MARBLE),{z:1.0,key:.5}),lectern(.78,.9),barrel(-.86,.86,WOOD,{h:.32}),
    fx(3,()=>{const[a,b]=at(0,2.1,0);return{dyn:pageDyn(a,b,6,2,30)}})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Galerie à portique',desc:'Le plan d’un petit temple : fronton d’ardoise sur quatre colonnes de marbre, et derrière elles le mur du fond tapissé de rayonnages. On lit les livres depuis la rue. Deux veilleuses blanches sur les marches.',
  build(){const objs=[slab(rect(-1.28,-1.28,1.28,1.28),0,.12,stone(MARBLE,{noise:.06}),{key:-9}),slab(rect(-1.15,.55,1.15,1.05),.12,.24,stone(MARBLE,{noise:.06}),{key:-8}),
    box(0,-.45,1.1,.62,.12,1.32,mMat({inlay:anyI(booksI(-1.0,1.0,.3,1.22,3,4),rectI(0,1.1,.12,.3,()=>rp(MARBLE,.75,0,0)))}),{key:-1}),
    ...[-.9,-.3,.3,.9].map(cx=>column(cx,.78,1.32,MARBLE)),
    roof('gz',0,-.18,1.24,1.1,1.32,.55,shingle(SLATE,{axis:'z',cw:.13,side:q=>Math.hypot(q.x,q.y-1.5)<.11?(Math.hypot(q.x,q.y-1.5)<.07?WINW:rp(MARBLE,.95,q.sx,q.sy)):rp(MARBLE,.72+(q.lip?.15:0),q.sx,q.sy)}),{key:2,noShadow:1}),
    box(0,.86,1.26,.07,1.24,1.34,mMat(),{key:2.5}),
    column(-.95,1.18,.36,MARBLE,{flame:'white',light:WHITEC}),column(.95,1.18,.36,MARBLE,{flame:'white',light:WHITEC}),
    fx(3,()=>{const[a,b]=at(0,.9,.2);return{dyn:pageDyn(a,b,3,6,16),lights:[{x:a,y:b,r:50,i:.4,c:WHITEC}]}})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Tour du scribe',desc:'Une tour carrée de marbre à toit pyramidal d’ardoise, fenêtre haute éclairée où travaille le copiste ; à ses pieds une annexe basse à toit en appentis, porte ouverte sur des étagères. La plus verticale : elle se repère de loin.',
  build(){const objs=[plinth(SLATE,.1),
    box(-.42,-.42,.55,.55,.1,2.25,mMat({inlay:anyI(archI(0,.17,1.45,1.95,winFill(WINW)),archI(0,.13,.7,1.05,winFill(WINW)),frontI(q=>Math.abs(q.y-1.32)<.04?rp(MARBLE,.92,q.sx,q.sy):null))}),{key:-.4,lights:[{x:-.42,y:1.7,z:.2,r:40,i:.7,c:WHITEC}]}),
    roof('pyr',-.42,-.42,.68,.68,2.25,.78,shingle(SLATE,{axis:'r',cw:.13}),{key:.4,noShadow:1}),
    slab(square(.05),3.03,3.2,stone(IRON),{x:-.42,z:-.42,key:.5}),
    box(.62,.2,.55,.62,.1,.95,sMat({inlay:anyI(rectI(-.05,.3,.1,.75,q=>booksI(-.32,.22,.12,.74,2,9)(q)??rp(DSTONE,.2,q.sx,q.sy)))}),{key:.6}),
    roof('shed',.62,.2,.66,.72,.95,.42,woodMat(WOOD,{along:'x'}),{key:1,noShadow:1,th:.05}),
    crate(.15,1.05,.14),crate(-.12,1.12,.12),lectern(-.9,.8),lanternHang(.25,.86,.92),
    fx(2,()=>{const[a,b]=at(-.42,1.7,.14);return{dyn:pageDyn(a,b-8,3,8,18)}})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Cloître aux rayonnages',desc:'Pas de toit fermé : trois murs-bibliothèques en U, chacun sous un auvent d’ardoise, entourent une table de lecture où un grand livre reste ouvert. Les pages tournent toutes seules et des feuillets flottent au-dessus.',
  build(){const ob=q=>q.f==='top'&&Math.abs(q.x)<.28&&Math.abs(q.z)<.18?(Math.abs(q.x)<.02?PARCH[1]:rp(PARCH,.85-Math.abs(q.x)*.6,q.sx,q.sy)):null;
   const objs=[slab(square(1.3),0,.1,stone(MARBLE,{noise:.06,pave:q=>(Math.floor(q.x/.33)+Math.floor(q.z/.33))&1?.06:0}),{key:-9}),
    box(0,-1.02,1.22,.2,.1,1.15,mMat({inlay:booksI(-1.12,1.12,.2,1.08,3,11)}),{key:-1}),
    roof('shed',0,-1.02,1.3,.3,1.15,.25,shingle(SLATE,{cw:.1}),{key:-.7,noShadow:1}),
    box(-1.08,0,.18,.85,.1,1.0,mMat({inlay:booksI(-.12,.12,.2,.95,3,5)}),{key:.85}),box(1.08,0,.18,.85,.1,1.0,mMat({inlay:booksI(-.12,.12,.2,.95,3,6)}),{key:.85}),
    roof('gz',-1.08,0,.26,.92,1.0,.2,shingle(SLATE,{axis:'z',cw:.1}),{key:.95,noShadow:1}),roof('gz',1.08,0,.26,.92,1.0,.2,shingle(SLATE,{axis:'z',cw:.1}),{key:.95,noShadow:1}),
    box(0,.1,.42,.28,.1,.5,woodMat(WOOD,{inlay:ob}),{key:.3,lights:[{x:0,y:.6,z:.1,r:48,i:.6,c:WHITEC}]}),
    fx(.9,()=>{const[a,b]=at(0,.5,.1);return{dyn:(F,t)=>{const u=(t%3)/3;if(u<.35){const p=u/.35,w=Math.round(Math.cos(p*Math.PI)*6);for(let j=0;j<4;j++)F.set(a+w,b-1-j-Math.round(Math.sin(p*Math.PI)*3),PARCH[4])}pageDyn(a,b-6,5,4,26)(F,t)}}}),
    column(-.75,.95,.6,MARBLE,{flame:'white',light:WHITEC}),column(.75,.95,.6,MARBLE,{flame:'white',light:WHITEC})];
   return{ground:floor(),objs}}},
 {g:'library',name:'Archive en gradins',desc:'Trois gradins de marbre dont chaque contremarche est un rayonnage de livres et de rouleaux ; un escalier au milieu mène au pupitre du sommet, où un grand livre lévite dans un rai de lumière blanche.',
  build(){const objs=[slab(square(1.24),0,.62,mMat({inlay:anyI(rectI(0,.16,.1,.62,q=>rp(MARBLE,.55+((q.y*T/3|0)&1?.2:0),q.sx,q.sy)),booksI(-1.14,-.2,.08,.56,2,2),booksI(.2,1.14,.08,.56,2,3,{scrolls:1}))}),{key:-3}),
    slab(square(.88),.62,1.12,mMat({inlay:anyI(rectI(0,.16,.62,1.12,q=>rp(MARBLE,.55+((q.y*T/3|0)&1?.2:0),q.sx,q.sy)),booksI(-.8,-.2,.68,1.08,2,7,{scrolls:1}),booksI(.2,.8,.68,1.08,2,8))}),{key:-2}),
    slab(square(.55),1.12,1.55,mMat({inlay:booksI(-.48,.48,1.17,1.5,2,12)}),{key:-1}),
    slab(square(.6),1.55,1.62,stone(MARBLE),{key:-.5}),lectern(0,0,{y0:1.62}),
    fx(1,()=>{const[a,b]=at(0,2.15,0);return{lights:[{x:a,y:b,r:58,i:.9,c:WHITEC}],dyn:(F,t)=>{const bob=Math.round(Math.sin(t*1.8)*1.5),y=b+bob;
     for(let j=-24;j<12;j++)if(hash(j,Math.floor(t*4),5)>.55)F.set(a+((j*7)%5)-2,y+j,WHC[1]);for(let i=-6;i<=6;i++)for(let j=-2;j<=1;j++)if(i)F.set(a+i,y+j-Math.round(Math.abs(i)*.25),rp(PARCH,.9-Math.abs(i)*.04,i,j));F.set(a,y-1,PARCH[1]);F.set(a,y,PARCH[1]);
     pageDyn(a,y-4,4,13,20)(F,t)}}})];
   return{ground:floor(),objs}}},
// ======================= ATELIER =======================
 {g:'workshop',name:'Hangar de charpente',desc:'Une charpente ouverte : quatre poteaux, un toit à pignon en bardeaux de bois. Dessous, l’établi et ses outils ; devant, un rondin sur chevalet qu’on scie (sciure), une pile de planches et de pieux. Lanterne d’Aether au faîtage.',
  build(){const objs=[slab(square(1.28),0,.08,woodMat(WOOD,{along:'x'}),{key:-9}),
    box(0,-.95,1.05,.12,.08,.95,woodMat(WOOD,{inlay:frontI(q=>{const k=Math.floor((q.x+1)*4.2);if(q.y>.45&&q.y<.8&&((q.x+1)*4.2)%1<.25)return rp(IRON,.75,q.sx,q.sy);if(q.y>.5&&q.y<.78&&k%3===1&&Math.abs(((q.x+1)*4.2)%1-.5)<.25)return rp(WOOD,.9,q.sx,q.sy);return null})}),{key:-1}),
    box(-.1,-.55,.7,.22,.08,.48,woodMat(WOOD,{along:'x'}),{key:-.4}),
    post(-1.08,-.9,1.25),post(1.08,-.9,1.25),post(-1.08,.75,1.25),post(1.08,.75,1.25),
    roof('gz',0,-.15,1.3,.98,1.25,.7,shingle(BARK,{axis:'z',cw:.12,side:q=>Math.abs(q.x)<.05||Math.abs(q.y-1.42)<.035?rp(WOOD,.8,q.sx,q.sy):rp(DSTONE,.18,q.sx,q.sy)}),{key:2,noShadow:1}),
    lanternHang(0,1.5,.85,AEC,VIOBLUE),
    sawhorse(.35,.9),roof('logz',.35,.9,.55,.11,.34,.22,logMat,{hf:(lx,lz)=>Math.abs(lx)>.55||Math.abs(lz)>.11?null:.34+.11+Math.sqrt(Math.max(0,.0121-lz*lz)),key:1.2,noShadow:1,th:0}),
    planks(-.8,.95,5,.38),post(-.25,1.05,.55,WOOD,.035),post(-.15,1.08,.62,WOOD,.035),
    fx(1.3,()=>{const[a,b]=at(.35,.38,.92);return{dyn:(F,t)=>{dustDyn(a,b+3,7,4)(F,t);const s=Math.round(Math.sin(t*6)*3);for(let i=0;i<6;i++)F.set(a+s+i-2,b-3-Math.round(i*.3),SILVER[i%2?2:4])}}})];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Atelier des instruments',desc:'Une maison de pierre au toit d’ardoise ; sur le faîtage tourne une petite sphère armillaire d’Aether qui sert de girouette. Fenêtre bleu-violet, porte de bois, établi extérieur avec étau et caisse de pièces.',
  build(){const objs=[plinth(SLATE,.1),
    box(0,-.3,1.05,.72,.1,1.0,dMat({inlay:anyI(rectI(-.45,.19,.1,.78,doorFill()),rectI(.42,.27,.42,.75,winFill(WINV)))}),{key:-1,lights:[{x:.42,y:.6,z:.45,r:40,i:.65,c:VIOBLUE}]}),
    roof('gx',0,-.3,1.16,.86,1.0,.72,shingle(SLATE,{cw:.13,moss:.12}),{key:1,noShadow:1}),
    slab(square(.04),1.72,2.02,stone(IRON),{z:-.3,key:1.2}),
    fx(1.3,()=>{const[a,b]=at(0,2.12,-.3);return{lights:[{x:a,y:b,r:30,i:.6,c:VIOBLUE}],dyn:(F,t,S)=>{ringDyn(a,b,7,['#5a5cff','#9aa0ff','#e0e4ff'],1.1)(F,t,S);ringDyn(a,b,5,['#34327a','#9aa0ff','#e0e4ff'],-.7)(F,t,S);F.set(a,b,AEC[3]);F.set(a,b-1,AEC[2])}}}),
    box(.75,.85,.36,.18,0,.4,woodMat(WOOD,{along:'x'}),{key:.85}),slab(rect(-.07,-.05,.07,.05),.4,.52,stone(IRON),{x:.55,z:.85,key:.9}),
    crate(-.78,.82,.17),crate(-.42,.95,.13),slab(circle(.06),.4,.44,stone(SILVER),{x:.88,z:.85,key:.91})];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Établi sous auvent',desc:'Un mur de pierre sèche porte le panneau d’outils ; devant, un auvent de toile tendu sur deux perches. Un tour à pédale fait tourner sa grande roue, des copeaux volent. Fagots de pieux et rouleau de corde pour les barricades.',
  build(){const tools=frontI(q=>{if(q.y<.35||q.y>.95)return null;const u=(q.x+1)*3.3,k=Math.floor(u),f=u-k;if(k<0||k>5)return null;if(k%2===0)return Math.abs(f-.5)<.08&&q.y<.9?rp(WOOD,.8,q.sx,q.sy):Math.abs(f-.5)<.25&&q.y>.82&&q.y<.9?rp(IRON,.85,q.sx,q.sy):null;return Math.abs(f-.5)<.06&&q.y>.45?rp(SILVER,.8,q.sx,q.sy):Math.abs(f-.5)<.2&&q.y<.5&&q.y>.42?rp(WOOD,.6,q.sx,q.sy):null});
   const stripe=q=>q.f==='top'?rp(((Math.floor((q.x+2)*3.5))&1)?CANVAS:R_(['#33345e','#43457a','#575aa0','#7174c4','#9396dc']),q.b+(q.eave?.1:0),q.sx,q.sy):rp(CANVAS,.5,q.sx,q.sy);
   const objs=[slab(square(1.28),0,.08,stone(TERRE,{noise:.14}),{key:-9}),
    box(0,-1.0,1.2,.22,.08,1.1,stone(MSTONE,{courses:.16,joint:.3,noise:.18,moss:.1,inlay:tools}),{key:-1}),
    post(-1.05,.05,1.12,WOOD,.05),post(1.05,.05,1.12,WOOD,.05),
    roof('shed',0,-.55,1.25,.62,1.08,.3,stripe,{key:.2,noShadow:1,th:.03,hf:(lx,lz)=>1.08+.3*(.62-lz)/1.24-.03*Math.sin((lx+1.25)*Math.PI*2.4)**2}),
    box(.2,-.45,.6,.2,.08,.46,woodMat(WOOD,{along:'x'}),{key:-.6}),box(-.7,.45,.2,.14,.08,.38,woodMat(WOOD),{key:.4}),
    fx(.6,()=>{const[a,b]=at(-.82,.62,.45);return{dyn:(F,t)=>{wheelDyn(a,b,8,6,2.2,WOOD,{thick:1})(F,t);dustDyn(a+12,b+2,5,8)(F,t);F.line(a+9,b-1,a+14,b-1,WOOD[4]);F.set(a+15,b-1,IRON[4])}}}),
    ...logs(.72,.7,3,.3),slab(circle(.13),.08,.2,stone(SAND,{noise:.2,inlay:ringI(.06,.03,SAND[1])}),{x:-.2,z:.95}),
    lanternHang(.95,1.02,.05,AEC,VIOBLUE)];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Chantier à la grue',desc:'Une petite remise de planches et, à côté, une grue de bois qui hisse une poutre : la poutre monte, se balance, redescend. Tas de madriers, chevalet, caisse de clous. Raconte « on construit les défenses ici ».',
  build(){const objs=[plinth(TERRE,.06,1.3),
    box(-.55,-.6,.62,.55,.06,.95,woodMat(WOOD,{inlay:rectI(.05,.22,.06,.7,q=>rp(DSTONE,.15,q.sx,q.sy))}),{key:-.8}),
    roof('gx',-.55,-.6,.72,.68,.95,.5,shingle(SLATE,{cw:.12}),{key:.1,noShadow:1}),
    post(.78,-.65,2.05,WOOD,.07),box(.78,-.65,.12,.12,0,.18,stone(SLATE),{key:-.6}),
    fx(-.5,()=>{const[a,b]=at(.78,2.0,-.65);return{dyn:(F,t)=>{F.line(a-3,b,a+22,b+2,WOOD[4]);F.line(a-3,b+1,a+22,b+3,WOOD[2]);F.line(a,b+1,a+20,b+3,WOOD[1]);F.line(a+1,b,a+1,b-3,IRON[3]);F.line(a+1,b-3,a+21,b+1,IRON[2]);
     const u=(t%7)/7,p=u<.4?u/.4:u<.55?1:u<.95?1-(u-.55)/.4:0,e=p*p*(3-2*p),y=Math.round(b+38-e*28),sw=Math.round(Math.sin(t*2.1)*1.6*e);for(let j=b+3;j<y;j++)F.set(a+20+(j>b+12?sw:0),j,IRON[1]);
     for(let i=-9;i<=9;i++)for(let j=0;j<3;j++)F.set(a+20+sw+i,y+j,j===0?WOOD[5]:WOOD[j===2?1:3]);F.set(a+20+sw,y-1,IRON[4])}}}),
    planks(.15,.95,6,.45,{seed:7}),...logs(-.75,.6,3,.35),crate(.95,.75,.14),sawhorse(.55,.25)];
   return{ground:floor(),objs}}},
 {g:'workshop',name:'Roue de l’atelier',desc:'Une grande roue à rayons, à hauteur d’homme, tourne contre le pignon de l’atelier et entraîne une scie circulaire sur l’établi : copeaux et étincelles bleutées. Le mécanisme fait le spectacle, même vu de loin.',
  build(){const objs=[plinth(SLATE,.1),
    box(.25,-.55,.95,.62,.1,.95,dMat({inlay:anyI(rectI(.45,.2,.1,.72,doorFill()),rectI(-.25,.18,.45,.72,winFill(WINV)))}),{key:-1,lights:[{x:0,y:.6,z:.1,r:36,i:.55,c:VIOBLUE}]}),
    roof('gz',.25,-.55,1.05,.72,.95,.62,shingle(SLATE,{axis:'z',cw:.12,side:q=>rp(WOOD,.55+(((q.x*T/3)|0)&1?.08:-.06),q.sx,q.sy)}),{key:.2,noShadow:1}),
    box(.35,.55,.62,.2,.1,.48,woodMat(WOOD,{along:'x'}),{key:.55}),
    box(-.98,.05,.08,.12,.1,.85,woodMat(WOOD),{key:.04}),
    fx(.6,()=>{const[a,b]=at(-1.0,.85,.12);const[c,d]=at(.35,.48,.55);return{lights:[{x:c,y:d-2,r:24,i:.5,c:VIOBLUE}],dyn:(F,t)=>{wheelDyn(a,b,15,8,1.1,WOOD,{thick:1,teeth:1})(F,t);
     F.line(a,b,c-6,d-2,IRON[3]);bladeDyn(c,d-1,5,10)(F,t);sparkC(c+4,d-2,['#34327a','#9aa0ff','#e0e4ff'],7,3,8,7)(F,t);dustDyn(c-5,d,4,2)(F,t)}}}),
    planks(.75,1.05,3,.32),crate(-.4,1.0,.13),barrel(-.55,.62,WOOD,{h:.36,r:.13})];
   return{ground:floor(),objs}}},
// ======================= FORGE =======================
 {g:'forge',name:'Forge à hotte',desc:'Un foyer ouvert sous une immense hotte de pierre qui se resserre en cheminée : le feu bleu-violet d’Aether brûle à hauteur de taille. Enclume, baquet de trempe qui fume, soufflet, râtelier de barres.',
  build(){const hearth=q=>q.f==='top'&&Math.abs(q.x)<.5&&Math.abs(q.z)<.22?rp(R_(['#1a1830','#2a2850','#3c3a7a']),.5+(hash(q.sx,q.sy,2)-.5)*.6,q.sx,q.sy):null;
   const objs=[plinth(DSTONE,.1),
    box(0,-.95,1.1,.3,.1,1.2,dMat(),{key:-2}),
    box(0,-.35,.72,.36,.1,.55,dMat({inlay:hearth}),{key:-.2,lights:[{x:0,y:.8,z:-.3,r:60,i:1,c:VIOBLUE,fl:.2}]}),
    roof('hip',0,-.6,1.02,.62,1.2,.72,stone(DSTONE,{courses:.16,joint:.4,noise:.12}),{key:.1,noShadow:1,hf:(lx,lz)=>{const f=Math.min(1-Math.abs(lx)/1.02,1-Math.abs(lz)/.62);return 1.2+Math.min(.62,f*1.05)}}),
    box(0,-.6,.26,.22,1.82,2.55,dMat(),{key:.15}),
    post(-.85,.05,1.2,DSTONE,.09),post(.85,.05,1.2,DSTONE,.09),
    fx(.12,()=>{const[a,b]=at(0,2.55,-.6);return{dyn:smokeDyn(a,b-1,36,10)}}),
    fx(.2,()=>{const p=[-.3,-.1,.1,.3].map(x=>at(x,.55,-.3));return{dyn:(F,t)=>{for(const[a,b]of p)flameDyn(a,b,'vb',1.05)(F,t);sparkC(p[1][0],p[1][1]-4,['#34327a','#9aa0ff','#e0e4ff'],6,9,10,8)(F,t)}}}),
    anvil(.4,.62),barrel(-.75,.65,WOOD,{water:1,h:.36,r:.17}),fx(.9,()=>{const[a,b]=at(-.75,.4,.65);return{dyn:steamDyn(a,b,14)}}),
    fx(.7,()=>{const[a,b]=at(.42,.4,.62);return{dyn:(F,t)=>{const k=Math.floor(t*3)%3;for(let i=-3;i<=3;i++)F.set(a+i,b-1,MOLT[k===0?4:3]);sparkC(a,b-2,['#7a3008','#ec8424','#ffeec0'],8,5,8,6,1,.35)(F,t)}}}),
    rack(1.05,.7,2)];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge stellaire',desc:'Un four en dôme percé de petites étoiles qui laissent filer la lueur bleu-violette (une carte du ciel d’Aether). La gueule s’ouvre en arc sur le foyer ; trois étincelles en orbite. Enclume et lingots devant.',
  build(){const stars=q=>{if(q.f!=='top')return null;const k=hash(Math.floor(q.ang*9),Math.floor(q.y*9),4);if(k>.9&&((q.sx*7+q.sy*3)%5===0))return AEC[3];if(k>.84&&((q.sx+q.sy)%7===0))return AEC[2];return null};
   const mouth=q=>q.f==='side'&&Math.abs(q.ang-Math.PI/2)<.38&&q.y<.12+.5*Math.cos((q.ang-Math.PI/2)/.38*Math.PI/2)?rp(R_(['#2a2850','#5a5cff','#9aa0ff','#e0e4ff'].map(E)),.95-q.v*1.6+(hash(q.sx,q.sy,3)-.5)*.3,q.sx,q.sy):null;
   const objs=[slab(poly(8,1.3,Math.PI/8),0,.12,stone(DSTONE,{noise:.08}),{key:-9}),
    slab(circle(.92),.12,.62,dMat({inlay:anyI(mouth,q=>q.f==='side'&&Math.abs(q.v-.85)<.08?rp(IRON,q.b+.1,q.sx,q.sy):null)}),{key:-.5,lights:[{x:0,y:.4,z:.95,r:62,i:1,c:VIOBLUE,fl:.2}]}),
    roof('dome',0,0,.92,.92,.62,.62,((dm)=>q=>stars(q)??dm(q))(shingle(DSTONE,{axis:'r',cw:.14})),{key:.5,noShadow:1}),
    slab(circle(.16),1.18,1.46,dMat(),{key:.6}),
    fx(.7,()=>{const[a,b]=at(0,1.46,0);return{dyn:smokeDyn(a,b,30,8,7)}}),
    fx(.8,()=>{const[a,b]=at(0,1.05,0);return{dyn:orbit(a,b,30,10,3,['#5a5cff','#9aa0ff','#e0e4ff'],.8,1)}}),
    anvil(.55,.95),slab(rect(-.2,-.1,.2,.1),0,.1,stone(IRON),{x:-.7,z:.9}),slab(rect(-.2,-.1,.2,.1),.1,.2,stone(IRON),{x:-.68,z:.9}),
    fx(1.1,()=>{const[a,b]=at(0,.25,1.0);return{dyn:sparkC(a,b,['#34327a','#9aa0ff','#e0e4ff'],6,4,10,7)}})];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge à martinet',desc:'La halle de forge, toit d’ardoise et cheminée ; devant, un martinet : une roue à cames soulève le grand marteau qui retombe sur l’enclume en gerbe d’étincelles, en cadence. Le plus vivant.',
  build(){const objs=[plinth(DSTONE,.1),
    box(-.15,-.6,1.0,.62,.1,1.0,dMat({inlay:anyI(rectI(.3,.3,.1,.72,q=>rp(R_(['#1a1830','#34327a','#5a5cff'].map(E)),.3+(1-(q.y-.1)/.62)*.7+(hash(q.sx,q.sy,5)-.5)*.3,q.sx,q.sy)),rectI(-.6,.18,.45,.75,winFill(WINV)))}),{key:-1,lights:[{x:.3,y:.4,z:.05,r:48,i:.85,c:VIOBLUE,fl:.2}]}),
    roof('gx',-.15,-.6,1.12,.76,1.0,.62,shingle(SLATE,{cw:.13}),{key:.2,noShadow:1}),
    slab(square(.2),0,2.2,dMat(),{x:-.75,z:-.75,taper:[1.15,.9],key:-.3}),fx(-.29,()=>{const[a,b]=at(-.75,2.2,-.75);return{dyn:smokeDyn(a,b,34,10,6)}}),
    box(.72,.55,.1,.1,.1,.8,woodMat(WOOD),{key:.5}),box(.72,.95,.1,.1,.1,.8,woodMat(WOOD),{key:.9}),
    anvil(.05,.75),
    fx(1.2,()=>{const[a,b]=at(.72,.6,.75);const[c,d]=at(.06,.38,.75);return{dyn:(F,t)=>{wheelDyn(a+6,b+4,7,4,2*Math.PI/1.1,WOOD,{thick:1})(F,t);hammerDyn(a-1,b-2,a-c-1,1.1,-1,{cols:MOLT})(F,t);
     const u=(t%1.1)/1.1;if(u>.8)for(let i=-3;i<=3;i++)F.set(c+i,d-1,MOLT[4]);else for(let i=-3;i<=3;i++)F.set(c+i,d-1,MOLT[2])}}}),
    barrel(-.85,.7,WOOD,{water:1,h:.34,r:.15}),rack(-.35,.25,2)];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge de pierres sèches',desc:'Une forge de campagne à ciel ouvert : murets de pierres sèches en U, haute cheminée tronconique au fond, soufflet de cuir qui respire, foyer au feu bleu-violet. Discrète et rustique, entre ruine et bivouac.',
  build(){const dry=o=>stone(MSTONE,{courses:.14,joint:.26,noise:.22,moss:.16,...o});
   const objs=[slab(square(1.28),0,.06,stone(TERRE,{noise:.15}),{key:-9}),
    box(0,-1.02,1.18,.2,.06,.7,dry(),{key:-1.1}),box(-1.0,-.25,.18,.62,.06,.5,dry(),{key:-.2}),box(1.0,-.25,.18,.62,.06,.5,dry(),{key:-.2}),
    slab(circle(.42),.0,2.1,dry({courses:.14}),{z:-.8,key:-.9,taper:[1,.55]}),
    box(0,-.2,.48,.32,.06,.42,dry({inlay:q=>q.f==='top'&&Math.abs(q.x)<.32&&Math.abs(q.z)<.18?rp(R_(['#1a1830','#2a2850','#3c3a7a']),.6,q.sx,q.sy):null}),{key:-.1,lights:[{x:0,y:.7,z:-.2,r:58,i:1,c:VIOBLUE,fl:.22}]}),
    fx(-.05,()=>{const p=[-.15,.05,.2].map(x=>at(x,.42,-.2));return{dyn:(F,t)=>{for(const[a,b]of p)flameDyn(a,b,'vb',1.2)(F,t)}}}),
    fx(-.85,()=>{const[a,b]=at(0,2.1,-.8);return{dyn:smokeDyn(a,b,34,10,4)}}),
    bellows(-.65,.25),anvil(.55,.55),rack(.9,.85,3),fx(.6,()=>{const[a,b]=at(.55,.4,.55);return{dyn:sparkC(a,b-2,['#7a3008','#ec8424','#ffeec0'],7,8,9,6,1.6,.3)}})];
   return{ground:floor(),objs}}},
 {g:'forge',name:'Forge en cloche',desc:'Un four en forme de cloche de fer cerclée, autour duquel tournent deux anneaux d’Aether (l’astronomie du culte) ; une bouche en bas crache la lueur bleu-violette. Enclume, pince et lingots de part et d’autre. Le plus « Aether ».',
  build(){const mouth=q=>q.f==='side'&&Math.abs(q.ang-Math.PI/2)<.3&&q.v<.35?rp(R_(['#2a2850','#5a5cff','#9aa0ff','#e0e4ff'].map(E)),.95-q.v*2.2+(hash(q.sx,q.sy,3)-.5)*.3,q.sx,q.sy):null;
   const objs=[slab(circle(1.3),0,.12,stone(DSTONE,{noise:.08,inlay:anyI(ringI(1.1,.03,AEC[1]),dotsI(1.2,12,AEC[2]))}),{key:-9}),
    slab(circle(.72),.12,.5,iMat({inlay:anyI(mouth,q=>q.f==='side'&&Math.abs(q.v-.9)<.08?rp(IRON,q.b+.18,q.sx,q.sy):null)}),{key:-.5,lights:[{x:0,y:.3,z:.75,r:56,i:.95,c:VIOBLUE,fl:.2}]}),
    roof('bell',0,0,.72,.72,.5,1.15,stone(IRON,{noise:.06,inlay:q=>Math.abs(q.y-1.0)<.035||Math.abs(q.y-1.4)<.035?rp(IRON,q.b+.2,q.sx,q.sy):null}),{key:.3,noShadow:1}),
    slab(circle(.12),1.62,1.9,iMat(),{key:.4}),fx(.45,()=>{const[a,b]=at(0,1.9,0);return{dyn:smokeDyn(a,b,30,8,2)}}),
    fx(.5,()=>{const[a,b]=at(0,1.0,0);return{lights:[{x:a,y:b,r:50,i:.35,c:VIOBLUE}],dyn:(F,t,S)=>{ringDyn(a,b,26,['#5a5cff','#9aa0ff','#e0e4ff'],.6)(F,t,S);ringDyn(a,b-4,20,['#34327a','#9aa0ff','#e0e4ff'],-.45)(F,t,S)}}}),
    anvil(.8,.75),slab(rect(-.2,-.1,.2,.1),0,.1,stone(IRON),{x:-.85,z:.75}),slab(rect(-.18,-.09,.18,.09),.1,.2,stone(IRON),{x:-.84,z:.75}),
    fx(.9,()=>{const[a,b]=at(.8,.4,.75);return{dyn:sparkC(a,b-1,['#7a3008','#ec8424','#ffeec0'],6,2,8,6,1.4,.3)}})];
   return{ground:floor(),objs}}},
// ======================= ENTREPÔT LOGISTIQUE =======================
 {g:'warehouse',name:'Halle des rayonnages',desc:'Un haut rayonnage de caisses sous un appentis d’ardoise porté par quatre piliers de marbre ; devant, une cour dallée où s’alignent coffres bleus et rouges, une palette et des caisses à ranger. Lecture « stock » immédiate.',
  build(){const objs=[slab(square(1.28),0,.1,stone(MARBLE,{noise:.06,pave:q=>(Math.floor(q.x/.42)+Math.floor(q.z/.42))&1?.05:0}),{key:-9}),
    box(0,-.98,1.18,.2,.1,1.38,mMat({inlay:booksI(-1.08,1.08,.18,1.3,3,21,{crates:1})}),{key:-1.2}),
    ...[-1.08,-.36,.36,1.08].map(x=>column(x,-.5,1.38,MARBLE)),
    roof('shed',0,-.88,1.3,.46,1.38,.42,shingle(SLATE,{cw:.12}),{key:-.3,noShadow:1}),
    chest(-.75,-.05,BLUEC),chest(-.3,-.05,BLUEC),chest(.75,-.05,REDC),crate(.55,.55,.15),crate(.2,.72,.12),chest(-.55,.62,REDC),box(.1,.2,.32,.2,0,.05,woodMat(WOOD,{along:'x'})),crate(.05,.2,.13,.05),
    lanternHang(0,1.3,-.48),fx(1,()=>({dyn:pageDyn(...at(0,.6,.3),2,17,10)}))];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Quai de transbordement',desc:'Un quai de pierre surélevé avec rampe d’accès et petit bureau du magasinier au fond ; un palan sur potence monte et descend une caisse entre le sol et le quai. Coffres bleus et rouges sur le quai.',
  build(){const objs=[slab(square(1.3),0,.05,stone(TERRE,{noise:.14}),{key:-9}),
    box(.1,-.35,1.15,.85,.05,.55,sMat({courses:.18}),{key:-1.3}),
    roof('shed',.1,.75,.5,.28,.05,.5,stone(SLATE,{noise:.1,inlay:q=>q.f==='top'&&((q.z*T/2.5|0)&1)?rp(SLATE,.6,q.sx,q.sy):null}),{key:.6,hf:(lx,lz)=>.05+.5*(.28-lz)/.56,noShadow:1}),
    box(-.5,-.85,.55,.35,.55,1.35,woodMat(WOOD,{inlay:anyI(rectI(.12,.15,.55,1.05,doorFill()),rectI(-.25,.14,.82,1.12,winFill(WINW)))}),{key:-1,lights:[{x:-.75,y:1.0,z:-.5,r:32,i:.6,c:WHITEC}]}),
    roof('gx',-.5,-.85,.65,.45,1.35,.4,shingle(SLATE,{cw:.12}),{key:-.4,noShadow:1}),
    {key:-.3,draw(L){prism(L,rect(-.19,-.12,.19,.12),{x:.3,z:-.6,y0:.55,y1:.82,mat:chestMat(BLUEC)});prism(L,rect(-.19,-.12,.19,.12),{x:.78,z:-.55,y0:.55,y1:.82,mat:chestMat(REDC)});return{}}},
    {key:-.1,draw(L){prism(L,square(.15),{x:.55,z:-.05,y0:.55,y1:.81,mat:crateMat(.15)});prism(L,rect(-.19,-.12,.19,.12),{x:-.5,z:-.1,y0:.55,y1:.82,mat:chestMat(BLUEC)});return{}}},
    post(1.05,.75,1.55,WOOD,.06),fx(.8,()=>{const[a,b]=at(1.05,1.5,.75);return{dyn:(F,t)=>{F.line(a,b,a-15,b+1,WOOD[4]);F.line(a,b+1,a-15,b+2,WOOD[2]);hoistDyn(a-14,b+2,22,6,{sway:1})(F,t)}}}),
    crate(.85,1.0,.15),chest(-.7,.95,REDC)];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Réserve voûtée',desc:'Une voûte en berceau à demi enterrée, couverte de terre et de mousse ; façade de pierre taillée, porte cintrée à deux battants ferrés. Caisses et tonneaux attendent devant, sous une lanterne. Massive et sûre.',
  build(){const objs=[plinth(SLATE,.08),
    roof('vault',0,-.25,1.1,1.0,.08,1.25,q=>q.f==='top'?(vnoise(q.x*3,q.z*3+q.y,8)>.45?rp(MOSS,q.b,q.sx,q.sy):rp(EARTH,q.b+.1,q.sx,q.sy)):rp(EARTH,.4,q.sx,q.sy),{key:-1,shadow:.5,th:.02}),
    box(0,.62,1.05,.14,.08,1.18,sMat({courses:.16,joint:.42,inlay:anyI(archI(0,.4,.08,.95,(q,dx)=>Math.abs(dx)<.6/T?rp(IRON,.3,q.sx,q.sy):Math.abs(q.y-.35)<.03||Math.abs(q.y-.7)<.03?rp(IRON,.55,q.sx,q.sy):doorFill()(q,dx)),frontI(q=>q.y>1.02&&Math.abs(q.x)<.15?rp(MARBLE,.85,q.sx,q.sy):null))}),{key:.7}),
    lanternHang(.55,1.05,.8),
    crate(-.75,1.0,.16),crate(-.6,1.08,.12,.27),barrel(.85,1.0),barrel(.62,1.12,WOOD,{h:.38}),chest(-.25,1.12,BLUEC)];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Grange aux silos',desc:'Deux silos ronds en pierre, coiffés de cônes d’ardoise, encadrent une grange à pignon ; porte de grange ouverte sur les caisses. Palettes de coffres devant. Se lit comme un dépôt de vivres et de matériaux.',
  build(){const objs=[plinth(SLATE,.08),
    box(0,-.45,.62,.72,.08,1.05,woodMat(WOOD,{inlay:rectI(0,.34,.08,.8,q=>booksI(-.32,.32,.1,.78,2,31,{crates:1})(q)??rp(DSTONE,.15,q.sx,q.sy))}),{key:-.9}),
    roof('gz',0,-.45,.74,.82,1.05,.62,shingle(SLATE,{axis:'z',cw:.13,side:q=>woodMat(WOOD)(q)}),{key:.3,noShadow:1}),
    slab(circle(.42),.08,1.55,stone(MSTONE,{courses:.18,joint:.4,noise:.12,moss:.08}),{x:-.88,z:-.55,key:-.4}),roof('cone',-.88,-.55,.48,.48,1.55,.55,shingle(SLATE,{axis:'r',cw:.12}),{key:-.05,noShadow:1}),
    slab(circle(.42),.08,1.55,stone(MSTONE,{courses:.18,joint:.4,noise:.12,moss:.08}),{x:.88,z:-.55,key:-.4}),roof('cone',.88,-.55,.48,.48,1.55,.55,shingle(SLATE,{axis:'r',cw:.12}),{key:-.05,noShadow:1}),
    box(-.6,.75,.32,.22,0,.06,woodMat(WOOD,{along:'x'})),chest(-.72,.75,BLUEC),chest(-.45,.78,BLUEC),
    box(.6,.75,.32,.22,0,.06,woodMat(WOOD,{along:'x'})),chest(.5,.75,REDC),crate(.78,.8,.12,.06),lanternHang(0,1.12,.3)];
   return{ground:floor(),objs}}},
 {g:'warehouse',name:'Magasin à étages',desc:'Un haut magasin de bois et de pierre sur deux niveaux, toit à pignon ; à l’étage, une porte de chargement sous une poutre à poulie : une caisse monte et descend au bout de sa corde. Coffres bleu et rouge de part et d’autre de la porte basse.',
  build(){const objs=[plinth(SLATE,.08),
    box(0,-.4,1.0,.75,.08,.75,sMat({courses:.18,joint:.5,inlay:rectI(0,.24,.08,.66,doorFill())}),{key:-1.2}),
    box(0,-.4,1.04,.79,.75,1.9,woodMat(WOOD,{inlay:anyI(rectI(0,.24,.95,1.55,q=>rp(DSTONE,.15,q.sx,q.sy)),rectI(-.65,.14,1.15,1.5,winFill(WINW)),rectI(.65,.14,1.15,1.5,winFill(WINW)),frontI(q=>q.y<.82?rp(WOOD,.8,q.sx,q.sy):null))}),{key:-1.1,lights:[{x:-.65,y:1.3,z:.4,r:30,i:.55,c:WHITEC},{x:.65,y:1.3,z:.4,r:30,i:.55,c:WHITEC}]}),
    roof('gx',0,-.4,1.14,.9,1.9,.62,shingle(SLATE,{cw:.13}),{key:.5,noShadow:1}),
    box(0,.55,.05,.18,1.95,2.03,woodMat(WOOD),{key:.6}),
    fx(.7,()=>{const[a,b]=at(0,1.95,.72);return{dyn:(F,t)=>{F.set(a,b,IRON[4]);F.set(a+1,b,IRON[2]);hoistDyn(a,b+1,30,6)(F,t)}}}),
    chest(-.62,.55,BLUEC),chest(.62,.55,REDC),crate(-.95,.95,.14),crate(.15,1.05,.13)];
   return{ground:floor(),objs}}},
];
function floorScene(){const S=new Scene();S.bake(floor(),[]);return S}
