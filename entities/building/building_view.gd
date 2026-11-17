class_name BuildingView
extends Node2D
## Rendu d'un bâtiment (drawBuilding, buildings.js, 73b410f), dans le tri en profondeur du monde.
##  - Achevé : image de la boucle animée précalculée (PixelBuildings.draw), à l’échelle « scale » du manifeste
##    (1 : tous les arts sont dessinés ou réduits en 2×2 natif, tools/batiments_2x2) ou size/3 à défaut.
##  - Chantier : empreinte animée (TempleKit.footprint), puis le site d'incantation (port de
##    TempleIncantation.drawSite) : le sprite est découpé en pierres de 6 px, qui se décollent d'un éboulis,
##    montent en arc et se tassent à leur place, assise par assise, avec des bouffées de poussière.
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
var _full: Texture2D
var _dim: Texture2D
var _site: Dictionary
var _footprint: Texture2D
## Sommet visible du sprite par rapport au point au sol, en pixels natifs.
var top_offset := 0.0
## Pierres en vol à cette image (coordonnées natives du monde), pour les éclairs du miroir.
var stones: Array[Vector2] = []


func setup(b: Building) -> void:
	building = b
	if _meta.is_empty():
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))
		_meta = m["buildings"]
		_footprint_meta = m["overlay"]["footprints"]["build"]
	_art = b.def()["art"]
	# Échelle du repère 320×240 : size/3 pour les sprites du prototype ; « scale » explicite pour un art
	# dessiné directement à l'échelle native (Puits des Âmes · Lotus de pierre : scale 1).
	_f = float(_meta["arts"][_art].get("scale", int(b.def()["size"]) / 3.0))
	_anim = load("res://assets/baked/buildings/%s_anim.png" % _art)
	_footprint = load("res://assets/baked/overlay/footprint_build.png")
	_site = site(_art)
	var top := float(SH)
	for tile: Dictionary in _site["tiles"]:
		top = minf(top, tile["y"])
	top_offset = (top - float(_meta["arts"][_art]["anchor"][1])) * _f
	_full = _site["full"]
	_dim = _site["dim"]
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
		var i := floori(t * float(an["fps"])) % int(an["count"])
		var cols := int(an["cols"])
		var src := Rect2((i % cols) * SW, (i / cols) * SH, SW, SH)
		draw_set_transform(-anchor * _f, 0.0, Vector2(_f, _f))
		draw_texture_rect_region(_anim, Rect2(0, 0, SW, SH), src)
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


## init(kind) : découpe de l'image 0 du bâtiment achevé en pierres, version atténuée pour l'éboulis.
static func site(art: String) -> Dictionary:
	if _sites.has(art):
		return _sites[art]
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["buildings"]
	var A: Dictionary = _meta["arts"][art]
	var ay := float(A["anchor"][1])
	var sheet: Texture2D = load("res://assets/baked/buildings/%s_anim.png" % art)
	var full := sheet.get_image().get_region(Rect2i(0, 0, SW, SH))
	full.convert(Image.FORMAT_RGBA8)
	var dim := full.duplicate() as Image
	var data := dim.get_data()
	for i in range(0, data.size(), 4):
		var l := (data[i] + data[i + 1] + data[i + 2]) / 3.0
		data[i] = _u8(l * 0.45 + 18.0)
		data[i + 1] = _u8(l * 0.42 + 14.0)
		data[i + 2] = _u8(l * 0.5 + 22.0)
	dim.set_data(SW, SH, false, Image.FORMAT_RGBA8, data)
	var fdata := full.get_data()
	var tiles: Array[Dictionary] = []
	var top := SH
	var bot := 0
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
	var sm := 0.0
	for p in tiles:
		var id: int = p["id"]
		var h := float(bot - p["y"]) / float(bot - top if bot != top else 1)
		p["s"] = h * 0.78 + hs(id * 3.1) * 0.12
		sm = maxf(sm, p["s"])
		if p["y"] + TS > ay:
			p["gy"] = float(p["y"])
			p["rx"] = float(p["x"])
		else:
			p["gy"] = ay - 6.0 + hs(id * 2.3) * 16.0
			p["rx"] = p["x"] + (hs(id * 7.7) * 2.0 - 1.0) * 16.0
	for p in tiles:
		p["n"] = p["s"] / sm
	var out := {"full": ImageTexture.create_from_image(full), "dim": ImageTexture.create_from_image(dim), "tiles": tiles}
	_sites[art] = out
	return out


## Uint8ClampedArray : arrondi au plus proche, égalité vers le pair.
static func _u8(v: float) -> int:
	var f := floorf(v)
	var r := v - f
	var n := int(f) + (1 if r > 0.5 or (r == 0.5 and int(f) % 2 == 1) else 0)
	return clampi(n, 0, 255)


static func _path(p: Dictionary, u: float) -> Vector2:
	var sx: float = p["rx"]
	var sy: float = p["gy"]
	var id: int = p["id"]
	if u < 0.3:
		var k := _eo(u / 0.3)
		return Vector2(sx + sin(u * 40.0 + id) * 0.6, sy - k * 9.0)
	if u < 0.9:
		var k := _eio((u - 0.3) / 0.6)
		return Vector2(lerpf(sx, p["x"], k), lerpf(sy - 9.0, p["y"] - 2.0, k) - sin(PI * k) * 10.0)
	var k := (u - 0.9) / 0.1
	return Vector2(p["x"], p["y"] - 2.0 + k * 2.0 + sin(k * PI))


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


## drawSite : chantier à `progress` ∈ [0, 1[, sur une durée `dur`. Dessine dans le repère 320×240 du
## bâtiment et renvoie les pierres en vol (dans ce repère).
static func draw_site(ci: CanvasItem, S: Dictionary, progress: float, dur: float) -> Array[Vector2]:
	var full: Texture2D = S["full"]
	var dim: Texture2D = S["dim"]
	var tiles: Array = S["tiles"]
	var moving: Array[Vector2] = []
	var fx: Array[Array] = []
	for p: Dictionary in tiles:
		var raw: float = (progress - p["n"] * (1.0 - D)) / D
		if raw <= 0.0:
			var w0 := float(mini(TS, SW - int(p["x"])))
			ci.draw_texture_rect_region(dim, Rect2(jr(p["rx"]), jr(p["gy"]), w0, TS), Rect2(p["x"], p["y"], w0, TS))
	for p: Dictionary in tiles:
		var raw: float = (progress - p["n"] * (1.0 - D)) / D
		if raw <= 0.0:
			continue
		var u := _cl(raw)
		var t := D * dur
		# Pierre de la dernière colonne : rognée au bord de l'image (drawImage hors source).
		var tw := float(mini(TS, SW - int(p["x"])))
		var src := Rect2(p["x"], p["y"], tw, TS)
		if u >= 1.0:
			ci.draw_texture_rect_region(full, Rect2(p["x"], p["y"], tw, TS), src)
			var age := (raw - 1.0) * t
			if age < 0.7:
				fx.append([p["x"] + 3.0, p["y"] + TS, age, p["id"]])
			continue
		var q := _path(p, u)
		ci.draw_texture_rect_region(full, Rect2(jr(q.x), jr(q.y), tw, TS), src)
		moving.append(q + Vector2(3, 3))
		if u * t < 0.5:
			fx.append([p["rx"] + 3.0, p["gy"] + TS, u * t, p["id"] + 7])
	for f in fx:
		_puff(ci, f[0], f[1], f[2], f[3])
	return moving
