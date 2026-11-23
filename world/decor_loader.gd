class_name DecorLoader
extends RefCounted
## Construit le décor à partir des fichiers du baker (res://assets/baked/world/, 73b410f) et crée les nœuds
## des objets ajoutés en cours de partie (faces de falaise, stalagmites des galeries, portails maléfiques).
## Les positions sont en pixels natifs, sous le nœud World mis à l'échelle ×PX.
##
## Tri de profondeur : le prototype trie par d (dz de l'objet, sinon z). L'ordonnée native d'un point
## au sol vaut 8·z, donc le tri par Y de Godot reproduit cet ordre si le nœud trié est placé à y = 8·d.
## Quand le point de dessin diffère (faces de falaise, autel, orbe, stalagmites des galeries dont d = x + z),
## un nœud porteur à y = 8·d contient le sprite décalé.

const BAKED := "res://assets/baked/world/"
const ORB_SHADER := preload("res://shaders/orb.gdshader")

## Fournit la modulation qui signale un feuillage (type d'arbre, ancre verticale ay) au shader des objets
## triés (world_sprite.gdshader).
var foliage_material: Callable
## Nœud trié par Y qui reçoit le décor.
var parent: Node2D
## Nœuds remarquables : orb, orb_holder, portal, deity_portals[id], deity_fx[id], evil (liste).
var special := {"deity_portals": {}, "deity_fx": {}, "evil": []}
var _textures := {}
var _sprites := {}
## Planche commune du décor (tools/baker/decor_atlas.py) : une texture pour tous les sprites.
var _atlas: Texture2D
## Planches du décor par palier de roche (mêmes régions ; 0 = Temple) et leurs AtlasTexture.
var _atlases: Array[Texture2D] = []
var _atlas_tex_tier: Array[Dictionary] = []
var _regions := {}
var _atlas_tex := {}
var _count := 0


func _init() -> void:
	_sprites = read_json(BAKED + "decor_sprites.json")
	for id: String in _sprites:
		_sprites[id]["path"] = BAKED + "sprites/%s.png" % id
	var runtime: Dictionary = read_json("res://assets/baked/manifest.json")["world"]["runtime_decor"]
	for f: Dictionary in runtime["faces"]:
		_sprites["face5_%d" % f["v"]] = {"ax": f["ax"], "ay": f["ay"], "path": ArtStyle.RUNTIME + "face5_%d.png" % f["v"]}
		# Même paroi dans la roche de chaque palier (TerrainOps.face_id).
		for t in range(1, Biomes.ROCKS.size()):
			var sfx := Biomes.sprite_suffix(t)
			_sprites["face5_%d%s" % [f["v"], sfx]] = {"ax": f["ax"], "ay": f["ay"], "path": ArtStyle.RUNTIME + "face5_%d%s.png" % [f["v"], sfx]}
	for s: Dictionary in runtime["spires"]:
		_sprites["gallery_spire_%d" % s["v"]] = {"ax": s["ax"], "ay": s["ay"], "path": ArtStyle.RUNTIME + "gallery_spire_%d.png" % s["v"]}
	_atlas = load(ArtStyle.ATLAS)
	for t in Biomes.ROCKS.size():
		_atlases.append(_atlas if t == 0 else load(ArtStyle.ROOT + "decor_atlas%s.png" % Biomes.sprite_suffix(t)))
		_atlas_tex_tier.append(_atlas_tex if t == 0 else {})
	_regions = read_json(BAKED + "decor_atlas.json")["sprites"]


static func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


## Décor initial : remplit `registry` (dans l'ordre du prototype) et crée les nœuds sous `parent`.
func build_decor(registry: DecorRegistry) -> void:
	var placements: Array = read_json(BAKED + "decor_placements.json")["placements"]
	for p: Dictionary in placements:
		if _retired(p):
			continue
		var e := p.duplicate()
		e["node"] = make_node(e)
		registry.add_raw(e)


## Anciens portails retirés du jeu : portail central des Exilés (la capsule le remplace), portails des
## quatre dieux, leurs effets et les piliers sculptés qui les encadrent ; autel de pierre de l'Ancre (le puits
## d'AnchorView le remplace).
static func _retired(p: Dictionary) -> bool:
	return p.has("portal") or p.has("dportal") or p.has("deity_fx") or String(p.get("s", "")).begins_with("deity_deco") \
		or p.get("s", "") == "altar_01"


## Crée et ajoute le nœud d'une entrée du décor ; renvoie ce nœud.
func make_node(e: Dictionary) -> Node2D:
	_count += 1
	var d: float = e["d"]
	var x: float = e["x"]
	var z: float = e["z"]
	if e.has("portal") or e.has("dportal") or e.has("deity_fx") or e.has("evil"):
		var slot := Node2D.new()
		slot.position = Vector2(Proj.nat(x, 0, z).x, 8.0 * d)
		slot.set_meta("world", Vector2(x, z))
		parent.add_child(slot)
		if e.has("portal"):
			slot.name = "PortalSlot"
			special["portal"] = slot
		elif e.has("dportal"):
			slot.name = "DeityPortal_" + e["dportal"]
			special["deity_portals"][e["dportal"]] = slot
		elif e.has("deity_fx"):
			slot.name = "DeityFx_" + e["deity_fx"]
			special["deity_fx"][e["deity_fx"]] = slot
		else:
			slot.name = "EvilPortal_%d" % e["evil"]["id"]
			special["evil"].append(slot)
		return slot
	var orb: bool = e.get("orb", false)
	var spr := _sprite(e["s"], Biomes.rock_tier(z) if rocky(e["s"]) else 0)
	var draw_at := Proj.nat(e["bx"], 0, e["bz"]) if e.has("bx") else Proj.nat(x, 0, z)
	if orb:
		# Position continue (non arrondie) : pas de shader d'alignement ; orbe éteinte au départ.
		draw_at = Proj.nat(x, 2.6, z)
		var m := ShaderMaterial.new()
		m.shader = ORB_SHADER
		spr.use_parent_material = false
		spr.material = m
		special["orb"] = spr
	if e.has("wind"):
		var fid: String = _sprites[e["s"]]["foliage"]
		var leaves := _sprite(fid)
		leaves.self_modulate = foliage_material.call(e["wind"], float(_sprites[fid]["ay"]))
		spr.add_child(leaves)
	if not e.has("bx") and not orb and absf(d - z) < 1e-6:
		spr.position = draw_at
		parent.add_child(spr)
		return spr
	var holder := Node2D.new()
	holder.name = "%s_%d" % [e["s"], _count]
	holder.position = Vector2(draw_at.x, 8.0 * d)
	holder.use_parent_material = true
	spr.position = Vector2(0.0, draw_at.y - 8.0 * d)
	holder.add_child(spr)
	parent.add_child(holder)
	if orb:
		special["orb_holder"] = holder
	return holder


## Sprites de roche (les mêmes que is_rocky de tools/ardoise/ardoise.py, parois à part : elles ont leur
## identifiant « _r2 ») : au nord du Temple ils prennent les teintes de la roche de vert-de-gris.
static func rocky(id: String) -> bool:
	return id.get_slice("_", 0) in ["rock", "mountain", "spire", "crystal"] or id.begins_with("gallery_spire")


func _sprite(id: String, tier := 0) -> Sprite2D:
	var info: Dictionary = _sprites[id]
	var s := Sprite2D.new()
	if _regions.has(id):
		s.texture = _atlas_texture(id, tier)
	else:
		s.texture = texture(String(info["path"]).replace(".png", Biomes.sprite_suffix(tier) + ".png") if tier > 0 else info["path"])
	s.centered = false
	s.offset = -Vector2(info["ax"], info["ay"])
	s.use_parent_material = true
	return s


## Région de la planche commune pour un sprite (une AtlasTexture partagée par identifiant).
func _atlas_texture(id: String, tier := 0) -> AtlasTexture:
	tier = clampi(tier, 0, _atlases.size() - 1)
	var cache: Dictionary = _atlas_tex_tier[tier]
	if not cache.has(id):
		var r: Array = _regions[id]
		var a := AtlasTexture.new()
		a.atlas = _atlases[tier]
		a.region = Rect2(r[0], r[1], r[2], r[3])
		cache[id] = a
	return cache[id]
