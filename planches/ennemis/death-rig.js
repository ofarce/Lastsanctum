'use strict';
// Cinématique de mort uniquement. Les pièces rigides tournent autour d'articulations ;
// les textures sont échantillonnées dans leur repère initial, sans étirement du sprite.
const DeathRig=(()=>{
const clamp=x=>Math.max(0,Math.min(1,x));
const smooth=x=>{x=clamp(x);return x*x*(3-2*x)};
const mix=(a,b,t)=>a+(b-a)*t;
const point=(a,b,t)=>[mix(a[0],b[0],t),mix(a[1],b[1],t)];
function key(t,keys){
  for(let i=1;i<keys.length;i++)if(t<=keys[i][0]){
    const a=keys[i-1],b=keys[i],u=smooth((t-a[0])/(b[0]-a[0]));
    return a.slice(1).map((v,j)=>mix(v,b[j+1],u));
  }
  return keys[keys.length-1].slice(1);
}
function rigid(origin,target,angle){
  const c=Math.cos(angle),s=Math.sin(angle);
  return {
    to(x,y){x-=origin[0];y-=origin[1];return [target[0]+x*c-y*s,target[1]+x*s+y*c]},
    from(x,y){x-=target[0];y-=target[1];return [origin[0]+x*c+y*s,origin[1]-x*s+y*c]}
  };
}
function bone(a,b,c,d){
  const a0=Math.atan2(b[1]-a[1],b[0]-a[0]);
  const a1=Math.atan2(d[1]-c[1],d[0]-c[0]);
  return rigid(a,c,a1-a0);
}
// Chaîne à deux segments, longueur conservée et cible bornée à la portée du membre.
function joint(a,target,l1,l2,side){
  const dx=target[0]-a[0],dy=target[1]-a[1],distance=Math.hypot(dx,dy)||.001;
  const d=Math.max(Math.abs(l1-l2)+.01,Math.min(l1+l2-.01,distance));
  const end=[a[0]+dx/distance*d,a[1]+dy/distance*d];
  const angle=Math.atan2(dy,dx)+side*Math.acos(Math.max(-1,Math.min(1,(l1*l1+d*d-l2*l2)/(2*l1*d))));
  return {elbow:[a[0]+Math.cos(angle)*l1,a[1]+Math.sin(angle)*l1],end};
}
const length=(a,b)=>Math.hypot(b[0]-a[0],b[1]-a[1]);
function limb(a,b,c,start,end,side){
  const bend=Math.sign((c[0]-a[0])*(b[1]-a[1])-(c[1]-a[1])*(b[0]-a[0]))||side;
  const j=joint(start,end,length(a,b),length(b,c),bend);
  return {upper:bone(a,b,start,j.elbow),lower:bone(b,c,j.elbow,j.end),tip:j.end,
    hand:rigid(c,j.end,Math.atan2(j.end[1]-j.elbow[1],j.end[0]-j.elbow[0])-Math.atan2(c[1]-b[1],c[0]-b[0])),
    choose(x,y){return length([x,y],point(a,b,.5))<length([x,y],point(b,c,.5))?this.upper:this.lower}};
}
function human(t,s){
  // Recul court → perte des appuis → genou au sol → bascule accélérée → contact → relâchement.
  const [hx,hy,angle]=key(t,[[0,30,49,0],[.10,28,49,-.10],[.27,27,56,.05],[.44,29,66,.34],[.62,33,68,.72],[.78,35,67,1.40],[.84,36,65.5,1.36],[1,36,67,1.43]]);
  const body=rigid([30,49],[hx,hy],angle),settle=smooth((t-.77)/.23);
  const head=rigid([31,26],body.to(31,26),angle+smooth((t-.36)/.4)*.16-settle*.05);
  const legs=[];
  for(const side of [-1,1]){
    const x=30+side*4.5*(s.bulk||1),a=[x,50],b=[x,61],c=[x,77];
    const start=body.to(...a);
    // Le pied avant reste planté jusqu'au contact du genou. Ensuite les jambes traînent.
    const slide=smooth((t-(side<0?.49:.39))/.48);
    const end=point(c,side<0?[15,79]:[25,80],slide);
    legs.push(limb(a,b,c,start,end,side<0?-1:1));
  }
  const bulk=s.bulk||1;
  const sources=[[[30-9.5*bulk,32],s.eRo||[30-12.5*bulk,42],s.hRo||[30-11*bulk,50]],
    [[30+9.5*bulk,32],s.eLo||[30+13*bulk,40],s.hLo||[30+12*bulk,47]]];
  if(s.pose==='guard'&&!s.hRo){sources[0][1]=[30-12*bulk,40];sources[0][2]=[24,44]}
  if(s.pose==='twohand'){
    if(!s.eRo)sources[0][1]=[30-12*bulk,44];if(!s.hRo)sources[0][2]=[25,52];
    if(!s.eLo)sources[1][1]=[30+12*bulk,38];if(!s.hLo)sources[1][2]=[37,41];
  }
  const arms=sources.map(([a,b,c],i)=>{
    const reach=smooth((t-.3)/.45),start=body.to(...a);
    const end=point(body.to(...c),i?[60,77]:[62,76],reach);
    end[0]+=settle*(i?2:4);end[1]+=settle*(i?1:2);
    return limb(a,b,c,start,end,i?1:-1);
  });
  const cape=rigid([30,31],body.to(30,31),angle-smooth((t-.45)/.5)*.10);
  return (x,y,z)=>{
    const side=x<30?0:1;
    if(z>=5&&z<=7)return z===6?legs[side].hand:legs[side].choose(x,y);
    if(z===16)return arms[side].choose(x,y);
    if(z===17)return arms[side].hand;
    if(z>=55&&z<=59)return arms[1].hand;
    if(z>=64||(z>=49&&z<=54))return arms[0].hand;
    if(y<29&&z>=29)return head;
    if(z===1)return cape;
    return body;
  };
}
function automaton(t){
  // Le colosse se tasse sous son poids, pose un poing puis roule sur l'épaule.
  const [x,y,a]=key(t,[[0,40,59,0],[.14,39,61,-.06],[.37,39,68,.10],[.58,43,70,.42],[.76,47,67,.96],[.82,48,65,.91],[1,48,67,1.01]]);
  const body=rigid([40,59],[x,y],a),drop=smooth((t-.25)/.55);
  const arms=[limb([24,38],[16,56],[18,72],body.to(24,38),point(body.to(18,72),[59,78],drop),-1),
    limb([54,40],[64,54],[62,68],body.to(54,40),point(body.to(62,68),[77,78],drop),1)];
  const backFoot=bone([34,64],[31,80],body.to(34,64),[29,80]);
  const frontFoot=bone([48,64],[51,80],body.to(48,64),[44,81]);
  return (x,y,z)=>{
    if((z===8||z===9)&&x>25&&y>63)return backFoot;
    if((z===30||z===31)&&y>63)return frontFoot;
    if((z===9||z===10)&&x<26)return arms[0].choose(x,y);
    if(z===40&&y>44)return arms[1].choose(x,y);
    if(z===41&&y>55)return arms[1].hand;
    return body;
  };
}
function beast(t){
  // Un quadrupède perd ses appuis sous le ventre ; il ne tombe pas comme un humain.
  const [drop,tilt,headDrop]=key(t,[[0,0,0,0],[.12,-1,-.04,-1],[.34,4,.06,4],[.58,9,.12,14],[.67,8,.10,13],[.86,10,.13,16],[1,10,.13,16]]);
  const body=rigid([38,63],[38,63+drop],tilt);
  const neck=body.to(54,58);
  const head=rigid([54,58],[neck[0],58+headDrop],tilt+smooth(t/.65)*.25);
  const tuck=smooth((t-.15)/.5);
  const tail=rigid([24,68],body.to(24,68),-tuck*.25);
  const legs=new Map();
  for(const x of [28,34,46,52])legs.set(x,limb([x,66],[x-4,72],[x-1,80],body.to(x,66),[x-1-tuck*5,80],x<40?-1:1));
  return (x,y,z)=>{
    if(z===8||z===9||z===30||z===31){
      const leg=[28,34,46,52].reduce((a,b)=>Math.abs(x-b)<Math.abs(x-a)?b:a);
      return legs.get(leg).choose(x,y);
    }
    if(z>=39){
      // Les yeux et la gueule suivent le crâne, le réseau veineux suit le corps.
      if(x>52&&z!==60)return head;
    }
    if(z===10&&x<25)return tail;
    return body;
  };
}
function proxy(P,t,s={}){
  const choose=s.deathKind==='golem'?automaton(t):s.deathKind==='beast'?beast(t):human(t,s);
  return {w:P.w,h:P.h,d:P.d,
    set(x,y,c,z){const tr=choose(x,y,z),p=tr.to(x,y);P.set(...p,c,z)},
    ramp:(...a)=>P.ramp(...a),
    poly(pts,fn,z){
      const x=pts.reduce((v,p)=>v+p[0],0)/pts.length,y=pts.reduce((v,p)=>v+p[1],0)/pts.length;
      const tr=choose(x,y,z);
      P.poly(pts.map(p=>tr.to(...p)),(x,y)=>fn(...tr.from(x,y)),z);
    },
    line(x,y,x2,y2,c,z){const tr=choose((x+x2)/2,(y+y2)/2,z);P.line(...tr.to(x,y),...tr.to(x2,y2),c,z)}
  };
}
return {proxy};
})();
