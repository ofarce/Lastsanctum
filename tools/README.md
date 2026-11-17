# tools/

Outils hors jeu, exclus de l'export.

- `baker/` : extrait les graphismes procéduraux et les références du prototype JS (lecture seule) vers `res://assets/baked/` et `tests/visual/reference/`.
- `batiments_2x2/reduce.py` : réduit à 2/3 (« natif · plus proche », planche `batiments-2x2.html`) les sprites de bâtiments dessinés pour 3×3 et les marque `scale: 1`. À relancer après un passage du baker.
- `resync.py` : **procédure R**, la resynchronisation avec une nouvelle version du prototype.

```bash
python3 tools/resync.py <nouvelle_rev>            # rapport complet, avec le baker (environ 2 min)
python3 tools/resync.py <nouvelle_rev> --no-bake  # fichiers et déclarations JS seulement
python3 tools/resync.py WORKTREE                  # dossier de travail du prototype
```

  Le rapport est écrit dans `resync_out/<rev>/RAPPORT.md`, avec `rapport.json` et les extractions brutes. Il liste :
  - les fichiers du jeu modifiés ;
  - les déclarations JS ajoutées, retirées ou modifiées, avec les fichiers Godot qui les citent ;
  - les sorties du baker et les références visuelles qui changent ;
  - les étapes du plan à rouvrir (proposition).

  Rien n'est modifié dans le projet. Les étapes à rouvrir se décident ensemble.
