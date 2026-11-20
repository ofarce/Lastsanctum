extends RefCounted
## Une case du terrain mesure quatre unités. Le masque a un texel par unité pour
## conserver la silhouette du chemin permanent aux bords de la montagne.
const ORIGIN := Vector2i(int(CaveShape.WORLD_X0), int(CaveShape.WORLD_Z0))
const SIZE := Vector2i(int(CaveShape.WORLD_X1 - CaveShape.WORLD_X0), int(CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0))
const CELL_SIZE := 4
const TORCH_SPACING := 4 * CELL_SIZE
# Visibilité aux distances de 3 à 5 cases, interpolée entre chaque repère ;
# au-delà de 5 cases, seul le voile d'exploration subsiste (7 → 6 → 5 cases le 2026-11-19).
const VISIBILITY := [1.0, 0.6, 0.2]
const RADIUS := 5 * CELL_SIZE
const WALL_DEPTH := 2 * 4
const WIDTH := RADIUS * 2 + 1
# Les rayons relatifs sont partagés entre toutes les sources et les parties.
static var _shadows: Array[PackedInt32Array] = []
static var _penumbra: Array[PackedInt32Array] = []
static var _bands := PackedByteArray()

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
var _sources := {}
var _terrain_version := -1
var _solid_tiles := {}


func _init() -> void:
	reset_exploration()
	if _shadows.is_empty():
		_prepare_rays()
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
	var sources := {Vector2i(CaveShape.CORE.floor()): true}
	for torch in road_torches:
		sources[Vector2i(torch)] = true
	sources[Vector2i(Simulation.PORTAL.floor())] = true
	for portal in st.portals:
		if portal.get("active", false):
			sources[Vector2i(floori(portal["x"]), floori(portal["z"]))] = true
	if spark_lights.is_valid():
		for light: Dictionary in spark_lights.call():
			sources[Vector2i(floori(light["x"]), floori(light["z"]))] = true
	if st.vault_open:
		sources[Vector2i(CaveShape.CHEST.floor())] = true
	# L'Œil de la Matrice éveillé : sa lueur montre toute la salle.
	if OeilMatrice.active():
		var eye := TerrainState.eye_room_center()
		for dx: float in [-34.0, 0.0, 34.0]:
			sources[Vector2i(floori(eye.x + dx), floori(eye.y))] = true
		sources[Vector2i(0, floori(TerrainState.frontier_z() + TerrainState.FRONTIER_HALF + 1.0))] = true
	for u in GameState.units:
		if u.alive() and not u.hidden:
			sources[Vector2i(u.pos().floor())] = true
	for b in GameState.buildings:
		if b.complete:
			sources[Vector2i(floori(b.x), floori(b.z))] = true
	for turret in GameState.turrets:
		if turret["complete"]:
			sources[Vector2i(floori(turret["x"]), floori(turret["z"]))] = true
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
	var added: Array[Vector2i] = []
	for origin: Vector2i in sources:
		if not _sources.has(origin):
			_sources[origin] = _field(st, origin)
			added.append(origin)
		next[origin] = _sources[origin]
	var removed: Array[Vector2i] = []
	for origin: Vector2i in _sources:
		if not next.has(origin):
			removed.append(origin)
	_sources = next
	# Coût (en cases parcourues) de la recomposition locale ; au-delà de la composition complète, on y renonce.
	if not rebuild and removed.size() <= MAX_LOCAL:
		var cost := (removed.size() + added.size()) * WIDTH * WIDTH
		for gone: Vector2i in removed:
			for origin: Vector2i in _sources:
				var d := (gone - origin).abs()
				if d.x < WIDTH and d.y < WIDTH:
					cost += (WIDTH - d.x) * (WIDTH - d.y)
		rebuild = cost >= _sources.size() * WIDTH * WIDTH
	if rebuild or removed.size() > MAX_LOCAL:
		# Composer les sources par maximum de visibilité, y compris aux intersections.
		_pixels = _explored_pixels.duplicate()
		_current_visibility.fill(0)
		for origin: Vector2i in _sources:
			_apply(origin, 0, WIDTH, 0, WIDTH)
	else:
		# Quelques sources ont bougé : le maximum n'est recomposé que dans le carré des sources disparues (toutes
		# les sources qui le recouvrent y sont rejouées), puis les nouvelles s'ajoutent. Même résultat que la
		# composition complète : hors de ces carrés, aucune source n'a changé.
		for gone: Vector2i in removed:
			var corner := gone - Vector2i(RADIUS, RADIUS) - ORIGIN
			var y0 := maxi(0, -corner.y)
			var y1 := mini(WIDTH, SIZE.y - corner.y)
			var x0 := maxi(0, -corner.x)
			var x1 := mini(WIDTH, SIZE.x - corner.x)
			for y in range(y0, y1):
				var row := (corner.y + y) * SIZE.x + corner.x
				for x in range(x0, x1):
					var cell := row + x
					_current_visibility[cell] = 0
					_pixels[cell * 4 + 3] = _explored_pixels[cell * 4 + 3]
			for origin: Vector2i in _sources:
				var d := gone - origin
				if absi(d.x) >= WIDTH or absi(d.y) >= WIDTH:
					continue
				# Partie du champ de `origin` qui tombe dans le carré de `gone` (repère du champ).
				_apply(origin, maxi(0, d.y), mini(WIDTH, WIDTH + d.y), maxi(0, d.x), mini(WIDTH, WIDTH + d.x))
		for origin in added:
			_apply(origin, 0, WIDTH, 0, WIDTH)
	image.set_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, _pixels)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	revision += 1


## Ajoute par maximum le champ de vision de la source `origin`, limité aux lignes [fy0, fy1[ et colonnes
## [fx0, fx1[ de son champ (et à la carte).
func _apply(origin: Vector2i, fy0: int, fy1: int, fx0: int, fx1: int) -> void:
	var field: PackedByteArray = _sources[origin]
	var corner := origin - Vector2i(RADIUS, RADIUS) - ORIGIN
	var x0 := maxi(fx0, -corner.x)
	var x1 := mini(fx1, SIZE.x - corner.x)
	for y in range(maxi(fy0, -corner.y), mini(fy1, SIZE.y - corner.y)):
		var row := (corner.y + y) * SIZE.x + corner.x
		for x in range(x0, x1):
			var strength := field[y * WIDTH + x]
			var cell := row + x
			if strength > _current_visibility[cell]:
				_current_visibility[cell] = strength
				var alpha_index := cell * 4 + 3
				_pixels[alpha_index] = 255 - strength
				_explored_pixels[alpha_index] = EXPLORED_ALPHA


## Masque local des obstacles à la résolution native des galeries (1 unité).
## Les blocs de 4 × 4 évitent de recalculer walkable dans les zones déjà parcourues.
func _obstacles(st: TerrainState, origin: Vector2i) -> PackedByteArray:
	var solid := PackedByteArray()
	solid.resize(WIDTH * WIDTH)
	var corner := origin - Vector2i(RADIUS, RADIUS)
	var end := origin + Vector2i(RADIUS, RADIUS)
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
			for y in range(maxi(0, -offset.y), mini(4, WIDTH - offset.y)):
				for x in range(maxi(0, -offset.x), mini(4, WIDTH - offset.x)):
					if bits & (1 << (4 * y + x)):
						solid[(offset.y + y) * WIDTH + offset.x + x] = 1
	return solid


## Parcours supercover entre centres de texels. Les deux voisins d'un sommet
## bloquent la diagonale. La destination est exclue pour montrer la face du premier mur.
static func _prepare_rays() -> void:
	_bands.resize(WIDTH * WIDTH)
	for i in WIDTH * WIDTH:
		_shadows.append(PackedInt32Array())
		_penumbra.append(PackedInt32Array())
	for y in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			var delta := Vector2i(x, y)
			var target := (y + RADIUS) * WIDTH + x + RADIUS
			if delta.length_squared() > RADIUS * RADIUS:
				continue
			var distance := clampf(delta.length() / CELL_SIZE - 3.0, 0.0, VISIBILITY.size() - 1)
			var index := floori(distance)
			var fraction := distance - index
			var strength := lerpf(VISIBILITY[index], VISIBILITY[mini(index + 1, VISIBILITY.size() - 1)], fraction)
			_bands[target] = 255 - roundi((1.0 - strength) * 255.0)
			var at := Vector2i.ZERO
			var direction := delta.sign()
			var count := delta.abs()
			while at != delta:
				var decision := (1 + 2 * absi(at.x)) * count.y - (1 + 2 * absi(at.y)) * count.x
				var idx := (at.y + RADIUS) * WIDTH + at.x + RADIUS
				if decision == 0:
					_record_shadow(idx + direction.x, target)
					_record_shadow(idx + direction.y * WIDTH, target)
				if decision <= 0:
					at.x += direction.x
				if decision >= 0:
					at.y += direction.y
				if at != delta:
					_record_shadow((at.y + RADIUS) * WIDTH + at.x + RADIUS, target)


static func _record_shadow(blocker: int, target: int) -> void:
	var dx := target % WIDTH - blocker % WIDTH
	var dy := floori(float(target) / WIDTH) - floori(float(blocker) / WIDTH)
	if dx * dx + dy * dy <= WALL_DEPTH * WALL_DEPTH:
		_penumbra[blocker].append(target)
	else:
		_shadows[blocker].append(target)


func _field(st: TerrainState, origin: Vector2i) -> PackedByteArray:
	var solid := _obstacles(st, origin)
	solid[RADIUS * WIDTH + RADIUS] = 0
	var levels := _bands.duplicate()
	if solid.has(1):
		# Les rayons rencontrent d'abord une paroi bordant le sol libre. Chaque
		# texel de paroi applique son ombre précalculée à toutes ses destinations.
		for y in range(1, WIDTH - 1):
			for x in range(1, WIDTH - 1):
				var k := y * WIDTH + x
				if not solid[k]:
					continue
				if (solid[k - 1] and solid[k + 1] and solid[k - WIDTH] and solid[k + WIDTH]
						and solid[k - WIDTH - 1] and solid[k - WIDTH + 1]
						and solid[k + WIDTH - 1] and solid[k + WIDTH + 1]):
					continue
				for target in _penumbra[k]:
					levels[target] = mini(127, levels[target])
				for target in _shadows[k]:
					levels[target] = 0
	return levels


## Déjà exploré (vu au moins une fois), même hors du champ de vision actuel.
func explored_at(point: Vector2) -> bool:
	var p := Vector2i(point.floor()) - ORIGIN
	return Rect2i(Vector2i.ZERO, SIZE).has_point(p) and _explored_pixels[(p.y * SIZE.x + p.x) * 4 + 3] < 255


func visible_at(point: Vector2) -> bool:
	var p := Vector2i(point.floor()) - ORIGIN
	return Rect2i(Vector2i.ZERO, SIZE).has_point(p) and _current_visibility[p.y * SIZE.x + p.x] > 0
