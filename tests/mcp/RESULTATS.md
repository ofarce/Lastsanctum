# Tests de fumée MCP — résultats (étape 10, 15/11/2026)

Scénarios : [`smoke_scenarios.json`](smoke_scenarios.json). Ils ont été joués dans l'éditeur Godot 4.7.2, sur la scène principale, par les outils du MCP Godot :
- `godot_runtime_play_scene` ;
- `godot_input_simulate_key` et `godot_input_simulate_mouse` ;
- `godot_runtime_read_property` et `godot_testing_assert_node_state` ;
- `godot_testing_run_stress_test` ;
- `godot_runtime_get_game_output` et `godot_profiling_get_performance_monitors`.

| Scénario | Résultat | Relevés |
|---|---|---|
| `introduction_et_reactivation` | ✅ | Ancre éteinte à 5,5 s. Échap ferme l'accueil, R donne l'ordre (`orb_owner` défini) et l'Ancre s'active (`orb_active`). |
| `menu_de_construction` | ✅ | B ouvre le menu de construction, G arme le Temple de Sigil, Échap annule. |
| `camera_clavier_et_molette` | ✅ | D maintenu : caméra de x = 0 à x = 1,8 (10 u/s). Molette vers le haut : PX de 1 à 2. |
| `touche_A_selection` | ✅ | A maintenue : la caméra repart vers la gauche (x de 1,8 à 0,3). Rejoué après la décision D2 : Ctrl+A laisse la caméra en place (x = 0), puis A seule la déplace (x = −1,33). |
| `redemarrage` | ✅ | Maj+R : nouvelle partie, le temps repart de zéro. |
| `fuzz` | ✅ | 400 entrées aléatoires (graine 7 : touches du jeu, clics) : partie en cours, sans erreur, 59 im/s, 0 nœud orphelin. |

**Constats sur l'outillage**
- **Touches synthétiques** : le MCP n'envoie pas `key_label`, alors que le jeu lit cette lettre pour suivre la disposition AZERTY, comme `ev.key` dans le prototype. `InputController` retombe désormais sur `keycode` quand `key_label` est vide. Sans ce correctif, aucune touche envoyée par le MCP n'agissait.
- **`godot_testing_run_test_scenario`** : il envoie ses événements dès que la sonde se connecte, donc dès le début de la partie, et ne sait pas attendre entre deux événements. Il ne convient pas à ce jeu, où l'Ingénieur sort du portail au bout de 3 s. Les scénarios sont donc écrits étape par étape (`wait_until`, `key`, `assert`…) et joués avec les outils unitaires.
- **Sonde lente** : les lectures expirent souvent avec le délai par défaut (1,5 à 2 s), surtout juste après une touche ou pendant la régénération du monde. Elles aboutissent avec un délai de 10 à 30 s. Le jeu, lui, tournait à 60 im/s pendant ces lectures.
- **Valeurs non lisibles** : les tableaux d'objets (`selected`) ne sont pas lisibles par la sonde. La sélection est vérifiée par les tests GDScript (`test_full_game.gd`, `test_hud_actions.gd`).
- **Modificateurs synthétiques** : le MCP envoie A avec le drapeau Ctrl, mais jamais l'appui sur Ctrl lui-même. La caméra ne peut donc pas se fier à `Input.is_key_pressed(KEY_CTRL)`. Elle retient les touches appuyées avec Ctrl ou Cmd et ne défile pas tant que l'une d'elles est maintenue (D2).
