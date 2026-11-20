class_name EnemyShotsView
extends Node2D
## Tirs ennemis esquivables (sim/enemy_shots.gd) dans leur propre calque, au-dessus de l'obscurité (Lighting,
## calque 1) et de la pluie (RainLayer, calque 2, ajouté avant lui) : bilan de la planche « Visibilité des balles »,
## piste 1·C (2026-11-20). Balles, halos, ombres, annonces et zone touchée de l'Exilé y passent tous ; le brouillard
## (calque 3) reste par-dessus, mais une balle hors de vue n'est pas dessinée.
## Le calque n'a pas de transformation : repère de l'écran, comme WorldOverlay. Dessin : EffectsDrawer.draw_enemy_layer.

var world: World
var _fx := EffectsDrawer.new()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or world.terrain_state == null or world.camera == null:
		return
	_fx.ci = self
	_fx.world = world
	_fx.draw_enemy_layer(GameState.sim_time)
