# Animations ennemies validées

36 atlas PNG : repos, marche, attaque et mort pour neuf ennemis. Le gabarit vivant est de 40 × 42 pixels ; les chutes disposent d'une marge pour le corps et les armes au sol. Ancres, cadence et découpage sont dans `manifest.json`.

Le générateur est celui de `planches/ennemis-animations.html`, incluant `death-rig.js`. Les quatre anciennes marches et leurs repos proviennent des atlas du baker, sans redessin. Ne pas retoucher les atlas manuellement.

Exception : la marche du Strazhar est à quatre pattes (« La ruée », choix 04 de `planches/strazhar-quadrupede-propositions.html`). Elle vient de `planches/ennemis/strazhar-quadrupede-v3.js`, exportée par le même bouton, dans un cadre de 68 × 48 avec son ancre propre (`walk.ax`, `walk.ay` dans le manifeste, lus par `UnitView` pendant la marche). Sa foulée est de 4,125 unités, soit 33 px natifs par cycle, pour que les poings ne glissent pas. Le repos, l'attaque et la mort du Strazhar restent debout.

Pour régénérer depuis la racine du projet :

```sh
python3 tools/export_enemy_animations.py
```

Ouvrir `http://127.0.0.1:8791/planches/ennemis-animations.html?export=1` et cliquer sur « Exporter les animations Godot ». Attendre « Export terminé : 9 ennemis, 36 atlas », puis réimporter dans Godot.

Les références de `assets/baked/enemies/` restent intactes. Les statistiques de combat sont dans `data/catalog.gd`. Les renforts entrent progressivement aux assauts 2 (éclaireur), 3 (soldat), 4 (archer), 5 (bouclier). Un Strazhar ouvre chaque assaut dès 1 000 de Menace ou à partir de la vague 8. La Menace est relevée au lancement de la vague ; une file déjà préparée reste inchangée. Le budget global de puissance des vagues n'est pas modifié par cette règle d'apparition.
