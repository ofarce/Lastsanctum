#!/usr/bin/env python3
"""Style « Ardoise tyrienne » : repeint le sol et le décor rocheux issus du baker.

Lit res://assets/baked/ (jamais modifié) et écrit res://assets/ardoise/ :
  world/ground/ground_r*_c*.png   sol complet : roche → dessus d'ardoise, sol de grotte → dalles
  world/tiles/{floor,rock,dug}.png textures 504×504 périodiques, échantillonnées en coordonnées
                                   absolues du sol (le peintre du jeu et ce script lisent les mêmes)
  world/decor_atlas.png            planche du décor, mêmes régions que celle du baker
  world/runtime/*.png              faces et stalagmites ajoutées en cours de partie
  palette.json                     couleurs de bord (remplacent CAVE_C)

Les fonctions de texture sont reprises de la planche validée (caverne-planches.js, style « ardoise »),
rendues périodiques : le bruit est calculé sur un réseau qui se referme tous les P pixels.

    python3 tools/ardoise/ardoise.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "baked")
OUT = os.path.join(ROOT, "assets", "ardoise")
P = 504  # période des textures : multiple de 18 (largeur des dalles), 14×2 (deux rangées), 9 et 12

hx = lambda s: tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))
SL = [hx(c) for c in ['#141922', '#1c222d', '#262e3b', '#323c4b', '#424e5f', '#556274', '#6c7a8c', '#8a98a8']]
SLF = [hx(c) for c in ['#2a2f37', '#353b45', '#424954', '#515863', '#626973', '#757b84', '#8a8f96']]
EARTH1 = [hx(c) for c in ['#2a241d', '#372f26', '#463c30', '#574b3b', '#695a47']]
MOSS = [hx(c) for c in ['#22401f', '#2f5528', '#3e6c31', '#52833a']]
QUARTZ = [hx(c) for c in ['#8e9aac', '#b6c0ce', '#dfe5ee', '#f6f8fb']]
OUTL = hx('#0b0a0e')

M32 = 0xFFFFFFFF


# ---------- bruit (identique au prototype, en entiers 32 bits) ----------
def hash_(x, y, s):
    x = np.asarray(x, np.int64) & M32
    y = np.asarray(y, np.int64) & M32
    h = (x * 374761393 + y * 668265263 + (s & M32) * 982451653) & M32
    h = ((h ^ (h >> 13)) * 1274126177) & M32
    return (h ^ (h >> 16)).astype(np.float64) / 4294967296.0


def vnoise_t(x, y, nx, ny, s):
    """vnoise sur un réseau de nx × ny cellules par période P (coordonnées pixel x, y)."""
    u = x * nx / P
    v = y * ny / P
    xi = np.floor(u).astype(np.int64)
    yi = np.floor(v).astype(np.int64)
    xf, yf = u - xi, v - yi
    a_, b_ = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    x0, x1, y0, y1 = xi % nx, (xi + 1) % nx, yi % ny, (yi + 1) % ny
    a, b, c, d = hash_(x0, y0, s), hash_(x1, y0, s), hash_(x0, y1, s), hash_(x1, y1, s)
    return a + (b - a) * a_ + (c - a) * b_ + (a - b - c + d) * a_ * b_


def vn(x, y, sx, sy, s, m=1.0):
    return vnoise_t(x, y, max(1, round(P * m / sx)), max(1, round(P * m / sy)), s)


def fbm(x, y, sx, sy, s):
    """fbm(x/sx, y/sy, s) du prototype, rendu périodique."""
    return vn(x, y, sx, sy, s) * .6 + vn(x, y, sx, sy, s + 7, 2.1) * .28 + vn(x, y, sx, sy, s + 13, 4.3) * .12


BAY = (np.array([0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]) + .5) / 16


def rp(R, v, x, y):
    R = np.array(R, np.uint8)
    n = len(R) - 1
    i = np.floor(v * n + BAY[(y & 3) * 4 + (x & 3)]).astype(np.int64)
    return R[np.clip(i, 0, n)]


def pick(cond, a, b):
    return np.where(cond[..., None], a, b)


# ---------- textures du style ardoise (caverne-planches.js) ----------
def grid():
    y, x = np.mgrid[0:P, 0:P]
    return x.astype(np.int64), y.astype(np.int64)


def tex_top():
    x, y = grid()
    v = .36 + (fbm(x, y, 9, 7, 11) - .5) * .4
    seam = ((x + y * 2 + np.floor(vn(x, y, 12, 12, 3) * 10).astype(np.int64)) % 9) == 0
    v = v - seam * .14
    moss = fbm(x, y, 10, 8, 13) > .78
    return pick(moss, rp(MOSS, v - .05, x, y), rp(SL, v, x, y))


def tex_floor():
    x, y = grid()
    row = y // 14
    off = (row & 1) * 9
    col = (x + off) // 18
    lu, lv = x + off - col * 18, y - row * 14
    colw = col % (P // 18)
    rowv = row % (P // 14)
    earth = (hash_(colw, rowv, 31) > .88) | (fbm(x, y, 16, 12, 30) > .75)
    joint = (lu == 0) | (lv == 0)
    v = .55 + (hash_(colw, rowv, 32) - .5) * .26 + (fbm(x, y, 7, 7, 34) - .5) * .2
    v = v + (lv == 1) * .12 - ((lu == 17) | (lv == 13)) * .12 - (hash_(x, y, 35) > .97) * .2
    out = rp(SLF, v, x, y)
    out = pick(joint, rp(EARTH1, np.full(x.shape, .15), x, y), out)
    return pick(earth, rp(EARTH1, .35 + fbm(x, y, 5, 5, 33) * .45, x, y), out)


def tex_dug():
    x, y = grid()
    chip = hash_(x >> 1, y >> 1, 40) > .86
    return pick(chip, rp(SL, np.full(x.shape, .55), x, y), rp(EARTH1, .3 + fbm(x, y, 6, 5, 41) * .5, x, y))


# ---------- correspondances de palettes ----------
def rock_map(rock):
    """CAVE_C.rock (9 teintes) → ardoise (8 teintes), même rang de clarté."""
    return [SL[min(7, round(k * 7 / (len(rock) - 1)))] for k in range(len(rock))]


def rgb_int(a):
    a = a.astype(np.int64)
    return (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


# ---------- sol ----------
def build_ground(W, top, flo, rmap):
    g = W["ground"]
    C = W["CAVE_C"]
    width, height, chunk = g["width"], g["height"], g["chunk"]
    G = np.zeros((height, width, 4), np.uint8)
    for r in range(g["rows"]):
        for c in range(g["cols"]):
            a = np.array(Image.open(f"{SRC}/world/ground/ground_r{r}_c{c}.png").convert("RGBA"))
            h, w = min(chunk, height - r * chunk), min(chunk, width - c * chunk)
            G[r * chunk:r * chunk + h, c * chunk:c * chunk + w] = a[:h, :w]
    v = rgb_int(G)
    ints = lambda L: [int(s[1:], 16) for s in L]
    floor_i, rock_i, moss_i = ints(C["floor"]), ints(C["rock"]), ints(W["C_moss"])
    is_floor = np.isin(v, floor_i)
    is_rock = np.isin(v, rock_i)
    # Mousse sur la roche : une teinte de C_moss entourée de roche (l'herbe a sa propre palette).
    is_moss = np.isin(v, moss_i) & dilate(is_rock, 6)
    rocky = is_rock | is_moss
    # Pixels assombris (× 0,55) au bord des cases : on retrouve la teinte d'origine.
    dark = np.zeros(v.shape, bool)
    dark_src = np.zeros(v.shape + (3,), np.uint8)
    near = dilate(is_floor | is_rock, 3) & ~(is_floor | is_rock | is_moss)
    ys, xs = np.nonzero(near)
    pal = [(c, "floor", k) for k, c in enumerate(C["floor"])] + [(c, "rock", k) for k, c in enumerate(C["rock"])]
    px = G[ys, xs, :3].astype(np.int64)
    best = np.full(len(ys), 1e9)
    bsel = np.full(len(ys), -1)
    for n, (c, _, _) in enumerate(pal):
        d = np.abs(px - np.round(np.array(hx(c)) * .55)).sum(1)
        better = d < best
        best[better], bsel[better] = d[better], n
    ok = best <= 3
    yy, xx = np.mgrid[0:height, 0:width]
    TX, TY = xx % P, yy % P
    out = G.copy()
    out[..., :3] = np.where(is_floor[..., None], flo[TY, TX], out[..., :3])
    # Roche : texture d'ardoise ; près d'un bord (sol, herbe…), on garde le dessin et on change la teinte.
    edge = rocky & dilate(~rocky, 3)
    out[..., :3] = np.where((rocky & ~edge)[..., None], top[TY, TX], out[..., :3])
    ri = {iv: k for k, iv in enumerate(rock_i)}
    lut = np.zeros((len(rock_i), 3), np.uint8)
    for k in range(len(rock_i)):
        lut[k] = rmap[k]
    e_ys, e_xs = np.nonzero(edge & is_rock)
    out[e_ys, e_xs, :3] = lut[[ri[int(t)] for t in v[e_ys, e_xs]]]
    e_ys, e_xs = np.nonzero(edge & is_moss)
    out[e_ys, e_xs, :3] = top[e_ys % P, e_xs % P]
    for i in np.nonzero(ok)[0]:
        c, kind, k = pal[bsel[i]]
        y, x = ys[i], xs[i]
        base = flo[y % P, x % P] if kind == "floor" else np.array(rmap[k], np.uint8)
        out[y, x, :3] = np.round(base * .55).astype(np.uint8)
    os.makedirs(f"{OUT}/world/ground", exist_ok=True)
    for r in range(g["rows"]):
        for c in range(g["cols"]):
            tile = np.zeros((chunk, chunk, 4), np.uint8)
            part = out[r * chunk:(r + 1) * chunk, c * chunk:(c + 1) * chunk]
            tile[:part.shape[0], :part.shape[1]] = part
            Image.fromarray(tile).save(f"{OUT}/world/ground/ground_r{r}_c{c}.png", optimize=True)
    print("sol :", int(is_floor.sum()), "px de dalles,", int(rocky.sum()), "px de roche,", int(ok.sum()), "px de bord assombri")


# ---------- sprites ----------
def lum(a):
    return a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11


def recolor(a, keep_purple=False):
    """Recolore un sprite rocheux du baker : clarté conservée, teinte d'ardoise ; mousse, quartz, contour."""
    a = a.copy()
    op = a[..., 3] > 0
    r, g, b = (a[..., i].astype(np.int64) for i in range(3))
    L = lum(a[..., :3].astype(np.float64)) / 255
    y, x = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    outline = L < .09
    moss = (g > r + 12) & (g > b + 8)
    crystal = (b > r + 30) & (g > r + 15)
    purple = keep_purple & (r > g + 20) & (b > g + 20)
    stone = op & ~outline & ~moss & ~crystal & ~purple
    a[..., :3] = np.where(stone[..., None], rp(SL, np.clip(L * 1.45 - .04, 0, 1), x, y), a[..., :3])
    a[..., :3] = np.where((op & moss & ~outline)[..., None], rp(MOSS, np.clip(L * 2.2 - .1, 0, 1), x, y), a[..., :3])
    a[..., :3] = np.where((op & crystal)[..., None], rp(QUARTZ, np.clip(L * 1.3 - .2, 0, 1), x, y), a[..., :3])
    a[..., :3] = np.where((op & outline)[..., None], np.array(OUTL, np.uint8), a[..., :3])
    return a


def face_sprite(a, seed, outdoor):
    """Paroi de falaise redessinée en feuillets d'ardoise (face() de la planche), stalactites à l'intérieur."""
    a = a.copy()
    h, w = a.shape[:2]
    op = a[..., 3] > 0
    L = lum(a[..., :3].astype(np.float64)) / 255
    outline = op & (L < .09) & dilate(~op, 1)  # seulement le vrai contour, pas les fissures sombres
    body = op & ~outline
    rgb = a[..., :3].copy()
    for x in range(w):
        col = np.nonzero(body[:, x])[0]
        if len(col) == 0:
            continue
        top, H = col[0], len(col)
        for y in col:
            ly = y - top
            if ly == 0:
                rgb[y, x] = SL[7]
                continue
            off = int(np.floor(vnoise_t(np.array(x + seed * 32), np.array(0), 3, 1, 21) * 6))
            yy = ly + off
            band, bl = yy // 5, yy % 5
            v = .6 - ly / H * .32 + (hash_(band, (x + seed * 32) // (7 + int(hash_(band, 1, 2) * 9)), 23) - .5) * .22
            v += .13 if bl == 0 else (-.2 if bl == 4 else 0)
            xs, ys = np.array([x]), np.array([y])
            if outdoor and ly < H * .45 and fbm(np.array([float(x + seed * 32)]), ys * 1.0, 6, 4, 25)[0] > .58:
                rgb[y, x] = rp(MOSS, np.array([v + .1]), xs, ys)[0]
            else:
                rgb[y, x] = rp(SL, np.array([float(v)]), xs, ys)[0]
    if not outdoor:
        # stalac() : 2 à 4 éclats d'ardoise pendus sous l'arête, contour noir sur la paroi.
        rnd = np.random.default_rng(seed * 31 + 11)
        ys0 = [np.nonzero(body[:, x])[0] for x in range(w)]
        tops = [c[0] for c in ys0 if len(c)]
        H = max(len(c) for c in ys0)
        yt = int(min(tops)) + 2
        shard = np.zeros((h, w), bool)
        colr = np.zeros((h, w, 3), np.uint8)
        for _ in range(2 + int(rnd.random() * 3)):
            cx = 3 + rnd.random() * (w - 6)
            ln = 5 + rnd.random() * H * .42
            wd = 1.5 + rnd.random() * 1.6
            tip = cx + (rnd.random() - .5) * 2
            for y in range(yt, int(yt + ln) + 1):
                t = (y + .5 - yt) / ln
                if t > 1:
                    break
                half = wd * (1 - t) + .3 * (1 - t)
                cxx = cx + (tip - cx) * t
                for x in range(int(np.floor(cxx - half)), int(np.ceil(cxx + half)) + 1):
                    if 0 <= x < w and 0 <= y < h and abs(x + .5 - cxx) <= half + .2 and body[y, x]:
                        shard[y, x] = True
                        v = (.75 if x < cxx else .5) - t * .15
                        colr[y, x] = rp(SL, np.array([v]), np.array([x]), np.array([y]))[0]
        ring = dilate(shard, 1) & ~shard & body
        rgb = np.where(shard[..., None], colr, rgb)
        rgb = np.where(ring[..., None], np.array(OUTL, np.uint8), rgb)
    a[..., :3] = np.where(body[..., None], rgb, a[..., :3])
    a[..., :3] = np.where(outline[..., None], np.array(OUTL, np.uint8), a[..., :3])
    return a


def is_rocky(sid):
    return sid.split("_")[0] in ("rock", "mountain", "spire", "crystal", "altar") or sid.startswith(("face", "gallery_spire"))


def convert_sprite(sid, a):
    if sid.startswith("face"):
        outdoor = a.shape[0] <= 40
        seed = int(sid.rsplit("_", 1)[1]) + (100 if sid.startswith("face5") else 0)
        return face_sprite(a, seed, outdoor)
    return recolor(a, keep_purple=sid.startswith("altar"))


def main():
    W = json.load(open(f"{SRC}/manifest.json"))["world"]
    os.makedirs(f"{OUT}/world/tiles", exist_ok=True)
    top, flo, dug = tex_top(), tex_floor(), tex_dug()
    for name, t in (("rock", top), ("floor", flo), ("dug", dug)):
        Image.fromarray(np.dstack([t, np.full(t.shape[:2], 255, np.uint8)])).save(f"{OUT}/world/tiles/{name}.png", optimize=True)
    rmap = rock_map(W["CAVE_C"]["rock"])
    json.dump({"note": "Style ardoise tyrienne (tools/ardoise/ardoise.py)", "period": P,
               "rock": ["#%02x%02x%02x" % c for c in rmap],
               "light": [0.95, 1.02, 1.14]}, open(f"{OUT}/palette.json", "w"), indent=1)
    build_ground(W, top, flo, rmap)
    atlas = np.array(Image.open(f"{SRC}/world/decor_atlas.png").convert("RGBA"))
    regions = json.load(open(f"{SRC}/world/decor_atlas.json"))["sprites"]
    n = 0
    pad = json.load(open(f"{SRC}/world/decor_atlas.json"))["pad"]
    for sid, (x, y, w, h) in regions.items():
        if is_rocky(sid):
            atlas[y:y + h, x:x + w] = convert_sprite(sid, atlas[y:y + h, x:x + w])
            # Marge de la planche : les bords du sprite y sont recopiés (anti-fuite au filtrage).
            for yy in range(max(0, y - pad), min(atlas.shape[0], y + h + pad)):
                for xx in range(max(0, x - pad), min(atlas.shape[1], x + w + pad)):
                    if (x <= xx < x + w and y <= yy < y + h) or atlas[yy, xx, 3] == 0:
                        continue
                    atlas[yy, xx] = atlas[min(max(yy, y), y + h - 1), min(max(xx, x), x + w - 1)]
            n += 1
    Image.fromarray(atlas).save(f"{OUT}/world/decor_atlas.png", optimize=True)
    os.makedirs(f"{OUT}/world/runtime", exist_ok=True)
    for f in sorted(os.listdir(f"{SRC}/world/runtime")):
        if f.endswith(".png"):
            a = np.array(Image.open(f"{SRC}/world/runtime/{f}").convert("RGBA"))
            Image.fromarray(convert_sprite(f[:-4], a)).save(f"{OUT}/world/runtime/{f}", optimize=True)
            n += 1
    print("sprites repeints :", n)


if __name__ == "__main__":
    sys.exit(main())
