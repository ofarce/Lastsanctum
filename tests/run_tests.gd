extends SceneTree
## Lanceur de tests headless :
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --only=full_game   # fichiers contenant « full_game »
## Découvre res://tests/test_*.gd, exécute chaque méthode test_*(), affiche
## PASS/FAIL et quitte avec le code 1 si au moins un test échoue (ou si aucun
## test n'est trouvé).

const TESTS_DIR := "res://tests/"


func _initialize() -> void:
	# Les tests démarrent après la première image : l'arbre de scène est alors actif et les nœuds
	# ajoutés par les tests reçoivent _ready immédiatement.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	var passed := 0
	var failed := 0
	for file in _test_files():
		var script := load(TESTS_DIR + file) as GDScript
		# Un fichier qui ne compile pas compte comme un échec (sinon ses tests disparaîtraient en silence).
		if script == null or not script.can_instantiate():
			print("FAIL %s (chargement impossible)" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var instance: RefCounted = script.new()
			instance.call(name)
			# Une image entre deux tests : les messages différés (redessins, libérations) sont traités.
			await process_frame
			var failures: PackedStringArray = instance.get("failures")
			if failures.is_empty():
				print("PASS %s::%s" % [file, name])
				passed += 1
			else:
				print("FAIL %s::%s" % [file, name])
				for failure in failures:
					print("     - " + failure)
				failed += 1
	print("\n%d réussi(s), %d échoué(s)" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)


func _test_files() -> PackedStringArray:
	var files: PackedStringArray = []
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	for file in DirAccess.get_files_at(TESTS_DIR):
		if only and not file.contains(only):
			continue
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			files.append(file)
	files.sort()
	return files
