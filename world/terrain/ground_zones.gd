class_name GroundZones
extends Sprite2D
## Sol de la jungle teinté par sous-zone (Flora.zone_weights) : boue au marais, herbe claire en clairière,
## sous-bois sombre en forêt dense, cailloutis au coin rocheux. Un seul sprite posé sur le sol, sous la
## rivière et sous les objets : une carte des zones à 1 texel par unité, mise en couleur au pixel natif
## par ground_zones.gdshader. Rien sur les chemins ni sous la montagne. Décor seulement.

const SHADER := preload("res://shaders/ground_zones.gdshader")
const PX := 8
## Carte des zones par graine (boucle par texel) : reprise à chaque nouvelle partie de même graine.
const CACHE_SIZE := 4
static var _cache := {}
## Calculs lancés en avance sur un fil de travail (prepare) : graine → [tâche, Image].
static var _pending := {}


## Lance le calcul de la carte des zones sur un fil de travail (2026-11-22, chargement) : zone_map ne fait que
## lire la flore, la rivière et le chemin ; setup attend le résultat. Même image qu'un calcul sur place.
static func prepare(flora: Flora) -> void:
	if _cache.has(flora.seed) or _pending.has(flora.seed):
		return
	# Une tâche par tranche de rangées, chacune dans sa propre image ; setup les recolle.
	var r := rect()
	var strips := []
	var n := ceili(r.size.y / float(STRIP))
	for k in n:
		strips.append([])
	var task := WorkerThreadPool.add_group_task(func(k: int) -> void:
		(strips[k] as Array).append(zone_rows(flora, k * STRIP, mini(r.size.y, (k + 1) * STRIP))), n, -1, false, "zones de la jungle")
	_pending[flora.seed] = [task, strips]


## Bornes de la carte (unités) : toute la jungle, du haut du flanc de la montagne au bord sud.
static func rect() -> Rect2i:
	var z0 := floori(Biomes.BASE_Z - 8.0)
	return Rect2i(int(CaveShape.WORLD_X0), z0, int(CaveShape.WORLD_X1 - CaveShape.WORLD_X0), ceili(CaveShape.WORLD_Z1 + 6.0) - z0)


## Rangées par tâche du calcul en parallèle.
const STRIP := 16


## Carte des zones : R marais, G clairière, B dense, A rocheux.
static func zone_map(flora: Flora) -> Image:
	var r := rect()
	return _join([zone_rows(flora, 0, r.size.y)], r.size.y)


static func _join(strips: Array, h: int) -> Image:
	var r := rect()
	var img := Image.create(r.size.x, h, false, Image.FORMAT_RGBA8)
	var y := 0
	for s: Image in strips:
		img.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(0, y))
		y += s.get_height()
	return img


## Rangées [j0, j1) de la carte des zones, dans une image à part.
static func zone_rows(flora: Flora, j0: int, j1: int) -> Image:
	var r := rect()
	var img := Image.create(r.size.x, j1 - j0, false, Image.FORMAT_RGBA8)
	# Les chemins ne sont interrogés que dans leurs rectangles englobants (le reste de la carte en est loin).
	var near_road: Array[Rect2] = []
	if flora.road != null:
		for b in flora.road.bounds():
			near_road.append(b.grow(3.0))
	for j in range(j0, j1):
		var z := r.position.y + j + 0.5
		for i in r.size.x:
			var x := r.position.x + i + 0.5
			# Fondu à la lisière de la montagne et au bord des chemins.
			var m := smoothstep(1.0, 4.0, z - CaveShape.mountain_edge(x))
			if m > 0.0:
				for b in near_road:
					if b.has_point(Vector2(x, z)):
						m *= smoothstep(0.4, 2.2, flora.road.sample(x, z).x)
						break
			if m <= 0.0:
				continue
			var w := flora.zone_weights(x, z)
			img.set_pixel(i, j - j0, Color(w.r * m, w.g * m, w.b * m, w.a * m))
	return img


func setup(flora: Flora) -> void:
	name = "GroundZones"
	var tex: ImageTexture = _cache.get(flora.seed)
	if tex == null:
		var img: Image = null
		if _pending.has(flora.seed):
			var slot: Array = _pending[flora.seed]
			WorkerThreadPool.wait_for_group_task_completion(slot[0])
			_pending.erase(flora.seed)
			var parts := []
			for s: Array in slot[1]:
				parts.append(s[0])
			img = _join(parts, rect().size.y)
		tex = ImageTexture.create_from_image(img if img != null else zone_map(flora))
		if _cache.size() >= CACHE_SIZE:
			_cache.erase(_cache.keys()[0])
		_cache[flora.seed] = tex
	var r := rect()
	texture = tex
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	position = Vector2(r.position * PX)
	scale = Vector2(PX, PX)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("origin", Vector2(r.position * PX))
	m.set_shader_parameter("texel", float(PX))
	material = m
