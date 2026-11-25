class_name MiniBoss2Art
extends RefCounted
## Atlas des mini-boss des Salles oubliées (assets/imported/miniboss2/, tools/miniboss2/export.py) : une bande par
## animation, cadres côte à côte, pied en (ax, ay). meta.json : {eclusier, patine, pump : {frame_w, frame_h, ax, ay,
## anims : {nom : {count, fps, loop}}}}.

const DIR := "res://assets/imported/miniboss2/"

static var _meta: Dictionary
static var _tex := {}


static func meta(who: String) -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "meta.json"))
	return _meta[who]


static func tex(who: String, anim: String) -> Texture2D:
	var key := anim if who == "pump" else who + "_" + anim
	if not _tex.has(key):
		_tex[key] = load(DIR + key + ".png")
	return _tex[key]


## Image de l'animation `anim` à `t` secondes de son début (bouclée, ou arrêtée sur la dernière).
static func frame(who: String, anim: String, t: float) -> int:
	var a: Dictionary = meta(who)["anims"][anim]
	var n := int(a["count"])
	var f := floori(maxf(0.0, t) * float(a["fps"]))
	return f % n if a["loop"] else mini(f, n - 1)


## Dessine l'image f de `anim`, pied en `at` (pixels natifs), retournée si flip.
static func draw(ci: CanvasItem, who: String, anim: String, f: int, at: Vector2, flip: bool, tint := Color.WHITE) -> void:
	var m := meta(who)
	var fw := float(m["frame_w"])
	var fh := float(m["frame_h"])
	ci.draw_set_transform(at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect_region(tex(who, anim), Rect2(-float(m["ax"]), -float(m["ay"]), fw, fh), Rect2(f * fw, 0.0, fw, fh), tint)
	ci.draw_set_transform(Vector2.ZERO)
