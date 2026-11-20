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


## Bornes de la carte (unités) : toute la jungle, du haut du flanc de la montagne au bord sud.
static func rect() -> Rect2i:
	var z0 := floori(Biomes.BASE_Z - 8.0)
	return Rect2i(int(CaveShape.WORLD_X0), z0, int(CaveShape.WORLD_X1 - CaveShape.WORLD_X0), ceili(CaveShape.WORLD_Z1 + 6.0) - z0)


## Carte des zones : R marais, G clairière, B dense, A rocheux.
static func zone_map(flora: Flora) -> Image:
	var r := rect()
	var img := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	# Les chemins ne sont interrogés que dans leurs rectangles englobants (le reste de la carte en est loin).
	var near_road: Array[Rect2] = []
	if flora.road != null:
		for b in flora.road.bounds():
			near_road.append(b.grow(3.0))
	for j in r.size.y:
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
			img.set_pixel(i, j, Color(w.r * m, w.g * m, w.b * m, w.a * m))
	return img


func setup(flora: Flora) -> void:
	name = "GroundZones"
	var tex: ImageTexture = _cache.get(flora.seed)
	if tex == null:
		tex = ImageTexture.create_from_image(zone_map(flora))
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
