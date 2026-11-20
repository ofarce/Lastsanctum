class_name SanctumArt
## Sprites du décor du Temple : atlas exporté de la planche (python3 tools/sanctum/export.py →
## assets/sanctum/props.png + props.json). JSON : nom → [x, y, w, h, ax, ay] (ancre relative au rectangle).

const ATLAS := "res://assets/sanctum/props.png"
const INDEX := "res://assets/sanctum/props.json"

static var _index := {}
static var _atlas: Texture2D
static var _cache := {}


static func _load() -> void:
	if _atlas != null:
		return
	# Lu sur disque : l'atlas n'a pas besoin d'être réimporté par l'éditeur après un nouvel export.
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	if img == null and ResourceLoader.exists(ATLAS):
		img = (load(ATLAS) as Texture2D).get_image()
	_atlas = ImageTexture.create_from_image(img)
	_index = JSON.parse_string(FileAccess.get_file_as_string(INDEX))


static func has(k: String) -> bool:
	_load()
	return _index.has(k)


static func texture(k: String) -> AtlasTexture:
	_load()
	if not _cache.has(k):
		var e: Array = _index[k]
		var t := AtlasTexture.new()
		t.atlas = _atlas
		t.region = Rect2(e[0], e[1], e[2], e[3])
		_cache[k] = t
	return _cache[k]


## Ancre du sprite (pixels depuis son coin haut gauche) ; `flip` : sprite retourné horizontalement.
static func anchor(k: String, flip := false) -> Vector2:
	_load()
	var e: Array = _index[k]
	return Vector2(float(e[2]) - 1.0 - float(e[4]) if flip else float(e[4]), e[5])
