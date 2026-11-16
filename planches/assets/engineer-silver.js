// Propositions en textile argenté, gabarit natif EngineerBare (80×84), rendu jeu ×0,5.
'use strict';
const EngineerSilver=(()=>{
 const silver=['#30353d','#555d67','#7d8792','#aab3bc','#d4dbe0','#eef1f1'];
 const dark=['#171c22','#252d35','#39434d','#55616b','#79858f'];
 const {fill,ell,seg,line,outlineAll}=UnitKit;
 function sprite(id,t=0){
  const P=new Px(40,42,true),Q=UnitKit.scaled(P,.5),b=Math.sin(t*2.6)>0?0:1;
  const O=EngineerBare.parts.off(Q,0,b),SK=UnitKit.K.skin;
  // Souplesse du textile : jambes distinctes, plis, aucun élément d'armure.
  for(const s of [-1,1]){const x=30+s*4,z=s<0?3:5;
   fill(Q,[[x-3.5,47],[x+3.5,47],[x+3,62],[x+2.5,77],[x-3,77],[x-3.5,62]],silver,z,{v:s<0?.61:.83,fold:1,tex:8});
   fill(Q,[[x-3,75],[x+3,75],[x+6,79],[x+6,80],[x-3,80]],dark,z+.3,{v:.7});
   line(Q,x-2,61,x+2,62,silver[2],z+.4);
  }
  for(const s of [-1,1]){const z=s<0?2:13,a=[30+s*8,32],e=[30+s*10,42],h=[30+s*10,51];
   seg(O,a,e,id===2?6:5.3,silver,z,{v:s<0?.62:.87,fold:1});
   seg(O,e,[h[0],h[1]-2],4.5,id===1?SK:silver,z,{v:s<0?.56:.8,fold:1});
   fill(O,[[h[0]-2,49],[h[0]+2,49],[h[0]+2,54],[h[0]-2,54]],SK,z+.3,{v:.7});
   if(id===3)line(O,e[0]-2,e[1],e[0]+2,e[1]+1,dark[2],z+.5);
  }
  fill(O,[[22,29],[27,28],[34,28],[38,30],[37,48],[23,48]],silver,8,{v:.9,fold:1,tex:9});
  fill(O,[[23,46],[37,46],[38,51],[23,51]],silver,9,{v:.7});
  if(id===0){line(O,30,30,30,47,dark[1],10);line(O,31,31,31,45,silver[4],10);}
  if(id===1||id===3){for(const x of[24,32]){fill(O,[[x,34],[x+4,34],[x+4,39],[x,39]],silver,10,{v:.75});line(O,x,35,x+4,35,dark[2],11)}}
  if(id===2){line(O,25,29,35,42,dark[1],10);line(O,26,29,36,42,silver[4],10);line(O,24,45,35,45,dark[2],10)}
  if(id===3){fill(O,[[22,31],[25,34],[25,46],[23,46]],dark,10,{v:.65});fill(O,[[35,34],[38,31],[37,46],[35,46]],dark,10,{v:.6});}
  if(id!==2){fill(O,[[22,46],[38,46],[38,49],[22,49]],dark,11,{v:.65});fill(O,[[29,46],[32,46],[32,49],[29,49]],silver,12,{v:.95})}
  if(id===1||id===3){fill(O,[[21,48],[26,48],[26,55],[21,55]],UnitKit.K.leath,12,{v:.8});line(O,23,49,23,53,silver[3],13)}
  if(id===4){fill(O,[[33,39],[37,39],[37,43],[33,43]],dark,10,{v:.8});line(Q,31,65,35,66,dark[2],12);EngineerBare.parts.scarf(O,[31,30],t)}
  // Posture verticale : cou au centre du buste, crâne au-dessus, regard horizontal.
  // Le visage est redessiné ici : la tête inclinée d’EngineerBare n’est pas réutilisée.
  seg(O,[30,29],[30,22],5,SK,22,{v:.7});
  ell(O,30,17,6,8,SK,24,{v:.83});
  fill(O,[[25,16],[35,15],[37,18],[36,22],[33,25],[28,24],[26,21]],SK,25,{v:.8});
  const hair=['#17110d','#2e2016','#46321f','#665039'];
  fill(O,[[24,18],[23,13],[25,9],[28,8],[32,8],[35,10],[37,12],[35,14],[28,13],[27,18]],hair,26,{v:.75});
  line(O,26,10,31,9,hair[3],26.2);line(O,24,13,27,11,hair[2],26.2);
  ell(O,26,18,1.5,2,SK,27,{v:.7});
  // Sourcils et yeux au même niveau : aucune pente du front vers le nez.
  line(O,30,16,32,16,hair[0],27);line(O,34,16,35,16,hair[0],27);
  O.set(31,17,'#17120f',28);O.set(35,17,'#17120f',28);
  O.set(36,19,SK[4],28);line(O,32,22,35,22,SK[1],28);
  for(const [x,y] of [[29,22],[30,23],[32,24],[34,23]])O.set(x,y,hair[1],28);
  outlineAll(P);P.flush();return P.c;
 }
 return {sprite};
})();
