class_name BuildingView
extends Node2D
## Rendu d'un bâtiment (drawBuilding, buildings.js, 73b410f), dans le tri en profondeur du monde.
##  - Achevé : image de la boucle animée précalculée (PixelBuildings.draw), à l’échelle « scale » du manifeste
##    (1 : tous les arts sont dessinés ou réduits en 2×2 natif, tools/batiments_2x2) ou size/3 à défaut.
##  - Visée (planches/pose-rendu-propositions.html, piste B « Liseré ») : Ghost dessine le vrai sprite à 65 %,
##    cerné d'un liseré d'un pixel vert d'eau ; pose impossible, teinte et liseré rouges.
##  - Pose (planches/pose-batiment-propositions.html, piste 4 « Le plan se défait », sortie « couleurs ») :
##    pendant POSE secondes, le rendu de visée s'écroule de la base au sommet ; chaque pierre roule jusqu'à
##    son tas, sa couleur s'éteignant en ardoise. Le hissage occupe le reste de la durée du chantier.
##  - Chantier (planches/chantier-debut-propositions.html, piste C « Échafaudage ») : empreinte animée
##    (TempleKit.footprint) et deux tas de moellons d'ardoise neutres de part et d'autre ; les perches de bois
##    sortent du sol, puis les traverses se posent. Le sprite est découpé en pierres de 6 px : chacune quitte
##    le sommet de son tas, est hissée à la verticale, glisse à sa place en prenant la couleur du bâtiment et
##    s'y tasse avec une bouffée de poussière, assise par assise. À la fin, l'échafaudage tombe.
## Origine du nœud : point au sol du bâtiment, en pixels natifs, sans arrondi (comme drawImage au
## pixel près de l'écran dans le prototype).

const TS := 6
const D := 0.11
const SW := 320
const SH := 240

static var _meta: Dictionary
static var _footprint_meta: Dictionary
static var _sites := {}

var building: Building
var _art := ""
var _f := 1.0
var _anim: Texture2D
## Boucle « au repos » (personnel absent ; autel où personne ne prie), si l'art en fournit une (clé « rest » du manifeste).
var _rest: Texture2D
var _idle := false
## Pièces de l'Atelier (WorkshopMorph), créées au premier dessin au travail.
var _morph: WorkshopMorph
var _idle_checked := -INF
var _full: Texture2D
var _site: Dictionary
var _footprint: Texture2D
## Sommet visible du sprite par rapport au point au sol, en pixels natifs.
var top_offset := 0.0
## Pierres en vol à cette image (coordonnées natives du monde), pour les éclairs du miroir.
var stones: Array[Vector2] = []


func setup(b: Building) -> void:
	building = b
	# Chargés séparément : l'aperçu de visée (Ghost → site()) peut remplir _meta avant le premier chantier.
	if _meta.is_empty() or _footprint_meta.is_empty():
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))
		_meta = m["buildings"]
		_footprint_meta = m["overlay"]["footprints"]["build"]
	_art = b.def()["art"]
	# Échelle du repère 320×240 : size/3 pour les sprites du prototype ; « scale » explicite pour un art
	# dessiné directement à l'échelle native (Puits des Âmes · Lotus de pierre : scale 1).
	_f = float(_meta["arts"][_art].get("scale", int(b.def()["size"]) / 3.0))
	_anim = load("res://assets/baked/buildings/%s_anim.png" % _art)
	var rest_path := "res://assets/baked/buildings/%s_rest.png" % _art
	if _meta["arts"][_art].has("rest") and ResourceLoader.exists(rest_path):
		_rest = load(rest_path)
	_footprint = load("res://assets/baked/overlay/footprint_build.png")
	_site = site(_art)
	var top := float(SH)
	for tile: Dictionary in _site["tiles"]:
		top = minf(top, tile["y"])
	top_offset = (top - float(_meta["arts"][_art]["anchor"][1])) * _f
	if b.type == "workshop":
		# Les pièces flottent au-dessus de la table : la tuile de fabrication se place plus haut qu'elles.
		top_offset = minf(top_offset, (WorkshopMorph.SPOT.y - 34.0 - float(_meta["arts"][_art]["anchor"][1])) * _f)
	_full = _site["full"]
	position = Proj.nat(b.x, 0.0, b.z)
	# Empreinte du chantier, dessinée sous le site et lissée (tracé vectoriel dans le prototype).
	var fp := _Footprint.new()
	fp.view = self
	fp.show_behind_parent = true
	fp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(fp)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var b := building
	var A: Dictionary = _meta["arts"][_art]
	var anchor := Vector2(A["anchor"][0], A["anchor"][1])
	var t := GameState.sim_time
	if b.complete:
		stones.clear()
		var an: Dictionary = A["anim"]
		var sheet := _anim
		if _rest != null:
			# Personnel absent du poste : boucle de repos (relu quatre fois par seconde).
			if t - _idle_checked > 0.25 or t < _idle_checked:
				_idle_checked = t
				_idle = Simulation.temple_idle(b) if b.is_temple() else Oublieux.resting(b) if b.type == "eglise" else Production.idle(b)
			if _idle:
				an = A["rest"]
				sheet = _rest
		var i := floori(t * float(an["fps"])) % int(an["count"])
		var cols := int(an["cols"])
		var src := Rect2((i % cols) * SW, (i / cols) * SH, SW, SH)
		draw_set_transform(-anchor * _f, 0.0, Vector2(_f, _f))
		draw_texture_rect_region(sheet, Rect2(0, 0, SW, SH), src)
		# Atelier au travail : les pièces de bois prennent la forme de l'objet fabriqué.
		if b.type == "workshop" and not _idle:
			if _morph == null:
				_morph = WorkshopMorph.new()
			var chest := Production.chest_pos(b, "out")
			_morph.draw(self, b, anchor + (Proj.nat(chest.x, 0.0, chest.y) - position) / _f - Vector2(0, 8))
		return
	# Site d'incantation.
	draw_set_transform(-anchor * _f, 0.0, Vector2(_f, _f))
	stones = draw_site(self, _site, b.progress / float(b.def()["time"]), float(b.def()["time"]))
	for k in stones.size():
		stones[k] = position + (stones[k] - anchor) * _f
	draw_set_transform(Vector2.ZERO)


## Empreinte animée du chantier (TempleKit.footprint) : repère 320×240 à l'échelle Z/16, soit 0,5814 pixel
## natif (× size/3), précalculée au double.
class _Footprint extends Node2D:
	var view: BuildingView

	func _process(_delta: float) -> void:
		visible = not view.building.complete
		if visible:
			queue_redraw()

	func _draw() -> void:
		var F := BuildingView._footprint_meta
		var fi := floori(GameState.sim_time * 12.0) % int(F["count"])
		var cols := int(F["cols"])
		var src := Rect2((fi % cols) * float(F["frame_w"]), (fi / cols) * float(F["frame_h"]), F["frame_w"], F["frame_h"])
		var fs := 8.0 / 0.86 / 16.0 * (int(view.building.def()["size"]) / 3.0) / 2.0
		draw_set_transform(-Vector2(F["ax"], F["ay"]) * fs, 0.0, Vector2(fs, fs))
		draw_texture_rect_region(view._footprint, Rect2(0, 0, src.size.x, src.size.y), src)


# ---------------------------------------------------------------- TempleIncantation

static func hs(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


static func _cl(v: float) -> float:
	return clampf(v, 0.0, 1.0)


static func _eio(u: float) -> float:
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0


static func _eo(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


## Math.round du JS.
static func jr(v: float) -> float:
	return floorf(v + 0.5)


## init(kind) : découpe de l'image 0 du bâtiment achevé en pierres, emplacement de chaque pierre dans les
## deux tas de moellons et emprise de l'échafaudage.
static func site(art: String) -> Dictionary:
	if _sites.has(art):
		return _sites[art]
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["buildings"]
	var A: Dictionary = _meta["arts"][art]
	var ax := float(A["anchor"][0])
	var ay := float(A["anchor"][1])
	var sheet: Texture2D = load("res://assets/baked/buildings/%s_anim.png" % art)
	var full := sheet.get_image().get_region(Rect2i(0, 0, SW, SH))
	full.convert(Image.FORMAT_RGBA8)
	var fdata := full.get_data()
	var tiles: Array[Dictionary] = []
	var top := SH
	var bot := 0
	var x0 := SW
	var x1 := 0
	for y in range(0, SH, TS):
		for x in range(0, SW, TS):
			var n := 0
			for j in range(y, y + TS):
				for i in range(x, x + TS):
					# Lecture à plat comme dans le prototype : au-delà du bord droit, on lit la ligne suivante.
					var idx := (j * SW + i) * 4 + 3
					if idx < fdata.size() and fdata[idx] > 120:
						n += 1
			if n > 4:
				tiles.append({"x": x, "y": y, "id": tiles.size()})
				top = mini(top, y)
				bot = maxi(bot, y)
				x0 = mini(x0, x)
				x1 = maxi(x1, x + TS)
	var sm := 0.0
	for p in tiles:
		var id: int = p["id"]
		var h := float(bot - p["y"]) / float(bot - top if bot != top else 1)
		p["h"] = h
		p["s"] = h * 0.78 + hs(id * 3.1) * 0.12
		sm = maxf(sm, p["s"])
	for p in tiles:
		p["n"] = p["s"] / sm
	# Deux tas, à gauche et à droite de l'empreinte : les dernières pierres à partir au fond, les premières
	# au sommet.
	var sides := [[], []]
	for p in tiles:
		sides[0 if p["x"] + 3 < ax else 1].append(p)
	for side in 2:
		var arr: Array = sides[side]
		arr.sort_custom(func(a, b): return a["n"] > b["n"])
		var hx := ax + (-46.0 if side == 0 else 46.0)
		for k in arr.size():
			var p: Dictionary = arr[k]
			var lvl := floorf((1.0 - sqrt(1.0 - float(k) / arr.size())) * 6.0)
			p["hx"] = hx + (hs(p["id"] * 5.3) * 2.0 - 1.0) * (6.0 - lvl) * 2.6 - 3.0
			p["hy"] = ay + 5.0 - lvl * 3.2 - 3.0 + hs(p["id"] * 1.9) * 1.5
	# Le tas se dessine du fond vers le sommet.
	var heap := tiles.duplicate()
	heap.sort_custom(func(a, b): return a["n"] > b["n"])
	var w := x1 - x0
	# Liseré d'un pixel autour de la silhouette (blanc, teinté au dessin).
	var line := Image.create(SW, SH, false, Image.FORMAT_RGBA8)
	for y in SH:
		for x in SW:
			if fdata[(y * SW + x) * 4 + 3] > 24:
				continue
			if (x > 0 and fdata[(y * SW + x - 1) * 4 + 3] > 24) or (x < SW - 1 and fdata[(y * SW + x + 1) * 4 + 3] > 24) \
					or (y > 0 and fdata[((y - 1) * SW + x) * 4 + 3] > 24) or (y < SH - 1 and fdata[((y + 1) * SW + x) * 4 + 3] > 24):
				line.set_pixel(x, y, Color.WHITE)
	var out := {"full": ImageTexture.create_from_image(full), "outline": ImageTexture.create_from_image(line),
		"tiles": tiles, "heap": heap, "ay": ay, "ax": ax,
		"poles": [x0 - 3, x0 + roundi(w / 3.0), x1 - roundi(w / 3.0) - 2, x1 + 1], "height": ay + 2.0 - (top - 6)}
	_sites[art] = out
	return out


## Moellon neutre d'ardoise (6 × 6), trois teintes selon l'identifiant.
const ROCK := [
	[Color("#1e232b"), Color("#3a4250"), Color("#55606e"), Color("#76818e")],
	[Color("#1e232b"), Color("#333a46"), Color("#4e5866"), Color("#6e7a88")],
	[Color("#1a1f26"), Color("#2e3540"), Color("#465060"), Color("#647080")],
]


static func _rock(ci: CanvasItem, x: float, y: float, id: int, a: float) -> void:
	if a <= 0.0:
		return
	var P: Array = ROCK[id % 3]
	var m := Color(1, 1, 1, a)
	ci.draw_rect(Rect2(x, y, 6, 6), P[0] * m)
	ci.draw_rect(Rect2(x + 1, y + 1, 4, 4), P[2] * m)
	ci.draw_rect(Rect2(x + 1, y + 1, 4, 1), P[3] * m)
	ci.draw_rect(Rect2(x + 1, y + 1, 1, 2), P[3] * m)
	ci.draw_rect(Rect2(x + 1, y + 4, 4, 1), P[1] * m)
	if hs(id * 4.1) > 0.5:
		ci.draw_rect(Rect2(x + 3, y + 2, 1, 1), P[1] * m)


static func _sst(a: float, b: float, v: float) -> float:
	var t := _cl((v - a) / (b - a))
	return t * t * (3.0 - 2.0 * t)


## Hissage : la pierre monte à la verticale de son tas jusqu'à 4 px au-dessus de sa place, glisse
## jusqu'à l'aplomb, puis s'y tasse.
static func _path(p: Dictionary, u: float) -> Vector2:
	var ty: float = p["y"] - 4.0
	if u < 0.55:
		return Vector2(p["hx"], lerpf(p["hy"], ty, _eio(u / 0.55)))
	if u < 0.9:
		return Vector2(lerpf(p["hx"], p["x"], _eio((u - 0.55) / 0.35)), ty)
	return Vector2(p["x"], ty + 4.0 * (u - 0.9) / 0.1)


const WOOD_DARK := Color("#2e2016")
const WOOD := Color("#9c7048")
const WOOD_MID := Color("#6e4830")
const WOOD_LIGHT := Color("#c49a68")
## Part du hissage à laquelle l'échafaudage commence à tomber.
const SCAFF_DOWN := 0.9
## Durée de la pose (écroulement du rendu de visée), prise sur le début du chantier.
const POSE := 0.65
## Rendu de visée : opacité du sprite, liseré possible / impossible, teinte de la pose impossible.
const GHOST_ALPHA := 0.65
const GHOST_OK := Color("#a4f2ca")
const GHOST_BAD := Color("#ff7a68")
const GHOST_RED := Color(1.0, 0.41, 0.35)


## Échafaudage : perches extérieures et traverses derrière le bâtiment (front = false), perches
## intérieures devant (front = true). Montage en secondes depuis la pose (`tau`), chute en part du hissage (`q`).
static func _scaffold(ci: CanvasItem, S: Dictionary, tau: float, q: float, front: bool) -> void:
	var xs: Array = S["poles"]
	var H: float = S["height"]
	var ay: float = S["ay"]
	var end := _cl((q - SCAFF_DOWN) / (1.0 - SCAFF_DOWN))
	for i in 4:
		if (i == 1 or i == 2) != front:
			continue
		var fall := _cl(end * 4.0 - i)
		if fall >= 1.0:
			continue
		var h := roundf(H * _sst(0.35 + i * 0.04, 0.65 + i * 0.04, tau) * (1.0 - fall))
		if h <= 0.0:
			continue
		var x: float = xs[i]
		var y := ay + 2.0 - h
		ci.draw_rect(Rect2(x - 1, y, 4, h), WOOD_DARK)
		ci.draw_rect(Rect2(x, y, 2, h), WOOD)
		ci.draw_rect(Rect2(x, y, 1, h), WOOD_LIGHT)
	if front:
		return
	for j in 4:
		var k := _sst(0.58 + j * 0.04, 0.76 + j * 0.04, tau)
		var fall := _cl(end * 4.0 - j * 0.7)
		if k <= 0.0 or fall >= 1.0:
			continue
		var y := roundf(ay - 6.0 - j * (H - 12.0) / 3.0) + fall * 30.0
		var w := roundf((float(xs[3]) - float(xs[0]) + 3.0) * k)
		ci.draw_rect(Rect2(xs[0] - 1, y - 1, w + 2, 4), WOOD_DARK)
		ci.draw_rect(Rect2(xs[0], y, w, 2), WOOD_MID)
		ci.draw_rect(Rect2(xs[0], y, w, 1), WOOD_LIGHT)


static func _puff(ci: CanvasItem, x: float, y: float, age: float, seed: int) -> void:
	if age < 0.0 or age > 0.7:
		return
	var k := age / 0.7
	for i in 4:
		var a := hs(seed + i) * PI
		var v := 6.0 + hs(seed * 3 + i) * 8.0
		var sgn := 1.0 if hs(seed + i * 5) > 0.5 else -1.0
		var w := 2.0 if k < 0.5 else 1.0
		ci.draw_rect(Rect2(jr(x + cos(a) * v * k * sgn), jr(y - sin(a) * v * k * 0.4 - k * 2.0), w, w),
			Color("#8d8770") if k < 0.4 else Color("#6c6856"))


## Rendu de visée : vrai sprite en transparence et liseré, rouges si la pose est impossible. Repère 320×240.
static func draw_ghost(ci: CanvasItem, S: Dictionary, ok: bool) -> void:
	ci.draw_texture(S["full"], Vector2.ZERO, Color(1, 1, 1, GHOST_ALPHA) if ok else Color(GHOST_RED, GHOST_ALPHA))
	ci.draw_texture(S["outline"], Vector2.ZERO, GHOST_OK if ok else GHOST_BAD)


## Écroulement à la pose : la pierre attend à sa place dans le rendu de visée (les assises du bas partent les
## premières), puis roule jusqu'à son tas ; sa couleur s'éteint en ardoise pendant la chute.
static func _crumble(ci: CanvasItem, S: Dictionary, p: Dictionary, tau: float) -> void:
	var tw := float(mini(TS, SW - int(p["x"])))
	var src := Rect2(p["x"], p["y"], tw, TS)
	var t0: float = 0.08 + hs(p["id"] * 9.1) * 0.1 + p["h"] * 0.18
	if tau < t0:
		ci.draw_texture_rect_region(S["full"], src, src, Color(1, 1, 1, GHOST_ALPHA))
		return
	var g := _cl((tau - t0) / 0.25)
	if g >= 1.0:
		_rock(ci, jr(p["hx"]), jr(p["hy"]), p["id"], 1.0)
		return
	var x := jr(lerpf(p["x"], p["hx"], g))
	var y := jr(lerpf(p["y"], p["hy"], g * g) - 5.0 * sin(PI * g) * (1.0 - g))
	_rock(ci, x, y, p["id"], _cl(g * 2.5))
	ci.draw_texture_rect_region(S["full"], Rect2(x, y, tw, TS), src, Color(1, 1, 1, (1.0 - g) * GHOST_ALPHA))


## drawSite : chantier à `progress` ∈ [0, 1[, sur une durée `dur`. Les POSE premières secondes, le rendu de
## visée s'écroule en deux tas ; le hissage occupe le reste. Dessine dans le repère 320×240 du bâtiment et
## renvoie les pierres en vol (dans ce repère).
static func draw_site(ci: CanvasItem, S: Dictionary, progress: float, dur: float) -> Array[Vector2]:
	var full: Texture2D = S["full"]
	var moving: Array[Vector2] = []
	var fx: Array[Array] = []
	var pose := minf(POSE, dur * 0.5)
	var tau := progress * dur
	var hoist := tau >= pose
	var q := _cl((tau - pose) / (dur - pose))
	var t := D * (dur - pose)
	if tau < 1.4:
		# Poussière au pied des deux tas quand les pierres y arrivent.
		for sg: int in [-1, 1]:
			for i in 4:
				fx.append([S["ax"] + sg * 46.0 + (hs(i * 3.7 + sg) - 0.5) * 24.0, S["ay"] + 8.0, tau - 0.3 - i * 0.08, i * 13 + sg + 70])
	_scaffold(ci, S, tau, q, false)
	for p: Dictionary in S["heap"]:
		if hoist and (q - p["n"] * (1.0 - D)) / D > 0.0:
			continue
		if hoist:
			_rock(ci, jr(p["hx"]), jr(p["hy"]), p["id"], 1.0)
		else:
			_crumble(ci, S, p, tau)
	if hoist:
		for p: Dictionary in S["tiles"]:
			var raw: float = (q - p["n"] * (1.0 - D)) / D
			if raw <= 0.0:
				continue
			var u := _cl(raw)
			# Pierre de la dernière colonne : rognée au bord de l'image (drawImage hors source).
			var tw := float(mini(TS, SW - int(p["x"])))
			var src := Rect2(p["x"], p["y"], tw, TS)
			if u >= 1.0:
				ci.draw_texture_rect_region(full, Rect2(p["x"], p["y"], tw, TS), src)
				var age := (raw - 1.0) * t
				if age < 0.7:
					fx.append([p["x"] + 3.0, p["y"] + TS, age, p["id"]])
				continue
			var at := _path(p, u)
			var k := _sst(0.2, 0.7, u)
			_rock(ci, jr(at.x), jr(at.y), p["id"], 1.0 - k)
			ci.draw_texture_rect_region(full, Rect2(jr(at.x), jr(at.y), tw, TS), src, Color(1, 1, 1, k))
			moving.append(at + Vector2(3, 3))
			if u * t < 0.4:
				fx.append([p["hx"] + 3.0, p["hy"] + TS, u * t, p["id"] + 7])
	_scaffold(ci, S, tau, q, true)
	# Le liseré de visée claque en blanc au clic.
	if tau < 0.1:
		ci.draw_texture(S["outline"], Vector2.ZERO, Color(1, 1, 1, 1.0 - tau / 0.1))
	for f in fx:
		_puff(ci, f[0], f[1], f[2], f[3])
	return moving


## Aperçu de pose en mode construction : suit la case visée, dans le tri en profondeur du monde.
class Ghost extends Node2D:
	var world: Node
	var _type := ""
	var _ok := false

	func _process(_delta: float) -> void:
		var p: Variant = GameState.build_pointer
		visible = GameState.hud_mode == "build" and p != null and not GameState.hud_build_type.is_empty() and world.simulation != null
		if not visible:
			return
		_type = GameState.hud_build_type
		var at := Simulation.snap_for(_type, p)
		_ok = world.simulation.site_visible(_type, at) and world.simulation.valid_site(_type, at)
		position = Proj.nat(at.x, 0.0, at.y)
		queue_redraw()

	func _draw() -> void:
		if _type.is_empty():
			return
		var def: Dictionary = Catalog.BUILDINGS[_type]
		var S := BuildingView.site(def["art"])
		var A: Dictionary = BuildingView._meta["arts"][def["art"]]
		var f := float(A.get("scale", int(def["size"]) / 3.0))
		draw_set_transform(-Vector2(A["anchor"][0], A["anchor"][1]) * f, 0.0, Vector2(f, f))
		BuildingView.draw_ghost(self, S, _ok)
