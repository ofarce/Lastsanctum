class_name SanctumArt
## Sprites du décor du Temple, lus dans deux atlas exportés des planches :
## - galeries et salles à thème : python3 tools/sanctum/export.py → assets/sanctum/props.png + props.json ;
## - monastère (couloirs C1–C6, arènes B1–B4) : python3 tools/salles-decor/export.py → assets/monastere/ ;
## - Salles oubliées (V1–V6, L1, R1, R3, A1–A4) : python3 tools/salles-oubliees/export.py → assets/oubliees/, avec
##   calques de lueur et effets animés (fx.json), comme les Forges ;
## - Forges mortes (F1–F6, L2, R1, R3, R4, A1–A4) : python3 tools/forges-decor/export.py → assets/forges/, avec
##   les calques de lueur (« <nom>_glow ») et les effets animés par pièce (fx.json, lus par PropAnim).
## JSON : nom → [x, y, w, h, ax, ay] (ancre relative au rectangle). Un nom n'existe que dans un des atlas.

const SOURCES := [
	["res://assets/sanctum/props.png", "res://assets/sanctum/props.json"],
	["res://assets/monastere/props.png", "res://assets/monastere/props.json"],
	["res://assets/oubliees/props.png", "res://assets/oubliees/props.json"],
	["res://assets/forges/props.png", "res://assets/forges/props.json"],
]
const FX_FILES := ["res://assets/oubliees/fx.json", "res://assets/forges/fx.json"]

static var _index := {}
static var _atlas_of := {}
static var _loaded := false
static var _cache := {}
static var _fx := {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for src: Array in SOURCES:
		# Lu sur disque : l'atlas n'a pas besoin d'être réimporté par l'éditeur après un nouvel export.
		var path: String = src[0]
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null and ResourceLoader.exists(path):
			img = (load(path) as Texture2D).get_image()
		if img == null or not FileAccess.file_exists(src[1]):
			continue
		var tex := ImageTexture.create_from_image(img)
		var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src[1]))
		for k: String in idx:
			_index[k] = idx[k]
			_atlas_of[k] = tex
	for path: String in FX_FILES:
		if FileAccess.file_exists(path):
			var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			_fx.merge(fx)


static func has(k: String) -> bool:
	_load()
	return _index.has(k)


static func texture(k: String) -> AtlasTexture:
	_load()
	if not _cache.has(k):
		var e: Array = _index[k]
		var t := AtlasTexture.new()
		t.atlas = _atlas_of[k]
		t.region = Rect2(e[0], e[1], e[2], e[3])
		_cache[k] = t
	return _cache[k]


## Ancre du sprite (pixels depuis son coin haut gauche) ; `flip` : sprite retourné horizontalement.
static func anchor(k: String, flip := false) -> Vector2:
	_load()
	var e: Array = _index[k]
	return Vector2(float(e[2]) - 1.0 - float(e[4]) if flip else float(e[4]), e[5])


## Effets animés d'une pièce (assets/forges/fx.json) : [{m: glow|flow|embers|steam|swing|flame, o, p, s, r, n}].
static func fx(k: String) -> Array:
	_load()
	return _fx.get(k, [])
