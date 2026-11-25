class_name EclusierView
extends Node2D
## Rendu de l'Éclusier de Byrsa (sim/eclusier.gd), silhouette E2 « Le Porte-clef » : bandes « full_* » tant que la
## salle est noyée (hublot et réservoir pleins, armure 5), « dry_* » une fois sèche (armure 0). Repos, marche, harpon
## (armé puis lancé), vannes (la clef se lève et s'abat, aussi pour le coup au contact), chute. Le sprite regarde à
## gauche (harpon au poing gauche) : il est retourné quand il fait face à l'est. Origine : son point au sol.

var enemy: Enemy
var world: World


func setup(e: Enemy, w: World) -> void:
	enemy = e
	world = w
	name = "Eclusier"


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
	var r := Eclusier.run()
	var tint := Color.WHITE
	var anim := "death"
	var t := now - enemy.died_at
	if enemy.hp > 0.0:
		var pre := "full_" if Eclusier.wet() else "dry_"
		var mode := String(r.get("mode", "idle"))
		t = now - float(r.get("t0", 0.0))
		if mode == "harpoon":
			anim = pre + "harpoon"
		elif mode in ["vanne", "strike", "short"]:
			anim = pre + "vanne"
		elif Eclusier.walking():
			anim = pre + "walk"
			t = now
		else:
			anim = pre + "idle"
			t = now
		if now - enemy.hurt_at < 0.12:
			tint = Color(1.7, 1.5, 1.3)
		# Court-circuit : il crépite tant que l'eau est électrisée.
		if not (r.get("short", {}) as Dictionary).is_empty() and fmod(now * 12.0, 2.0) < 1.0:
			tint = tint * Color(0.85, 1.05, 1.4)
	else:
		tint = Color(1, 1, 1, clampf(Loot.corpse_life(enemy) - t, 0.0, 1.0))
	var f := MiniBoss2Art.frame("eclusier", anim, t)
	MiniBoss2Art.draw(self, "eclusier", anim, f, Vector2.ZERO, enemy.face > 0, tint)
	# Hublot plein : une lueur d'eau dans la cloche.
	if enemy.hp > 0.0 and Eclusier.wet():
		var hp := Vector2(0.0, 18.0 - 72.0)
		for k in 3:
			draw_circle(hp, 4.0 + k * 2.5, Color(0.47, 0.86, 0.9, 0.08 - k * 0.02))
