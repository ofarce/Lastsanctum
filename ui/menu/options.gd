class_name GameOptions
extends RefCounted
## Réglages du joueur (menu de pause) : volume de la musique et des bruitages, gardés dans user://options.cfg.
## Deux bus audio créés à la volée, « Musique » et « Bruitages », sous le bus Master.

const FILE := "user://options.cfg"
const MUSIC_BUS := "Musique"
const SFX_BUS := "Bruitages"
## Paliers proposés par le menu (clic = palier suivant).
const STEPS := [1.0, 0.75, 0.5, 0.25, 0.0]

static var music := 1.0
static var sfx := 1.0
static var _ready := false


## Crée les bus si besoin et applique les volumes enregistrés (appelée par les lecteurs audio).
static func ensure() -> void:
	if _ready:
		return
	_ready = true
	for bus: String in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		music = clampf(float(cfg.get_value("audio", "musique", 1.0)), 0.0, 1.0)
		sfx = clampf(float(cfg.get_value("audio", "bruitages", 1.0)), 0.0, 1.0)
	_apply()


static func set_volume(bus: String, v: float) -> void:
	ensure()
	if bus == MUSIC_BUS:
		music = v
	else:
		sfx = v
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(FILE)
	cfg.set_value("audio", "musique", music)
	cfg.set_value("audio", "bruitages", sfx)
	cfg.save(FILE)


## Palier suivant (100 → 75 → 50 → 25 → 0 → 100 %).
static func next_step(v: float) -> float:
	for i in STEPS.size():
		if is_equal_approx(v, STEPS[i]):
			return STEPS[(i + 1) % STEPS.size()]
	return STEPS[0]


static func _apply() -> void:
	for pair: Array in [[MUSIC_BUS, music], [SFX_BUS, sfx]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(i, pair[1] <= 0.0)
