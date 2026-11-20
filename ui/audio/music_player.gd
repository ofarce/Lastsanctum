extends AudioStreamPlayer
## Bande son : « Cavern's Resolve » en boucle dès que la capsule est allumée (Capsule.powered()),
## coupée en fondu si elle s'éteint (nouvelle partie). Continue pendant la pause.

const TRACK := "res://assets/audio/music/caverns_resolve.mp3"
const MUSIC_DB := -12.0
const SILENT_DB := -60.0
## Durée des fondus d'entrée et de sortie (secondes réelles).
const FADE := 2.0

var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = _load()
	volume_db = SILENT_DB


func _process(_dt: float) -> void:
	if stream == null:
		return
	var on := Capsule.powered()
	if on and not playing:
		play()
		_fade_to(MUSIC_DB)
	elif not on and playing and (_fade == null or not _fade.is_running()):
		_fade_to(SILENT_DB).finished.connect(stop)


func _fade_to(db: float) -> Tween:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", db, FADE)
	return _fade


func _load() -> AudioStreamMP3:
	var s: AudioStreamMP3 = null
	if ResourceLoader.exists(TRACK):
		s = load(TRACK)
	elif FileAccess.file_exists(TRACK):
		# Fichier pas encore importé par l'éditeur : lecture directe du MP3.
		s = AudioStreamMP3.load_from_file(ProjectSettings.globalize_path(TRACK))
	if s == null:
		push_warning("Musique introuvable : %s" % TRACK)
		return null
	s.loop = true
	return s
