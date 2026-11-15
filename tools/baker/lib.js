'use strict';
// Outils communs du baker : chargement du prototype (lecture seule), envoi des
// fichiers au serveur, planches de sprites, recherche de boucle d'animation.

const Baker = {
  errors: [],
  counts: {},
  checks: {roundtrip: 0, roundtripFailures: []},
};

// Dernière instruction du script principal d'Index.html (73b410f) : l'amorçage du jeu, que le
// baker n'exécute pas. Tout ce qui précède (déclarations, génération des arbres) est exécuté.
const BOOT_MARKER = 'generateGalleries();buildPixelWorld();';
// Graine de Math.random (décision D4 : instantané figé des arbres).
const RANDOM_SEED = 19653;
// Graine des galeries pour l'extraction et les captures de référence (décision D12).
const GALLERY_SEED = 20261114;

window.addEventListener('error', e => Baker.errors.push(`${e.message} (${e.filename}:${e.lineno})`));
window.addEventListener('unhandledrejection', e => Baker.errors.push(String(e.reason && e.reason.stack || e.reason)));

async function bkLog(msg) {
  document.getElementById('log').textContent += msg + '\n';
  try { await fetch('/log', {method: 'POST', body: msg}); } catch (_) { /* hors serveur */ }
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const el = document.createElement('script');
    el.src = src;
    el.onload = resolve;
    el.onerror = () => reject(new Error('Chargement impossible : ' + src));
    document.head.append(el);
  });
}

// Charge les modules du prototype puis le script principal d'Index.html, arrêté avant l'amorçage.
// Les déclarations globales (PW, SPR, buildPixelWorld…) deviennent accessibles par leur nom.
async function loadGame() {
  Math.random = mulberry32(RANDOM_SEED);
  const html = await (await fetch('/src/Index.html')).text();
  // Scripts classiques d'Index.html, dans leur ordre (le module Three.js n'en fait pas partie).
  const scripts = [...html.matchAll(/<script src="([^"?]+)/g)].map(m => m[1]);
  for (const file of scripts) await loadScript('/src/' + file + '?baker');
  Baker.scripts = scripts;
  const inline = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
  const cut = inline.indexOf(BOOT_MARKER);
  if (cut < 0) throw new Error('Marqueur d’amorçage introuvable dans Index.html : le prototype a changé.');
  const el = document.createElement('script');
  el.textContent = inline.slice(0, cut) + '\nwindow.__gameDefined = true;';
  document.head.append(el);
  if (!window.__gameDefined) throw new Error('Le script principal d’Index.html a échoué : ' + Baker.errors.join(' | '));
}

function bkCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.ceil(w));
  c.height = Math.max(1, Math.ceil(h));
  return c;
}

function bkPixels(c) {
  return c.getContext('2d', {willReadFrequently: true}).getImageData(0, 0, c.width, c.height).data;
}

// Envoie un fichier au serveur. Pour les PNG, vérifie le décodage aller-retour :
// les pixels opaques doivent être identiques à l'octet près.
async function save(path, data) {
  let body = data;
  if (typeof data?.toBlob === 'function') { // canvas, y compris d'une autre fenêtre (iframe)
    body = await new Promise(r => data.toBlob(r, 'image/png'));
    await verifyRoundtrip(path, data, body);
  } else if (typeof data !== 'string') {
    body = JSON.stringify(data, null, 1) + '\n';
  }
  const res = await fetch('/out/' + path, {method: 'POST', body});
  if (!res.ok) throw new Error(`Écriture refusée : ${path} (${res.status})`);
  const kind = path.split('/')[0];
  Baker.counts[kind] = (Baker.counts[kind] || 0) + 1;
}

async function verifyRoundtrip(path, source, blob) {
  const bitmap = await createImageBitmap(blob, {premultiplyAlpha: 'none', colorSpaceConversion: 'none'});
  const c = bkCanvas(bitmap.width, bitmap.height);
  c.getContext('2d').drawImage(bitmap, 0, 0);
  const a = bkPixels(source), b = bkPixels(c);
  let bad = 0;
  for (let i = 0; i < a.length; i += 4) {
    if (a[i + 3] !== b[i + 3]) { bad++; continue; }
    if (a[i + 3] === 255 && (a[i] !== b[i] || a[i + 1] !== b[i + 1] || a[i + 2] !== b[i + 2])) bad++;
  }
  Baker.checks.roundtrip++;
  if (bad) Baker.checks.roundtripFailures.push(`${path} : ${bad} pixels différents`);
}

// Planche en grille : chaque image occupe une cellule de taille fixe, alignée en haut à gauche.
function sheet(frames, maxCols = 12) {
  const w = frames[0].width, h = frames[0].height;
  for (const f of frames) {
    if (f.width !== w || f.height !== h) throw new Error(`Tailles d’images hétérogènes (${w}×${h} / ${f.width}×${f.height})`);
  }
  const cols = Math.min(maxCols, frames.length), rows = Math.ceil(frames.length / cols);
  const c = bkCanvas(cols * w, rows * h), g = c.getContext('2d');
  frames.forEach((f, i) => g.drawImage(f, (i % cols) * w, Math.floor(i / cols) * h));
  return {canvas: c, meta: {frame_w: w, frame_h: h, cols, rows, count: frames.length}};
}

// Rectangle englobant des pixels non transparents, commun à toutes les images.
function unionBBox(frames) {
  let x0 = Infinity, y0 = Infinity, x1 = -1, y1 = -1;
  for (const f of frames) {
    const d = bkPixels(f), w = f.width;
    for (let i = 3; i < d.length; i += 4) {
      if (!d[i]) continue;
      const p = (i - 3) / 4, x = p % w, y = (p - x) / w;
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  }
  return x1 < 0 ? {x: 0, y: 0, w: 1, h: 1} : {x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1};
}

function crop(frames, box) {
  return frames.map(f => {
    const c = bkCanvas(box.w, box.h);
    c.getContext('2d').drawImage(f, -box.x, -box.y);
    return c;
  });
}

function diffCount(a, b) {
  let n = 0;
  for (let i = 0; i < a.length; i += 4) {
    if (a[i] !== b[i] || a[i + 1] !== b[i + 1] || a[i + 2] !== b[i + 2] || a[i + 3] !== b[i + 3]) n++;
  }
  return n;
}

// Échantillonne render(t) à fps images/s et choisit la boucle dont le raccord est le moins visible :
// le plus petit k ≥ 1 donnant une image identique à la première, sinon le k de [minK, maxK]
// qui minimise les pixels différents entre l'image k et l'image 0 (R3).
function findLoop(render, {fps = 12, minSeconds = 2, maxSeconds = 10} = {}) {
  const maxK = Math.round(maxSeconds * fps), minK = Math.round(minSeconds * fps);
  const frames = [], data = [];
  for (let k = 0; k <= maxK; k++) {
    const c = render(k / fps);
    frames.push(c);
    data.push(bkPixels(c));
  }
  // Période exacte : toute la séquence échantillonnée se répète avec un décalage de k.
  const periodic = k => {
    for (let j = 0; j + k <= maxK; j++) if (diffCount(data[j], data[j + k])) return false;
    return true;
  };
  const total = data[0].length / 4;
  for (let k = 1; k <= maxK; k++) {
    if (!diffCount(data[0], data[k]) && periodic(k)) {
      return {frames: frames.slice(0, k), fps, seconds: k / fps, seam_pixels: 0, seam_ratio: 0, exact: true};
    }
  }
  // Pas de période exacte sur la grille : recherche fine de la durée T (pas de 1/(8·fps) s) dont
  // l'image ressemble le plus à la première, puis N = round(T·fps) images régulièrement espacées
  // sur [0, T[ : le raccord est alors aussi discret que le dessin d'origine le permet.
  const step = 1 / (fps * 8);
  let bestT = maxSeconds, bestDiff = Infinity;
  for (let T = minSeconds; T <= maxSeconds + 1e-9; T += step) {
    const d = diffCount(data[0], bkPixels(render(T)));
    if (d < bestDiff) { bestDiff = d; bestT = T; }
  }
  const n = Math.max(1, Math.round(bestT * fps)), out = [];
  for (let i = 0; i < n; i++) out.push(render(i * bestT / n));
  return {frames: out, fps: +(n / bestT).toFixed(5), seconds: +bestT.toFixed(5), seam_pixels: bestDiff,
    seam_ratio: +(bestDiff / total).toFixed(5), exact: false};
}

const round4 = v => Math.round(v * 1e4) / 1e4;

// Scénario de creusement de référence, partagé par le baker (fixtures) et le harnais (captures).
// Un tunnel droit part de la paroi est de la salle vers l'est, à la première rangée de cases dont le
// tunnel touche une galerie en moins de 25 cases. Le prototype doit avoir généré ses galeries avec
// GALLERY_SEED. Renvoie {seed, j, cells: [[i, j], …]} ; les fonctions viennent d'Index.html.
function digScenario() {
  const hit = (i, j) => {
    for (let z = j * 4; z < j * 4 + 4; z++) for (let x = i * 4; x < i * 4 + 4; x++) if (isGallery(x + .5, z + .5)) return true;
    return false;
  };
  for (let j = -40; j <= -26; j++) {
    let i = Math.floor(caveE(j * 4 + 2) / 4);
    while (walkable(i * 4 + 2, j * 4 + 2)) i++;
    const cells = [];
    for (let k = 0; k < 25; k++, i++) {
      cells.push([i, j]);
      if (hit(i + 1, j)) { cells.push([i + 1, j]); return {seed: GALLERY_SEED, j, cells}; }
    }
  }
  return {seed: GALLERY_SEED, j: null, cells: []};
}
