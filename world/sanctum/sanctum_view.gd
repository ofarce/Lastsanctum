class_name SanctumView
extends Node
## Affichage du décor du Temple (SanctumLayout) : un Sprite2D par objet, créé et libéré par chunk autour de la
## caméra comme le décor généré. Les objets debout vont dans le tri en Y du monde, les objets à plat (dalles,
## mousse, flaques, estrades) dans `ground`, sous les unités. Un objet n'apparaît que dans une galerie ouverte ;
## dans la grotte de départ, il s'efface sous un bâtiment. Fournit aussi les lumières (quartz, braseros, salles).

const CHUNK := 32
## Marge de chunks créés autour de l'écran, et marge gardée avant de libérer.
const MARGIN := 1
const KEEP := 2
const REFRESH := 0.25
const MAX_LIGHTS := 40

var world: World
var ground := Node2D.new()
var _props := {}
var _rooms: Array = []
var _live := {}
var _view := Rect2i(0, 0, -1, -1)
var _since := 0.0


func _ready() -> void:
	ground.name = "SanctumGround"
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## À chaque nouvelle carte, après la génération des galeries (les nœuds du tri en Y sont déjà libérés).
func reset() -> void:
	for child in ground.get_children():
		child.free()
	_live.clear()
	_props.clear()
	_view = Rect2i(0, 0, -1, -1)
	var st := world.terrain_state
	var layout: Dictionary = Sanctum.data(st)["layout"]
	for e: Dictionary in layout["props"]:
		if not SanctumArt.has(e["k"]):
			continue
		var c := Vector2i(floori(float(e["x"]) / CHUNK), floori(float(e["z"]) / CHUNK))
		if not _props.has(c):
			_props[c] = []
		_props[c].append(e)
	_rooms = layout["rooms"]
	for room: Dictionary in _rooms:
		if room["kind"] == "cistern":
			var pool := CisternView.new()
			pool.name = "Cistern"
			pool.setup(st, room)
			ground.add_child(pool)


func _process(delta: float) -> void:
	if world == null or world.terrain_state == null:
		return
	var view := world._decor_view().grow(MARGIN - World.DECOR_MARGIN)
	if view != _view:
		_view = view
		_stream(view)
	_since += delta
	if _since >= REFRESH:
		_since = 0.0
		_refresh()


func _stream(view: Rect2i) -> void:
	var keep := view.grow(KEEP - MARGIN)
	for c: Vector2i in _live.keys():
		if keep.has_point(c):
			continue
		for item: Dictionary in _live[c]:
			var node: Node = item["node"]
			if is_instance_valid(node):
				node.queue_free()
		_live.erase(c)
	for cz in range(view.position.y, view.end.y):
		for cx in range(view.position.x, view.end.x):
			var c := Vector2i(cx, cz)
			if _live.has(c) or not _props.has(c):
				continue
			var items: Array = []
			for e: Dictionary in _props[c]:
				items.append({"e": e, "node": _make(e), "k": e["k"]})
			_live[c] = items
			for item: Dictionary in items:
				_update(item)


func _make(e: Dictionary) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.flip_h = e.get("flip", false)
	s.position = Vector2(roundf(float(e["x"]) * Proj.K), roundf(float(e["z"]) * Proj.K))
	s.modulate.a = e.get("alpha", 1.0)
	s.visible = false
	_skin(s, e, e["k"])
	if e.has("brazier") or e.has("flame"):
		var f := FlameView.new()
		f.candle = e.has("flame")
		f.seed = float(e["x"]) * 1.7 + float(e["z"])
		if e.has("brazier"):
			var i: int = e["brazier"]
			f.burning = func() -> bool: return Sanctum.lit(world.terrain_state, i)
		s.add_child(f)
	(ground if e.get("ground", false) else world.ysort).add_child(s)
	return s


func _skin(s: Sprite2D, e: Dictionary, k: String) -> void:
	s.texture = SanctumArt.texture(k)
	s.offset = -SanctumArt.anchor(k, s.flip_h) + Vector2(0.0, e.get("dy", 0))


## Visibilité et état d'un objet vivant (coffre ouvert, support vidé, brasero allumé).
func _update(item: Dictionary) -> void:
	var s: Sprite2D = item["node"]
	if not is_instance_valid(s):
		return
	var e: Dictionary = item["e"]
	var st := world.terrain_state
	var x: float = e["x"]
	var z: float = e["z"]
	if e.get("start", false):
		var show := true
		for b in GameState.buildings:
			if absf(b.x - x) < 5.0 and absf(b.z - z) < 5.0:
				show = false
				break
		s.visible = show
	else:
		s.visible = st.is_gallery_open(x, z) or st.is_gallery_open(x, z + 1.0)
	if not s.visible:
		return
	var k: String = e["k"]
	if e.has("brazier") and Sanctum.lit(st, e["brazier"]):
		k = "brazier_lit"
	elif e.get("role", "") == "chest" and Sanctum.done(st, e["room"]):
		k = "chest_open"
	elif e.get("role", "") == "stand" and Sanctum.done(st, e["room"]):
		k = "stand_empty"
	if k != item["k"]:
		item["k"] = k
		_skin(s, e, k)


func _refresh() -> void:
	for c: Vector2i in _live:
		for item: Dictionary in _live[c]:
			_update(item)


## Lumières des objets visibles : quartz, champignons, lampes des salles, braseros allumés.
func lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null:
		return out
	var st := world.terrain_state
	var t := GameState.sim_time
	for c: Vector2i in _live:
		for item: Dictionary in _live[c]:
			var s: Sprite2D = item["node"]
			if out.size() >= MAX_LIGHTS or not is_instance_valid(s) or not s.visible:
				continue
			var e: Dictionary = item["e"]
			var x: float = e["x"]
			var z: float = e["z"]
			if e.has("brazier"):
				if Sanctum.lit(st, e["brazier"]):
					out.append({"x": x, "z": z - 0.8, "r": 9.0 * Lighting.flick(t, x, 0.07), "rgb": Lighting.WARM, "glow": 0.18})
			elif e.has("light"):
				var l: Dictionary = e["light"]
				var k := 0.5 + 0.5 * sin(t * 1.4 + x * 0.3)
				var glow: float = l["glow"]
				var role: String = e.get("role", "")
				if (role == "lectern" or role == "chest") and Sanctum.done(st, e["room"]):
					glow *= 0.35
				elif role == "basin" and not Sanctum.ready(st, e["room"]):
					glow *= 0.3
				out.append({"x": x, "z": z - 0.5, "r": float(l["r"]) * (0.92 + 0.08 * k), "rgb": l["rgb"], "glow": glow * (0.85 + 0.15 * k)})
	return out
