class_name World
extends Node2D
## Monde vu de dessus en 3/4 (MIGRATION_PLAN.md v2, §4.2).
##
## Le monde est dessiné à la résolution écran, dans ce nœud mis à l'échelle ×PX : l'espace local est en
## pixels natifs. Chaque sprite pixel art est aligné sur la grille native par le shader pixel_snap
## (équivalent de natP), tandis que le feuillage reste lissé et cisaillé par le vent, comme dans le prototype.

const SNAP_SHADER := preload("res://shaders/pixel_snap.gdshader")
## Matériau unique des objets triés (étape 12) : alignement natif et feuillage au vent dans un seul shader.
const SPRITE_SHADER := preload("res://shaders/world_sprite.gdshader")

## 0 fige le vent (captures de validation).
var wind_scale := 1.0
## Graine des galeries (décision D12) : tirée au hasard à chaque partie, affichée, réutilisable.
var gallery_seed := 0

## Terrain dynamique (étape 3) : galeries, cases creusées, praticabilité ; décor ; opérations.
var terrain_state := TerrainState.new()
var decor := DecorRegistry.new()
var terrain_ops: TerrainOps
var pathfinder := Pathfinder.new(terrain_state)
var _loader: DecorLoader

## Décalage caméra en pixels natifs (Proj.camera_offset) : position native à l'écran = nat + native_offset.
var native_offset := Vector2.ZERO
## Points alignés sur la grille native de l'écran (portails), replacés à chaque changement de vue.
var _anchors: Array[ScreenAnchor] = []
var _portal_meta := {}
## Éclairage (étape 4) : créé après le décor, donc dessiné par-dessus.
var lighting: Lighting
## Simulation (étape 5) : fournit les unités à dessiner.
var simulation: Simulation
var _unit_views := {}
var _unit_meta := {}
var _building_views := {}
var _enemy_views := {}
var _enemy_meta := {}
var _turret_views := {}
## Surimpression à la résolution de l'écran (libellés, incantation, mode construction), sous l'éclairage.
var overlay: WorldOverlay
## Étincelle de réactivation de l'Ancre (caméra qui la suit, halo), dans la surimpression.
var anchor_spark: AnchorSpark
## Surcharge de l'Ancre après l'armement des balistes (colonne, nova, bouclier, pièces d'armure).
var anchor_overload: AnchorOverload
## Emprises au sol des bâtiments (drawBuildGrid), sous le décor.
var build_grid: BuildGrid

var _snap := ShaderMaterial.new()
var _sprites_mat := ShaderMaterial.new()
var _special := {}

@onready var camera: WorldCamera = $Camera
@onready var terrain: Terrain = $Terrain
@onready var ysort: Node2D = $YSort


func _ready() -> void:
	# Pixel art net quel que soit le viewport (un SubViewport filtre en linéaire par défaut) ;
	# le feuillage est lissé dans le shader (world_sprite.gdshader).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_snap.shader = SNAP_SHADER
	terrain.material = _snap
	_sprites_mat.shader = SPRITE_SHADER
	var kinds := PackedVector2Array()
	for k: String in Wind.TREES:
		kinds.append(Vector2(Wind.TREES[k]["amplitude"], Wind.TREES[k]["height"]))
	_sprites_mat.set_shader_parameter("kinds", kinds)
	_sprites_mat.set_shader_parameter("meta", load("res://assets/baked/world/decor_atlas_meta.png"))
	ysort.material = _sprites_mat
	camera.view_changed.connect(apply_view)
	build_grid = BuildGrid.new()
	build_grid.name = "BuildGrid"
	build_grid.world = self
	add_child(build_grid)
	move_child(build_grid, ysort.get_index())
	overlay = WorldOverlay.new()
	overlay.name = "Overlay"
	overlay.world = self
	add_child(overlay)
	anchor_spark = AnchorSpark.new()
	anchor_spark.name = "AnchorSpark"
	anchor_spark.world = self
	overlay.add_child(anchor_spark)
	anchor_overload = AnchorOverload.new()
	anchor_overload.name = "AnchorOverload"
	anchor_overload.world = self
	overlay.add_child(anchor_overload)
	lighting = Lighting.new()
	lighting.name = "Lighting"
	lighting.world = self
	lighting.providers.append(_unit_lights)
	lighting.providers.append(_building_lights)
	lighting.providers.append(_combat_lights)
	lighting.providers.append(anchor_spark.lights)
	lighting.providers.append(anchor_overload.lights)
	add_child(lighting)
	reset_world(randi())


## Remet le monde à son état initial (init() du prototype) avec une graine de galeries donnée :
## sol d'origine, décor d'origine, galeries régénérées, aucune case creusée.
func reset_world(seed: int) -> void:
	gallery_seed = seed
	terrain.build()
	for child in ysort.get_children():
		child.free()
	_unit_views.clear()
	_building_views.clear()
	_enemy_views.clear()
	_turret_views.clear()
	decor = DecorRegistry.new()
	_loader = DecorLoader.new()
	_loader.foliage_material = _foliage_material
	_loader.parent = ysort
	_anchors.clear()
	_loader.build_decor(decor)
	decor.builder = _build_runtime_node
	_special = _loader.special
	for e: Dictionary in decor.entries():
		_attach_visuals(e)
	terrain_state.generate_galleries(seed)
	terrain_state.reset_digging()
	terrain_ops = TerrainOps.new(terrain_state, decor, TerrainPainter.new(terrain, terrain_state))
	print("Graine des galeries : %d (%d réseaux)" % [seed, terrain_state.count])
	apply_view()


## Nœud d'un objet ajouté en cours de partie (face, stalagmite, portail maléfique), avec ses effets.
func _build_runtime_node(e: Dictionary) -> Node:
	var node := _loader.make_node(e)
	e["node"] = node
	_attach_visuals(e)
	return node


## Ajoute aux emplacements spéciaux leur rendu de l'étape 4 : arcs de l'orbe, portails, effets divins.
func _attach_visuals(e: Dictionary) -> void:
	if _portal_meta.is_empty():
		_portal_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["portals"]
	var slot: Node2D = e.get("node")
	if slot == null:
		return
	var P: Dictionary = _portal_meta
	if e.get("orb", false):
		var orb: Sprite2D = _special["orb"]
		var arcs := OrbArcs.new()
		arcs.name = "Arcs"
		orb.add_child(arcs)
	elif e.has("portal"):
		var ex: Dictionary = P["exiles"]
		var spr := _portal_sprite(slot, Vector2(e["x"], e["z"]), "exiles", 1.0, Vector2(ex["ox"], ex["oy"]))
		spr.active_texture = load(ex["atlas"])
		spr.frames = int(ex["frames"])
		spr.cols = int(ex["cols"])
		spr.frame_size = Vector2i(ex["frame_w"], ex["frame_h"])
	elif e.has("dportal"):
		var id: String = e["dportal"]
		var dp: Dictionary = P["deity"]
		var spr := _portal_sprite(slot, Vector2(e["x"], e["z"]), "deity", float(dp["scale"]), Vector2(P["exiles"]["ox"], P["exiles"]["oy"]))
		spr.deity_id = id
		spr.active_texture = load("res://assets/baked/portals/deity_%s.png" % id)
		spr.off_texture = load("res://assets/baked/portals/deity_off.png")
		spr.cols = int(dp[id]["cols"])
		spr.frame_size = Vector2i(dp[id]["frame_w"], dp[id]["frame_h"])
	elif e.has("deity_fx"):
		var fx := DeityFx.new()
		fx.deity_id = e["deity_fx"]
		fx.deity_x = e["x"]
		fx.world = self
		for hex: String in P["deity"]["look"][fx.deity_id]["glow"]:
			fx.glow.append(Color(hex))
		slot.add_child(fx)
	elif e.has("evil"):
		var ev: Dictionary = P["evil"]
		var spr := _portal_sprite(slot, Vector2(e["x"], e["z"]), "evil", float(ev["scale"]), Vector2(P["exiles"]["ox"], P["exiles"]["oy"]))
		spr.active_texture = load("res://assets/baked/portals/evil.png")
		spr.cols = int(ev["sheet"]["cols"])
		spr.frame_size = Vector2i(ev["sheet"]["frame_w"], ev["sheet"]["frame_h"])
		var embers := EvilEmbers.new()
		embers.world = self
		embers.world_xz = Vector2(e["x"], e["z"])
		for hex: String in ev["look"]:
			embers.look.append(Color(hex))
		slot.add_child(embers)


func _portal_sprite(slot: Node2D, xz: Vector2, kind: String, k: float, origin_offset: Vector2) -> PortalSprite:
	var anchor := ScreenAnchor.new()
	anchor.world_xz = xz
	slot.add_child(anchor)
	_anchors.append(anchor)
	var spr := PortalSprite.new()
	spr.kind = kind
	anchor.add_child(spr)
	spr.setup(k, origin_offset)
	anchor.place(native_offset)
	return spr


## Image du sol de la case (i, j) (32 × 32 pixels natifs), relevée avant qu'elle soit creusée : la roche
## suspendue par les pitons de l'Ingénieur garde l'aspect exact de la case.
func cell_image(i: int, j: int) -> Image:
	if terrain == null or terrain_ops == null or terrain_ops.painter == null:
		return null
	return terrain.copy_region(terrain_ops.painter.ground_px(i * 4.0, j * 4.0), Vector2i(32, 32))


## Creuse la case (i, j) : sol repeint, décor mis à jour, galerie révélée si elle est touchée.
func dig_cell(i: int, j: int) -> void:
	terrain_ops.dig_cell(i, j)
	# Les nœuds ajoutés reçoivent les paramètres courants des matériaux.
	apply_view()


## Budget de peinture du sol par image (révélation des galeries), en millisecondes.
const PAINT_BUDGET_MS := 8.0


func _process(_delta: float) -> void:
	if terrain_ops and terrain_ops.painter.pending() > 0:
		terrain_ops.painter.process(PAINT_BUDGET_MS)
	_sync_units()
	_sync_buildings()
	_sync_enemies()
	_sync_turrets()
	_update_dynamic()


## Crée ou retire les nœuds des unités pour suivre GameState.units (les unités mortes ne sont pas dessinées).
## Les adeptes (rôles des temples et de la caserne) ont leur propre rendu (AdeptView).
func _sync_units() -> void:
	if _unit_meta.is_empty():
		_unit_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))["units"]["roles"]
	var live := {}
	for u in GameState.units:
		var adept := Catalog.is_adept(u)
		if not u.alive() or not (adept or _unit_meta.has(u.role)):
			continue
		live[u] = true
		if not _unit_views.has(u):
			var v: Node2D
			if adept:
				var av := AdeptView.new()
				av.setup(u, self)
				v = av
			else:
				var uv := UnitView.new()
				v = uv
			v.name = "Unit_%d" % u.id
			ysort.add_child(v)
			if v is UnitView:
				(v as UnitView).setup(u, _unit_meta[u.role], simulation, self)
			_unit_views[u] = v
	for u: Unit in _unit_views.keys():
		if not live.has(u):
			var v: Node = _unit_views[u]
			if is_instance_valid(v):
				v.queue_free()
			_unit_views.erase(u)


## Crée ou retire les nœuds des bâtiments pour suivre GameState.buildings.
func _sync_buildings() -> void:
	var live := {}
	for b in GameState.buildings:
		live[b] = true
		if not _building_views.has(b):
			var v := BuildingView.new()
			v.name = "Building_%d" % b.id
			v.setup(b)
			ysort.add_child(v)
			_building_views[b] = v
	for b: Building in _building_views.keys():
		if not live.has(b):
			var v: Node = _building_views[b]
			if is_instance_valid(v):
				v.queue_free()
			_building_views.erase(b)


## Ennemis : même rendu que les unités (planches des Forces de la Bête), sans sélection.
func _sync_enemies() -> void:
	if _enemy_meta.is_empty():
		_enemy_meta = EnemyArt.all()
	var live := {}
	for e: Enemy in GameState.enemies + GameState.enemy_corpses:
		if (e.hp <= 0.0 and not e.dead) or not _enemy_meta.has(e.kind):
			continue
		live[e] = true
		if not _enemy_views.has(e):
			var v := UnitView.new()
			v.name = "Enemy_%s" % e.kind
			ysort.add_child(v)
			v.setup(e, _enemy_meta[e.kind], simulation, self)
			_enemy_views[e] = v
	for e: Enemy in _enemy_views.keys():
		if not live.has(e):
			var v: Node = _enemy_views[e]
			if is_instance_valid(v):
				v.queue_free()
			_enemy_views.erase(e)


## Balistes de l'entrée (une vue par baliste de GameState.turrets). Index : identifiant de la baliste (un
## dictionnaire servirait mal de clé, son contenu change à chaque image) ; une nouvelle partie recrée les vues.
func _sync_turrets() -> void:
	var live := {}
	for b in GameState.turrets:
		var id: int = b["id"]
		live[id] = true
		var v: TurretView = _turret_views.get(id)
		if v and not is_same(v.turret, b):
			v.queue_free()
			v = null
		if v == null:
			v = TurretView.new()
			v.name = "Turret_%d" % id
			v.setup(b)
			ysort.add_child(v)
			_turret_views[id] = v
	for id: int in _turret_views.keys():
		if not live.has(id):
			var v: Node = _turret_views[id]
			if is_instance_valid(v):
				v.queue_free()
			_turret_views.erase(id)


## Lumières des balistes (chaudes, 5) et des explosions de carreaux (forge, 4) — collectLights.
func _combat_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in GameState.turrets:
		out.append({"x": b["x"], "z": b["z"], "r": 5.0, "rgb": Lighting.WARM, "glow": 0.1})
	for e in GameState.effects:
		if e["type"] == "xboom" and e["age"] >= 0.0:
			out.append({"x": e["x"], "z": e["z"], "r": 4.0, "rgb": Lighting.FORGE, "glow": 0.3})
	return out


func building_view(b: Building) -> BuildingView:
	return _building_views.get(b)


## Lumières des bâtiments (collectLights) : écart voulu D16 (charte graphique), chaque bâtiment éclaire
## dans la couleur de son culte ; les feux d'Indra vacillent.
func _building_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := GameState.sim_time
	for b in GameState.buildings:
		var c: String = Lighting.CULT_OF.get(b.type, "")
		if c == "indra":
			out.append({"x": b.x, "z": b.z, "r": 8.5 * Lighting.flick(t, b.x, 0.08), "rgb": Lighting.CULT[c], "glow": 0.18})
		elif c != "":
			out.append({"x": b.x, "z": b.z, "r": 8.0, "rgb": Lighting.CULT[c], "glow": 0.14})
		else:
			out.append({"x": b.x, "z": b.z, "r": 7.5, "rgb": Lighting.WARM, "glow": 0.12})
	return out


## Lumières des unités (collectLights) : 8 × scintillement, chaude.
func _unit_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in GameState.units:
		if u.alive() and not u.hidden:
			out.append({"x": u.x, "z": u.z, "r": 8.0 * Lighting.flick(GameState.sim_time, u.id), "rgb": Lighting.WARM, "glow": 0.14})
	return out


func unit_view(u: Unit) -> Node2D:
	return _unit_views.get(u)


## Termine immédiatement la peinture en attente (captures, tests).
func finish_painting() -> void:
	terrain_ops.painter.finish()


## Le feuillage n'a plus de matériau propre : le shader des objets triés le reconnaît par la planche
## (decor_atlas_meta.png). Modulation neutre, pour ne pas casser le regroupement des appels de dessin.
func _foliage_material(_kind: String, _anchor_y: float) -> Color:
	return Color.WHITE


## Place le monde selon la caméra : échelle ×PX, origine native décalée (Proj.camera_offset).
func apply_view() -> void:
	var px := camera.px
	scale = Vector2(px, px)
	native_offset = Proj.camera_offset(camera.cam, px, get_viewport_rect().size)
	position = native_offset * px
	for a in _anchors:
		if is_instance_valid(a):
			a.place(native_offset)
	_snap.set_shader_parameter("px", float(px))
	_sprites_mat.set_shader_parameter("px", float(px))
	_sprites_mat.set_shader_parameter("world_origin", position)
	_update_dynamic()


func _update_dynamic() -> void:
	var t := GameState.sim_time
	_sprites_mat.set_shader_parameter("sim_time", t)
	_sprites_mat.set_shader_parameter("wind_scale", wind_scale)
	# Orbe de l'Ancre (orbY, Index.html) : 2,6 unités de haut éteinte, 3 + sin(t·1,7)·0,2 active.
	var orb: Sprite2D = _special.get("orb")
	var holder: Node2D = _special.get("orb_holder")
	if orb and holder:
		var y := 3.0 + sin(t * 1.7) * 0.2 if GameState.orb_active else 2.6
		var core: Vector2 = Vector2(0, -154)
		orb.position.y = Proj.nat(core.x, y, core.y).y - holder.position.y
		(orb.material as ShaderMaterial).set_shader_parameter("active", GameState.orb_active)
		(orb.material as ShaderMaterial).set_shader_parameter("lift", Overload.sphere_lift())
		(orb.material as ShaderMaterial).set_shader_parameter("ring_dark", Overload.ring_mask(false))
		(orb.material as ShaderMaterial).set_shader_parameter("ring_flash", Overload.ring_mask(true))


func special(name: String) -> Variant:
	return _special.get(name)
