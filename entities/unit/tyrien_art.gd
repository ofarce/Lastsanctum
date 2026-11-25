class_name TyrienArt
extends RefCounted
## Ingénieur sans armure, tenue « Le Tyrien » (planche planches/tyrien-equipement.html) : un corps (« base »)
## et un calque par pièce d'équipement visible, pour chaque animation. Chaque calque ne contient que les pixels
## que la pièce change, corps en place : on empile la base puis les pièces portées dans l'ordre `order`.
## Planches générées par planches/tyrien-export.html (tools/tyrien/serve.py) depuis planches/assets/engineer-volume.js.
## Corps actuel : le « Templier technomancien » à mains nues (BODY_DIR, planches/ingenieur-exil-propositions.html piste B,
## exporté par tools/ingenieur/export.py) remplace la base tyrienne, au même gabarit. Sa tenue tient lieu d'armure : les
## calques d'équipement restent chargés (icônes, emplacements) mais ne sont plus empilés (« overlays »: false).
## Avant la combinaison (remise par la capsule, GameState.capsule_gift) : corps « exil » (EXIL_DIR, torse nu en chausses
## déchirées, planches/ingenieur-pantalon-dechire-propositions.html piste A, tools/ingenieur/export.py exil), même
## gabarit et mêmes animations ; les rangées Arbalestrie (c_*) et le casque restent ceux du Templier.
## Dessin et animations des deux corps : planches/assets/engineer-maj.js (membres articulés, « hit » = touché).

const DIR := "res://assets/imported/engineer/tyrien/"
const BODY_DIR := "res://assets/imported/engineer/templier/"
const PORTRAIT := BODY_DIR + "templier_portrait.png"
const EXIL_DIR := "res://assets/imported/engineer/exil/"
const EXIL_PORTRAIT := EXIL_DIR + "exil_portrait.png"
const ANIMS := ["idle", "walk", "kneel", "pray", "settle", "lotus", "aim", "slash1", "slash2", "shoot", "idle_d", "walk_d", "idle_u", "walk_u", "shoot_d", "shoot_u", "hit", "c_idle", "c_walk", "c_shoot", "c_idle_d", "c_walk_d", "c_idle_u", "c_walk_u", "c_shoot_d", "c_shoot_u", "idle_dr", "walk_dr", "idle_ur", "walk_ur", "c_idle_dr", "c_walk_dr", "c_idle_ur", "c_walk_ur", "shoot_dr", "shoot_ur", "c_shoot_dr", "c_shoot_ur", "fall", "helm", "helm_d", "helm_u", "helm_dr", "helm_ur"]

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
	# Gabarit, animations et visée du corps actuel ; pièces, emplacements et ordre restent ceux du Tyrien.
	var body: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BODY_DIR + "templier.json"))
	for key: String in body:
		meta[key] = body[key]
	var layers: Array = ["base"]
	layers.append_array((meta["pieces"] as Dictionary).keys())
	for layer: String in layers:
		var tex: Texture2D = load(BODY_DIR + "templier_base.png") if layer == "base" else load(DIR + "tyrien_%s.png" % layer)
		var by_anim := {}
		for anim: String in ANIMS:
			by_anim[anim] = _sheet(tex, meta["anims"][anim])
		frames[layer] = by_anim
	if ResourceLoader.exists(EXIL_DIR + "exil_base.png"):
		var tex_exil: Texture2D = load(EXIL_DIR + "exil_base.png")
		var by_anim := {}
		for anim: String in ANIMS:
			by_anim[anim] = _sheet(tex_exil, meta["anims"][anim])
		frames["exil"] = by_anim
		for anim: String in ANIMS:
			var list: Array = by_anim[anim]
			for i in list.size():
				_index[list[i]] = [anim, i]
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


## Ingénieur encore sans combinaison (avant la capsule) : corps « exil ».
static func ragged() -> bool:
	return not GameState.capsule_gift


## Calque du corps pour l'animation `name` : « exil » avant la combinaison, sauf Arbalestrie et casque.
static func _body_layer(name: String) -> String:
	if ragged() and frames.has("exil") and not name.begins_with("c_") and not name.begins_with("helm"):
		return "exil"
	return "base"


static func portrait() -> String:
	return EXIL_PORTRAIT if ragged() and ResourceLoader.exists(EXIL_PORTRAIT) else PORTRAIT


static func anim(name: String) -> Array[AtlasTexture]:
	load_all()
	return frames[_body_layer(name)][name]


## Animation d'un corps donné (exil = avant la combinaison), sans regarder l'état de la partie.
static func anim_of(name: String, exil: bool) -> Array[AtlasTexture]:
	load_all()
	return frames["exil" if exil and frames.has("exil") and not name.begins_with("c_") and not name.begins_with("helm") else "base"][name]


static func fps(name: String) -> float:
	load_all()
	return float(meta["anims"][name].get("fps", 10.0))


## Image de visée de la base : rangée (recul 0 / 1,5 / 3, suspension) et colonne d'angle.
static func aim_frame(row: int, col: int) -> AtlasTexture:
	load_all()
	return frames[_body_layer("aim")]["aim"][row * int(meta["anims"]["aim"]["cols"]) + col]


## Pièce d'équipement → emplacement de l'inventaire (« Tête », « Torse »…).
static func slot_of(piece: String) -> String:
	load_all()
	return meta["slots"][meta["pieces"][piece]["slot"]]


## Calques à empiler sur l'image `base_frame` pour les pièces portées (emplacement → pièce),
## dans l'ordre d'empilement. Vide si l'image n'est pas une image du Tyrien.
static func overlays(base_frame: Texture2D, pieces: Dictionary) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if pieces.is_empty() or not _index.has(base_frame) or not bool(meta.get("overlays", true)):
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


## Icône 32 × 32 d'une arme du Creuset (planches/assets/armes-creuset.js), ou null.
static var _weapon_icons: Dictionary = {}
static func weapon_icon(item: String) -> AtlasTexture:
	load_all()
	var order: Array = meta.get("weapon_icons", [])
	var i := order.find(item)
	if i < 0:
		return null
	if not _weapon_icons.has(item):
		var a := AtlasTexture.new()
		a.atlas = load(DIR + "tyrien_weaponicons.png")
		a.region = Rect2(i * 32, 0, 32, 32)
		_weapon_icons[item] = a
	return _weapon_icons[item]
