const CW=56,CH=56,GY=47,PI2=Math.PI*2,OUT='#0b090b';
const POSES=['sortie','marche','porter','prier','travail','combat','mort'];
const LABELS=['Sortie du portail','Marche','Porter une caisse','Prière','Travail / minage','Combat','Mort'];
const R=Math.round,sn=(t,k=1,ph=0)=>Math.sin((t*k+ph)*PI2),cs=(t,k=1,ph=0)=>Math.cos((t*k+ph)*PI2);
const sm=x=>x<=0?0:x>=1?1:x*x*(3-2*x),cl=x=>Math.max(0,Math.min(1,x)),lerp=(a,b,k)=>a+(b-a)*k;
function hash(x,y,s=0){let h=(x*374761393+y*668265263+s*1442695041)|0;h=(h^(h>>>13))*1274126177|0;return((h^(h>>>16))>>>0)/4294967296}
const RGB={};function rgb(c){return RGB[c]||(RGB[c]=[parseInt(c.slice(1,3),16),parseInt(c.slice(3,5),16),parseInt(c.slice(5,7),16)])}
function mix(a,b,k){const A=rgb(a),B=rgb(b);return'#'+A.map((v,i)=>R(lerp(v,B[i],k)).toString(16).padStart(2,'0')).join('')}

class L{
 constructor(){this.a=new Array(CW*CH).fill(null)}
 p(x,y,c){x=R(x);y=R(y);if(!c||x<0||y<0||x>=CW||y>=CH)return;this.a[y*CW+x]=c}
 g(x,y){return x<0||y<0||x>=CW||y>=CH?null:this.a[y*CW+x]}
 rect(x,y,w,h,c){x=R(x);y=R(y);for(let j=0;j<h;j++)for(let i=0;i<w;i++)this.p(x+i,y+j,c)}
 ell(cx,cy,rx,ry,c){for(let y=Math.floor(cy-ry-1);y<=Math.ceil(cy+ry+1);y++)for(let x=Math.floor(cx-rx-1);x<=Math.ceil(cx+rx+1);x++){const dx=(x-cx)/(rx+.4),dy=(y-cy)/(ry+.4);if(dx*dx+dy*dy<=1)this.p(x,y,c)}}
 disc(x,y,r,c){this.ell(x,y,r,r,c)}
 line(x0,y0,x1,y1,c,w=1){const n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))*1.5));for(let i=0;i<=n;i++){const x=lerp(x0,x1,i/n),y=lerp(y0,y1,i/n);if(w>1)this.rect(x-(w>>1),y-(w>>1),w,w,c);else this.p(x,y,c)}}
 poly(pts,c){const xs=pts.map(p=>p[0]),ys=pts.map(p=>p[1]);for(let y=Math.floor(Math.min(...ys));y<=Math.ceil(Math.max(...ys));y++)for(let x=Math.floor(Math.min(...xs));x<=Math.ceil(Math.max(...xs));x++){let ins=false;for(let i=0,j=pts.length-1;i<pts.length;j=i++){const[xi,yi]=pts[i],[xj,yj]=pts[j];if((yi>y+.5)!==(yj>y+.5)&&x+.5<(xj-xi)*(y+.5-yi)/(yj-yi)+xi)ins=!ins}if(ins)this.p(x,y,c)}}
 mask(fn){for(let y=0;y<CH;y++)for(let x=0;x<CW;x++)if(fn(x,y))this.a[y*CW+x]=null}
}
function crate(S,x,y){S.rect(x,y,10,8,'#5c4632');S.rect(x,y,10,2,'#7d6346');S.rect(x+1,y+4,8,1,'#3e2f22');S.rect(x+4,y+2,2,6,'#4a3828');S.p(x+5,y+5,'#7a3e3e')}
function rock(S,x,y){S.ell(x+4,y+5,5,5,'#333a46');S.ell(x+3,y+3,3,2.5,'#404955');S.p(x+5,y+6,'#b07a4a');S.p(x+2,y+7,'#b07a4a')}
function star(F,x,y,c,r=2){F.p(x,y,c);for(let i=1;i<=r;i++){F.p(x+i,y,c);F.p(x-i,y,c);F.p(x,y+i,c);F.p(x,y-i,c)}}

const GODS={
 medeina:{name:'Medeina',sub:'Vie, mort, renaissance. Puits des Âmes, Chambre.',col:'#6cc24a',c:['#1f3d1e','#2f5a2c','#4f8a3e','#86c25a','#c6eb8e'],bone:['#8f8774','#b9b19b','#e2dcc8'],flower:'#f1efd2'},
 indra:{name:'Indra',sub:'Discipline martiale. Caserne (les soldats formés restent humains). Frappe deux fois plus fort.',col:'#ee8f2e',c:['#4a220c','#7a3a12','#c0621c','#ee8f2e','#ffc070'],steel:['#2c2c32','#46464e','#64646e']},
 aether:{name:'Aether',sub:'Astronomie. Atelier, Forge, Creuset, et les mineurs.',col:'#7b7fe0',c:['#1d1b4a','#2c2a6a','#4b4cb0','#7b7fe0','#b9bcff'],metal:['#2a2840','#3f3c5e','#5c5880']},
 sigil:{name:'Sigil',sub:'Savoir et recherche, érudition sans magie. Bibliothèque, transport.',col:'#b5b7bb',c:['#3c3e44','#55575d','#7d7f85','#a4a6ab','#cbccce']}
};

/* ============ MEDEINA ============ */
function deer(S,F,G,o){
 const c=G.c,b=G.bone,{bx,by}=o;
 if(o.lie){S.rect(bx-9,by+3,6,2,b[1]);S.rect(bx+1,by+3,7,2,c[1])}
 else{const ox=[-8,-5,3,6];for(let k=0;k<4;k++){const x0=bx+ox[k],sw=o.leg?o.leg[k]:0;S.line(x0,by+2,x0+sw,GY,k<2?b[1]:c[1]);S.p(x0+sw,GY,'#2a2218')}}
 S.line(bx-10,by-3,bx,by-3,b[1]);for(const i of[-8,-6,-4,-2])S.line(bx+i,by-3,bx+i,by+3,b[2]);S.ell(bx-10,by-1,2,2,b[1]);
 S.ell(bx+3,by,6,4,c[2]);S.ell(bx+3,by-2,4,1.5,c[3]);S.p(bx+2,by-3,G.flower);S.p(bx+6,by-1,G.flower);S.p(bx+4,by+1,'#e9e4b0');
 const[hx,hy]=o.head;S.line(bx+7,by-2,hx-1,hy+1,c[2],2);
 const a=o.antler||1;S.line(hx-1,hy-2,hx-1-a,hy-5-a*2,c[0]);S.line(hx-1-a*.5,hy-4-a,hx+1+a,hy-6-a*2,c[0]);S.p(hx-2-a,hy-5-a*2,c[3]);S.p(hx+1+a,hy-6-a*2,c[3]);
 S.ell(hx,hy,3,2,c[2]);S.p(hx+3,hy+1,c[1]);S.p(hx+1,hy-1,'#10140e');S.line(hx-2,hy-2,hx-3,hy-4,c[1]);
 if(o.blooms)for(let i=0;i<o.blooms;i++)S.disc(bx-8+i*2,by-4-(i%2),1,i%2?G.flower:'#e9e4b0');
}
function biche(S,F,pose,t,G){
 const c=G.c,b=G.bone;let bx=24,by=35;
 if(pose==='mort'){
  if(t<.45){deer(S,F,G,{bx,by:41,lie:true,head:[bx+12,44]});return{x:bx,rx:12}}
  const k=sm((t-.5)/.4);S.line(bx-6,45,bx+6,45,b[2],2);S.disc(bx-7,45,1.5,b[1]);S.disc(bx+7,45,1.5,b[1]);
  if(t>.5){S.line(bx,44,bx,44-k*6,G.c[2]);if(k>.4){S.p(bx-1,42-k*3,c[3]);S.p(bx+1,41-k*3,c[3])}F.p(bx,43-k*6,c[4])}
  return{x:bx,rx:8}}
 const w=sn(t),bob=R(Math.abs(w));
 if(pose==='marche'||pose==='porter'){by=35-bob;deer(S,F,G,{bx,by,leg:[w*2,-w*2,-w*2,w*2],head:[bx+11,by-9]});
  if(pose==='porter'){crate(S,bx-8,by-12);S.line(bx-8,by-6,bx-7,by-3,c[1]);S.line(bx+1,by-6,bx,by-3,c[1]);S.p(bx-3,by-13,c[3])}}
 if(pose==='prier'){deer(S,F,G,{bx,by:41,lie:true,head:[bx+11,32],blooms:Math.floor(sm(t*1.3)*5)});
  for(let i=0;i<3;i++){const u=(t+i/3)%1;F.p(bx-6+i*3,37-u*14,u<.8?c[4]:c[3])}}
 if(pose==='travail'){deer(S,F,G,{bx,by,head:[bx+13,by+7+R(sn(t,2)*.6)]});
  for(let i=0;i<4;i++){const u=(t+i/4)%1;F.p(bx+10+i*2+sn(u,1)*1.5,by-6+u*14,G.flower)}}
 if(pose==='combat'){const d=Math.max(0,sn(t))*6;deer(S,F,G,{bx:bx+d,by:by+1,leg:[-2,-2,2,2],head:[bx+d+13,by+1],antler:2});
  if(t>.18&&t<.34)star(F,R(bx+d+19),by-3,c[4],3)}
 return{x:bx,rx:11}}

function cairn(S,F,pose,t,G){
 const c=G.c,st=['#4b5548','#6a7564','#8f9a86'];
 const stone=(x,y,rx,ry)=>{S.ell(x,y,rx,ry,st[1]);S.ell(x-1,y-1,rx-1.5,ry-1.2,st[2]);S.p(x+R(rx/2),y+1,st[0]);S.p(x-R(rx/2),y,c[2]);S.p(x-R(rx/2)+1,y,c[3])};
 const bud=(x,y,h=3)=>{S.line(x,y,x,y-h,c[2]);S.p(x-1,y-h,c[3]);S.p(x+1,y-h+1,c[3]);S.p(x-2,y-h+1,c[2]);F.p(x,y-h-1,c[4])};
 let f=sn(t)*1.5,x=27;
 if(pose==='marche'){const sw=sn(t,1);stone(x+sw,40+f,6,3);stone(x-sw,33+f,5,2.5);stone(x+sw*1.5,27+f,4,2);bud(x+R(sw*1.5),25+f);return{x,rx:7}}
 if(pose==='porter'){stone(x,41+f,6,3);crate(S,x-5,33+f);stone(x,28+f,5,2.5);stone(x,22+f,4,2);bud(x,20+f);return{x,rx:7}}
 if(pose==='prier'){stone(x,44,6,3);stone(x,39,5,2.5);stone(x,35,4,2);bud(x,33,3+R(sm(t)*2));
  for(let i=0;i<4;i++){const h=R(sm(cl(t*1.6-i*.15))*4);if(h>0)S.line(x-10+i*6+(i>1?2:0),GY,x-10+i*6+(i>1?2:0),GY-h,c[2]);if(h>3)S.p(x-10+i*6+(i>1?2:0),GY-h,c[4])}
  return{x,rx:7}}
 if(pose==='travail'){for(let k=0;k<3;k++){const a=t+k/3,ox=sn(a)*5,oy=cs(a)*1.5;stone(x+ox,[40,33,27][k]+oy+f*.5,[6,5,4][k],[3,2.5,2][k])}bud(x,24);
  for(let i=0;i<3;i++){const u=(t+i/3)%1;F.p(x+8+i*2,30+u*14,c[3])}return{x,rx:9}}
 if(pose==='combat'){stone(x,40+f,6,3);stone(x,33+f,5,2.5);
  if(t<.15)stone(x,26-t*20,4,2);else if(t<.65){const u=(t-.15)/.5;stone(lerp(x,51,u),lerp(24,44,u)-Math.sin(u*Math.PI)*12,4,2);if(u>.85)star(F,50,44,c[4],2)}
  else{const k=(t-.65)/.35;if(k>.5)stone(x,27+f,4,2);else bud(x,31+f,R(k*6))}
  return{x,rx:7}}
 if(pose==='mort'){const k=sm(t*2.2);stone(x-k*6,40+k*5,6,3);stone(x+k*7,33+k*12,5,2.5);stone(x+k*2,27+k*18,4,2);
  if(t>.6)bud(x-1,46,R(sm((t-.6)/.35)*5));return{x,rx:9}}
 return{x,rx:7}}

function mue(S,F,pose,t,G){
 const sc=['#5f8a4a','#9cc47e','#c9e6ae'],path=[];let N=22;
 for(let i=0;i<=N;i++){const u=i/N;let x,y;
  if(pose==='prier'){const a=u*PI2*1.6,r=lerp(9,1.5,u);x=27+Math.cos(a)*r;y=43+Math.sin(a)*r*.45;if(u>.86){x=27;y=lerp(43,30,(u-.86)/.14)}}
  else if(pose==='mort'){const k=sm(t*1.6);x=8+u*24;y=lerp(u<.6?45:45-(u-.6)/.4*18,46,k)+sn(u*1.5)*1*(1-k)}
  else{const amp=pose==='travail'?3:1.6,ph=pose==='combat'?0:t;x=6+u*24;y=u<.6?45-sn(u*1.6-ph)*amp:45-((u-.6)/.4)*18;
   if(pose==='combat'&&u>.55)x+=Math.max(0,sn(t))*8*((u-.55)/.45);if(pose==='porter'&&u<.6){const a=u/.6*PI2*1.25;x=24+Math.cos(a)*7;y=38+Math.sin(a)*4}}
  path.push([x,y])}
 if(pose==='porter')crate(S,19,33);
 path.forEach(([x,y],i)=>{const r=i<4?1+i*.3:2.2;S.disc(x,y,r,i%3===0?sc[0]:i%3===1?sc[1]:sc[2]);if(i%3===2)S.p(x,y,sc[0])});
 if(pose==='porter')path.slice(0,8).forEach(([x,y],i)=>{if(y>37)S.disc(x,y,2,i%2?sc[1]:sc[2])});
 const[hx,hy]=path[N];if(pose!=='mort'||t<.5){S.ell(hx,hy-1,4.5,4,sc[1]);S.ell(hx,hy-1,3,2.6,sc[2]);S.ell(hx+1,hy-3,2.5,1.6,sc[1]);S.p(hx,hy-3,'#1a2a1a');S.p(hx+2,hy-3,'#1a2a1a');}
 else S.ell(hx,46,4,1.5,sc[1]);
 if(pose==='combat'&&t>.2&&t<.35)star(F,R(hx+6),R(hy-2),G.c[4],2);
 if(pose==='prier')for(let i=0;i<3;i++){const u=(t+i/3)%1;F.p(23+i*4,40-u*14,G.c[4])}
 if(pose==='travail')for(let i=0;i<3;i++){const u=(t+i/3)%1;F.p(6+i*3,46-u*4,G.c[3])}
 return{x:20,rx:12}}

/* ============ INDRA ============ */
function plate(S,G,x,y,w,h){const c=G.c;S.rect(x,y,w,h,c[2]);S.rect(x,y,w,1,c[3]);if(h>2)S.rect(x,y+h-1,w,1,c[1]);S.p(x+R(w/2),y+R(h/2),G.c[0])}
function lamelles(S,F,pose,t,G){
 const c=G.c,P=[];let dy=0,j=1;
 // [x,y,w,h]
 const base=[[23,22,9,3],[24,25,7,3],[24,28,7,3],[23,31,9,3],[22,35,5,3],[28,35,5,3],[22,39,5,3],[28,39,5,3],[22,43,5,3],[28,43,5,3],[18,23,4,4],[17,28,4,4],[33,23,4,4],[34,28,4,4]];
 base.forEach(b=>P.push(b.slice()));
 const legs=[4,6,8],legR=[5,7,9],armL=[10,11],armR=[12,13];
 if(pose==='marche'||pose==='porter'||pose==='sortie'){const w=pose==='sortie'?0:sn(t);legs.forEach((k,i)=>{P[k][0]+=R(w*(i+1)*.6);if(w>0)P[k][1]-=R(w*(i)*.5)});legR.forEach((k,i)=>{P[k][0]-=R(w*(i+1)*.6);if(w<0)P[k][1]+=R(w*(i)*.5)});dy=-R(Math.abs(w))}
 if(pose==='porter'){P[10]=[22,27,4,4];P[11]=[23,31,4,3];P[12]=[31,27,4,4];P[13]=[30,31,4,3]}
 if(pose==='prier'){j=0;dy=5;P[6]=[18,39,5,3];P[8]=[17,43,5,3];P[7]=[28,39,5,3];P[9]=[33,42,5,3];P[4]=[22,36,5,3];P[5]=[28,36,5,3];P[10]=[22,27,4,4];P[11]=[23,31,4,3];P[12]=[30,27,4,4];P[13]=[29,31,4,3]}
 if(pose==='travail'){for(let k=0;k<4;k++){const a=t+k/4;P[k]=[R(27+Math.cos(a*PI2)*10-P[k][2]/2),R(27+Math.sin(a*PI2)*3),P[k][2],P[k][3]]}}
 if(pose==='combat'){const sp=t<.4?sm(t/.4):t<.5?1-sm((t-.4)/.1):0;P.forEach((p,k)=>{p[0]+=R((p[0]+p[2]/2-27)*sp*.5);p[1]+=R((p[1]-30)*sp*.4)});
  const pu=t>.4&&t<.65?1:0;P[12]=[33+pu*7,24,4,4];P[13]=[35+pu*5,24,4,4];if(t>.45&&t<.62){star(F,46,25,c[4],3);F.p(44,22,c[3]);F.p(48,28,c[3])}}
 if(pose==='mort'){const k=sm(t*1.5);P.forEach((p,i)=>{const gx=16+(i*7)%22,gy=GY-2-(i%3)*2;p[0]=R(lerp(p[0],gx,k));p[1]=R(lerp(p[1],gy,k))})}
 const hd=pose==='mort'?[R(lerp(24,32,sm(t*1.5))),R(lerp(14,42,sm(t*1.5)))]:pose==='prier'?[25,14+dy]:[24,14];
 P.forEach((p,k)=>{const jj=j?R(sn(t,1,k*.13)*.7):0;plate(S,G,p[0],p[1]+dy+jj,p[2],p[3])});
 const hy=hd[1]+(pose==='prier'||pose==='mort'?0:dy);S.rect(hd[0],hy,7,6,c[2]);S.rect(hd[0],hy,7,1,c[3]);S.rect(hd[0]+1,hy+3,5,1,'#120804');
 if(pose!=='mort'||t<.3)for(let i=-1;i<=1;i++)S.line(hd[0]+3,hy-1,hd[0]+3+i*3,hy-5,c[3]);
 if(pose==='porter')crate(S,23,26+dy);
 if(pose==='porter'){plate(S,G,21,27+dy,3,4);plate(S,G,32,27+dy,3,4)}
 if(pose==='prier'){for(let k=0;k<4;k++)F.rect(25,24+k*3+dy+ (k>1?1:0),5,0,c[4]);F.p(27,21+dy,c[4]);const u=t;F.p(27+R(sn(u)*3),18-R(u*6),c[3])}
 if(pose==='travail')for(let k=0;k<4;k++)F.p(27,24+k*3,t*4%1<.5?c[4]:c[3]);
 return{x:27,rx:9}}

function braise(S,F,pose,t,G){
 const c=G.c,s=G.steel;let x=27,y=32,rx=9,ember=1,legs=true,dash=0;
 const w=sn(t);
 if(pose==='marche'||pose==='porter'){y=32-R(Math.abs(w))}
 if(pose==='prier'){y=37;legs=false;ember=.4+.6*Math.abs(sn(t,.5))}
 if(pose==='travail'){rx=Math.max(1.5,9*Math.abs(cs(t)))}
 if(pose==='combat'){dash=Math.max(0,sn(t))*8;x+=dash}
 if(pose==='mort'){const k=sm(t*2);if(k<1||true){
   S.line(21,44,22,47,s[1]);S.line(33,44,32,47,s[1]);
   const ry=lerp(9,2.5,k),cy=lerp(32,44,k);S.ell(27,cy,9,ry,c[1]);S.ell(27,cy,7,ry*.75,c[2]);S.ell(27,cy,4,ry*.45,c[3]);S.disc(27,cy,ry>3?2:1,mix(c[4],'#4a4a4a',k));
   if(t<.5)F.p(27,R(cy),c[4]);else if(hash(R(t*12),1)>.7)F.p(27,R(cy)-2-R(t*4),'#5a5a5a');return{x:27,rx:10}}}
 if(legs){const l=pose==='marche'||pose==='porter'?w*2:0;S.line(x-4,y+7,x-4+l,GY,s[1],2);S.line(x+3,y+7,x+3-l,GY,s[1],2);S.rect(x-6+l,GY,4,1,s[0]);S.rect(x+2-l,GY,4,1,s[0])}
 S.ell(x,y,rx,9,c[1]);S.ell(x,y,Math.max(1,rx-2),7,c[2]);if(rx>4){S.ell(x,y,rx-4,4.5,c[3]);S.ell(x-2,y-3,Math.max(1,rx-7),1.5,c[4])}
 for(const a of[0,.25,.5,.75]){const px=x+Math.cos(a*PI2)*(rx-1),py=y+Math.sin(a*PI2)*8;S.p(px,py,s[2])}
 if(rx>3){S.disc(x,y,2,c[0]);F.disc(x,y,ember>.7?1.5:1,mix('#3a1a08',c[4],ember));F.p(x,y,ember>.6?'#fff0d0':c[3])}
 if(pose==='porter')crate(S,x-5,y-16);
 if(pose==='prier')for(let i=0;i<3;i++){const u=(t+i/3)%1;F.p(x-3+i*3,y-10-u*10,u<.6?c[4]:c[2])}
 if(pose==='travail'&&rx<3)F.p(x,y-9,'#fff0d0');
 if(pose==='combat'&&t>.15&&t<.35){star(F,R(x+11),y,c[4],3);F.p(R(x+13),y-4,c[3]);F.p(R(x+13),y+4,c[3])}
 return{x,rx:9}}

function ombre(S,F,pose,t,G){
 const c=G.c,wood='#6b4a2a',body=c[1],rim=c[2];
 const fig=(x,y,lean,arm,F2)=>{const L2=F2||S;const hx=x+lean,hy=y;
  L2.poly([[x-5,y+5],[x+5,y+5],[x+3,y+19],[x-3,y+19]],F2?c[2]:body);if(!F2){L2.line(x-5,y+5,x-3,y+19,rim)}
  for(let i=0;i<4;i++){const wx=x-3+i*2+sn(t,2,i*.25)*1.5;L2.line(x-3+i*2,y+19,wx,y+24+(i%2)*2,F2?c[2]:i%2?body:c[0])}
  L2.disc(hx,hy,3,F2?c[2]:body);if(!F2){L2.p(hx-1,hy-2,rim);F.p(hx+1,hy,c[4]);F.p(hx+2,hy,c[4])}
  const ax=x+Math.cos(arm)*9,ay=y+8+Math.sin(arm)*9;if(!F2){S.line(x+3,y+7,ax,ay,body,2);S.line(ax-Math.cos(arm)*12,ay-Math.sin(arm)*12,ax+Math.cos(arm)*6,ay+Math.sin(arm)*6,wood)}};
 const f=R(sn(t)*1);let x=27,y=16+f;
 if(pose==='marche'){fig(x,y,1,-1.2)}
 if(pose==='porter'){fig(x,y,0,-2.4);crate(S,x-3,y+8);S.p(x-3,y+10,body);S.p(x+6,y+10,body)}
 if(pose==='prier'){fig(x,23,2,1.4)}
 if(pose==='travail'){fig(x,y,0,t*PI2)}
 if(pose==='combat'){const k=t<.4?t/.4:1;const arm=lerp(-2.6,.4,sm(k));const ka=cl(k-.25);if(t>.25)fig(x-4,y,0,lerp(-2.6,.4,sm(ka)),F);fig(x,y,2,arm);if(t>.38&&t<.55)star(F,44,29,c[4],3)}
 if(pose==='mort'){fig(x,y+R(t*6),2,1.4);S.mask((px,py)=>S.g(px,py)&&hash(px,py,7)<t*1.3);for(let i=0;i<6;i++){const u=(t+i/6)%1;if(t>.2)F.p(20+i*3,40-u*24,u<.5?c[2]:c[1])}}
 if(pose==='marche'||pose==='prier'||pose==='travail')for(let i=0;i<2;i++){const u=(t+i/2)%1;F.p(25+i*4,42-u*8,c[2])}
 return{x:27,rx:7}}

/* ============ AETHER ============ */
function ring(S,F,cx,cy,r,tilt,spin,col,hi,back,front){for(let i=0;i<64;i++){const a=i/64*PI2;let x=r*Math.cos(a),y=0,z=r*Math.sin(a);const y2=y*Math.cos(tilt)-z*Math.sin(tilt),z2=y*Math.sin(tilt)+z*Math.cos(tilt);const x3=x*Math.cos(spin)+z2*Math.sin(spin),z3=-x*Math.sin(spin)+z2*Math.cos(spin);(z3<0?back:front).push([cx+x3,cy+y2,i%8===0?hi:col])}}
function orrery(S,F,pose,t,G){
 const c=G.c,m=G.metal;let x=27,y=27,hop=0,core=true,back=[],front=[];
 if(pose==='marche'||pose==='porter'){hop=-R(Math.abs(sn(t))*3)}
 const stand=(tilt=0)=>{S.ell(x+tilt*2,46,4.5,1.5,m[1]);S.line(x,45,x+tilt,y+hop+4,m[2]);S.p(x-1,45,m[2])};
 let rs=[[10,.9,t],[8,1.6,-t*1.3+.2],[12,.3,t*.7+.5]];
 if(pose==='prier'){rs=rs.map(([r,ti,sp],k)=>[r,lerp(ti,1.5,sm(t*2)),sp*.3])}
 if(pose==='porter')rs=[[11,.9,t],[13,.4,-t*.8]];
 if(pose==='mort'){const k=sm(t*2);stand(k*3);rs.forEach(([r,ti],i)=>{S.ell(x-6+i*6,lerp(y,45,k),r*lerp(1,.6,k),lerp(r*Math.cos(ti),1.2,k),c[2]);S.ell(x-6+i*6,lerp(y,45,k),r*lerp(1,.6,k)-1,lerp(r*Math.cos(ti),.3,k),null)});
  for(const L2 of[S]){}S.mask(()=>false);S.disc(x+k*3,y+hop+R(k*14),3,mix(c[3],m[0],k));if(t<.4)F.disc(x,y,1,c[4]);return{x,rx:9}}
 let det=null;
 if(pose==='travail'){det=rs.pop();rock(S,43,36)}
 if(pose==='combat'){det=rs.pop()}
 rs.forEach(([r,ti,sp])=>ring(S,F,x,y+hop,r,ti*PI2/4,sp*PI2,c[2],c[4],back,front));
 stand();
 back.forEach(([a,b,cc])=>S.p(a,b,cc));
 if(pose==='porter'){crate(S,x-5,y-4+hop)}else{S.disc(x,y+hop,3.5,m[1]);S.disc(x,y+hop,2.5,c[3]);F.disc(x,y+hop,1.5,c[4]);F.p(x,y+hop,'#eef0ff')}
 front.forEach(([a,b,cc])=>S.p(a,b,cc));
 if(det){if(pose==='travail'){const sw=t<.5?sm(t/.5):1-sm((t-.5)/.5);const hx=lerp(36,46,sw),hy=lerp(22,33,sw);const fb=[],ff=[];ring(S,F,hx,hy,6,PI2/4,.25*PI2+sw,c[2],c[4],fb,ff);fb.concat(ff).forEach(([a,b,cc])=>S.p(a,b,cc));if(t>.42&&t<.6){star(F,49,37,c[4],2);F.p(52,34,'#d8a070');F.p(45,34,'#d8a070')}}
  else{const u=t<.5?sm(t/.5):1-sm((t-.5)/.5);const dx=lerp(x,50,u);S.ell(dx,y,6*Math.abs(cs(t,4))+1,2,c[2]);S.ell(dx,y,Math.max(0,6*Math.abs(cs(t,4))-1),.5,null);for(let i=1;i<4;i++)F.p(dx-i*3*(t<.5?1:-1),y,c[3]);if(t>.4&&t<.6)star(F,52,y,c[4],3)}}
 if(pose==='prier')for(let i=0;i<3;i++){const u=(t+i/3)%1;F.p(x-8+i*8,y-6-u*10,c[4])}
 return{x,rx:7}}

function constel(S,F,pose,t,G){
 const c=G.c;const base=[[-9,4],[-6,-2],[0,-3],[5,-5],[8,-9],[6,-15],[9,-16],[11,-7],[4,3],[-6,6],[-10,0]];
 const edges=[[0,1],[1,2],[2,3],[3,4],[4,5],[4,6],[3,7],[2,8],[1,9],[0,10],[1,10]];
 let pts=base.map(p=>p.slice()),cx=27,cy=36;
 if(pose==='marche'||pose==='porter'){const h=Math.abs(sn(t))*5;cy-=h;pts[8][1]+=R(sn(t)*2);pts[9][1]-=R(sn(t)*2)}
 if(pose==='prier'){const k=sm(t*1.6);pts=pts.map((p,i)=>{const a=i/pts.length*PI2+t;return[lerp(p[0],Math.cos(a)*9,k),lerp(p[1],-6+Math.sin(a)*9,k)]})}
 if(pose==='combat'){const k=Math.max(0,sn(t));pts[4][0]+=k*12;pts[5][0]+=k*12;pts[6][0]+=k*12;pts[3][0]+=k*6}
 if(pose==='mort'){pts=pts.map((p,i)=>[p[0]*(1+t*1.5)+sn(i*.37)*t*6,p[1]*(1+t)+t*8])}
 if(pose==='porter')crate(S,cx-5,cy-7);
 const dim=pose==='mort'?1-t:1;
 edges.forEach(([a,b],k)=>{if(pose==='mort'&&hash(k,3)<t*1.4)return;const[x0,y0]=pts[a],[x1,y1]=pts[b];const n=Math.ceil(Math.hypot(x1-x0,y1-y0));for(let i=1;i<n;i++)if((i+R(t*8))%2===0)F.p(cx+lerp(x0,x1,i/n),cy+lerp(y0,y1,i/n),c[2])});
 pts.forEach(([x,y],i)=>{if(pose==='mort'&&hash(i,9)<t*1.2)return;const tw=hash(i,R(t*12))>.75;F.p(cx+x,cy+y,tw?'#ffffff':c[4]);if(tw||i===4){F.p(cx+x+1,cy+y,c[3]);F.p(cx+x-1,cy+y,c[3]);F.p(cx+x,cy+y-1,c[3]);F.p(cx+x,cy+y+1,c[3])}});
 if(pose==='travail'){rock(S,42,36);for(let i=0;i<4;i++){const u=(t+i/4)%1;F.p(lerp(cx+5,46,u),lerp(cy-5,38,u)-Math.sin(u*Math.PI)*6,c[4])}if(t%.25<.08)star(F,47,38,c[4],1)}
 if(pose==='combat'&&t>.15&&t<.35)star(F,cx+21,cy-12,'#ffffff',3);
 return{x:cx,rx:8,faint:true}}

function lyrique(S,F,pose,t,G){
 const c=G.c,m=G.metal;let x=27,y=0,lean=0,bow=0;const w=sn(t);
 if(pose==='marche'||pose==='porter')y=-R(Math.abs(w));
 if(pose==='prier'){bow=R(sm(t*2)*3);}
 if(pose==='travail'){lean=R(Math.max(0,sn(t))*3);rock(S,42,36)}
 if(pose==='mort'){bow=R(sm(t*2)*6)}
 const l=pose==='marche'||pose==='porter'?w*2:0;
 if(pose!=='mort'){S.line(x-4,40+y,x-4+l,GY,m[1],2);S.line(x+3,40+y,x+3-l,GY,m[1],2)}else{S.line(x-5,44,x-7,GY,m[1],2);S.line(x+4,44,x+6,GY,m[1],2)}
 const by=(pose==='mort'?4:0)+y;
 S.rect(x-7,36+by,14,5,c[1]);S.rect(x-7,36+by,14,1,c[2]);S.p(x-3,38+by,'#0c0b1c');S.p(x+2,38+by,'#0c0b1c');
 const top=17+bow+y,tx=lean+bow;
 const arm=(s)=>{S.line(x+s*6,36+by,x+s*9+tx*.3,28+by+bow*.5,c[2],2);S.line(x+s*9+tx*.3,28+by+bow*.5,x+s*6+tx,top,c[2],2);S.p(x+s*7+tx,top-1,c[4])};
 arm(-1);arm(1);S.line(x-6+tx,top,x+6+tx,top,c[3],2);
 for(let i=-1;i<=1;i++){const vib=(pose==='combat'||pose==='travail'||pose==='prier')&&i===0?R(sn(t,6)*1):0;
  if(pose==='mort'&&t>.3){F.line(x+i*2.5+tx,top+2,x+i*3+tx+R(sn(i*.3)*3),top+8,c[3])}else F.line(x+i*2.5+tx,top+2,x+i*2.5+vib*(i===0?1:0)+tx*.2,36+by,pose==='prier'?c[4]:c[3])}
 if(pose==='porter'){crate(S,x-5,24+y);S.p(x-6,27+y,c[2]);S.p(x+5,27+y,c[2])}
 const note=(nx,ny,cc)=>{F.rect(nx,ny,2,2,cc);F.line(nx+1,ny,nx+1,ny-4,cc);F.p(nx+2,ny-4,cc)};
 if(pose==='travail'){if(t>.2&&t<.35)star(F,41,37,c[4],2);const u=(t+.6)%1;note(36+R(u*4),30-R(u*12),c[4])}
 if(pose==='prier'){const u=t;note(x+8,24-R(u*12),c[4])}
 if(pose==='combat')for(let k=0;k<2;k++){const u=(t+k/2)%1,ax=x+8+u*20,r=3+u*5;for(let a=-.8;a<=.8;a+=.2)F.p(ax+Math.cos(a)*r-r,30+Math.sin(a)*r,u<.7?c[4]:c[3])}
 return{x,rx:8}}

/* ============ SIGIL ============ */
function capuche(S,F,pose,t,G){
 const c=G.c,v='#0e0f12';let x=27,y=R(sn(t)*1),bow=0,h=1;
 if(pose==='prier')bow=R(sm(t*2)*2)+1;
 if(pose==='mort'){h=lerp(1,.25,sm(t*1.6));}
 const top=17+y+R((1-h)*26),hem=42+y;
 if(pose==='mort'&&t>.3){S.ell(x,45,9,2.5,c[2]);S.ell(x-1,44,7,1.5,c[3]);S.line(x-6,45,x+6,44,c[1]);S.ell(x+R(t*6),lerp(30,42,sm(t*2)),4,3,c[2]);S.ell(x+R(t*6)+1,lerp(30,42,sm(t*2)),2,1.5,v);return{x,rx:10}}
 const fl=k=>R(sn(t,2,k*.2)*(pose==='marche'||pose==='porter'?1.5:.7));
 const rp=[[x-6,top+6],[x+6,top+6],[x+8,hem+fl(1)],[x+4,hem-1+fl(2)],[x,hem+fl(3)],[x-4,hem-1+fl(4)],[x-8,hem+fl(5)]];S.poly(rp,c[2]);
 S.line(x-6,top+6,x-8,hem,c[1]);S.line(x+3,top+9,x+6,hem-1,c[3]);S.line(x-2,top+12,x+1,top+18,c[1]);S.line(x+1,top+18,x-1,top+24,c[1]);
 for(let i=0;i<3;i++){const u=(t+i/3)%1;if(pose!=='prier')F.p(x-5+i*5,hem+2+u*3,c[3])}
 const hx=x+bow,hy=top+bow;S.ell(hx,hy,5.5,5.5,c[2]);S.ell(hx-1,hy-2,3,2,c[3]);S.ell(hx+1,hy+1,3,3.2,v);F.p(hx,hy,c[1]);F.p(hx+2,hy,c[1]);
 let sl=[[x-6,top+7,x-8,top+16],[x+6,top+7,x+8,top+16]];
 if(pose==='porter'){crate(S,x-3,top+11);sl=[[x-6,top+7,x-3,top+13],[x+6,top+7,x+7,top+13]]}
 if(pose==='prier')sl=[[x-5,top+8+bow,x+1,top+14],[x+6,top+8+bow,x+3,top+14]];
 if(pose==='combat'){const a=t<.4?-2.2:lerp(-2.2,.3,sm((t-.4)/.2));sl[1]=[x+6,top+7,x+6+Math.cos(a)*10,top+9+Math.sin(a)*10];const[,,ex,ey]=sl[1];S.line(ex-3,ey-1,ex+3,ey+1,'#d9d3bd',2);S.p(ex+3,ey+1,'#8a8270');if(t>.55&&t<.7)star(F,R(ex+5),R(ey),c[4],2);
  for(let i=0;i<2;i++){const u=(t*1.5+i/2)%1;if(t>.5)F.rect(lerp(x+10,52,u),lerp(top+10,top+6,u),3,2,'#e6e2d4')}}
 sl.forEach(([a,b,cc,d])=>{S.line(a,b,cc,d,c[2],3);S.p(cc,d+1,v)});
 if(pose==='travail'){S.rect(44,20,9,27,'#3a3128');S.rect(45,26,7,1,'#5a4a38');S.rect(45,33,7,1,'#5a4a38');S.rect(45,40,7,1,'#5a4a38');for(let k=0;k<3;k++){S.rect(46+k*2,22,1,4,['#6e5a44','#7d7f85','#5c4632'][k]);S.rect(45+k*2,29,1,4,['#7d7f85','#5c4632','#6e5a44'][k])}
  for(let i=0;i<2;i++){const u=(t+i/2)%1;const px=lerp(hx+3,48,u),py=lerp(hy,35,u)-Math.sin(u*Math.PI)*10;S.rect(px,py,4,3,'#e6e2d4');S.p(px+1,py+1,c[1])}}
 if(pose==='prier')for(let i=0;i<2;i++){const u=(t+i/2)%1;F.p(hx+1,hy-6-u*10,c[4])}
 return{x,rx:8}}

function buste(S,F,pose,t,G){
 const c=G.c;let x=27,lean=0,hdx=0,hdy=0,glow=0;const f=pose==='marche'||pose==='porter'?R(Math.abs(sn(t))*1):0;
 if(pose==='prier'){hdx=1;hdy=R(sm(t*2)*1)+1;glow=.4}
 if(pose==='travail'){glow=Math.abs(sn(t))}
 if(pose==='combat'){lean=R(Math.max(0,sn(t))*4)}
 if(pose==='mort'){const k=sm(t*1.6);S.rect(19,44,16,3,c[2]);S.rect(19,44,16,1,c[3]);S.line(22,44,26,46,c[0]);
  const hx=lerp(27,40,k),hy=lerp(18,43,k);if(t<.35){S.rect(23,32,9,12,c[2]);S.line(25,33,25,43,c[1]);S.line(28,33,28,43,c[1])}
  S.ell(hx,hy,4,5,c[2]);S.ell(hx-1,hy-2,2.5,2,c[3]);S.line(hx-2,hy-3,hx+1,hy+3,c[0]);return{x,rx:9}}
 S.rect(22,45-f,11,2,c[3]);S.rect(23,32-f,9,13,c[2]);S.line(25,33-f,25,44-f,c[1]);S.line(28,33-f,28,44-f,c[1]);S.line(30,33-f,30,44-f,c[3]);S.rect(21,30-f,13,3,c[3]);S.rect(21,32-f,13,1,c[1]);
 S.line(24,36-f,29,41-f,c[0]);
 const sx=x+lean*.5,sy=27-f;S.ell(sx,sy,7,3,c[2]);S.ell(sx-1,sy-1,5,1.5,c[3]);S.rect(sx-1,sy-5,3,3,c[2]);
 const hx=x+lean+hdx,hy=18-f+hdy;S.ell(hx,hy,4,5,c[2]);S.ell(hx-1,hy-3,3.5,2,c[4]);S.p(hx-2,hy,c[1]);S.p(hx+1,hy,c[1]);S.p(hx+3,hy+1,c[1]);S.rect(hx-1,hy+3,2,1,c[1]);
 S.line(hx-3,hy-2,hx-1,hy+2,c[0]);S.line(sx+2,sy-1,sx+5,sy+1,c[0]);
 if(glow>.3){const g=mix(c[2],'#f0f1f3',glow);F.line(hx-3,hy-2,hx-1,hy+2,g);F.line(sx+2,sy-1,sx+5,sy+1,g);F.line(24,36-f,29,41-f,g)}
 if(pose==='porter')crate(S,hx-5,hy-13);
 if(pose==='marche'||pose==='porter')for(let i=0;i<2;i++){const u=(t+i/2)%1;F.p(20-u*5,46-u*2,c[1])}
 if(pose==='travail'){S.rect(40,30,9,6,'#e6e2d4');S.line(44,30,44,35,'#8a8270');S.line(41,32,43,32,c[1]);S.line(45,33,47,33,c[1]);S.line(41,34,43,34,c[1]);F.p(44,28-R(t*6),c[4])}
 if(pose==='combat'&&t>.18&&t<.34)star(F,hx+6,hy,c[4],3);
 return{x,rx:8}}

function marginalia(S,F,pose,t,G){
 const c=G.c,pa='#d6d3c8',pb='#a8a59a',ink='#55575d';let x=27,y=24,flap=sn(t,2),sc=1,fold=0;
 if(pose==='porter'){y=31+R(sn(t,4)*1);flap=sn(t,4)}
 if(pose==='prier'){y=42;flap=-.6;fold=1}
 if(pose==='combat'){const u=t<.6?sm(t/.6):1-sm((t-.6)/.4);x=lerp(18,42,u);y=lerp(16,38,u);flap=-.8}
 if(pose==='mort'){const k=sm(t*1.5);y=lerp(24,44,k);sc=lerp(1,.45,k);flap=0}
 if(pose==='travail'){const k=t<.5?sm(t/.5):1-sm((t-.5)/.5);if(k>.5){const px=21,py=30;S.rect(px,py,13,10,pa);S.rect(px,py,13,1,pb);for(let r=0;r<4;r++)S.line(px+2,py+2+r*2,px+10-(r%2)*3,py+2+r*2,ink);S.p(px+12,py+9,pb);return{x:27,rx:7}}y=lerp(24,32,k);sc=lerp(1,1.3,k);flap=lerp(flap,0,k)}
 const P=(dx,dy)=>[x+dx*sc,y+dy*sc];
 if(pose==='porter'){crate(S,x-5,y+9);S.line(x-2,y+2,x-4,y+9,pb);S.line(x+3,y+2,x+4,y+9,pb)}
 S.poly([P(-8,2),P(8,-1),P(3,3)],pb);
 const wy=fold?-3:-10*flap;S.poly([P(-2,0),P(4,-1),P(-3,wy-1)],pa);S.line(...P(-1,-1),...P(-2,wy*.6),ink);
 S.poly([P(-8,2),P(8,-1),P(2,1)],pa);S.line(...P(-4,1),...P(4,0),ink);S.p(...P(7,-1),pb);
 S.poly([P(0,0),P(5,-1),P(2,wy*(fold?.8:.75)+(fold?0:2))],mix(pa,'#ffffff',.25));S.line(...P(2,-1),...P(2.5,wy*.45),ink);
 if(pose==='mort'&&t>.5){S.mask((px,py)=>S.g(px,py)&&hash(px,py,3)<.25)}
 if(pose==='combat')for(let i=1;i<5;i++)F.p(x-i*3,y-i*1.6,c[3]);
 if(pose==='combat'&&t>.5&&t<.66)star(F,44,40,c[4],2);
 if(pose==='prier')for(let i=0;i<2;i++){const u=(t+i/2)%1;F.p(x-2+i*4,y-4-u*10,c[4])}
 return{x,rx:pose==='prier'?7:5}}

