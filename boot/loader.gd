extends Control
## Écran de chargement : charge main.tscn en tâche de fond et affiche la vraie progression.
## 0–85 % : chargement des ressources (ResourceLoader threadé).
## 85–100 % : instanciation + génération du monde (main._ready, synchrone).

const TARGET := "res://main/main.tscn"
const LOAD_SHARE := 0.85

@onready var _bar: ProgressBar = %Bar
@onready var _label: Label = %Status

var _shown := 0.0
var _done := false


func _ready() -> void:
	var err := ResourceLoader.load_threaded_request(TARGET, "", true)
	if err != OK:
		push_error("Chargement impossible : %s" % TARGET)
		get_tree().change_scene_to_file.call_deferred(TARGET)
		_done = true


func _process(delta: float) -> void:
	if _done:
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(TARGET, progress)
	var target := 0.0
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			target = float(progress[0]) * LOAD_SHARE
		ResourceLoader.THREAD_LOAD_LOADED:
			target = LOAD_SHARE
		_:
			push_error("Échec du chargement : %s" % TARGET)
			_done = true
			get_tree().change_scene_to_file.call_deferred(TARGET)
			return
	_shown = move_toward(_shown, target, delta * 2.0)
	_set_progress(_shown)
	if status == ResourceLoader.THREAD_LOAD_LOADED and _shown >= LOAD_SHARE:
		_done = true
		_finish()


func _finish() -> void:
	_label.text = "Génération du monde…"
	_set_progress(LOAD_SHARE)
	# Deux images pour que le texte soit réellement affiché avant le travail bloquant.
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(TARGET)
	get_tree().change_scene_to_packed(packed)


func _set_progress(v: float) -> void:
	_bar.value = v * 100.0
	if v < LOAD_SHARE:
		_label.text = "Chargement… %d %%" % int(v * 100.0)
