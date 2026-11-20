extends Node
## Bande son, deux pistes en boucle qui se fondent l'une dans l'autre :
## - monde : « Cavern's Resolve » dès que la capsule est allumée (Capsule.powered()) ;
## - boss : « Shadowed Champion » tant que l'Ingénieur est en combat de boss (boss_fight()).
## Pendant un combat, la piste du monde est mise en pause et reprend où elle en était quand il se termine
## (boss vaincu, Ingénieur tombé ou sorti du combat). La piste de boss repart du début à chaque combat.
## Continue pendant la pause du jeu.

const WORLD := "res://assets/audio/music/caverns_resolve.mp3"
const BOSS := "res://assets/audio/music/shadowed_champion.mp3"
const MUSIC_DB := -12.0
## Durée des fondus (secondes réelles).
const FADE := 2.0
const FADE_BOSS := 1.0

var _world := AudioStreamPlayer.new()
var _boss := AudioStreamPlayer.new()
## Niveau courant de chaque piste, de 0 (muette) à 1 (MUSIC_DB).
var _gain := {}


## L'Ingénieur est en combat de boss : duel contre la Martyre ou l'Œil de la Matrice, ou vivant dans la
## salle de Gorge-Cuivre éveillée.
static func boss_fight() -> bool:
	if Martyre.active() and GameState.martyre_state == "duel":
		return true
	if OeilMatrice.active() and GameState.oeil_state == "duel":
		return true
	if Gorge.active():
		var eng := Capsule.engineer()
		return eng != null and not eng.hidden and eng.pos().distance_to(Gorge.center()) <= Gorge.ROOM + 4.0
	return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world.stream = _load(WORLD)
	_boss.stream = _load(BOSS)
	for p: AudioStreamPlayer in [_world, _boss]:
		add_child(p)
		_gain[p] = 0.0


func _process(dt: float) -> void:
	var fight := boss_fight() and _boss.stream != null
	_step(_boss, fight, dt / FADE_BOSS, false)
	_step(_world, Capsule.powered() and not fight, dt / FADE, Capsule.powered())


## Rapproche la piste p de son niveau voulu ; arrivée à zéro, elle se met en pause (keep) ou s'arrête.
func _step(p: AudioStreamPlayer, on: bool, step: float, keep: bool) -> void:
	if p.stream == null:
		return
	var g: float = move_toward(_gain[p], 1.0 if on else 0.0, step)
	_gain[p] = g
	if on:
		if not p.playing and not p.stream_paused:
			p.play()
		p.stream_paused = false
	elif g <= 0.0:
		if keep and (p.playing or p.stream_paused):
			p.stream_paused = true
		else:
			p.stream_paused = false
			p.stop()
	p.volume_db = MUSIC_DB + linear_to_db(maxf(g, 0.001))


func _load(path: String) -> AudioStreamMP3:
	var s: AudioStreamMP3 = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif FileAccess.file_exists(path):
		# Fichier pas encore importé par l'éditeur : lecture directe du MP3.
		s = AudioStreamMP3.load_from_file(ProjectSettings.globalize_path(path))
	if s == null:
		push_warning("Musique introuvable : %s" % path)
		return null
	s.loop = true
	return s
