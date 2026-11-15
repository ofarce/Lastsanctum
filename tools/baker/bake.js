'use strict';
// Extraction des graphismes procéduraux du prototype, version figée 73b410f (MIGRATION_PLAN.md v2, étape 1).
// Toutes les images viennent des fonctions d'origine exécutées sans modification ; ce fichier ne fait
// que les appeler, recadrer et assembler les planches.
// Paramètre d'URL facultatif : ?only=world,portals,units,adepts,buildings,overlay,fixtures

const ONLY = new URLSearchParams(location.search).get('only')?.split(',') || null;
const wantPart = part => !ONLY || ONLY.includes(part);
const BUILDING_FPS = 12, ACTOR_FPS = 12;
// Éléments affichés à la résolution écran (empreintes) : échelle ×2 pour rester nets.
const OVERLAY_SCALE = 2;
const manifest = {version: 2, generated_by: 'tools/baker/bake.js', random_seed: RANDOM_SEED, gallery_seed: GALLERY_SEED};
const thumbs = [];
const bkKeep = (name, c, w, h) => thumbs.push([name, c, w ?? c.width, h ?? c.height]);

function copyCanvas(src) {
  const c = bkCanvas(src.width, src.height);
  c.getContext('2d').drawImage(src, 0, 0);
  return c;
}

// ---------------------------------------------------------------- Monde : sol, décor, tuiles
function decorKind(o) {
  if (o.wind) return 'tree_' + o.wind;
  if (o.orb) return 'orb';
  if (o.light !== undefined) return o.light ? 'crystal' : 'spire';
  const w = o.spr.c.width, h = o.spr.c.height;
  if (o.bx !== undefined) return w === 32 ? 'face' : 'altar';
  if (w === 48 && h === 80) return 'deity_deco';
  if (w === 70) return 'mountain_rock';
  if (w === 40 && o.spr.ay === 26) return 'fern';
  if (w === 40) return 'rock';
  return 'misc';
}

async function bakeWorld() {
  await bkLog(`Monde : galeries (graine ${GALLERY_SEED}) et buildPixelWorld…`);
  generateGalleries(GALLERY_SEED);
  buildPixelWorld();
  const G = PW.ground, CH = 1024, cols = Math.ceil(G.width / CH), rows = Math.ceil(G.height / CH);
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    const w = Math.min(CH, G.width - c * CH), h = Math.min(CH, G.height - r * CH), part = bkCanvas(w, h);
    part.getContext('2d').drawImage(G, c * CH, r * CH, w, h, 0, 0, w, h);
    await save(`world/ground/ground_r${r}_c${c}.png`, part);
  }
  manifest.world = {WORLD, CAVE, NAT, core, CAVE_C, C_moss: C.moss, C_outline: C.outline,
    ground: {width: G.width, height: G.height, gx0: PW.gx0, gy0: PW.gy0, chunk: CH, cols, rows,
      note: 'Origine du monde (0, 0, 0) au pixel (gx0, gy0) du sol ; natW(x, y, z) = (x·8, z·8 − y·KH).'}};

  const ids = new Map(), sprites = {}, counters = {};
  async function spriteId(spr, kind) {
    if (ids.has(spr)) return ids.get(spr);
    counters[kind] = (counters[kind] || 0) + 1;
    const id = `${kind}_${String(counters[kind]).padStart(2, '0')}`;
    ids.set(spr, id);
    await save(`world/sprites/${id}.png`, spr.c);
    sprites[id] = {w: spr.c.width, h: spr.c.height, ax: spr.ax, ay: spr.ay};
    if (spr.foliage) sprites[id].foliage = await spriteId(spr.foliage, kind + '_foliage');
    return id;
  }
  const placements = [];
  for (const o of PW.objs) {
    // Positions en double précision, sans arrondi : un arrondi peut faire basculer natP d'un pixel
    // quand la position tombe près d'un demi-pixel.
    const base = {x: o.x, z: o.z, d: o.d};
    if (o.portal) { placements.push({portal: true, ...base}); continue; }
    if (o.dportal) { placements.push({dportal: o.dportal.id, ...base}); continue; }
    if (o.deityFx) { placements.push({deity_fx: o.deityFx.id, ...base}); continue; }
    if (!o.spr) { Baker.errors.push('Objet de décor inconnu : ' + JSON.stringify(Object.keys(o))); continue; }
    const p = {s: await spriteId(o.spr, decorKind(o)), ...base};
    if (o.bx !== undefined) { p.bx = o.bx; p.bz = o.bz; }
    if (o.wind) p.wind = o.wind;
    if (o.light !== undefined) p.light = !!o.light;
    if (o.orb) p.orb = true;
    placements.push(p);
  }
  await save('world/decor_sprites.json', sprites);
  await save('world/decor_placements.json', {
    note: 'Ordre de dessin d’origine (tri par d = dz ou z). Position native : natW(x, 0, z), ou natW(bx, 0, bz) '
      + 'pour les faces et l’autel. Orbe : natW(core.x, orbY, core.z), orbY = 2,6 éteinte, 3 + sin(t·1,7)·0,2 active.',
    count: placements.length, placements});
  manifest.world.decor = {sprites: Object.keys(sprites).length, placements: placements.length, by_kind: counters, wind: WIND_TREES};

  // Décor ajouté en cours de partie (galleries.js : revealGallery ; adepts.js : digCell).
  const runtime = {faces: [], spires: []};
  for (let v = 0; v < 6; v++) {
    const f = faceSprite(5, rng(v * 41 + 5));
    await save(`world/runtime/face5_${v}.png`, f.c);
    runtime.faces.push({v, w: f.c.width, h: f.c.height, ax: f.ax, ay: f.ay});
    const crystal = v % 2 === 0, s = sprite(28, 44, 14, 40, (S, ax, ay) => caveSpire(S, ax, ay, rng(v * 17 + 3), crystal));
    await save(`world/runtime/gallery_spire_${v}.png`, s.c);
    runtime.spires.push({v, crystal, w: s.c.width, h: s.c.height, ax: s.ax, ay: s.ay});
  }
  manifest.world.runtime_decor = {...runtime,
    note: 'Faces : faceSprite(5, rng(v·41+5)), v = (i·7 + j·3 & 7) % 6 au creusement, ou tiré de rng(GAL.seed + n) à la révélation. '
      + 'Stalagmites des galeries : cristal si v pair.'};

  // Tuiles du terrain dynamique : bases constantes (coordonnées locales 32×32, sans les grains aléatoires).
  const old = diamond;
  diamond = squareTile;
  try {
    const cave = new Px(32, 32, true);
    caveTile(cave, 16, 0, () => 0, 0); // R() = 0 : les 6 grains tombent hors de la case
    cave.flush();
    await save('world/tiles/cave_base.png', cave.c);
    const rockT = new Px(32, 32, true);
    rockTile(rockT, 16, 0, null, 0);
    rockT.flush();
    await save('world/tiles/rock_base.png', rockT.c);
    bkKeep('tuile grotte', cave.c);
    bkKeep('tuile roche', rockT.c);
  } finally { diamond = old; }
  manifest.world.tiles = {size: 32,
    cave_specks: 'k < 6 : x = 16 + ((R() − 0,5)·40 | 0), y = 9 + (R()·14 | 0) → floor[5] ; si R() < 0,4 : (x + 1, y) → floor[4]',
    dig_seed: 'rng(i·977 + j·31 + 7)', region_seed: 'rng((x·977 + z·31) >>> 0)'};

  const solCrop = bkCanvas(480, 300);
  const [ox, oy] = natW(core.x, 0, core.z);
  solCrop.getContext('2d').drawImage(G, PW.gx0 + ox - 240, PW.gy0 + oy - 160, 480, 300, 0, 0, 480, 300);
  bkKeep('sol · salle', solCrop);
  const seen = new Set(), perKind = {};
  for (const o of PW.objs) {
    if (!o.spr || seen.has(o.spr)) continue;
    seen.add(o.spr);
    const kind = decorKind(o);
    if ((perKind[kind] = (perKind[kind] || 0) + 1) > 2) continue;
    let c = o.spr.c;
    if (o.spr.foliage) {
      const f = o.spr.foliage, x0 = Math.min(0, o.spr.ax - f.ax), y0 = Math.min(0, o.spr.ay - f.ay);
      c = bkCanvas(Math.max(o.spr.c.width, o.spr.ax - f.ax + f.c.width) - x0, Math.max(o.spr.c.height, o.spr.ay - f.ay + f.c.height) - y0);
      const g = c.getContext('2d');
      g.drawImage(o.spr.c, -x0, -y0);
      g.drawImage(f.c, o.spr.ax - f.ax - x0, o.spr.ay - f.ay - y0);
    }
    bkKeep(kind, c);
  }
}

// ---------------------------------------------------------------- Portails
async function bakePortals() {
  await bkLog('Portails : divins, maléfique…');
  manifest.portals = {exiles: {atlas: 'res://assets/imported/portal/portal_atlas.png', frame_w: PortalKit.W, frame_h: PortalKit.H, cols: 16,
    ox: PortalKit.OX, oy: PortalKit.OY, frames: PORTAL.frameCount, fps: PORTAL.fps, x: PORTAL.x, z: PORTAL.z, durations: PORTAL.dur,
    emerge_after_states: PORTAL.emerge, transform: 'translate(nx·PX, ny·PX) · matrice (PX, PX·0,5, 0, PX)'},
    deity: {n: DEITY_N, scale: DEITY_SCALE, deco_offset: DECO_OFF, look: DEITY_LOOK, portals: DEITY_PORTALS,
      frame: 'floor(t·12/(π/2)) mod 12', transform: 'matrice (k, k·0,5, 0, k), k = 0,62·PX'},
    evil: {scale: EVIL.scale, interval: EVIL.interval, cap: EVIL.cap, look: EVIL.look}};
  const off = deityFrames(DEITY_PORTALS[0].id, false)[0];
  await save('portals/deity_off.png', copyCanvas(off));
  bkKeep('portail éteint', off);
  for (const d of DEITY_PORTALS) {
    const {canvas: c, meta} = sheet(deityFrames(d.id, true).map(copyCanvas), 12);
    await save(`portals/deity_${d.id}.png`, c);
    manifest.portals.deity[d.id] = meta;
    bkKeep('portail ' + d.id, deityFrames(d.id, true)[3]);
  }
  const D = {...PortalKit.DESIGNS[0], glow: EVIL.look}, S = {glyph: .8, seals: 1, open: 1, field: .9, rim: 1, arcs: .8, unit: null};
  const evil = Array.from({length: 12}, (_, k) => PortalKit.render(D, S, k / 12 * Math.PI / 2));
  const {canvas: ec, meta: em} = sheet(evil.map(copyCanvas), 12);
  await save('portals/evil.png', ec);
  manifest.portals.evil.sheet = em;
  bkKeep('portail maléfique', evil[3]);
}

// ---------------------------------------------------------------- Unités, ennemis, attaques
async function bakeStrips(dir, name, S, extra = {}) {
  const meta = {ax: S.ax, ay: S.ay, h: S.h, stride: S.stride, self_bob: !!S.selfBob, ...extra};
  for (const [anim, frames] of [['idle', S.frames], ['walk', S.walk], ['shoot', S.shoot]]) {
    if (!frames) continue;
    const {canvas: c, meta: m} = sheet(frames);
    await save(`${dir}/${name}_${anim}.png`, c);
    meta[anim] = m;
  }
  return meta;
}

async function bakeUnits() {
  await bkLog('Unités : buildUnitSprites, buildEnemySprites, buildAttackSprites, agenouillement…');
  buildUnitSprites();
  buildEnemySprites();
  buildAttackSprites();
  manifest.units = {timing: {idle_frames: SPR_FRAMES, idle_loop_s: SPR_LOOP, walk_frames: WALK_N, scale: SPR_K,
    note: 'Repos : image (floor(t·24/2,4) + (id & 7)·3) mod 24. Marche : phase += distance / stride ; rebond de 1 px sauf self_bob.'}, roles: {}};
  for (const [role, S] of Object.entries(SPR)) {
    manifest.units.roles[role] = await bakeStrips('units', role, S);
    bkKeep(role, S.frames[0]);
    bkKeep(role + ' marche', S.walk[Math.floor(S.walk.length / 3)]);
  }
  manifest.enemies = {};
  for (const [kind, S] of Object.entries(ESPR)) {
    manifest.enemies[kind] = await bakeStrips('enemies', kind, S);
    bkKeep(kind, S.frames[0]);
  }
  // Agenouillement de l'Ingénieur pendant l'incantation (temple-incantation.js : kneelFrame).
  const kneel = findLoop(t => copyCanvas(TempleIncantation.kneelFrame({...UnitKit.ENGINEERS[4].s}, t, SPR_K)),
    {fps: ACTOR_FPS, minSeconds: .5, maxSeconds: 6});
  const ks = sheet(kneel.frames);
  await save('units/engineer_kneel.png', ks.canvas);
  manifest.units.roles.engineer.kneel = {...ks.meta, seconds: kneel.seconds, fps: kneel.fps, exact: kneel.exact};
  bkKeep('agenouillé', kneel.frames[0]);
  manifest.attacks = {sword: {swing_s: SWING_DUR, combos: ATK.sword.length, ax: ATK.sword[0].ax, ay: ATK.sword[0].ay},
    xbow: {volley_s: VOLLEY_DUR, shots_at: VOLLEY, ax: ATK.xbow.ax, ay: ATK.xbow.ay}};
  for (let i = 0; i < ATK.sword.length; i++) {
    const {canvas: c, meta} = sheet(ATK.sword[i].frames);
    await save(`attacks/sword_${i}.png`, c);
    manifest.attacks.sword.sheet = meta;
  }
  const {canvas: c, meta} = sheet(ATK.xbow.frames);
  await save('attacks/xbow.png', c);
  manifest.attacks.xbow.sheet = meta;
}

// ---------------------------------------------------------------- Adeptes (grilles pixel, adept-sprites.js)
// AdeptArt.draw dessine une ombre vectorielle puis l'image de la grille : seule l'image est extraite
// (l'ombre, une ellipse #07141699 de 8 × 2, est redessinée dans Godot).
function adeptFrame(role, mode, t) {
  const c = bkCanvas(64, 64), g = c.getContext('2d');
  const noShadow = new Proxy(g, {get: (o, p) => p === 'fill' ? () => {} : typeof o[p] === 'function' ? o[p].bind(o) : o[p],
    set: (o, p, v) => (o[p] = v, true)});
  AdeptArt.draw(noShadow, 32, 48, role, t, mode, 1);
  return c;
}

async function bakeAdepts() {
  await bkLog('Adeptes : 7 rôles × repos, marche, travail…');
  const modes = {idle: [0], walk: [0, 1 / 6], work: [0, 1 / 6, 2 / 6, 3 / 6]};
  manifest.adepts = {fps: 6, scale_k: BUILDING_CHAR_K, adept: ADEPT, fight: FIGHT,
    note: 'Échelle en jeu : Z()/16 × 1,9, soit 1,1047 × PX ; filtre « le plus proche ». Image : floor(t·6) & 3 (marche : & 1).', roles: {}};
  for (const role of Object.keys(AdeptArt.LOOK)) {
    const frames = Object.fromEntries(Object.entries(modes).map(([m, ts]) => [m, ts.map(t => adeptFrame(role, m, t))]));
    const box = unionBBox(Object.values(frames).flat());
    const entry = {ax: 32 - box.x, ay: 48 - box.y, modes: {}};
    for (const [m, list] of Object.entries(frames)) {
      const {canvas: c, meta} = sheet(crop(list, box));
      await save(`adepts/${role}_${m}.png`, c);
      entry.modes[m] = meta;
    }
    manifest.adepts.roles[role] = entry;
    bkKeep('adepte ' + role, crop([frames.work[1]], box)[0]);
  }
}

// ---------------------------------------------------------------- Bâtiments
function buildingFrame(kind, t, progress = 1, opts = {}) {
  const sp = PixelBuildings.sprite(kind, opts.variant), c = bkCanvas(PixelBuildings.W, PixelBuildings.H);
  PixelBuildings.draw(c.getContext('2d'), kind, sp.anchor[0], sp.anchor[1], 1, t, progress, opts);
  return c;
}

async function bakeBuildings() {
  await bkLog('Bâtiments : bases, boucles animées, balistes…');
  const catalogue = Object.fromEntries(Object.entries(BUILDINGS).map(([k, D]) => [k, {...D, size: D.size || 3}]));
  manifest.buildings = {fps: BUILDING_FPS, canvas: [PixelBuildings.W, PixelBuildings.H], catalogue, arts: {},
    constants: {CELL, SUMMON_COST, CASERNE_COST, CASERNE_TIME, CASERNE_QUEUE, REVIVE_COST, HERO_COST, CASERNE_UNITS, RES_ORDER, DEITY_RES, ORB_TIME: ORB.time},
    note: 'Échelle en jeu : k = Z()·0,86/8·(size/3) = PX·size/3 ; filtre « le plus proche ».'};
  const baseMeta = sp => ({anchor: sp.anchor, top: sp.top, bottom: sp.bottom});
  const arts = [...new Set(Object.values(BUILDINGS).map(D => D.art))];
  for (const art of arts) {
    const sp = PixelBuildings.sprite(art);
    await save(`buildings/${art}_base.png`, sp.img);
    const loop = findLoop(t => buildingFrame(art, t), {fps: BUILDING_FPS});
    const {canvas: c, meta} = sheet(loop.frames);
    await save(`buildings/${art}_anim.png`, c);
    manifest.buildings.arts[art] = {...baseMeta(sp), pick: PixelBuildings.PICKS[art],
      anim: {...meta, seconds: loop.seconds, fps: loop.fps, exact: loop.exact, seam_pixels: loop.seam_pixels}};
    bkKeep(art, buildingFrame(art, 1));
    await bkLog(`  ${art} : boucle ${loop.seconds} s, raccord ${loop.seam_pixels} px`);
  }
  // Balistes (turret-game.js) : ruine (variant false) et Garde tyrienne active (variant true).
  const ruin = PixelBuildings.sprite('ballista', false);
  await save('buildings/ballista_ruin_base.png', ruin.img);
  const ruinLoop = findLoop(t => buildingFrame('ballista', t, 1, {variant: false}), {fps: BUILDING_FPS, maxSeconds: 16});
  const ruinSheet = sheet(ruinLoop.frames);
  await save('buildings/ballista_ruin_anim.png', ruinSheet.canvas);
  const active = PixelBuildings.sprite('ballista', true);
  await save('buildings/ballista_active_base.png', active.img);
  const YAWS = 16, PHASES = 24, frames = [];
  for (let y = 0; y < YAWS; y++) for (let p = 0; p < PHASES; p++) {
    frames.push(buildingFrame('ballista', 0, 1, {variant: true, yaw: y * 2 * Math.PI / YAWS, phase: p / PHASES}));
  }
  const weapon = sheet(frames, PHASES);
  await save('buildings/ballista_weapon.png', weapon.canvas);
  manifest.buildings.ballista = {config: TURRET_CONFIG,
    ruin: {...baseMeta(ruin), anim: {...ruinSheet.meta, seconds: ruinLoop.seconds, fps: ruinLoop.fps, seam_pixels: ruinLoop.seam_pixels}},
    active: {...baseMeta(active), weapon: {...weapon.meta, yaws: YAWS, phases: PHASES,
      note: 'Ligne = yaw (k·2π/16, yaw = atan2(dz, dx) en monde) ; colonne = phase du cycle (cycleAge / cycle).'}},
    pick: PixelBuildings.PICKS.ballista};
  bkKeep('baliste ruine', buildingFrame('ballista', 0, 1, {variant: false}));
  bkKeep('baliste active', buildingFrame('ballista', 0, 1, {variant: true, yaw: Math.PI / 2, phase: .5}));
}

// ---------------------------------------------------------------- Surimpression (résolution écran)
async function bakeOverlay() {
  await bkLog('Surimpression : empreintes, icônes du HUD…');
  const K = OVERLAY_SCALE;
  manifest.overlay = {scale: K, footprints: {}, hud_icons: 'overlay/hud_icons.json',
    note: 'Empreintes à l’échelle ×2 du repère bâtiment 320×240 ; elles seront probablement redessinées dans Godot (_draw).'};
  for (const [name, color] of Object.entries({build: undefined, valid: '#a4f2ca', invalid: '#f28d80'})) {
    const loop = findLoop(t => {
      const c = bkCanvas(320 * K, 240 * K), g = c.getContext('2d');
      g.scale(K, K);
      TempleKit.footprint(g, t, color ? {color} : {});
      return c;
    }, {fps: 12, minSeconds: 1, maxSeconds: 6});
    const box = unionBBox(loop.frames), {canvas: c, meta} = sheet(crop(loop.frames, box), 6);
    await save(`overlay/footprint_${name}.png`, c);
    manifest.overlay.footprints[name] = {...meta, ax: 160 * K - box.x, ay: 186 * K - box.y, seconds: loop.seconds, seam_pixels: loop.seam_pixels};
  }
  await save('overlay/hud_icons.json', {viewBox: '0 0 24 24', stroke: 'currentColor', icons: HUD_ICONS});
}

// ---------------------------------------------------------------- Valeurs de référence pour les tests
async function sha1Hex(bytes) {
  const d = await crypto.subtle.digest('SHA-1', bytes);
  return [...new Uint8Array(d)].map(b => b.toString(16).padStart(2, '0')).join('');
}

async function bakeFixtures() {
  await bkLog('Fixtures : projection, vent, bruit, galeries, praticabilité, chemins, creusement…');
  const R = mulberry32(4242);
  cam = {x: 0, z: -148, zoom: .9};
  const pts = [];
  for (let i = 0; i < 20; i++) {
    const x = round4((R() - .5) * 440), y = round4(R() * 6), z = round4(-330 + R() * 400);
    const p = project(x, y, z), g = groundFromScreen(p.x, p.y + y * Z() * .96);
    pts.push({x, y, z, natW: natW(x, y, z), project: [p.x, p.y], ground_from_screen: [g.x, g.z]});
  }
  await save('fixtures/projection.json', {screen: [W, H], px: PX, Z: Z(), cam, NAT, center_y: .45, points: pts});
  const wind = [];
  for (let i = 0; i < 50; i++) {
    const x = round4((R() - .5) * 440), z = round4(-170 + R() * 240), t = round4(R() * 100);
    wind.push({x, z, t, v: windAt(x, z, t)});
  }
  await save('fixtures/wind.json', {samples: wind});
  const noise = [];
  for (let i = 0; i < 50; i++) {
    const x = round4(R() * 40), y = round4(R() * 40), s = Math.floor(R() * 50);
    noise.push({x, y, seed: s, vnoise: vnoise(x, y, s), hash: hash(Math.floor(x), Math.floor(y), s)});
  }
  await save('fixtures/noise.json', {samples: noise});
  const gens = {};
  for (const s of [5, 31, 77, 2024]) { const r = rng(s); gens[s] = Array.from({length: 10}, r); }
  let sd = 19653;
  const lcg = Array.from({length: 10}, () => { sd = (1664525 * sd + 1013904223) >>> 0; return sd / 4294967296; });
  await save('fixtures/rng.json', {rng: gens, lcg_19653: lcg});

  // Galeries pour 5 graines : empreinte du masque, nombre de réseaux, portails maléfiques.
  const galleries = [];
  for (const seed of [1, 7, 42, 1234, GALLERY_SEED]) {
    generateGalleries(seed);
    galleries.push({seed, mask_sha1: await sha1Hex(GAL.mask), cells: GAL.mask.reduce((n, v) => n + v, 0), count: GAL.count,
      portals: GAL.portals.map(p => ({x: p.x, z: p.z}))});
  }
  await save('fixtures/galleries.json', {size: [GAL.w, GAL.h], origin: [WORLD.x0, WORLD.z0], results: galleries});
  generateGalleries(GALLERY_SEED);

  // Praticabilité à l'état initial (aucune case creusée, aucune galerie découverte).
  const walk = [];
  for (let i = 0; i < 4000; i++) {
    const x = round4(WORLD.x0 + R() * (WORLD.x1 - WORLD.x0)), z = round4(WORLD.z0 + R() * (WORLD.z1 - WORLD.z0));
    walk.push([x, z, walkable(x, z) ? 1 : 0, inCave(x, z) ? 1 : 0, inTunnel(x, z) ? 1 : 0]);
  }
  await save('fixtures/walkable.json', {fields: ['x', 'z', 'walkable', 'inCave', 'inTunnel'], samples: walk});

  // Chemins A* témoins (état initial).
  const spots = [];
  while (spots.length < 60) {
    const x = WORLD.x0 + 10 + R() * (WORLD.x1 - WORLD.x0 - 20), z = -170 + R() * 236;
    if (walkable(x, z)) spots.push({x: round4(x), z: round4(z)});
  }
  const paths = [];
  for (let k = 0; k < 30; k++) {
    const a = spots[2 * k], b = spots[2 * k + 1], path = findPath(a, b);
    paths.push({from: a, to: b, path: path && path.map(p => [p.x, p.z])});
  }
  await save('fixtures/paths.json', {paths});

  // Scénario de creusement : tunnel vers une galerie (même scénario que le harnais de référence).
  const sc = digScenario(), walkBefore = WALK.version, objsBefore = PW.objs.length;
  for (const [i, j] of sc.cells) digCell(i, j);
  await save('fixtures/dig_scenario.json', {...sc, dug: [...DUG].sort(), found: GAL.found, open_sha1: await sha1Hex(GAL.open),
    active_portals: GAL.portals.filter(p => p.active).map(p => ({x: p.x, z: p.z})), objs_before: objsBefore, objs_after: PW.objs.length,
    walk_version_delta: WALK.version - walkBefore});
  if (!sc.cells.length) Baker.errors.push('Aucun scénario de creusement trouvé pour la graine ' + GALLERY_SEED);
  await bkLog(`  creusement : ${sc.cells.length} cases (rangée j = ${sc.j}), ${GAL.found} galerie(s) découverte(s)`);
}

// ---------------------------------------------------------------- Planche de contact
async function contactSheet(entries) {
  const CELL = 112, LABEL = 14, cols = 10, rows = Math.ceil(entries.length / cols);
  const c = bkCanvas(cols * CELL, rows * (CELL + LABEL)), g = c.getContext('2d');
  g.fillStyle = '#0b120e';
  g.fillRect(0, 0, c.width, c.height);
  g.imageSmoothingEnabled = false;
  g.font = '10px monospace';
  entries.forEach(([name, img, sw, sh], i) => {
    const x = (i % cols) * CELL, y = Math.floor(i / cols) * (CELL + LABEL);
    const fit = Math.min((CELL - 8) / sw, (CELL - 8) / sh), scale = fit >= 1 ? Math.floor(fit) : fit;
    g.drawImage(img, 0, 0, sw, sh, x + (CELL - sw * scale) / 2, y + (CELL - sh * scale) / 2, sw * scale, sh * scale);
    g.fillStyle = '#e6dfc8';
    g.fillText(name.slice(0, 18), x + 3, y + CELL + 10);
  });
  await save('_contact_sheet.png', c);
}

// ---------------------------------------------------------------- Programme principal
(async () => {
  const started = performance.now();
  try {
    await bkLog('Chargement du prototype (version figée, lecture seule)…');
    await loadGame();
    manifest.scripts = Baker.scripts;
    if (wantPart('world')) await bakeWorld();
    else { generateGalleries(GALLERY_SEED); buildPixelWorld(); }
    if (wantPart('portals')) await bakePortals();
    if (wantPart('units')) await bakeUnits();
    if (wantPart('adepts')) await bakeAdepts();
    if (wantPart('buildings')) await bakeBuildings();
    if (wantPart('overlay')) await bakeOverlay();
    if (wantPart('fixtures')) await bakeFixtures(); // en dernier : le creusement modifie le monde
    await save('manifest.json', manifest);
    if (thumbs.length) await contactSheet(thumbs);
  } catch (error) {
    Baker.errors.push(String(error && error.stack || error));
  }
  if (Baker.checks.roundtripFailures.length) Baker.errors.push(...Baker.checks.roundtripFailures);
  const summary = {errors: Baker.errors, counts: Baker.counts, roundtrip_checked: Baker.checks.roundtrip,
    roundtrip_failures: Baker.checks.roundtripFailures, page_seconds: Math.round(performance.now() - started) / 1000};
  await bkLog(`Terminé : ${JSON.stringify(Baker.counts)} ; ${Baker.errors.length} erreur(s)`);
  await fetch('/done', {method: 'POST', body: JSON.stringify(summary)});
})();
