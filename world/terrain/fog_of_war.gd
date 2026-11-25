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
## Vision de l'Exilé incarné : le double de RADIUS.
const PLAYER_RADIUS := 2 * RADIUS
const WALL_DEPTH := 2 * 4
const WIDTH := RADIUS * 2 + 1
# Les rayons relatifs, par rayon de vision, sont partagés entre toutes les sources et les parties :
# {rayon: {"w": largeur, "shadows": [...], "penumbra": [...], "bands": PackedByteArray}}.
static var _kits := {}

var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
# Zone explorée hors de vue : 20 % de visibilité.
const EXPLORED_ALPHA := 204
## Le Temple (biome 1, jungle comprise : tout ce qui est au sud de la frontière de l'Œil) est découvert d'emblée
## (demande du 2026-11-22) : rangée de l'image à partir de laquelle tout est exploré. Depuis le 2026-11-23, ce qui
## n'est pas dans le champ de vision y garde le voile d'exploration (EXPLORED_ALPHA), comme une zone déjà visitée.
static var clear_row := maxi(0, ceili(Biomes.north_z(0) - CaveShape.WORLD_Z0))
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
## Murs pleins du Temple (2026-11-22) : sans brouillard ailleurs, la roche massive (case de 4 et ses 8 voisines
## pleines) y reste voilée ; les galeries et le liseré de paroi qui les borde restent clairs.
## _wall_built : le masque a été posé au moins une fois depuis la remise à zéro.
var _wall_built := false


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
	_clear_temple()
	image.set_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, _explored_pixels)
	_current_visibility.resize(SIZE.x * SIZE.y)
	_current_visibility.fill(0)
	_pixels = PackedByteArray()
	_sources.clear()
	_wall_built = false


## Temple entièrement découvert : voile d'exploration partout hors de vue (les murs pleins restent à 255). Au nord de
## clear_row, un dégradé de CLEAR_FADE rangées remonte vers le brouillard ; il ne fonce jamais une zone déjà explorée.
const CLEAR_FADE := 16


func _clear_temple() -> void:
	for y in range(maxi(0, clear_row - CLEAR_FADE), SIZE.y):
		var a := EXPLORED_ALPHA if y >= clear_row \
			else EXPLORED_ALPHA + roundi((255.0 - EXPLORED_ALPHA) * float(clear_row - y) / float(CLEAR_FADE + 1))
		for x in SIZE.x:
			var i := (y * SIZE.x + x) * 4 + 3
			var e := _explored_pixels[i]
			# Sauvegarde d'avant le 2026-11-23 : le sol du Temple y était à 0 (clair même hors de vue).
			if (y >= clear_row and e < 255 and e != a) or (y < clear_row and a < e):
				_explored_pixels[i] = a


## Temple sans brouillard, mais pas sur du sol encore à peindre (il se verrait en noir) : World voile les cases mises
## en file de peinture (veil_cell), puis le peintre les découvre une à une (unveil_cell), d'abord à l'écran.
var _cells_dirty := false


func _set_cell_alpha(c: Vector2, a: int) -> void:
	var x0 := int(c.x) - ORIGIN.x
	var y0 := int(c.y) - ORIGIN.y
	if y0 + CELL_SIZE <= clear_row:
		return
	for y in range(maxi(y0, clear_row), mini(y0 + CELL_SIZE, SIZE.y)):
		for x in range(maxi(x0, 0), mini(x0 + CELL_SIZE, SIZE.x)):
			var i := (y * SIZE.x + x) * 4 + 3
			_explored_pixels[i] = a
			# La case se découvre aussi tout de suite à l'image (sinon tache noire au départ, où rien ne recompose les
			# sources) : en clair dans le champ de vision, sous le voile d'exploration au-dehors.
			if not _pixels.is_empty():
				_pixels[i] = 0 if a < 255 and _current_visibility[i >> 2] > 0 else a
	_cells_dirty = true


## Cases voilées en attente de peinture (Vector2i de case) : le masque des murs ne les découvre pas avant le peintre.
var _veiled := {}
## Cases découvertes avant que le terrain soit connu (pas encore de refresh) : masque des murs à reposer.
var _unveiled: Array[Vector2i] = []
var _st: TerrainState


func _cell_tile(c: Vector2) -> Vector2i:
	return Vector2i(floori((c.x - ORIGIN.x) / CELL_SIZE), floori((c.y - ORIGIN.y) / CELL_SIZE))


func veil_cell(c: Vector2) -> void:
	_veiled[_cell_tile(c)] = true
	_set_cell_alpha(c, 255)


## Découvre la case peinte, sauf si c'est de la roche massive : elle garde aussitôt son voile de mur plein
## (sinon le voile des murs ne revenait qu'au minage, quand _paint_walls repasse autour des unités).
func unveil_cell(c: Vector2) -> void:
	var tile := _cell_tile(c)
	_veiled.erase(tile)
	if _st == null:
		_unveiled.append(tile)
		_set_cell_alpha(c, EXPLORED_ALPHA)
		return
	_set_cell_alpha(c, 255 if _full_rock(_st, tile) else EXPLORED_ALPHA)


## Case de 4 sans sol à son centre, ainsi que ses 8 voisines.
func _full_rock(st: TerrainState, tile: Vector2i) -> bool:
	for j in range(-1, 2):
		for i in range(-1, 2):
			var wx := float(ORIGIN.x + (tile.x + i) * CELL_SIZE) + 2.0
			var wz := float(ORIGIN.y + (tile.y + j) * CELL_SIZE) + 2.0
			if st.ground(wx, wz):
				return false
	return true


## Zones explorées (canal alpha de l'image), pour la sauvegarde.
func explored_data() -> PackedByteArray:
	return _explored_pixels


func set_explored_data(data: PackedByteArray) -> void:
	if data.size() != _explored_pixels.size():
		return
	_explored_pixels = data
	# Une sauvegarde d'avant le Temple sans brouillard le remettrait : on le redégage.
	_clear_temple()
	image.set_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, _explored_pixels)
	_pixels = PackedByteArray()
	_sources.clear()
	_wall_built = false


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
	_st = st
	if not _unveiled.is_empty():
		for tile in _unveiled:
			if _full_rock(st, tile):
				_set_cell_alpha(Vector2(ORIGIN + tile * CELL_SIZE), 255)
		_unveiled.clear()
	if _terrain_version != st.version:
		_sources.clear()
		_solid_tiles.clear()
		_terrain_version = st.version
		rebuild = true
		_paint_walls(st, not _wall_built)
	elif not _wall_built:
		_paint_walls(st, true)
		rebuild = true
	if sources.size() == _sources.size() and _sources.has_all(sources.keys()):
		# Cases du Temple découvertes au fil de la peinture : l'image suit sans recomposer les sources.
		if _cells_dirty and not _pixels.is_empty():
			_cells_dirty = false
			image.set_data(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8, _pixels)
			texture.update(image)
			revision += 1
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
	_cells_dirty = false
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
	# Lanterne de Medeina (sim/mods.gd) : quelques cases de plus.
	var bonus := Mods.vision_bonus(u)
	# L'Exilé incarné (le joueur) voit deux fois plus loin (2026-11-23).
	if u == GameState.incarnated:
		return maxi(PLAYER_RADIUS, ceili(detect / CELL_SIZE) * CELL_SIZE) + bonus
	if detect <= RADIUS:
		return RADIUS + bonus
	return mini(MAX_RADIUS, ceili(detect / CELL_SIZE) * CELL_SIZE + bonus)


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
				if y < clear_row:
					_pixels[alpha_index] = 0
					_explored_pixels[alpha_index] = EXPLORED_ALPHA
				elif _explored_pixels[alpha_index] < 255:
					# Temple : clair dans le champ de vision ; mur plein et sol encore à peindre restent voilés.
					_pixels[alpha_index] = 0


## Masque des murs pleins du Temple, écrit dans _explored_pixels (255 = mur plein, EXPLORED_ALPHA = galerie).
## `whole` : toute la zone ; sinon seulement autour des unités (là où l'on creuse), pour rester bon marché.
const WALL_WINDOW := 64
func _paint_walls(st: TerrainState, whole: bool) -> void:
	var t0 := Vector2i(0, floori(float(clear_row) / CELL_SIZE))
	var t1 := Vector2i(ceili(float(SIZE.x) / CELL_SIZE), ceili(float(SIZE.y) / CELL_SIZE))
	var areas: Array[Rect2i] = []
	if whole:
		areas.append(Rect2i(t0, t1 - t0))
	else:
		for u in GameState.units:
			if u.alive():
				var c := (Vector2i(floori(u.x), floori(u.z)) - ORIGIN) / CELL_SIZE
				var r := WALL_WINDOW / CELL_SIZE
				areas.append(Rect2i(c - Vector2i(r, r), Vector2i(r, r) * 2 + Vector2i.ONE).intersection(Rect2i(t0, t1 - t0)))
	_wall_built = true
	for area in areas:
		if not area.has_area():
			continue
		# Pleins : case de 4 sans sol à son centre, sur l'aire élargie d'une case pour le test des voisines.
		var big := area.grow(1)
		var bw := big.size.x
		var rock := PackedByteArray()
		rock.resize(bw * big.size.y)
		for j in big.size.y:
			for i in bw:
				var wx := float(ORIGIN.x + (big.position.x + i) * CELL_SIZE) + 2.0
				var wz := float(ORIGIN.y + (big.position.y + j) * CELL_SIZE) + 2.0
				rock[j * bw + i] = 0 if st.ground(wx, wz) else 1
		for j in range(1, big.size.y - 1):
			for i in range(1, bw - 1):
				var k := j * bw + i
				var full := rock[k] and rock[k - 1] and rock[k + 1] and rock[k - bw] and rock[k + bw] \
					and rock[k - bw - 1] and rock[k - bw + 1] and rock[k + bw - 1] and rock[k + bw + 1]
				var a := 255 if full else EXPLORED_ALPHA
				var tx := (big.position.x + i) * CELL_SIZE
				var ty := (big.position.y + j) * CELL_SIZE
				# Sol encore à peindre : le voile reste jusqu'au peintre (unveil_cell).
				if a < 255 and _veiled.has(Vector2i(big.position.x + i, big.position.y + j)):
					continue
				var probe := (mini(maxi(ty, clear_row) + 1, SIZE.y - 1) * SIZE.x + mini(tx + 1, SIZE.x - 1)) * 4 + 3
				if _explored_pixels[probe] == a:
					continue
				for y in range(maxi(ty, clear_row), mini(ty + CELL_SIZE, SIZE.y)):
					var row := y * SIZE.x
					for x in range(tx, mini(tx + CELL_SIZE, SIZE.x)):
						_explored_pixels[(row + x) * 4 + 3] = a


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


## Dans le champ de vision actuel. Depuis le 2026-11-23, le Temple suit la même règle : hors de vue, ses créatures,
## tirs et butins sont cachés sous le voile d'exploration.
func visible_at(point: Vector2) -> bool:
	var p := Vector2i(point.floor()) - ORIGIN
	return Rect2i(Vector2i.ZERO, SIZE).has_point(p) and _current_visibility[p.y * SIZE.x + p.x] > 0


## Connu du joueur pour y agir (bâtir, miner, cliquer un bâtiment, un pylône ou un bosquet) : dans le champ de
## vision, ou n'importe où dans le Temple, entièrement découvert.
func known_at(point: Vector2) -> bool:
	var p := Vector2i(point.floor()) - ORIGIN
	if p.y >= clear_row and Rect2i(Vector2i.ZERO, SIZE).has_point(p):
		return true
	return visible_at(point)
