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
const MAX_LIGHTS := 64

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
		if not SanctumArt.has(e["k"]) and not e.has("anim") and not e.has("torch"):
			continue
		var c := Vector2i(floori(float(e["x"]) / CHUNK), floori(float(e["z"]) / CHUNK))
		if not _props.has(c):
			_props[c] = []
		_props[c].append(e)
	_rooms = layout["rooms"]
	for room: Dictionary in _rooms:
		if room["kind"] in ["cistern", "vcistern", "ftrempe"]:
			var pool := CisternView.new()
			pool.name = "Cistern"
			pool.trempe = room["kind"] == "ftrempe"
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
	if e.has("torch"):
		var tv := TorchView.new()
		tv.side = e["torch"]
		tv.seed = float(e["x"]) * 1.3 + float(e["z"]) * 0.7
		s.add_child(tv)
		world.ysort.add_child(s)
		return s
	_skin(s, e, e["k"])
	var dy := Vector2(0.0, e.get("dy", 0))
	# Monastère : cierges des candélabres et lampes des niches (décalages depuis l'ancre, en pixels).
	for o: Vector2 in e.get("flames", []):
		var cf := FlameView.new()
		cf.candle = true
		cf.seed = float(e["x"]) * 1.3 + o.x
		cf.position = o + dy
		s.add_child(cf)
	# Forges mortes : effets animés de la pièce (assets/forges/fx.json), décalés comme le sprite.
	var k0: String = e["k"]
	for fx: Dictionary in SanctumArt.fx(k0):
		var m: String = fx["m"]
		if m == "flame":
			var lf := FlameView.new()
			lf.candle = true
			lf.seed = float(e["x"]) * 1.3 + float(fx["o"][0])
			var fo := Vector2(fx["o"][0], fx["o"][1])
			if s.flip_h:
				fo.x = -fo.x
			lf.position = fo + dy
			s.add_child(lf)
			continue
		var fa := PropAnim.new()
		fa.mode = m
		fa.seed = float(e["x"]) * 0.7 + float(e["z"]) * 0.3
		if fx.has("o"):
			fa.at = Vector2(fx["o"][0], fx["o"][1]) + dy
		if fx.has("p"):
			fa.pivot = Vector2(fx["p"][0], fx["p"][1]) + dy
		fa.count = int(fx.get("n", 3))
		fa.spread = float(fx.get("s", 6.0))
		fa.rise = float(fx.get("r", 14.0))
		fa.data = fx
		s.add_child(fa)
		if (m == "glow" or m == "flow") and SanctumArt.has(k0 + "_glow"):
			fa.set_glow(SanctumArt.texture(k0 + "_glow"), -SanctumArt.anchor(k0 + "_glow", s.flip_h) + dy, s.flip_h)
	if e.has("anim"):
		var a := PropAnim.new()
		a.mode = e["anim"]
		a.seed = float(e["x"]) * 0.7 + float(e["z"]) * 0.3
		a.position = dy if a.mode == "censer" else Vector2.ZERO
		s.add_child(a)
	if e.has("brazier") or e.has("flame"):
		var f := FlameView.new()
		f.candle = e.has("flame")
		f.seed = float(e["x"]) * 1.7 + float(e["z"])
		# Temple en salles : la flamme prend la couleur de son quartier une fois ses repères allumés.
		var st: TerrainState = world.terrain_state
		if st != null and not st.temple_layout.is_empty():
			var q := QuarterMarks.quarter_at(st, Vector2(float(e["x"]), float(e["z"])))
			f.quarter = q if q in ["A", "B", "C", "VA", "VB", "VC"] else ""
		if e.has("brazier"):
			var i: int = e["brazier"]
			f.burning = func() -> bool: return Sanctum.lit(world.terrain_state, i)
		s.add_child(f)
	(ground if e.get("ground", false) else world.ysort).add_child(s)
	return s


func _skin(s: Sprite2D, e: Dictionary, k: String) -> void:
	if not SanctumArt.has(k):
		return
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
	# Trophées des arènes (B4) : posés seulement une fois le boss de la salle tombé.
	if e.has("trophy"):
		s.visible = s.visible and Sanctum.boss_down(st, e["trophy"])
	if not s.visible:
		return
	var k: String = e["k"]
	if e.has("brazier") and Sanctum.lit(st, e["brazier"]):
		k = "brazier_lit"
	elif e.get("role", "") == "chest" and Sanctum.done(st, e["room"]):
		k = "chest_open"
	elif e.get("role", "") == "stand" and Sanctum.done(st, e["room"]):
		k = "stand_empty"
	elif e.get("role", "") == "pump" and Sanctum.pump_held(st, e["room"]):
		k = "o_pump_held"
	elif e.get("role", "") == "ingots" and Sanctum.done(st, e["room"]):
		k = "o_ingots_s"
	elif e.has("done_k") and Sanctum.done(st, e["room"]):
		k = e["done_k"]
	elif e.get("role", "") == "chain" and Sanctum.chain_free(st, e["room"], e["chain"]):
		k = "f_unchained"
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
			if e.has("torch"):
				# Halo doux (H1) : dégradé continu, pas les paliers tramés des autres lueurs.
				out.append({"x": x + (0.2 if e["torch"] == "n" else 0.0), "z": z + (0.4 if e["torch"] == "n" else -0.2),
					"r": TorchView.LIGHT_R * Lighting.flick(t, x + z, 0.05), "rgb": TorchView.LIGHT, "glow": TorchView.GLOW, "soft": true})
			elif e.has("brazier"):
				if Sanctum.lit(st, e["brazier"]):
					out.append({"x": x, "z": z - 0.8, "r": 9.0 * Lighting.flick(t, x, 0.07), "rgb": Lighting.WARM, "glow": 0.18})
			elif e.has("light"):
				var l: Dictionary = e["light"]
				if e.has("trophy") and not Sanctum.boss_down(st, e["trophy"]):
					continue
				var k := 0.5 + 0.5 * sin(t * 1.4 + x * 0.3)
				var glow: float = l["glow"]
				var role: String = e.get("role", "")
				if (role == "lectern" or role == "chest" or role == "ingots") and Sanctum.done(st, e["room"]):
					glow *= 0.35
				elif role == "basin" and not Sanctum.ready(st, e["room"]):
					glow *= 0.3
				# Fanaux de Byrsa (Salles oubliées) : halo doux, comme les torches du Temple.
				if l.get("soft", false):
					out.append({"x": x, "z": z + 0.4, "r": float(l["r"]) * Lighting.flick(t, x + z, 0.05), "rgb": l["rgb"], "glow": glow, "soft": true})
					continue
				# « dz » : lumière décalée du pied (fissures des Forges, qui montent sur toute la paroi).
				out.append({"x": x, "z": z + float(l.get("dz", -0.5)), "r": float(l["r"]) * (0.92 + 0.08 * k), "rgb": l["rgb"], "glow": glow * (0.85 + 0.15 * k)})
	return out
