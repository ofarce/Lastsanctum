# data/

Ressources `.tres` d'équilibrage (unités, ennemis, bâtiments, vagues, tourelles). Chaque valeur cite sa ligne d'origine dans le prototype. Aucune constante de gameplay ne doit être codée en dur ailleurs.

- `mineable_blocks.gd` : catalogue des blocs minables (résistance en coups, nom de matière,
  identifiant de l'objet lâché) et des objets correspondants. Seule la roche est déclarée.
  Les nouvelles matières s'ajoutent ici et sont affectées à `TerrainState.block_types` par le monde.
