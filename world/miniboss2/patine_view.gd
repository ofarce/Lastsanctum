class_name PatineView
extends Node2D
## Rendu de la Martyre de la Patine (sim/patine.gd), silhouette P1 « L'Automate verdi » : repos, marche, incantation
## (bras qui se lèvent : pluie, salve, poussée), oxydation (fissures vertes allumées), chute. En phase II, repos et
## marche passent aux bandes « _ox » (fissures allumées). Origine : son point au sol.

var enemy: Enemy
var world: World


func setup(e: Enemy, w: World) -> void:
	enemy = e
	world = w
	name = "Patine"


func _process(_delta: float) -> void:
	if enemy == null:
		return
	position = Proj.nat(enemy.x, 0.0, enemy.z).round()
	queue_redraw()


func _draw() -> void:
	if enemy == null or enemy.hidden:
		return
	if world != null and not world.fog.visible_at(enemy.pos()):
		return
	var now := GameState.sim_time
	var r := Patine.run()
	var tint := Color.WHITE
	var anim := "death"
	var t := now - enemy.died_at
	if enemy.hp > 0.0:
		var ox := int(r.get("phase", 0)) >= 1
		var mode := String(r.get("mode", "idle"))
		t = now - float(r.get("t0", 0.0))
		if mode == "cast":
			anim = "cast"
		elif mode == "ox":
			anim = "ox"
		elif Patine.walking():
			anim = "walk_ox" if ox else "walk"
			t = now
		else:
			anim = "idle_ox" if ox else "idle"
			t = now
		if now - enemy.hurt_at < 0.12:
			tint = Color(1.6, 1.6, 1.4)
	else:
		tint = Color(1, 1, 1, clampf(Loot.corpse_life(enemy) - t, 0.0, 1.0))
	MiniBoss2Art.draw(self, "patine", anim, MiniBoss2Art.frame("patine", anim, t), Vector2.ZERO, enemy.face > 0, tint)
	# Oxydation : lueur verte du ventre qui monte avec le geste.
	if enemy.hp > 0.0 and String(r.get("mode", "")) == "ox":
		var k := clampf(t / Patine.OX["burst"], 0.0, 1.0)
		for i in 3:
			draw_circle(Vector2(0, -32), 8.0 + i * 6.0, Color(0.35, 0.9, 0.55, (0.12 - i * 0.035) * k))
