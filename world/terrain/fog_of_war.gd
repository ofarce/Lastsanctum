extends RefCounted
## Une case du terrain mesure quatre unités. Le masque a un texel par unité pour
## conserver la silhouette du chemin permanent aux bords de la montagne.
const ORIGIN := Vector2i(int(CaveShape.WORLD_X0), int(CaveShape.WORLD_Z0))
const SIZE := Vector2i(int(CaveShape.WORLD_X1 - CaveShape.WORLD_X0), int(CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0))
const CELL_SIZE := 4
const TORCH_SPACING := 4 * CELL_SIZE
# Force de vision aux distances de 3 à 5 cases, interpolée entre chaque repère ; au-delà de 5 cases, seul le voile
# d'exploration subsiste (7 → 6 → 5 cases le 2026-11-19). Ce qu'une source amie voit (force > 0) s'affiche sans aucun
# voile (2026-11-20) : la force ne sert plus qu'au maximum entre sources.
const VISIBILITY := [1.0, 0.6, 0.2]
const RADIUS := 5 * CELL_SIZE
## Rayon au-delà duquel la zone de détection d'une unité n'est plus suivie (poste de tir + Empennage : 36,5).
const MAX_RADIUS := 12 * CELL_SIZE
const WALL_DEPTH := 2 * 4
const WIDTH := RADIUS * 2 + 1
# Les rayons relatifs, par rayon de vision, sont partagés entre toutes les sources et les parties :
# {rayon: {"w": largeur, "shadows": [...], "penumbra": [...], "bands": PackedByteArray}}.
static var _kits := {}

var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
# Zone explorée hors de vue : 20 % de visibilité.
const EXPLORED_ALPHA := 204
var _explored_pixels: PackedByteArray
var _current_visibility := PackedByteArray()
## Pixels affichés (explorés + visibilité courante), gardés d'un rafraîchissement à l'autre ; vide = à recomposer.
var _pixels := PackedByteArray()
## Au-delà de ce nombre de sources disparues d'un coup, la composition complète est faite d'office.
const MAX_LOCAL := 8
var texture: ImageTexture
var spark_lights: Callable
var revision := 0
var road_torches := PackedVector2Array()
## Champ de vision par source, clé Vector3i(x, z, rayon).
var _sources := {}
var _terrain_version := -1
var _solid_tiles := {}


func _init() -> void:
	reset_exploration()
	# Une lumière tous les quatre carreaux ; les halos se recouvrent sur la chaussée.
	for z in range(int(CaveShape.CAVE_Z1), int(CaveShape.WORLD_Z1), TORCH_SPACING):
		road_torches.append(Vector2(0, z))



func reset_exploration() -> void:
	image.fill(Color.BLACK)
	_explored_pixels = image.get_data()
	# La jungle (au sud du flanc) est connue dès le départ : explorée, mais les créatures n'y sont vues
	# que dans le champ de vision.
	for x in SIZE.x:
		var wx := float(ORIGIN.x + x) + 0.5
		var y0 := maxi(0, ceili(CaveShape.mountain_edge(wx) + 1.0) - ORIGIN.y)
		for y in range(y0, SIZE.y):
			_explored_pixels[(y * SIZE.x + x) * 4 + 3] = EXPLORED_ALPHA
	image.set_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, _explored_pixels)
	_current_visibility.resize(SIZE.x * SIZE.y)
	_current_visibility.fill(0)
	_pixels = PackedByteArray()
	_sources.clear()


func refresh(st: TerrainState) -> void:
	var r := RADIUS
	var sources := {Vector3i(floori(CaveShape.CORE.x), floori(CaveShape.CORE.y), r): true}
	for torch in road_torches:
		sources[Vector3i(int(torch.x), int(torch.y), r)] = true
	sources[Vector3i(floori(Simulation.PORTAL.x), floori(Simulation.PORTAL.y), r)] = true
	for portal in st.portals:
		if portal.get("active", false):
			sources[Vector3i(floori(portal["x"]), floori(portal["z"]), r)] = true
	if spark_lights.is_valid():
		for light: Dictionary in spark_lights.call():
			sources[Vector3i(floori(light["x"]), floori(light["z"]), r)] = true
	if st.vault_open:
		sources[Vector3i(floori(CaveShape.CHEST.x), floori(CaveShape.CHEST.y), r)] = true
	# L'Œil de la Matrice éveillé : sa lueur montre toute la salle.
	if OeilMatrice.active():
		var eye := TerrainState.eye_room_center()
		for dx: float in [-34.0, 0.0, 34.0]:
			sources[Vector3i(floori(eye.x + dx), floori(eye.y), r)] = true
		sources[Vector3i(0, floori(TerrainState.frontier_z() + TerrainState.FRONTIER_HALF + 1.0), r)] = true
	# Chaque unité voit au moins jusqu'à sa zone de détection (portée + marge d'engagement, arrondie à la case).
	for u in GameState.units:
		if u.alive() and not u.hidden:
			sources[Vector3i(floori(u.x), floori(u.z), vision_radius(u))] = true
	for b in GameState.buildings:
		if b.complete:
			sources[Vector3i(floori(b.x), floori(b.z), r)] = true
	for turret in GameState.turrets:
		if turret["complete"]:
			sources[Vector3i(floori(turret["x"]), floori(turret["z"]), r)] = true
	var rebuild := _pixels.is_empty()
	if _terrain_version != st.version:
		_sources.clear()
		_solid_tiles.clear()
		_terrain_version = st.version
		rebuild = true
	if sources.size() == _sources.size() and _sources.has_all(sources.keys()):
		return

	# Réutilise le champ de vision des sources immobiles ; élimine les anciennes positions.
	var next := {}
	var added: Array[Vector3i] = []
	for key: Vector3i in sources:
		if not _sources.has(key):
			_sources[key] = _field(st, key)
			added.append(key)
		next[key] = _sources[key]
	var removed: Array[Vector3i] = []
	for key: Vector3i in _sources:
		if not next.has(key):
			removed.append(key)
	_sources = next
	# Coût (en cases parcourues) de la recomposition locale ; au-delà de la composition complète, on y renonce.
	if not rebuild and removed.size() <= MAX_LOCAL:
		var cost := 0
		var full := 0
		for key: Vector3i in _sources:
			full += _square(key).get_area()
		for key in added:
			cost += _square(key).get_area()
		for gone: Vector3i in removed:
			var square := _square(gone)
			cost += square.get_area()
			for key: Vector3i in _sources:
				cost += square.intersection(_square(key)).get_area()
		rebuild = cost >= full
	var whole := Rect2i(Vector2i.ZERO, SIZE)
	if rebuild or removed.size() > MAX_LOCAL:
		# Composer les sources par maximum de visibilité, y compris aux intersections.
		_pixels = _explored_pixels.duplicate()
		_current_visibility.fill(0)
		for key: Vector3i in _sources:
			_apply(key, whole)
	else:
		# Quelques sources ont bougé : le maximum n'est recomposé que dans le carré des sources disparues (toutes
		# les sources qui le recouvrent y sont rejouées), puis les nouvelles s'ajoutent. Même résultat que la
		# composition complète : hors de ces carrés, aucune source n'a changé.
		for gone: Vector3i in removed:
			var square := _square(gone).intersection(whole)
			for y in range(square.position.y, square.end.y):
				var row := y * SIZE.x
				for x in range(square.position.x, square.end.x):
					var cell := row + x
					_current_visibility[cell] = 0
					_pixels[cell * 4 + 3] = _explored_pixels[cell * 4 + 3]
			for key: Vector3i in _sources:
				if square.intersects(_square(key)):
					_apply(key, square)
		for key in added:
			_apply(key, whole)
	image.set_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, _pixels)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	revision += 1


## Carré couvert par le champ de la source `key`, en texels de la carte.
static func _square(key: Vector3i) -> Rect2i:
	return Rect2i(Vector2i(key.x - key.z, key.y - key.z) - ORIGIN, Vector2i.ONE * (key.z * 2 + 1))


## Rayon de vision d'une unité : sa zone de détection (portée d'attaque ou de sort + marge d'engagement), au moins
## RADIUS, arrondie à la case supérieure (peu de tables de rayons, pas de recalcul à chaque variation de brume).
static func vision_radius(u: Unit) -> int:
	var detect := 0.0
	if Catalog.is_mage(u.role):
		detect = float(Catalog.MAGE.get(u.role, {}).get("reach", 0.0))
	elif u.role != "engineer":
		detect = Catalog.unit_reach(u) + Combat.ENGAGE_MARGIN
	if detect <= RADIUS:
		return RADIUS
	return mini(MAX_RADIUS, ceili(detect / CELL_SIZE) * CELL_SIZE)


## Ajoute par maximum le champ de vision de la source `key`, limité au rectangle `clip` de la carte.
func _apply(key: Vector3i, clip: Rect2i) -> void:
	var field: PackedByteArray = _sources[key]
	var w := key.z * 2 + 1
	var square := _square(key)
	var area := square.intersection(clip)
	for y in range(area.position.y, area.end.y):
		var row := y * SIZE.x
		var frow := (y - square.position.y) * w - square.position.x
		for x in range(area.position.x, area.end.x):
			var strength := field[frow + x]
			var cell := row + x
			if strength > _current_visibility[cell]:
				_current_visibility[cell] = strength
				var alpha_index := cell * 4 + 3
				_pixels[alpha_index] = 0
				_explored_pixels[alpha_index] = EXPLORED_ALPHA


## Masque local des obstacles à la résolution native des galeries (1 unité).
## Les blocs de 4 × 4 évitent de recalculer walkable dans les zones déjà parcourues.
func _obstacles(st: TerrainState, origin: Vector2i, radius: int) -> PackedByteArray:
	var w := radius * 2 + 1
	var solid := PackedByteArray()
	solid.resize(w * w)
	var corner := origin - Vector2i(radius, radius)
	var end := origin + Vector2i(radius, radius)
	for j in range(floori(corner.y / 4.0), floori(end.y / 4.0) + 1):
		for i in range(floori(corner.x / 4.0), floori(end.x / 4.0) + 1):
			var tile := Vector2i(i, j)
			if not _solid_tiles.has(tile):
				var bits := 0
				for y in 4:
					for x in 4:
						if not st.ground(i * 4 + x + 0.5, j * 4 + y + 0.5):
							bits |= 1 << (4 * y + x)
				_solid_tiles[tile] = bits
			var bits: int = _solid_tiles[tile]
			if bits == 0:
				continue
			var offset := tile * 4 - corner
			for y in range(maxi(0, -offset.y), mini(4, w - offset.y)):
				for x in range(maxi(0, -offset.x), mini(4, w - offset.x)):
					if bits & (1 << (4 * y + x)):
						solid[(offset.y + y) * w + offset.x + x] = 1
	return solid


## Parcours supercover entre centres de texels. Les deux voisins d'un sommet
## bloquent la diagonale. La destination est exclue pour montrer la face du premier mur.
## Une table par rayon : la force décroît sur les deux dernières cases (repères VISIBILITY).
static func _kit(radius: int) -> Dictionary:
	if _kits.has(radius):
		return _kits[radius]
	var w := radius * 2 + 1
	var bands := PackedByteArray()
	bands.resize(w * w)
	var shadows: Array[PackedInt32Array] = []
	var penumbra: Array[PackedInt32Array] = []
	for i in w * w:
		shadows.append(PackedInt32Array())
		penumbra.append(PackedInt32Array())
	var fade_start := float(radius) / CELL_SIZE - (VISIBILITY.size() - 1)
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var delta := Vector2i(x, y)
			var target := (y + radius) * w + x + radius
			if delta.length_squared() > radius * radius:
				continue
			var distance := clampf(delta.length() / CELL_SIZE - fade_start, 0.0, VISIBILITY.size() - 1)
			var index := floori(distance)
			var fraction := distance - index
			var strength := lerpf(VISIBILITY[index], VISIBILITY[mini(index + 1, VISIBILITY.size() - 1)], fraction)
			bands[target] = 255 - roundi((1.0 - strength) * 255.0)
			var at := Vector2i.ZERO
			var direction := delta.sign()
			var count := delta.abs()
			while at != delta:
				var decision := (1 + 2 * absi(at.x)) * count.y - (1 + 2 * absi(at.y)) * count.x
				var idx := (at.y + radius) * w + at.x + radius
				if decision == 0:
					_record_shadow(shadows, penumbra, w, idx + direction.x, target)
					_record_shadow(shadows, penumbra, w, idx + direction.y * w, target)
				if decision <= 0:
					at.x += direction.x
				if decision >= 0:
					at.y += direction.y
				if at != delta:
					_record_shadow(shadows, penumbra, w, (at.y + radius) * w + at.x + radius, target)
	var kit := {"w": w, "shadows": shadows, "penumbra": penumbra, "bands": bands}
	_kits[radius] = kit
	return kit


static func _record_shadow(shadows: Array[PackedInt32Array], penumbra: Array[PackedInt32Array], w: int, blocker: int,
		target: int) -> void:
	var dx := target % w - blocker % w
	var dy := floori(float(target) / w) - floori(float(blocker) / w)
	if dx * dx + dy * dy <= WALL_DEPTH * WALL_DEPTH:
		penumbra[blocker].append(target)
	else:
		shadows[blocker].append(target)


func _field(st: TerrainState, key: Vector3i) -> PackedByteArray:
	var radius := key.z
	var kit := _kit(radius)
	var w: int = kit["w"]
	var solid := _obstacles(st, Vector2i(key.x, key.y), radius)
	solid[radius * w + radius] = 0
	var levels: PackedByteArray = kit["bands"].duplicate()
	if solid.has(1):
		# Les rayons rencontrent d'abord une paroi bordant le sol libre. Chaque
		# texel de paroi applique son ombre précalculée à toutes ses destinations.
		var shadows: Array[PackedInt32Array] = kit["shadows"]
		var penumbra: Array[PackedInt32Array] = kit["penumbra"]
		for y in range(1, w - 1):
			for x in range(1, w - 1):
				var k := y * w + x
				if not solid[k]:
					continue
				if (solid[k - 1] and solid[k + 1] and solid[k - w] and solid[k + w]
						and solid[k - w - 1] and solid[k - w + 1]
						and solid[k + w - 1] and solid[k + w + 1]):
					continue
				for target in penumbra[k]:
					levels[target] = mini(127, levels[target])
				for target in shadows[k]:
					levels[target] = 0
	return levels


## Déjà exploré (vu au moins une fois), même hors du champ de vision actuel.
func explored_at(point: Vector2) -> bool:
	var p := Vector2i(point.floor()) - ORIGIN
	return Rect2i(Vector2i.ZERO, SIZE).has_point(p) and _explored_pixels[(p.y * SIZE.x + p.x) * 4 + 3] < 255


func visible_at(point: Vector2) -> bool:
	var p := Vector2i(point.floor()) - ORIGIN
	return Rect2i(Vector2i.ZERO, SIZE).has_point(p) and _current_visibility[p.y * SIZE.x + p.x] > 0
