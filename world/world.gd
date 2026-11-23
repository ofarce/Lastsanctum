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
## Minerai vu sur le flanc d'une case de roche (piste « Nodules affleurants », tools/minerais/minerais_v4.py) :
## 4 colonnes (cuivre, fer, quartz, or) × 2 lignes (filon, gisement inépuisable) de 32 × 49, comme face5_*.
const ORE_FACES := preload("res://assets/ardoise/world/ore_faces.png")
const ROCK_TOP := preload("res://assets/ardoise/world/tiles/rock.png")
const OreBlocks := preload("res://data/mineable_blocks.gd")

## 0 fige le vent (captures de validation).
var wind_scale := 1.0
## Graine des galeries (décision D12) : tirée au hasard à chaque partie, affichée, réutilisable.
var gallery_seed := 0

## Terrain dynamique (étape 3) : galeries, cases creusées, praticabilité ; décor ; opérations.
var terrain_state := TerrainState.new()
var fog := preload("res://world/terrain/fog_of_war.gd").new()
var _fog_material := ShaderMaterial.new()
var decor := DecorRegistry.new()
var terrain_ops: TerrainOps
var pathfinder := Pathfinder.new(terrain_state)
var _loader: DecorLoader

## Décalage caméra en pixels natifs (Proj.camera_offset) : position native à l'écran = nat + native_offset.
var native_offset := Vector2.ZERO
## Points alignés sur la grille native de l'écran (portails), replacés à chaque changement de vue.
var _anchors: Array[ScreenAnchor] = []
## Éclairage (étape 4) : créé après le décor, donc dessiné par-dessus.
var lighting: Lighting
## Vie décorative de la jungle (oiseaux, papillons, poissons, pollen, brume).
var jungle_life: JungleLife
## Objets posés le long des chemins (RoadProps.place).
var road_props: Array[Dictionary] = []
## Crue affichée par river_view (unités), pour ne la renvoyer au shader que quand elle change.
var _flood_shown := -1.0
## Pluie et éclairs à l'écran (core/weather.gd).
var rain_view: RainView
## Simulation (étape 5) : fournit les unités à dessiner.
var simulation: Simulation
var _unit_views := {}
var _unit_meta := {}
var _building_views := {}
## Défenses posées (GameState.placed) → PlacedView, et aperçu de pose sous le pointeur.
var _placed_views := {}
var _place_preview: PlacedView
var _build_ghost: BuildingView.Ghost
## Coffres de production et silhouette « poste vide » de chaque bâtiment servi (ProductionView).
var _production_views := {}
var _enemy_views := {}
var _enemy_meta := {}
var _turret_views := {}
## Surimpression à la résolution de l'écran (libellés, incantation, mode construction), sous l'éclairage.
var overlay: WorldOverlay
## Tirs ennemis esquivables, dans leur calque au-dessus de l'éclairage (EnemyShotsView).
var enemy_shots_view: EnemyShotsView
## Étincelle de réactivation de l'Ancre (caméra qui la suit, halo), dans la surimpression.
var anchor_spark: AnchorSpark
## Surcharge de l'Ancre après l'armement des balistes (colonne, nova, bouclier, pièces d'armure).
var anchor_overload: AnchorOverload
## Emprises au sol des bâtiments (drawBuildGrid), sous le décor.
var build_grid: BuildGrid
var soulwell_halo: SoulwellHalo
var spirit_arrival: SpiritArrivalFx
## Coffre antique de la réserve scellée (visible une fois la réserve découverte).
var chest_view: ChestView
## Glyphe tyrien qui trahit la réserve scellée sur la paroi est de la salle.

var _snap := ShaderMaterial.new()
var _sprites_mat := ShaderMaterial.new()
var _special := {}
## Dessus de roche posés au-dessus des parois : [Sprite2D, x, z de la paroi], et version du terrain vue.
var _caps: Array = []
var _caps_version := -1
## Ambiances de la montagne (bassins sous les objets triés ; champignons, lianes, faune dans le tri).
var ambience_ground := Node2D.new()
## Nappes de corruption des Pylônes de Merenor (PylonZone), au sol sous les objets triés.
var pylon_ground := Node2D.new()
## Rendu de la rivière de la jungle (null sans rivière).
var river_view: RiverView
## Nœuds de la petite végétation (null sans végétation).
var flora_view: FloraView
var ambience := {}
## Décor et salles à thème du Temple (world/sanctum).
var sanctum_view := SanctumView.new()

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
	ambience_ground.name = "AmbienceGround"
	add_child(ambience_ground)
	move_child(ambience_ground, ysort.get_index())
	sanctum_view.name = "SanctumView"
	sanctum_view.world = self
	add_child(sanctum_view)
	add_child(sanctum_view.ground)
	move_child(sanctum_view.ground, ysort.get_index())
	pylon_ground.name = "PylonGround"
	pylon_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(pylon_ground)
	move_child(pylon_ground, ysort.get_index())
	build_grid = BuildGrid.new()
	build_grid.name = "BuildGrid"
	build_grid.world = self
	add_child(build_grid)
	move_child(build_grid, ysort.get_index())
	soulwell_halo = SoulwellHalo.new()
	soulwell_halo.name = "SoulwellHalo"
	soulwell_halo.world = self
	add_child(soulwell_halo)
	move_child(soulwell_halo, ysort.get_index())
	# Bouclier de la Martyre de Byrsa : moitié arrière sous les sprites, moitié avant par-dessus.
	for is_front: bool in [false, true]:
		var dome := MartyreDome.new()
		dome.name = "MartyreDomeFront" if is_front else "MartyreDome"
		dome.world = self
		dome.front = is_front
		add_child(dome)
		move_child(dome, ysort.get_index() + (1 if is_front else 0))
	# Œil de la Matrice (sim/oeil.gd) : couloirs au sol sous les sprites, balles par-dessus.
	for is_air: bool in [false, true]:
		var ofx := OeilFx.new()
		ofx.name = "OeilFxAir" if is_air else "OeilFxGround"
		ofx.world = self
		ofx.ground = not is_air
		add_child(ofx)
		move_child(ofx, ysort.get_index() + (1 if is_air else 0))
	# Gorge-Cuivre (sim/gorge.gd) : annonces et blocs qui tombent par-dessus les sprites.
	var gmarks := GorgeMarks.new()
	gmarks.name = "GorgeMarks"
	gmarks.world = self
	add_child(gmarks)
	move_child(gmarks, ysort.get_index() + 1)
	# Archiprêtre aux racines (sim/archipretre.gd) : nappe et places de prière sous les sprites, racines par-dessus.
	for is_air: bool in [false, true]:
		var am := ArchipretreMarks.new()
		am.name = "ArchipretreMarksAir" if is_air else "ArchipretreMarksGround"
		am.world = self
		am.air = is_air
		add_child(am)
		move_child(am, ysort.get_index() + (1 if is_air else 0))
	# Séquence d'ouverture (sim/opening.gd) : remparts et onde au sol sous les sprites ; portail, bouclier,
	# canons et fumées par-dessus.
	for is_air: bool in [false, true]:
		var ov := OpeningView.new()
		ov.name = "OpeningAir" if is_air else "OpeningGround"
		ov.world = self
		ov.ground = not is_air
		add_child(ov)
		move_child(ov, ysort.get_index() + (1 if is_air else 0))
	# Capsule de l'Ingénieur (sim/capsule.gd), à la place du portail central.
	for is_ground: bool in [true, false]:
		var capsule := CapsuleView.new()
		capsule.name = "CapsuleLink" if is_ground else "Capsule"
		capsule.ground = is_ground
		add_child(capsule)
		move_child(capsule, ysort.get_index() + (0 if is_ground else 1))
	# Puits de l'Ancre tyrienne, sous les sprites (le reste est trié avec eux : _attach_visuals).
	var anchor_well := AnchorView.new()
	anchor_well.name = "AnchorWell"
	anchor_well.ground = true
	add_child(anchor_well)
	move_child(anchor_well, ysort.get_index())
	# Arrivée des esprits à l'autel (Germe) : repère du monde, par-dessus les sprites.
	spirit_arrival = SpiritArrivalFx.new()
	spirit_arrival.name = "SpiritArrival"
	spirit_arrival.world = self
	add_child(spirit_arrival)
	move_child(spirit_arrival, ysort.get_index() + 1)
	var rain_layer := CanvasLayer.new()
	rain_layer.name = "RainLayer"
	rain_layer.layer = 2
	add_child(rain_layer)
	rain_view = RainView.new()
	rain_view.world = self
	rain_layer.add_child(rain_view)
	# Tirs ennemis au-dessus de l'obscurité et de la pluie (même calque que la pluie, ajouté après elle).
	var shots_layer := CanvasLayer.new()
	shots_layer.name = "EnemyShotsLayer"
	shots_layer.layer = 2
	add_child(shots_layer)
	enemy_shots_view = EnemyShotsView.new()
	enemy_shots_view.name = "EnemyShots"
	enemy_shots_view.world = self
	shots_layer.add_child(enemy_shots_view)
	jungle_life = JungleLife.new()
	jungle_life.name = "JungleLife"
	jungle_life.world = self
	add_child(jungle_life)
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
	lighting.providers.append(MartyreFx.lights)
	lighting.providers.append(anchor_spark.lights)
	fog.spark_lights = anchor_spark.lights
	lighting.providers.append(anchor_overload.lights)
	lighting.providers.append(_vault_lights)
	lighting.providers.append(_grove_lights)
	lighting.providers.append(_loot_lights)
	lighting.providers.append(_ambience_lights)
	lighting.providers.append(sanctum_view.lights)
	add_child(lighting)
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 3
	add_child(fog_layer)
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_material.shader = preload("res://shaders/fog_of_war.gdshader")
	veil.material = _fog_material
	fog_layer.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Sceau sensible : reflets des filons par-dessus le brouillard.
	var seal_layer := CanvasLayer.new()
	seal_layer.name = "SealGlintsLayer"
	seal_layer.layer = 3
	add_child(seal_layer)
	var seal_view := SealGlintsView.new()
	seal_view.world = self
	seal_layer.add_child(seal_view)
	# Pas de reset_world ici : la partie (Simulation.new_game) ou l'outil qui instancie le monde seul le
	# fait aussitôt avec sa graine ; le générer ici doublait le coût (~25 s) pour rien.


## Remet le monde à son état initial (init() du prototype) avec une graine de galeries donnée :
## sol d'origine, décor d'origine, galeries régénérées, aucune case creusée.
func reset_world(seed: int) -> void:
	gallery_seed = seed
	# Jungle d'abord (2026-11-22, chargement) : ses images (sol par zone, rivière, plusieurs secondes) se
	# calculent sur des fils de travail pendant tout le reste ; _build_ambience les attend.
	if terrain_state.groves:
		var jungle := TerrainState.jungle(seed)
		terrain_state.prebuilt = jungle
		GroundZones.prepare(jungle["flora"])
		RiverView.prepare(jungle["river"])
	terrain.build()
	for child in ysort.get_children():
		child.free()
	for child in pylon_ground.get_children():
		child.free()
	_unit_views.clear()
	_building_views.clear()
	_placed_views.clear()
	_place_preview = null
	_build_ghost = null
	_production_views.clear()
	_enemy_views.clear()
	_turret_views.clear()
	decor = DecorRegistry.new()
	_loader = DecorLoader.new()
	_loader.foliage_material = _foliage_material
	_loader.parent = ysort
	_anchors.clear()
	_loader.build_decor(decor)
	_build_generated_decor(seed)
	decor.builder = _build_runtime_node
	_special = _loader.special
	for e: Dictionary in decor.entries():
		_attach_visuals(e)
	terrain_state.reset_digging()
	terrain_state.generate_galleries(seed)
	# Images de la jungle (sol par zone, rivière) calculées en parallèle du reste ; _build_ambience les attend.
	if terrain_state.flora:
		GroundZones.prepare(terrain_state.flora)
	RiverView.prepare(terrain_state.river)
	_clear_river_decor()
	_thin_trees()
	_lay_roads()
	fog.reset_exploration()
	fog.refresh(terrain_state)
	_update_caps()
	_fog_material.set_shader_parameter("fog", fog.texture)
	for origin: Vector2i in terrain_state.wood_left:
		var grove := GroveView.new()
		grove.setup(terrain_state, origin)
		ysort.add_child(grove)
	for origin: Vector2i in terrain_state.lodes:
		var lode := LodeView.new()
		lode.setup(terrain_state, origin)
		ysort.add_child(lode)
	for key: Vector2i in terrain_state.block_types:
		if terrain_state.grove_cells.has(key) or terrain_state.lode_cells.has(key):
			continue
		var ore := preload("res://world/terrain/ore_view.gd").new()
		ore.setup(terrain_state, key)
		ysort.add_child(ore)
	_build_ambience()
	sanctum_view.reset()
	flora_view = null
	if terrain_state.flora:
		flora_view = FloraView.new()
		flora_view.setup(terrain_state.flora, ysort, ambience_ground)
	chest_view = ChestView.new()
	chest_view.name = "Chest"
	chest_view.setup(terrain_state)
	ysort.add_child(chest_view)
	var door := DoorView.new()
	door.name = "SouthDoor"
	ysort.add_child(door)
	if terrain_state.frontier:
		var gate := EyeGateView.new()
		gate.setup(terrain_state)
		ysort.add_child(gate)
	# Bornes et colonne de la capsule, triées avec les sprites (le puits et les invites restent hors tri : _ready).
	for part: String in ["back", "front"]:
		var cap := CapsuleView.new()
		cap.name = "Capsule" + part.capitalize()
		cap.layer = part
		ysort.add_child(cap)
	terrain_ops = TerrainOps.new(terrain_state, decor, TerrainPainter.new(terrain, terrain_state))
	terrain_ops.reshape_cave()
	# Galeries reliées (2026-11-22) : tout est ouvert dès le départ, le brouillard seul cache.
	if terrain_state.groves:
		terrain_ops.open_all_galleries()
	print("Graine des galeries : %d (%d réseaux avant raccords, %d pylônes)" % [seed, terrain_state.count, terrain_state.portals.size()])
	apply_view()


## Ni arbre ni caillou dans le lit, sur les berges ou sur les ponts (décor baké compris).
func _clear_river_decor() -> void:
	var r := terrain_state.river
	if r == null:
		return
	var zr := r.z_range()
	decor.remove_in_rect(CaveShape.WORLD_X0, zr.x, CaveShape.WORLD_X1, zr.y,
		func(e: Dictionary) -> bool: return not DecorRegistry.is_fixed(e) and r.clear_of_decor(float(e["x"]), float(e["z"])))


## Chemins de la jungle : sol repeint, décor dégagé, torches le long de la route principale.
func _lay_roads() -> void:
	var road := terrain_state.road
	if road == null:
		return
	terrain.paint_road(road)
	for r: Rect2 in road.bounds():
		decor.remove_in_rect(r.position.x, r.position.y, r.end.x, r.end.y,
			func(e: Dictionary) -> bool: return not DecorRegistry.is_fixed(e) and road.on_road(float(e["x"]), float(e["z"]), 1.5))
	# Objets du chemin et poste abandonné : sol dégagé autour, puis un sprite chacun.
	road_props = RoadProps.place(road, gallery_seed)
	for p: Dictionary in road_props:
		var x: float = p["x"]
		var z: float = p["z"]
		var r := RoadProps.OUTPOST_R + 1.5 if p["k"] == "outpost" else 1.6
		decor.remove_in_rect(x - r, z - r, x + r, z + r, func(e: Dictionary) -> bool: return not DecorRegistry.is_fixed(e))
		if terrain_state.flora:
			terrain_state.flora.clear_rect(x - r, z - r, x + r, z + r)
		if p["k"] == "outpost":
			continue
		var s := Sprite2D.new()
		s.name = "Prop_" + String(p["k"])
		var tex := PropArt.texture(p["k"])
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + 1.0)
		s.flip_h = p["flip"]
		s.position = Vector2(roundf(x * Proj.K), roundf(z * Proj.K))
		ysort.add_child(s)
	for k in fog.road_torches.size():
		var t: Vector2 = fog.road_torches[k]
		if t.y > Road.GATE_Z:
			fog.road_torches[k] = Vector2(roundf(road.main_x(t.y)), t.y)


## Clairières, marais et coins rocheux : moins d'arbres (Flora.thin_tree).
func _thin_trees() -> void:
	var f := terrain_state.flora
	if f == null:
		return
	decor.remove_in_rect(CaveShape.WORLD_X0, -100.0, CaveShape.WORLD_X1, CaveShape.WORLD_Z1,
		func(e: Dictionary) -> bool: return String(e.get("s", "")).begins_with("tree_") and f.thin_tree(float(e["x"]), float(e["z"])))
	# Bosquets de la jungle : rien de la flore ne pousse sur leurs 2 × 2 cases ni juste autour.
	for origin: Vector2i in terrain_state.wood_left.keys() + terrain_state.lodes.keys():
		if CaveShape.outdoors(origin.x * 4.0, origin.y * 4.0):
			decor.remove_in_rect(origin.x * 4.0 - 2.0, origin.y * 4.0 - 2.0, origin.x * 4.0 + 10.0, origin.y * 4.0 + 10.0, func(_e: Dictionary) -> bool: return true)


# ---------------------------------------------------------------- Décor généré (hors zone d'origine)
## Les entrées de tous les chunks sont dans le registre dès le départ (le creusement et la révélation des
## galeries les retirent comme les autres) ; seuls leurs nœuds sont créés à l'approche de la caméra et
## libérés quand elle s'éloigne (DECOR_KEEP chunks de marge en plus, pour ne pas osciller).

const DECOR_MARGIN := 1
const DECOR_KEEP := 2
## Vector2i(chunk) → Array[Dictionary] (entrées du registre).
var _gen_decor := {}
var _gen_live := {}
var _gen_view := Rect2i()


func _build_generated_decor(map_seed: int) -> void:
	_gen_decor.clear()
	_gen_live.clear()
	_gen_view = Rect2i()
	var cr := DecorGen.chunk_range()
	for cz in range(cr.position.y, cr.end.y):
		for cx in range(cr.position.x, cr.end.x):
			var c := Vector2i(cx, cz)
			var list := DecorGen.chunk(map_seed, c)
			if list.is_empty():
				continue
			for e in list:
				decor.add_raw(e)
			_gen_decor[c] = list


## Chunks de décor visibles (unités du monde) : écran à l'échelle ×PX, plus une marge.
func _decor_view() -> Rect2i:
	var half := get_viewport_rect().size / (16.0 * camera.px)
	var c0 := Vector2i(floori((camera.cam.x - half.x) / DecorGen.CHUNK), floori((camera.cam.y - half.y) / DecorGen.CHUNK))
	var c1 := Vector2i(floori((camera.cam.x + half.x) / DecorGen.CHUNK), floori((camera.cam.y + half.y) / DecorGen.CHUNK))
	return Rect2i(c0, c1 - c0 + Vector2i.ONE).grow(DECOR_MARGIN)


func _stream_decor() -> void:
	var view := _decor_view()
	if view == _gen_view:
		return
	_gen_view = view
	var keep := view.grow(DECOR_KEEP - DECOR_MARGIN)
	if flora_view:
		flora_view.stream(view, keep)
	if _gen_decor.is_empty():
		return
	for c: Vector2i in _gen_live.keys():
		if keep.has_point(c):
			continue
		for e: Dictionary in _gen_decor[c]:
			var node: Node = e.get("node")
			if node and is_instance_valid(node):
				node.queue_free()
			e.erase("node")
		_gen_live.erase(c)
	for cz in range(view.position.y, view.end.y):
		for cx in range(view.position.x, view.end.x):
			var c := Vector2i(cx, cz)
			if _gen_live.has(c) or not _gen_decor.has(c):
				continue
			_gen_live[c] = true
			for e: Dictionary in _gen_decor[c]:
				# Retirée du registre (creusement, galerie révélée) : plus jamais dessinée.
				if not decor.has(e):
					continue
				e["node"] = _loader.make_node(e)
				_attach_visuals(e)


## Nœuds de décor généré actuellement créés (tests, mesures).
func generated_decor_nodes() -> int:
	var n := 0
	for c: Vector2i in _gen_live:
		for e: Dictionary in _gen_decor[c]:
			if e.has("node"):
				n += 1
	return n


## Nœud d'un objet ajouté en cours de partie (face, stalagmite, portail maléfique), avec ses effets.
func _build_runtime_node(e: Dictionary) -> Node:
	var node := _loader.make_node(e)
	e["node"] = node
	_attach_visuals(e)
	return node


## Paroi face5 posée au sud d'une case de roche : si cette case est un minerai, son flanc le montre.
## La paroi est retirée avec la case quand on la creuse (TerrainOps.dig) ; le calque part avec elle.
func _attach_ore_face(e: Dictionary, slot: Node2D) -> void:
	var cell := Vector2i(floori(float(e["bx"]) / 4.0), floori(float(e["bz"]) / 4.0) - 1)
	_attach_rock_cap(e, slot)
	var column := OreBlocks.ORES.find(terrain_state.block_types.get(cell, ""))
	if column < 0 or terrain_state.dug.has(cell) or slot.get_child_count() == 0:
		return
	var face := slot.get_child(0) as Sprite2D
	if face == null:
		return
	var ore := Sprite2D.new()
	ore.name = "OreFace"
	ore.texture = ORE_FACES
	ore.region_enabled = true
	ore.region_rect = Rect2(column * 32, (49 if terrain_state.permanent_ores.has(cell) else 0), 32, 49)
	ore.centered = false
	ore.offset = face.offset
	ore.use_parent_material = true
	face.add_child(ore)


## Dessus texturé d'une roche d'une seule case de profondeur : la paroi (49 px) cache toute
## l'emprise de la case au sol ; sans roche derrière, on verrait le sol de la galerie au-dessus.
func _attach_rock_cap(e: Dictionary, slot: Node2D) -> void:
	var face := slot.get_child(0) as Sprite2D if slot.get_child_count() > 0 else null
	if face == null:
		return
	var bx := float(e["bx"])
	var bz := float(e["bz"])
	var cap := Sprite2D.new()
	cap.name = "RockCap"
	cap.texture = terrain.rock_texture(Biomes.rock_tier(floorf(bz / 4.0) * 4.0 - 2.0))
	cap.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cap.region_enabled = true
	var gx := posmod(int(bx * 8.0) + terrain.origin.x, ROCK_TOP.get_width())
	var gy := posmod(int((floorf(bz / 4.0) * 4.0 - 4.0) * 8.0) + terrain.origin.y, ROCK_TOP.get_height())
	cap.region_rect = Rect2(gx, gy, 32, 32)
	cap.centered = false
	cap.offset = face.offset + Vector2(0, -32)
	cap.use_parent_material = true
	cap.show_behind_parent = true
	face.add_child(cap)
	_caps.append([cap, bx, bz])
	_caps_version = -1


## Le dessus n'est montré que si la case au nord de la roche est creuse (roche isolée).
func _update_caps() -> void:
	if _caps_version == terrain_state.version:
		return
	_caps_version = terrain_state.version
	var keep: Array = []
	for c: Array in _caps:
		# Vérifié avant l'affectation typée : un sprite libéré (nouvelle partie) la ferait échouer.
		if not is_instance_valid(c[0]):
			continue
		var cap: Sprite2D = c[0]
		var top := floorf(float(c[2]) / 4.0) * 4.0 - 4.0
		cap.visible = terrain_state.ground(float(c[1]) + 2.0, top - 2.0)
		keep.append(c)
	_caps = keep


## Ajoute aux emplacements spéciaux leur rendu : arcs de l'orbe, faces de filon, pylônes de Merenor.
func _attach_visuals(e: Dictionary) -> void:
	var slot: Node2D = e.get("node")
	if slot == null:
		return
	if String(e.get("s", "")).begins_with("face5_"):
		_attach_ore_face(e, slot)
		return
	if e.get("orb", false):
		# Ancre tyrienne (AnchorView) : l'ancien sprite de l'orbe reste comme repère (survol, tests) mais ne
		# se dessine plus ; son porteur trié reçoit bornes, chaînes et sphère, calé devant les bornes avant.
		var orb: Sprite2D = _special["orb"]
		orb.self_modulate.a = 0.0
		var holder: Node2D = _special["orb_holder"]
		holder.position.y = 8.0 * (CaveShape.CORE.y + AnchorView.FRONT)
		var view := AnchorView.new()
		view.name = "AnchorView"
		view.orb = orb
		holder.add_child(view)
	elif e.has("evil"):
		# Pylône de Merenor (sim/pylons.gd) à la place du portail maléfique : obélisque trié, nappe au sol.
		var p: Dictionary = e["evil"]
		var view := PylonView.new()
		slot.add_child(view)
		view.setup(p, slot)
		var zone := PylonZone.new()
		zone.setup(terrain_state, p)
		pylon_ground.add_child(zone)


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


## Mur sud soufflé par l'explosion du bouclier (sim/opening.gd) : la brèche s'ouvre sur les remparts.
func open_breach() -> void:
	terrain_ops.open_breach()
	apply_view()


## Budget de peinture du sol par image (révélation des galeries), en millisecondes.
const PAINT_BUDGET_MS := 8.0


func _process(_delta: float) -> void:
	if terrain_ops and terrain_ops.painter.pending() > 0:
		terrain_ops.painter.process(PAINT_BUDGET_MS)
	fog.refresh(terrain_state)
	if GameState.hud_enemy and not fog.visible_at(GameState.hud_enemy.pos()):
		GameState.hud_enemy = null
	_sync_units()
	_sync_buildings()
	_sync_placed()
	_sync_enemies()
	_sync_turrets()
	_update_dynamic()
	if flora_view:
		flora_view.refresh()
	if terrain_state.river:
		# River.flood est tenu à jour par la simulation (Weather.tick) ; ici, seulement le rendu.
		var fl := Weather.flood()
		if fl != _flood_shown:
			_flood_shown = fl
			if river_view:
				river_view.set_flood(fl)


## Bosquets replantés par la Sylviculture (Simulation.regrow_groves) : leur vue rejoint le tri en profondeur.
func add_groves(origins: Array[Vector2i]) -> void:
	for origin: Vector2i in origins:
		var grove := GroveView.new()
		grove.setup(terrain_state, origin)
		ysort.add_child(grove)


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
				# Mort d'un soldat de la Caserne ou d'un esprit : chute ou dissipation à sa place.
				if v is AdeptView and u.hp <= 0.0 and not u.hidden:
					var fx := AllyDeathFx.new()
					if fx.setup(v as AdeptView):
						fx.name = "Death_%d" % u.id
						ysort.add_child(fx)
				v.queue_free()
			_unit_views.erase(u)


## Crée ou retire les nœuds des défenses posées (sim/placeables.gd) ; aperçu de pose en mode « place ».
func _sync_placed() -> void:
	if _build_ghost == null and GameState.hud_mode == "build":
		_build_ghost = BuildingView.Ghost.new()
		_build_ghost.name = "BuildGhost"
		_build_ghost.world = self
		ysort.add_child(_build_ghost)
	if _place_preview == null and GameState.hud_mode == "place":
		_place_preview = PlacedView.new()
		_place_preview.name = "PlacePreview"
		_place_preview.ghost = true
		_place_preview.world = self
		ysort.add_child(_place_preview)
	if GameState.placed.is_empty() and _placed_views.is_empty():
		return
	var live := {}
	# Clé : objet et case (un dictionnaire changeant ne peut pas servir de clé).
	for o: Dictionary in GameState.placed:
		var key := "%s@%d,%d" % [o["item"], o["cell"].x, o["cell"].y]
		live[key] = true
		if not _placed_views.has(key):
			var v := PlacedView.new()
			v.name = "Placed_%s_%d_%d" % [o["item"], o["cell"].x, o["cell"].y]
			v.setup(o)
			ysort.add_child(v)
			_placed_views[key] = v
	for key: String in _placed_views.keys():
		if not live.has(key):
			var v: Node = _placed_views[key]
			if is_instance_valid(v):
				v.queue_free()
			_placed_views.erase(key)


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
		if Production.staffed(b) and not _production_views.has(b):
			var pv := ProductionView.new()
			pv.name = "Production_%d" % b.id
			pv.setup(b, self)
			ysort.add_child(pv)
			_production_views[b] = pv
	for b: Building in _building_views.keys():
		if not live.has(b):
			var v: Node = _building_views[b]
			if is_instance_valid(v):
				v.queue_free()
			_building_views.erase(b)
	for b: Building in _production_views.keys():
		if not live.has(b):
			var v: Node = _production_views[b]
			if is_instance_valid(v):
				v.queue_free()
			_production_views.erase(b)


## Ennemis : même rendu que les unités (planches des Forces de la Bête), sans sélection.
func _sync_enemies() -> void:
	if _enemy_meta.is_empty():
		_enemy_meta = EnemyArt.all()
	var live := {}
	for e: Enemy in GameState.enemies + GameState.enemy_corpses:
		if (e.hp <= 0.0 and not e.dead) or not (_enemy_meta.has(e.role) or e.kind == OeilMatrice.KIND or e.kind == Gorge.KIND or e.kind == Archipretre.KIND):
			continue
		live[e] = true
		if not _enemy_views.has(e) and e.kind == Archipretre.KIND:
			var av := ArchipretreView.new()
			ysort.add_child(av)
			av.setup(e, self)
			_enemy_views[e] = av
			continue
		if not _enemy_views.has(e) and e.kind == Gorge.KIND:
			var gv := GorgeView.new()
			ysort.add_child(gv)
			gv.setup(e, self)
			_enemy_views[e] = gv
			continue
		if not _enemy_views.has(e) and e.kind == OeilMatrice.KIND:
			var ov := OeilView.new()
			ysort.add_child(ov)
			ov.setup(e, self)
			_enemy_views[e] = ov
		elif not _enemy_views.has(e):
			var v := UnitView.new()
			v.name = "Enemy_%s" % e.kind
			ysort.add_child(v)
			v.setup(e, _enemy_meta[e.role], simulation, self)
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
		v.visible = fog.visible_at(Vector2(b["x"], b["z"]))
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
## Rai de lumière de chaque bosquet pétrifié : lumière chaude et pâle au centre de l'emprise.
func _grove_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for origin: Vector2i in terrain_state.wood_left:
		out.append({"x": origin.x * 4.0 + 4.0, "z": origin.y * 4.0 + 4.0, "r": 10.0, "rgb": Color8(255, 241, 210), "glow": 0.12})
	for origin: Vector2i in terrain_state.lodes:
		out.append({"x": origin.x * 4.0 + 4.0, "z": origin.y * 4.0 + 4.0, "r": 10.0, "rgb": Color8(255, 241, 210), "glow": 0.12})
	return out


## Ambiances de la montagne (planche ambiances-montagne-detail.html), avec parcimonie : AmbienceLayout.
func _build_ambience() -> void:
	for child in ambience_ground.get_children():
		child.free()
	# Sol teinté par sous-zone, sous la rivière.
	if terrain_state.flora:
		var zones := GroundZones.new()
		zones.setup(terrain_state.flora)
		ambience_ground.add_child(zones)
	river_view = null
	if terrain_state.river:
		river_view = RiverView.new()
		river_view.setup(terrain_state.river)
		ambience_ground.add_child(river_view)
	for p: Dictionary in terrain_state.pools:
		var pool := PoolView.new()
		pool.setup(terrain_state, p)
		ambience_ground.add_child(pool)
	ambience = AmbienceLayout.build(terrain_state)
	for d: Dictionary in ambience["mushrooms"]:
		var m := MushroomView.new()
		m.setup(terrain_state, d)
		ysort.add_child(m)
	for key: String in ["vines", "roots"]:
		for d: Dictionary in ambience[key]:
			var v := VineView.new()
			v.setup(terrain_state, d, key == "roots")
			ysort.add_child(v)
	for pair: Array in [["bats", FaunaView.Kind.BATS], ["beetles", FaunaView.Kind.BEETLES], ["salamanders", FaunaView.Kind.SALAMANDER]]:
		for d: Dictionary in ambience[pair[0]]:
			var f := FaunaView.new()
			f.setup(terrain_state, d, pair[1])
			ysort.add_child(f)


## Lueur des champignons : pulsée, plus vive autour des lanternes ; seulement dans les galeries ouvertes.
func _ambience_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in ambience.get("mushrooms", []):
		if not terrain_state.is_gallery_open(d["x"], d["z"]):
			continue
		var k := 0.5 + 0.5 * sin(GameState.sim_time * 2.0 - float(d["x"]) * 0.32)
		out.append({"x": d["x"], "z": d["z"], "r": (6.0 if d["lantern"] else 4.5) * (0.85 + 0.15 * k), "rgb": Color8(220, 240, 205), "glow": 0.08 + 0.05 * k})
	return out


func _building_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := GameState.sim_time
	for b in GameState.buildings:
		var c: String = Lighting.CULT_OF.get(b.type, "")
		if b.type == "soulwell" and b.complete:
			# Le Lotus irradie toute sa zone de soin (halo diffus, SoulwellHalo).
			out.append({"x": b.x, "z": b.z, "r": float(b.def()["heal_radius"]), "rgb": Lighting.CULT[c], "glow": 0.1})
		elif c == "indra":
			out.append({"x": b.x, "z": b.z, "r": 8.5 * Lighting.flick(t, b.x, 0.08), "rgb": Lighting.CULT[c], "glow": 0.18})
		elif c != "":
			out.append({"x": b.x, "z": b.z, "r": 8.0, "rgb": Lighting.CULT[c], "glow": 0.14})
		else:
			out.append({"x": b.x, "z": b.z, "r": 7.5, "rgb": Lighting.WARM, "glow": 0.12})
	return out


## Lueur cyan des glyphes du coffre antique, plus vive une fois le couvercle ouvert ; aucune tant qu'il est éteint.
func _vault_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Capsule.chest_active():
		var opened := GameState.sim_time >= GameState.chest_opened_at
		out.append({"x": CaveShape.CHEST.x, "z": CaveShape.CHEST.y - 1.0, "r": 9.0 if opened else 5.5,
			"rgb": Color8(92, 232, 255), "glow": 0.22 if opened else 0.12})
	return out


## Lueur du phare de butin (planches/butin-propositions.html, piste 1) : un corps, une cache ou un objet au sol qui
## porte mieux que du normal éclaire le sol à la couleur de sa rareté, en pulsant comme le disque du phare.
func _loot_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := GameState.sim_time
	var add := func(x: float, z: float, rarity: String) -> void:
		if rarity == "normal" or not fog.visible_at(Vector2(x, z)):
			return
		var k := 0.5 + 0.5 * sin(t * 3.0 + x * 0.3)
		out.append({"x": x, "z": z, "r": 4.5 + 1.0 * k, "rgb": Loot.RARITY[rarity]["color"], "glow": 0.16 + 0.06 * k})
	for corpse: Enemy in GameState.enemy_corpses:
		if not corpse.loot.is_empty() and t - corpse.died_at >= 1.0:
			add.call(corpse.x, corpse.z, Loot.best_rarity(corpse.loot))
	for cache: Dictionary in GameState.caches:
		if not (cache["loot"] as Array).is_empty():
			add.call(float(cache["x"]), float(cache["z"]), Loot.best_rarity(cache["loot"]))
	for drop: Dictionary in GameState.ground_items:
		var at: Vector2 = drop["position"]
		add.call(at.x, at.y, Loot.rarity_of(drop["item"]))
	return out


## Lumières des unités (collectLights) : 8 × scintillement, chaude.
func _unit_lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in GameState.units:
		if u.alive() and not u.hidden:
			out.append({"x": u.x, "z": u.z, "r": 8.0 * Lighting.flick(GameState.sim_time, u.id), "rgb": Lighting.WARM, "glow": 0.14})
	return out


func unit_view(u: Unit) -> Node2D:
	return _unit_views.get(u, _enemy_views.get(u))


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
	_fog_material.set_shader_parameter("map_position", position + Vector2(fog.ORIGIN) * Proj.K * px)
	_fog_material.set_shader_parameter("map_size", Vector2(fog.SIZE) * Proj.K * px)
	for a in _anchors:
		if is_instance_valid(a):
			a.place(native_offset)
	_fog_material.set_shader_parameter("px", float(px))
	_snap.set_shader_parameter("px", float(px))
	_sprites_mat.set_shader_parameter("px", float(px))
	_sprites_mat.set_shader_parameter("world_origin", position)
	_stream_decor()
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
