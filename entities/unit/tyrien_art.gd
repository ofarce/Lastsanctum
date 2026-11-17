class_name TyrienArt
extends RefCounted
## Ingénieur sans armure, tenue « Le Tyrien » (planche planches/tyrien-equipement.html) : un corps (« base »)
## et un calque par pièce d'équipement visible, pour chaque animation. Chaque calque ne contient que les pixels
## que la pièce change, corps en place : on empile la base puis les pièces portées dans l'ordre `order`.
## Planches générées par planches/tyrien-export.html (tools/tyrien/serve.py) depuis planches/assets/engineer-volume.js.

const DIR := "res://assets/imported/engineer/tyrien/"
const PORTRAIT := DIR + "tyrien_portrait.png"
const ANIMS := ["idle", "walk", "kneel", "pray", "settle", "lotus", "aim"]

static var meta: Dictionary
## frames[calque][animation] : Array[AtlasTexture] ; calque = "base" ou une pièce (helm, iron…).
static var frames: Dictionary = {}
## Image de la base → [animation, index], pour retrouver l'image correspondante dans chaque calque.
static var _index: Dictionary = {}
## Rectangle utile de la première image de repos de chaque pièce (icône d'objet).
static var _icon_rect: Dictionary = {}


static func load_all() -> void:
	if not frames.is_empty():
		return
	meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tyrien.json"))
	var layers: Array = ["base"]
	layers.append_array((meta["pieces"] as Dictionary).keys())
	for layer: String in layers:
		var tex: Texture2D = load(DIR + "tyrien_%s.png" % layer)
		var by_anim := {}
		for anim: String in ANIMS:
			by_anim[anim] = _sheet(tex, meta["anims"][anim])
		frames[layer] = by_anim
	for anim: String in ANIMS:
		var list: Array = frames["base"][anim]
		for i in list.size():
			_index[list[i]] = [anim, i]


static func _sheet(tex: Texture2D, m: Dictionary) -> Array[AtlasTexture]:
	var fw := float(meta["frame_w"])
	var fh := float(meta["frame_h"])
	var out: Array[AtlasTexture] = []
	for i in int(m["count"]):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2((i % int(m["cols"])) * fw, float(m["y"]) + (i / int(m["cols"])) * fh, fw, fh)
		out.append(a)
	return out


static func anim(name: String) -> Array[AtlasTexture]:
	load_all()
	return frames["base"][name]


static func fps(name: String) -> float:
	load_all()
	return float(meta["anims"][name].get("fps", 10.0))


## Image de visée de la base : rangée (recul 0 / 1,5 / 3, suspension) et colonne d'angle.
static func aim_frame(row: int, col: int) -> AtlasTexture:
	load_all()
	return frames["base"]["aim"][row * int(meta["anims"]["aim"]["cols"]) + col]


## Pièce d'équipement → emplacement de l'inventaire (« Tête », « Torse »…).
static func slot_of(piece: String) -> String:
	load_all()
	return meta["slots"][meta["pieces"][piece]["slot"]]


## Calques à empiler sur l'image `base_frame` pour les pièces portées (emplacement → pièce),
## dans l'ordre d'empilement. Vide si l'image n'est pas une image du Tyrien.
static func overlays(base_frame: Texture2D, pieces: Dictionary) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if pieces.is_empty() or not _index.has(base_frame):
		return out
	var at: Array = _index[base_frame]
	for slot_key: String in meta["order"]:
		var label: String = meta["slots"][slot_key]
		var piece: String = pieces.get(label, "")
		if piece != "" and frames.has(piece):
			out.append(frames[piece][at[0]][at[1]])
	return out


static func is_tyrien(frame: Texture2D) -> bool:
	return _index.has(frame)


## Icône d'une pièce : son calque de repos recadré sur ses pixels.
static func icon(piece: String) -> AtlasTexture:
	load_all()
	if not frames.has(piece):
		return null
	if not _icon_rect.has(piece):
		var first: AtlasTexture = frames[piece]["idle"][0]
		var img := first.atlas.get_image().get_region(Rect2i(first.region))
		var used := img.get_used_rect()
		var a := AtlasTexture.new()
		a.atlas = first.atlas
		a.region = Rect2(first.region.position + Vector2(used.position), Vector2(used.size))
		_icon_rect[piece] = a
	return _icon_rect[piece]
