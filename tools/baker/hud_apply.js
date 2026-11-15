'use strict';
// Applique un contexte déclaratif de hud_contexts.json au jeu d'origine (73b410f).
// Cette fonction est évaluée DANS la portée globale du jeu (iframe) : elle lit et règle ses variables
// globales (units, buildings, ORB, HUD…). Utilisée par hud.js (extraction) et hud_shot.html (captures).
function hudApplyContext(c) {
    init();generateGalleries(GALLERY_SEED);closeCharacterDialogue();
    units=[];uid=0;buildings=[];FALLEN=[];DIG_HITS_DONE.clear();
    currentTime=c.t;ended=!!c.ended;coreHP=c.core_hp??100;nextWave=c.next_wave??0;spawnQueue=[];
    for(const k of RES_ORDER)RES[k]=(c.res&&c.res[k])||0;
    const mk=s=>{const u=soldier(s.name,s.x??0,s.z??-147,s.role);if(ADEPT[s.role]){u.hp=u.max=ADEPT[s.role].hp;u.radius=.55}
      if(s.hp!=null)u.hp=s.hp;if(s.hidden)u.hidden=true;if(s.ability)u.ability=s.ability;if(s.stance)u.stance=s.stance;
      if(s.level)u.level=s.level;if(s.xp!=null)u.xp=s.xp;if(s.working)u.working=true;return u};
    for(const s of c.units||[])mk(s);
    buildings=(c.buildings||[]).map((s,i)=>({id:i,type:s.type,x:s.x,z:s.z,owner:null,progress:s.complete?BUILDINGS[s.type].time:(s.progress||0),
      complete:!!s.complete,queue:[...(s.queue||[])],train:0,spot:workSpot(s.type,{x:s.x,z:s.z})}));
    for(const s of c.fallen||[]){const u=mk(s);units=units.filter(o=>o!==u);u.hp=0;u.dead=true;FALLEN.push(u)}
    (c.units||[]).forEach((s,i)=>{const u=units[i];
      if(s.orb_job)u.orbJob=ORB;
      if(s.build_job!=null){const b=buildings[s.build_job];u.buildJob=b;b.owner=u}
      if(s.job&&s.job.type==='dig'){const[ci,cj]=s.job.cell;u.job={phase:'go',carry:0,work:0,type:'dig',cell:{i:ci,j:cj},at:{x:ci*4+2,z:cj*4+2}};
        if(s.job.hits)DIG_HITS_DONE.set(ci+','+cj,s.job.hits)}
      if(s.job&&s.job.type==='pray')u.job={phase:'go',carry:0,work:0,type:'pray',temple:buildings[s.job.temple]}});
    resetOrb();const o=c.orb||{};ORB.active=ORB.complete=!!o.active;ORB.progress=o.active?ORB.time:(o.progress||0);
    ORB.owner=o.owner!=null?units[o.owner]:null;
    selected=(c.selected||[]).map(i=>units[i]);HUD.anchor=!!c.anchor;HUD.building=c.building!=null?buildings[c.building]:null;
    HUD.menu=c.menu||null;HUD.mode=c.mode||null;HUD.buildType=c.build_type||null;
}
