class_name FloraView
extends RefCounted
## Nœuds de la petite végétation (Flora), créés par chunk autour de la caméra et libérés quand elle
## s'éloigne. Les plantes debout vont dans le nœud trié par Y, les plantes à plat dans la couche du sol.
## Un changement de stade (piétinement, feu, repousse) remplace la texture du sprite.

var flora: Flora
var upright: Node2D
var flat: Node2D
## Chunk → true ; id de plante → Sprite2D.
var _live := {}
var _sprites := {}


func setup(f: Flora, upright_parent: Node2D, flat_parent: Node2D) -> void:
	flora = f
	upright = upright_parent
	flat = flat_parent
	_live.clear()
	_sprites.clear()


## Chunks à garder : `view` (indices de chunk), plus une marge.
func stream(view: Rect2i, keep: Rect2i) -> void:
	for c: Vector2i in _live.keys():
		if keep.has_point(c):
			continue
		for id: int in flora.chunks.get(c, []):
			var s: Sprite2D = _sprites.get(id)
			if s and is_instance_valid(s):
				s.queue_free()
			_sprites.erase(id)
		_live.erase(c)
	for cz in range(view.position.y, view.end.y):
		for cx in range(view.position.x, view.end.x):
			var c := Vector2i(cx, cz)
			if _live.has(c) or not flora.chunks.has(c):
				continue
			_live[c] = true
			for id: int in flora.chunks[c]:
				_make(id)


## Applique les changements de stade.
func refresh() -> void:
	for id in flora.take_dirty():
		var s: Sprite2D = _sprites.get(id)
		if s == null or not is_instance_valid(s):
			continue
		var p := flora.plants[id]
		if p["k"] == "gone":
			s.queue_free()
			_sprites.erase(id)
			continue
		_dress(s, p)


func live_count() -> int:
	return _sprites.size()


func _make(id: int) -> void:
	var p := flora.plants[id]
	if p["k"] == "gone":
		return
	var s := Sprite2D.new()
	s.centered = false
	s.position = Vector2(roundf(p["x"] * Proj.K), roundf(p["z"] * Proj.K))
	_dress(s, p)
	(flat if Flora.FLAT.has(p["k"]) else upright).add_child(s)
	_sprites[id] = s


func _dress(s: Sprite2D, p: Dictionary) -> void:
	var tex := FloraArt.texture(p["k"], p["v"], p["s"], p["b"])
	s.texture = tex
	var sz := tex.get_size()
	if Flora.FLAT.has(p["k"]):
		s.offset = Vector2(-floorf(sz.x / 2.0), -floorf(sz.y / 2.0))
	else:
		s.offset = Vector2(-floorf(sz.x / 2.0), -sz.y + 1.0)
	s.flip_h = int(p["id"]) % 2 == 1
