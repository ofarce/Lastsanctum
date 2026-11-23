class_name PauseMenu
extends Control
## Menu de pause : Échap (quand il n'y a rien à annuler) ou la touche Pause. Le jeu est figé tant qu'il est
## ouvert. Reprendre, vitesse du jeu, sauvegarde et chargement, volumes, nouvelle partie, quitter.
## Raccourcis valables menu fermé : F2 (vitesse), F5 (sauvegarde rapide), F9 (chargement).
## Nouvelle partie et Quitter demandent un second clic (le libellé passe en laiton : « Confirmer … »).

const W := 430.0
const ROW_H := 38.0
const ROW_GAP := 6.0
const HEAD_H := 64.0
const PAD := 18.0

## Vrai tant que le menu est ouvert : InputController ne reçoit rien.
static var open := false

var sim: Simulation
var world: World
var hud: Hud

var _frame := _Frame.new()
var _rows: Array = []
var _status := HudStyle.label(12, HudStyle.MUTED, HudStyle.italic())
var _was_paused := false
var _cam_was := true
## Ligne qui attend sa confirmation (« new », « quit ») ; vide sinon.
var _confirm := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	open = false
	add_child(_frame)
	for id: String in ["resume", "speed", "save", "load", "music", "sfx", "new", "quit"]:
		var t: Control = HelpPanel._Tab.new()
		t.boxed = true
		t.set_meta("id", id)
		t.pressed.connect(_press.bind(id))
		_frame.add_child(t)
		_rows.append(t)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frame.add_child(_status)
	Events.pause_requested.connect(show_menu)
	Events.game_reset.connect(close)
	get_viewport().size_changed.connect(_layout)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.03, 0.62))


func show_menu() -> void:
	if open or Opening.cinematic() or HelpPanel.open:
		return
	open = true
	visible = true
	_confirm = ""
	_status.text = ""
	if sim != null:
		_was_paused = sim.paused
		sim.paused = true
	if world != null:
		_cam_was = world.camera.input_enabled
		world.camera.input_enabled = false
	Sfx.play("ui_banniere")
	_refresh()
	_layout()


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	if sim != null:
		sim.paused = _was_paused
	if world != null:
		world.camera.input_enabled = _cam_was


## Touches du menu et raccourcis globaux, appelée par Hud._input. Vrai si l'événement est consommé.
func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return open and event is InputEventKey
	var k: Key = event.key_label if event.key_label != KEY_NONE else event.keycode
	if open:
		if k in [KEY_ESCAPE, KEY_PAUSE]:
			close()
		elif k == KEY_F2:
			_press("speed")
		elif k == KEY_F5:
			_press("save")
		elif k == KEY_F9:
			_press("load")
		return true
	if Opening.cinematic() or HelpPanel.open or sim == null:
		return false
	match k:
		KEY_PAUSE:
			show_menu()
			return true
		KEY_F2:
			sim.cycle_speed()
			sim.say("Vitesse du jeu ×%d." % sim.speed, 1.5)
			hud.refresh(true)
			return true
		KEY_F5:
			var why := SaveGame.cannot_save(sim)
			if why != "":
				sim.say(why, 3.0)
			elif SaveGame.store(sim, hud):
				sim.say("Partie sauvegardée.", 2.0)
			return true
		KEY_F9:
			if SaveGame.exists():
				_load()
			else:
				sim.say("Aucune sauvegarde.", 2.0)
			return true
	return false


func _press(id: String) -> void:
	if id != _confirm:
		_confirm = ""
	match id:
		"resume":
			close()
			return
		"speed":
			sim.cycle_speed()
			hud.refresh(true)
		"save":
			var why := SaveGame.cannot_save(sim)
			if why != "":
				_status.text = why
			elif SaveGame.store(sim, hud):
				_status.text = "Partie sauvegardée."
			else:
				_status.text = "La sauvegarde a échoué."
		"load":
			if SaveGame.exists():
				_load()
				return
		"music":
			GameOptions.set_volume(GameOptions.MUSIC_BUS, GameOptions.next_step(GameOptions.music))
		"sfx":
			GameOptions.set_volume(GameOptions.SFX_BUS, GameOptions.next_step(GameOptions.sfx))
			Sfx.play("ui_banniere")
		"new":
			if _confirm != "new":
				_confirm = "new"
				_status.text = "La partie en cours sera perdue (sauf sauvegarde)."
			else:
				close()
				sim.new_game()
				return
		"quit":
			if _confirm != "quit":
				_confirm = "quit"
				_status.text = "La partie en cours sera perdue (sauf sauvegarde)."
			else:
				get_tree().quit()
				return
	_refresh()
	_layout()


func _load() -> void:
	# Le chargement régénère la carte (quelques secondes) : on l'annonce d'abord, deux images plus tôt.
	_status.text = "Chargement…"
	if not open:
		sim.say("Chargement…", 10.0)
	await get_tree().process_frame
	await get_tree().process_frame
	close()
	if SaveGame.restore(sim, hud):
		sim.say("Partie chargée : " + SaveGame.summary() + ".", 3.0)
	else:
		sim.say("Impossible de charger la sauvegarde.", 3.0)


func _refresh() -> void:
	var why := SaveGame.cannot_save(sim) if sim != null else ""
	for t: Control in _rows:
		var id: String = t.get_meta("id")
		t.selected = id == _confirm
		t.locked = false
		t.key = ""
		match id:
			"resume":
				t.text = "Reprendre"
				t.key = "Échap"
			"speed":
				t.text = "Vitesse du jeu : ×%d" % sim.speed
				t.key = "F2"
			"save":
				t.text = "Sauvegarder"
				t.key = "F5"
				t.locked = why != ""
			"load":
				t.text = "Charger · " + SaveGame.summary() if SaveGame.exists() else "Charger (aucune sauvegarde)"
				t.key = "F9"
				t.locked = not SaveGame.exists()
			"music":
				t.text = "Musique : %d %%" % roundi(GameOptions.music * 100.0)
			"sfx":
				t.text = "Bruitages : %d %%" % roundi(GameOptions.sfx * 100.0)
			"new":
				t.text = "Confirmer la nouvelle partie" if _confirm == "new" else "Nouvelle partie"
				t.key = "Maj + R"
			"quit":
				t.text = "Confirmer : quitter le jeu" if _confirm == "quit" else "Quitter le jeu"
		t.queue_redraw()
	if _status.text == "" and why != "":
		_status.text = why


func _layout() -> void:
	if not is_inside_tree():
		return
	size = get_viewport_rect().size
	var gaps := 3
	var h := HEAD_H + PAD + _rows.size() * (ROW_H + ROW_GAP) + gaps * 8.0 + 30.0
	_frame.size = Vector2(W, h)
	_frame.position = ((size - _frame.size) / 2.0).round()
	var y := HEAD_H + PAD
	for i in _rows.size():
		var t: Control = _rows[i]
		# Séparations : après Reprendre/Vitesse, après Charger, après les volumes.
		if i in [2, 4, 6]:
			y += 8.0
		t.position = Vector2(PAD, y)
		t.size = Vector2(W - 2.0 * PAD, ROW_H)
		y += ROW_H + ROW_GAP
	_status.position = Vector2(PAD + 4.0, y + 2.0)
	_status.size = Vector2(W - 2.0 * PAD - 8.0, 24.0)
	queue_redraw()
	_frame.queue_redraw()


class _Frame extends Control:
	func _draw() -> void:
		HudStyle.metal_panel(self, size)
		draw_rect(Rect2(6.0, PauseMenu.HEAD_H, size.x - 12.0, 1.0), HelpPanel.LINE)
		draw_string(HudStyle.spaced(2), Vector2(22.0, 26.0), "JEU EN PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e69354"))
		draw_string(HudStyle.font(), Vector2(22.0, 50.0), "Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, HudStyle.GOLD_LIGHT)
