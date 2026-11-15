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
var _regions := {}
var _atlas_tex := {}
var _count := 0


func _init() -> void:
	_sprites = read_json(BAKED + "decor_sprites.json")
	for id: String in _sprites:
		_sprites[id]["path"] = BAKED + "sprites/%s.png" % id
	var runtime: Dictionary = read_json("res://assets/baked/manifest.json")["world"]["runtime_decor"]
	for f: Dictionary in runtime["faces"]:
		_sprites["face5_%d" % f["v"]] = {"ax": f["ax"], "ay": f["ay"], "path": BAKED + "runtime/face5_%d.png" % f["v"]}
	for s: Dictionary in runtime["spires"]:
		_sprites["gallery_spire_%d" % s["v"]] = {"ax": s["ax"], "ay": s["ay"], "path": BAKED + "runtime/gallery_spire_%d.png" % s["v"]}
	_atlas = load(BAKED + "decor_atlas.png")
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
		var e := p.duplicate()
		e["node"] = make_node(e)
		registry.add_raw(e)


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
	var spr := _sprite(e["s"])
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


func _sprite(id: String) -> Sprite2D:
	var info: Dictionary = _sprites[id]
	var s := Sprite2D.new()
	s.texture = _atlas_texture(id) if _regions.has(id) else texture(info["path"])
	s.centered = false
	s.offset = -Vector2(info["ax"], info["ay"])
	s.use_parent_material = true
	return s


## Région de la planche commune pour un sprite (une AtlasTexture partagée par identifiant).
func _atlas_texture(id: String) -> AtlasTexture:
	if not _atlas_tex.has(id):
		var r: Array = _regions[id]
		var a := AtlasTexture.new()
		a.atlas = _atlas
		a.region = Rect2(r[0], r[1], r[2], r[3])
		_atlas_tex[id] = a
	return _atlas_tex[id]
