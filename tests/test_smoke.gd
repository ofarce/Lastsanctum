extends "res://tests/test_case.gd"
## Test trivial de l'étape 0 : vérifie que le lanceur et les réglages
## pixel art du projet sont en place.


func test_runner_works() -> void:
	check_eq(1 + 1, 2)


func test_pixel_art_settings() -> void:
	check_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "filtre de texture")
	check_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "moteur de rendu")
	# L'alignement sur la grille native est fait par shaders/pixel_snap.gdshader (comme natP) :
	# l'arrondi global de Godot doit rester désactivé, sinon il arrondit une seconde fois.
	check_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), false, "snap 2D global")
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://boot/loader.tscn", "scène principale")
