class_name EvilEmbers
extends Node2D
## Braises qui s'échappent d'un portail maléfique (drawEvilPortal, galleries.js, 73b410f), dessinées en
## pixels natifs de l'écran autour de natP(portail).

var world: World
var world_xz := Vector2.ZERO
var look: Array[Color] = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var n := Proj.nat(world_xz.x, 0.0, world_xz.y) + world.native_offset
	var nx := floorf(n.x + 0.5)
	var ny := floorf(n.y + 0.5)
	# Repère du nœud en pixels natifs du monde : écart entre coordonnées écran natives et locales.
	var o := world.native_offset + world.to_local(global_position)
	var t := GameState.sim_time
	for i in 6:
		var u := fmod(t * 0.6 + i / 6.0, 1.0)
		PixelDraw.npx(self, nx + sin(t * 2.0 + i * 2.1) * 9.0, ny - 6.0 - u * 34.0, look[4] if u < 0.5 else look[3], o)
