class_name SealGlintsView
extends Node2D
## Sceau sensible (sim/mods.gd) : reflets des filons proches, dans un calque au-dessus du brouillard (calque 3) pour
## qu'ils se voient à travers la roche et le noir. Repère de l'écran, comme EnemyShotsView ; dessin :
## EffectsDrawer.draw_seal_layer.

var world: World
var _fx := EffectsDrawer.new()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or world.terrain_state == null or world.camera == null:
		return
	_fx.ci = self
	_fx.world = world
	_fx.draw_seal_layer(GameState.sim_time)
