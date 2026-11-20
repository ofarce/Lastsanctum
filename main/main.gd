extends Node
## Scène racine : monde, simulation, entrées et HUD. Lance une nouvelle partie (init() du prototype).

@onready var world: World = $World
@onready var simulation: Simulation = $Simulation
@onready var hud: Hud = $Hud


## Banc d'essai demandé (`-- --banc`, ou `?banc` dans l'adresse de la page Web) : la scène racine laisse
## la place au banc (main/benchmark.tscn), qui instancie lui-même le jeu.
static func benchmark_requested() -> bool:
	if OS.get_cmdline_user_args().has("--banc"):
		return true
	if OS.has_feature("web"):
		return String(JavaScriptBridge.eval("window.location.search", true)).contains("banc")
	return false


func _ready() -> void:
	if get_parent() == get_tree().root and benchmark_requested():
		get_tree().change_scene_to_file.call_deferred("res://main/benchmark.tscn")
		return
	simulation.world = world
	world.simulation = simulation
	hud.setup(simulation, world)
	var cinema := CinemaLayer.new()
	cinema.name = "Cinema"
	cinema.simulation = simulation
	cinema.world = world
	cinema.hud = hud
	add_child(cinema)
	simulation.opening = Simulation.play_opening and not OS.get_cmdline_user_args().has("--sans-ouverture")
	if Simulation.autostart:
		simulation.new_game()
