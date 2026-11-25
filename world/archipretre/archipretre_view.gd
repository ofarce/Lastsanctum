class_name ArchipretreView
extends Node2D
## Rendu de l'Archiprêtre aux racines (sim/archipretre.gd) en pixel art ×3 : trois pixels de sprite par pixel natif,
## une bande par animation dans assets/imported/archipretre/hd (exportées par planches/archipretre-hd-rendu.html#export
## et tools/archipretre/serve.py), cadre de 252 × 222 dessiné au tiers, pied en (ax, ay). La lanterne de Medeina, son
## butin, est dans le sprite.
## - Repos : boucle « idle ».
## - Attaque : la bande de l'attaque en cours (regard, strabisme, pupilles, larmes, cils), découpée en entrée, tenue
##   en boucle et sortie ; la tenue dure autant que l'attaque (Archipretre.run().busy_until), la sortie se joue sur
##   ses dernières images. Le début d'une attaque se lit au changement de run().idx.
## - Chute : « death », puis la dernière image tant que le corps reste.
## Par-dessus, dessinées ici : la lueur du bulbe et le halo de la lanterne, aux points donnés image par image par
## meta.json (bulb, lan ; px natifs depuis le pied). Origine : le point au sol du boss, dans le tri en profondeur.

const DIR := "res://assets/imported/archipretre/hd/"
const SYLVE := Color("#9af070")

static var _meta: Dictionary
static var _tex := {}

var enemy: Enemy
var world: World
## Attaque en cours vue d'ici : rang dans la rotation (run().idx au moment où elle part) et instant de départ.
var _atk_idx := 0
var _atk_t0 := 0.0
## Instant où le repos a repris : la boucle « idle » repart de sa première image, celle où finit chaque sortie.
var _idle_since := 0.0
var _was_attacking := false


## Bandes et cadres, chargés à la première image visible (une centaine de Mo de textures : inutile avant l'éveil).
static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "meta.json"))
		for name: String in _meta["anims"]:
			_tex[name] = load(DIR + name + ".png")
	return _meta


func setup(e: Enemy, w: World) -> void:
	enemy = e
	world = w
	name = "Archipretre"
	_atk_idx = int(Archipretre.run().get("idx", 0))


func _process(_delta: float) -> void:
	if enemy == null:
		return
	position = Proj.nat(enemy.x, 0.0, enemy.z).round()
	queue_redraw()


## Bande et image à l'instant présent : [nom, image, attaque en cours].
func _frame(m: Dictionary) -> Array:
	var now := GameState.sim_time
	var fps := float(m["fps"])
	if enemy.hp <= 0.0:
		var n := int(m["anims"]["death"]["count"])
		return ["death", clampi(floori((now - enemy.died_at) * fps), 0, n - 1), false]
	var r := Archipretre.run()
	var idx := int(r.get("idx", 0))
	if idx != _atk_idx:
		_atk_idx = idx
		_atk_t0 = now
	var left := float(r.get("busy_until", -INF)) - now
	var rot := Archipretre.rotation()
	if idx > 0 and left > 0.0 and r.get("e") == enemy and not rot.is_empty():
		var p: String = rot[(idx - 1) % rot.size()]
		if m["anims"].has(p):
			_was_attacking = true
			var a: Dictionary = m["anims"][p]
			var n_in := int(a["in"])
			var n_loop := int(a["loop"])
			var n_out := int(a["out"])
			var e := now - _atk_t0
			if left < n_out / fps:
				return [p, n_in + n_loop + clampi(floori((n_out / fps - left) * fps), 0, n_out - 1), true]
			if e < n_in / fps:
				return [p, clampi(floori(e * fps), 0, n_in - 1), true]
			if n_loop > 0:
				return [p, n_in + floori((e - n_in / fps) * fps) % n_loop, true]
			return [p, n_in - 1, true]
	if _was_attacking:
		_was_attacking = false
		_idle_since = now
	return ["idle", floori(maxf(0.0, now - _idle_since) * fps) % int(m["anims"]["idle"]["count"]), false]


func _draw() -> void:
	if enemy == null or enemy.hidden:
		return
	if world != null and not world.fog.visible_at(enemy.pos()):
		return
	var m := meta()
	var now := GameState.sim_time
	var fr := _frame(m)
	var anim: String = fr[0]
	var f: int = fr[1]
	var s := float(m["scale"])
	var fw := float(m["frame_w"])
	var fh := float(m["frame_h"])
	var cols := int(m["cols"])
	var tint := Color.WHITE
	if now - enemy.hurt_at < 0.12 and enemy.hp > 0.0:
		tint = Color(1.7, 1.5, 1.3)
	if enemy.hp <= 0.0:
		tint = Color(1, 1, 1, clampf(Loot.corpse_life(enemy) - (now - enemy.died_at), 0.0, 1.0))
	var face := -1.0 if enemy.face < 0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1.0))
	draw_texture_rect_region(_tex[anim], Rect2(-float(m["ax"]) / s, -float(m["ay"]) / s, fw / s, fh / s),
		Rect2((f % cols) * fw, floorf(float(f) / cols) * fh, fw, fh), tint)
	var a: Dictionary = m["anims"][anim]
	# Halo vert de la lanterne : il reste sur le corps, c'est le plan qu'il laisse.
	var lan: Array = a["lan"][f]
	var lp := Vector2(float(lan[0]), float(lan[1]))
	var flick := 0.75 + 0.25 * sin(now * 7.0) * sin(now * 3.1)
	for k in 3:
		draw_circle(lp, 3.0 + k * 2.5, Color(SYLVE, (0.10 - k * 0.03) * flick * tint.a))
	# Lueur du bulbe : sourde au repos, vive pendant une attaque, éteinte à sa mort.
	if enemy.hp > 0.0:
		var bulb: Array = a["bulb"][f]
		var bp := Vector2(float(bulb[0]), float(bulb[1]))
		var casting: bool = fr[2]
		var pulse := 0.5 + 0.5 * sin(now * (6.0 if casting else 2.2))
		var c := Color(0.89, 0.22, 0.18, 0.10 + 0.10 * pulse) if casting else Color(0.82, 0.25, 0.3, 0.05 + 0.05 * pulse)
		for k in 3:
			draw_circle(bp, 6.0 + k * 4.0, Color(c, c.a * (1.0 - k * 0.3)))
	draw_set_transform(Vector2.ZERO)
