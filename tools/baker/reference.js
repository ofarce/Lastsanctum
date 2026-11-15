'use strict';
// Harnais de captures de référence : pilote le jeu d'origine (version figée) chargé dans une iframe de
// même origine. Seules les variables globales de l'iframe sont lues ou réglées ; aucun fichier n'est modifié.
// Lancement : python3 tools/baker/serve.py --page reference.html --out tests/visual/reference

const frame = document.getElementById('game');

// Charge Index.html dans l'iframe via srcdoc, en mémoire : <base> pointe vers /src/ et un script
// fixe Math.random avec la même graine que le baker (décision D4), avant tout script du jeu.
async function loadOriginal() {
  const html = await (await fetch('/src/Index.html')).text();
  const seed = `<base href="/src/"><script>${mulberry32.toString()}\nMath.random=mulberry32(${RANDOM_SEED});</script>`;
  const loaded = new Promise(resolve => frame.addEventListener('load', resolve, {once: true}));
  frame.srcdoc = html.replace('<head>', '<head>' + seed);
  await loaded;
}

// Évalue du code dans la portée globale de l'iframe (accès aux let/const du jeu).
function inGame(code) {
  return frame.contentWindow.eval(code);
}

// Éléments désactivables par scénario, pour ne comparer que ce qu'une étape a migré.
const DISABLE = {
  wind: 'windAt=()=>0',
  arcs: 'drawOrbArcs=()=>{}',
  portals: 'drawPortal=()=>flushDecor();drawDeityPortal=()=>flushDecor();deityFx=()=>{};drawEvilPortal=()=>flushDecor()',
  lighting: 'drawLighting=()=>{LIGHTING.c.style.display="none"}',
  effects: 'effects=[];drawEffects=()=>{};drawFireWalls=()=>{}',
  text: 'ctx.fillText=()=>{}',
  turrets: 'turrets=[]',
  units: 'for(const u of units)u.hidden=true',
};
const RESTORABLE = ['windAt', 'drawOrbArcs', 'drawPortal', 'drawDeityPortal', 'deityFx', 'drawEvilPortal', 'drawLighting', 'drawEffects', 'drawFireWalls'];

(async () => {
  const started = performance.now();
  const summary = {errors: Baker.errors, captures: []};
  try {
    await loadOriginal();
    const w = frame.contentWindow;
    w.addEventListener('error', e => Baker.errors.push('jeu : ' + e.message));
    // Gèle la boucle : la première image déjà demandée s'exécute (dt = 0), plus aucune ensuite.
    w.requestAnimationFrame = () => 0;
    await new Promise(r => setTimeout(r, 300));
    for (let i = 0; i < 50 && !inGame('PORTAL.atlas && PORTAL.atlas.complete && PORTAL.atlas.naturalWidth'); i++) {
      await new Promise(r => setTimeout(r, 100));
    }
    inGame(`var GALLERY_SEED=${GALLERY_SEED};var __ref=({${RESTORABLE.join(',')}})`);
    const config = await (await fetch('/reference_scenarios.json')).json();
    for (const s of config.scenarios) {
      inGame(`({${RESTORABLE.join(',')}}=__ref);delete ctx.fillText`);
      const off = s.disable || [];
      // init() régénère les galeries au hasard : la graine de référence est rétablie juste après.
      inGame(`init();generateGalleries(GALLERY_SEED);PIXEL=true;PX=${s.px};resize();currentTime=${s.t};portalTick();`);
      if (s.dig) {
        const n = inGame(`(()=>{const sc=(${digScenario.toString()})();for(const[i,j]of sc.cells)digCell(i,j);`
          + `const[i,j]=sc.cells[sc.cells.length-1];cam={x:i*4+2,z:j*4+2,zoom:.9};return sc.cells.length})()`);
        if (!n) Baker.errors.push(`${s.name} : aucun scénario de creusement`);
      }
      if (s.cam) inGame(`cam={x:${s.cam.x},z:${s.cam.z},zoom:.9};clampCam()`);
      // Bâtiments posés directement (étape 7) : achevés, ou chantier à une progression donnée (0–1), sans Ingénieur.
      if (s.buildings) inGame(`buildings=${JSON.stringify(s.buildings)}.map((b,i)=>({id:i,type:b.type,x:b.x,z:b.z,owner:null,`
        + `progress:(b.progress??1)*BUILDINGS[b.type].time,complete:(b.progress??1)>=1,queue:[],train:0}))`);
      if (s.orb === 'active') inGame('ORB.active=ORB.complete=true;ORB.progress=ORB.time');
      else if (typeof s.orb === 'number') inGame(`ORB.owner=units[0];ORB.progress=${s.orb}*ORB.time`);
      // init() ne remet pas d.active à zéro (recalculé seulement par updateAdepts) : état forcé à chaque scénario.
      inGame(`for(const d of DEITY_PORTALS)d.active=d.id===${JSON.stringify(s.deity || null)}`);
      for (const k of off) inGame(DISABLE[k]);
      // Ennemis posés directement (étape 8) et balistes éveillées.
      if (s.enemies) inGame(`enemies=${JSON.stringify(s.enemies)}.map(e=>({x:e.x,z:e.z,hp:20,max:35,speed:2,range:1.5,damage:6,kind:e.kind,cooldown:1,target:null}))`);
      if (s.turrets === 'active') inGame('activateTurrets();effects=[]');
      // Héros et personnages posés directement (étape 9) : coup d'épée k commencé il y a `swing[1]` s, salve
      // commencée il y a `volley` s, orientation imposée (u._face), PV, sélection.
      if (s.units) inGame(`units=[];uid=0;selected=[];for(const o of ${JSON.stringify(s.units)}){const u=soldier('U',o.x,o.z,o.role);`
        + `if(o.hp!=null)u.hp=o.hp;if(o.face)u._face=o.face;if(o.swing){u._sw=o.swing[0];u._swT0=currentTime-o.swing[1]}`
        + `if(o.volley!=null)u._shT0=currentTime-o.volley;if(o.selected)selected.push(u)}`);
      // Effets posés directement (étape 9), à l'âge donné ; murs de feu (âge, durée restante).
      if (s.effects) inGame(`effects=${JSON.stringify(s.effects)}`);
      if (s.fire_walls) inGame(`fireWalls=${JSON.stringify(s.fire_walls)}.map(w=>({x:w.x,z:w.z,dx:w.dx,dz:w.dz,len:w.len,`
        + `t0:currentTime-w.age,until:currentTime+w.left}))`);
      // Personnages : plusieurs images pour qu'ils passent au repos (u._still ≥ 4), comme en jeu.
      inGame(s.enemies || s.units ? 'for(let i=0;i<6;i++)draw()' : 'draw()');
      const c = w.document.getElementById('game');
      await save(`${s.name}.png`, c);
      if (!off.includes('lighting')) await save(`${s.name}_light.png`, inGame('LIGHTING.c'));
      summary.captures.push({...s, size: [c.width, c.height], cam: inGame('({x:cam.x,z:cam.z})')});
      await bkLog(`capture ${s.name} (${c.width}×${c.height})`);
    }
    await save('scenarios.json', {...config, generated_by: 'tools/baker/reference.js', gallery_seed: GALLERY_SEED, captures: summary.captures});
  } catch (error) {
    Baker.errors.push(String(error && error.stack || error));
  }
  summary.page_seconds = Math.round(performance.now() - started) / 1000;
  await fetch('/done', {method: 'POST', body: JSON.stringify(summary)});
})();
