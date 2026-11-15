'use strict';
// Extraction du HUD du prototype (version figée 73b410f), étape 6 du plan v2.
// Le jeu d'origine est chargé dans une iframe de même origine (comme reference.js) ; seules ses variables
// globales sont lues ou réglées. Rien n'est modifié dans le prototype.
// Lancement : python3 tools/baker/serve.py --page hud.html --out assets/baked/hud
// Produit :
//  - hud_actions.json : pour chaque contexte de hud_contexts.json, panelActions() et les textes du HUD ;
//  - hud_texts.json : catalogue (bâtiments, adeptes, coûts), textes fixes (dialogue, bannières, notices) ;
//  - portraits/<clé>.png : drawHUDPortrait() pour chaque clé de portrait ;
//  - minimap_initial.png, minimap_dig.png : fond de la minicarte (buildMiniMap) avant et après creusement ;
//  - minimap_frame.png : minicarte complète (drawMiniMap) au départ, dans une fenêtre de 1440×900.

const frame = document.getElementById('game');

async function loadOriginal() {
  const html = await (await fetch('/src/Index.html')).text();
  const seed = `<base href="/src/"><script>${mulberry32.toString()}\nMath.random=mulberry32(${RANDOM_SEED});</script>`;
  const loaded = new Promise(resolve => frame.addEventListener('load', resolve, {once: true}));
  frame.srcdoc = html.replace('<head>', '<head>' + seed);
  await loaded;
}

const inGame = code => frame.contentWindow.eval(code);

// Applique un contexte déclaratif (voir hud_contexts.json, hud_apply.js) au jeu d'origine.
function applyContext(c) {
  frame.contentWindow.__ctx = c;
  inGame(`(${hudApplyContext.toString()})(__ctx)`);
}

function readHUD() {
  return inGame(`(()=>{updateHUD(true);const e=HUD.els,txt=id=>e[id].textContent;
    return {actions:HUD.actions.map(a=>({id:a.id,icon:a.icon,label:a.label,key:a.key,title:a.title||'',disabled:!!a.disabled,active:!!a.active,cooldown:a.cooldown||''})),
      wave:txt('wave'),res:Object.fromEntries(RES_ORDER.map(k=>[k,txt('res-'+k)])),population:txt('population'),
      kind:txt('selection-kind'),chosen:txt('chosen'),health_text:txt('health-text'),health_pct:parseFloat(e['health-fill'].style.width),
      health_label:e['health-fill'].parentElement.getAttribute('aria-label'),status:txt('selection-status'),
      damage:txt('unit-damage'),armor:txt('unit-armor'),speed:txt('unit-speed'),lore:txt('lore'),assault:txt('assault-time'),
      anchor_details:!e['anchor-details'].hidden,portrait_enabled:!e['portrait-button'].disabled,portrait_key:HUD.portraitKey}})()`);
}

(async () => {
  const started = performance.now();
  const summary = {errors: Baker.errors, captures: []};
  try {
    await loadOriginal();
    const w = frame.contentWindow;
    w.addEventListener('error', e => Baker.errors.push('jeu : ' + e.message));
    w.requestAnimationFrame = () => 0;
    await new Promise(r => setTimeout(r, 300));
    inGame(`var GALLERY_SEED=${GALLERY_SEED}`);

    // 1. Listes d'actions et textes du HUD pour chaque contexte.
    const config = await (await fetch('/hud_contexts.json')).json();
    const results = [];
    for (const c of config.contexts) {
      applyContext(c);
      results.push({name: c.name, hud: readHUD()});
      await bkLog(`contexte ${c.name} : ${results.at(-1).hud.actions.map(a => a.id).join(', ') || '(aucune action)'}`);
    }
    await save('hud_actions.json', {generated_by: 'tools/baker/hud.js', contexts: config.contexts, results});

    // 2. Textes fixes et catalogue utilisés par le HUD.
    const texts = inGame(`(()=>{const out={};
      init();out.init_notice=document.getElementById('notice').textContent;
      out.greeting=(()=>{let d=null;const keep=showCharacterDialogue;showCharacterDialogue=x=>{d=x};greetEngineer(units[0]);showCharacterDialogue=keep;
        return {name:d.name,compact:d.compact,lines:d.lines}})();
      const banner=()=>document.getElementById('banner').innerHTML;
      end(true);out.banner_won=banner();init();
      coreHP=0;end(false);out.banner_core=banner();init();
      units[0].hp=0;end(false);out.banner_engineer=banner();init();
      out.lore=HUD_LORE;out.res_info=RES_INFO;out.res_order=RES_ORDER;out.deity_res=DEITY_RES;
      out.buildings=Object.fromEntries(Object.entries(BUILDINGS).map(([k,D])=>[k,{name:D.name,cost:D.cost,deity:D.deity||null,requires:D.requires||null,
        key:D.key,icon:D.icon,time:D.time,size:D.size||3,lore:D.lore,art:D.art}]));
      out.adept=ADEPT;out.fight=Object.fromEntries(Object.entries(FIGHT).map(([k,f])=>[k,{dmg:f.dmg,status:f.status}]));
      out.deity_portals=DEITY_PORTALS.map(d=>({id:d.id,name:d.name}));
      out.summon_cost=SUMMON_COST;out.caserne_cost=CASERNE_COST;out.caserne_time=CASERNE_TIME;out.caserne_queue=CASERNE_QUEUE;
      out.caserne_units=CASERNE_UNITS;out.revive_cost=REVIVE_COST;out.hero_cost=HERO_COST;out.orb_time=ORB.time;out.dig_hits=DIG_HITS;
      out.xp_need=[1,2,3,4,5,6,7,8].map(xpNeed);
      return out})()`);
    await save('hud_texts.json', {generated_by: 'tools/baker/hud.js', ...texts});

    // 3. Portraits (drawHUDPortrait) : Ancre, unités, adeptes, bâtiments, vide.
    const keys = ['anchor', 'engineer', 'shooter', 'paladin', 'healer', 'guard', ...Object.keys(texts.adept),
      ...Object.keys(texts.buildings).map(k => 'bld-' + k), 'empty'];
    for (const k of keys) {
      inGame(`drawHUDPortrait(${JSON.stringify(k)})`);
      await save(`portraits/${k}.png`, inGame('HUD.els.portrait'));
    }
    await bkLog(`${keys.length} portraits`);

    // 4. Emplacements de construction (étape 7) : 60 points témoins × 3 types, avec un temple déjà construit
    //    et l'Ingénieur dans la salle. snapFor, validSite, buildableGround, workSpot.
    const sites = inGame(`(()=>{init();generateGalleries(GALLERY_SEED);units=[];uid=0;
      const u=soldier('Ingénieur Exilé',-13,-147,'engineer');
      buildings=[{id:0,type:'sigil',x:-26,z:-118,owner:null,progress:4,complete:true,queue:[],train:0}];
      const R=(${mulberry32.toString()})(7707),out=[];
      for(let i=0;i<60;i++){const p={x:Math.round((R()*130-65)*1e4)/1e4,z:Math.round((R()*110-160)*1e4)/1e4};
        const row={p:[p.x,p.z],buildable:buildableGround(p.x,p.z)};
        for(const t of ['sigil','bedroom','caserne']){const q=snapFor(t,p);row[t]={snap:[q.x,q.z],valid:validSite(t,q),spot:(s=>[s.x,s.z])(workSpot(t,q))}}
        out.push(row)}
      return {gallery_seed:GALLERY_SEED,engineer:[u.x,u.z],buildings:buildings.map(b=>({type:b.type,x:b.x,z:b.z})),
        turrets:turrets.map(t=>[t.x,t.z]),points:out}})()`);
    await save('sites.json', sites);
    await bkLog(`emplacements : ${sites.points.filter(r => r.sigil.valid).length} / 60 valides (temple)`);

    // 5. Combat (étape 8) : tables, frappes de chaque rôle, charge de l'archer, expérience, vagues, ennemis.
    const combat = inGame(`(()=>{const out={},r4=v=>Math.round(v*1e4)/1e4;
      out.fight=JSON.parse(JSON.stringify(FIGHT));out.charge=CHARGE;out.moulinet=MOULINET;out.sillon=SILLON;out.kill_xp=KILL_XP;
      out.turret=TURRET_CONFIG;out.evil={interval:EVIL.interval,cap:EVIL.cap};out.volley=VOLLEY;
      out.after_armor=[];for(const lv of[1,2,5,30])for(const d of[4,6,12,20])out.after_armor.push([lv,d,afterArmor({level:lv},d)]);
      const setup=(role,level)=>{init();generateGalleries(GALLERY_SEED);units=[];uid=0;enemies=[];effects=[];fireWalls=[];currentTime=10;
        const u=soldier('U',0,-120,role);if(ADEPT[role]){u.hp=u.max=ADEPT[role].hp;u.radius=.55}u.level=level;return u};
      const foe=(kind,x,z,hp)=>{const e={x,z,hp,max:hp,speed:2,range:1.5,damage:6,kind,cooldown:1,target:null};enemies.push(e);return e};
      const snap=u=>({hp:enemies.map(e=>r4(e.hp)),attack:r4(u.attack),orage:u.orage||0,walls:fireWalls.length,xp:u.xp,level:u.level,
        stun:enemies.map(e=>r4(e.stun||0)),x:r4(u.x),z:r4(u.z)});
      const S=[];
      for(const[role,level,n]of[['engineer',1,3],['engineer',3,2],['sigil',1,2],['archer',2,2],['lame',1,5],['lame',4,5],['flammes',1,3],['flammes',2,2]]){
        const u=setup(role,level);foe('brute',1,-120,400);foe('creep',2,-121,400);foe('creep',1.5,-119,400);foe('spitter',6,-120,400);
        const log=[];for(let i=0;i<n;i++){barracksStrike(u,enemies[0]);log.push(snap(u));currentTime+=1}
        S.push({role,level,strikes:log})}
      out.strikes=S;
      // Charge du Lac : l'archer à 4 unités d'un rampant, pas de 0,05 s.
      {const u=setup('archer',1);const e=foe('creep',4,-120,200);const log=[];
       for(let i=0;i<30;i++){u.attack-=.05;archerTick(u,e,.05);currentTime+=.05;log.push(snap(u))}out.charge_run=log}
      // Expérience : gains successifs.
      {const u=setup('sigil',1);const log=[];for(const n of[10,15,35,6,10,35,35,35,15,10])log.push((gainXP(u,n),[u.level,u.xp]));out.xp_run=log}
      // Héros (étape 9) : 40 pas de 0,05 s de la boucle complète (update), puis les compétences.
      const usnap=()=>({units:units.map(o=>[r4(o.x),r4(o.z),r4(o.hp),r4(o.attack),r4(o.ability),r4(o.shield||0),r4(o.buff||0)]),
        enemies:enemies.map(e=>[r4(e.x),r4(e.z),r4(e.hp)]),core:r4(coreHP),effects:effects.length});
      out.heroes=[];
      for(const H of [
        {role:'paladin',level:1,allies:[],foes:[['brute',1.5,-120,400],['creep',2,-121,60]]},
        {role:'shooter',level:2,allies:[],foes:[['creep',12,-120,150],['spitter',15,-118,100]]},
        {role:'healer',level:1,allies:[['engineer',2,-120,50]],foes:[['creep',6,-120,500]]},
        {role:'paladin',level:3,allies:[['shooter',-3,-121,110]],foes:[['brute',4,-120,300],['spitter',9,-119,200],['creep',-6,-118,80]]}]){
        const u=setup(H.role,H.level);for(const[r,x,z,hp]of H.allies){const a=soldier('A',x,z,r);a.hp=hp}
        for(const[k,x,z,hp]of H.foes)foe(k,x,z,hp);nextWave=1e9;ORB.active=false;
        const log=[];for(let i=0;i<40;i++){update(.05);log.push(usnap())}out.heroes.push({...H,steps:log})}
      // Compétences : Égide, Restauration, Discipline martiale, tir de précision.
      {const p=setup('paladin',2);const h=soldier('Soigneur',1,-120,'healer');h.hp=30;const s=soldier('Tireur',-2,-121,'shooter');
       const a=soldier('Archer',3,-119,'archer');a.hp=a.max=ADEPT.archer.hp;a.squad=0;const g=soldier('Garde',12,-120,'guard');
       foe('creep',2,-120,100);foe('creep',8,-120,100);foe('brute',4,-121,300);
       const log=[];for(const who of[p,h,a,s,p]){selected=[who];ability();log.push({...usnap(),effect:effects.length?{...effects.at(-1),tgt:undefined}:null})}
       out.abilities=log}
      // Vagues 1 à 6.
      out.waves=[];for(let w=1;w<=6;w++){init();currentTime=100;wave=w-1;startWave();out.waves.push(spawnQueue.map(s=>({at:r4(s.at),x:s.x,kind:s.kind})))}
      // Statistiques des ennemis (hors tirages).
      init();enemies=[];out.enemies={};for(const k of['creep','spitter','brute']){spawn({x:2,kind:k});const e=enemies.at(-1);out.enemies[k]={hp:e.hp,max:e.max,speed:e.speed,range:e.range,damage:e.damage}}
      return out})()`);
    await save('combat.json', combat);
    await bkLog(`combat : ${combat.strikes.length} séquences de frappes, ${combat.waves.length} vagues`);

    // 6. Minicarte : fond initial, fond après le scénario de creusement, image complète au départ.
    inGame('init();generateGalleries(GALLERY_SEED);resetBlocks();buildPixelWorld();buildMiniMap()');
    await save('minimap_initial.png', inGame('HUD.mapBackground'));
    inGame('drawMiniMap()');
    await save('minimap_frame.png', inGame('HUD.els.minimap'));
    const n = inGame(`(()=>{const sc=(${digScenario.toString()})();for(const[i,j]of sc.cells)digCell(i,j);return sc.cells.length})()`);
    if (!n) Baker.errors.push('minicarte : aucun scénario de creusement');
    await save('minimap_dig.png', inGame('HUD.mapBackground'));
    const bar = inGame('HUD.els["command-bar"].getBoundingClientRect().height');
    // Arbres de la jungle (tirés au chargement du script, Math.random à graine fixe) : [x, z, grand (h > 4)].
    const trees = inGame('trees.map(t=>[Math.round(t.x*1e4)/1e4,Math.round(t.z*1e4)/1e4,t.h>4?1:0])');
    await save('minimap_meta.json', {gallery_seed: GALLERY_SEED, dig_cells: n, viewport: [1440, 900], command_bar_height: bar,
      cam: inGame('({x:cam.x,z:cam.z})'), px: inGame('PX'),
      deity_portals: inGame('DEITY_PORTALS.map(d=>({id:d.id,x:d.x,color:DEITY_LOOK[d.id].glow[3]}))'),
      turrets: inGame('turrets.map(t=>({x:t.x,z:t.z,complete:t.complete}))'), trees});
  } catch (error) {
    Baker.errors.push(String(error && error.stack || error));
  }
  summary.page_seconds = Math.round(performance.now() - started) / 1000;
  await fetch('/done', {method: 'POST', body: JSON.stringify(summary)});
})();
