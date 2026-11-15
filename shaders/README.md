# shaders/

Shaders 2D :
- `world_sprite` : objets triés par profondeur (décor, bâtiments, unités). Il aligne les sprites sur la grille native, applique le vent au feuillage et le lisse ; un seul matériau sert à tout le décor (étape 12).
- `pixel_snap` : alignement natif du terrain.
- `lighting_dark`, `lighting_upscale`, `lighting_glow` : éclairage. Calque d'obscurité au quart de la résolution, agrandi en bilinéaire ; lueurs additives.
- `orb` : orbe de l'Ancre.
