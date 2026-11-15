class_name Proj
## Projection « de dessus en 3/4 » du prototype (73b410f, Index.html : project, groundFromScreen, natW).
##
## Repères :
## - monde : (x, y, z) en unités de monde ; x vers la droite, z (sud) vers le bas, y = hauteur ;
## - natif : pixels de l'art ; natW(x, y, z) = (x·8, z·8 − y·KH) ; une case de 4×4 unités = 32×32 px ;
## - écran : pixels d'affichage = natif × PX, décalés par la caméra.
## En mode pixel, Z() = 8·PX/0,86, donc Z()·0,86 = 8·PX.

const K := 8.0
const KH := 8.0 * 0.96 / 0.86
## Centre de projection vertical : 45 % de la hauteur de l'écran (H*.45 dans le JS).
const CENTER_Y := 0.45


## Monde → pixels natifs, sans caméra (natW du JS).
static func nat(x: float, y: float, z: float) -> Vector2:
	return Vector2(x * K, z * K - y * KH)


## Décalage natif de l'origine du monde à l'écran : position native = nat(x, y, z) + camera_offset(...).
static func camera_offset(cam: Vector2, px: int, screen: Vector2) -> Vector2:
	return Vector2(screen.x / (2.0 * px) - cam.x * K, screen.y * CENTER_Y / px - cam.y * K)


## Monde → écran (project() du JS). cam = (cam.x, cam.z) en unités de monde.
static func project(x: float, y: float, z: float, cam: Vector2, px: int, screen: Vector2) -> Vector2:
	return (nat(x, y, z) + camera_offset(cam, px, screen)) * px


## Écran → sol (groundFromScreen du JS). Renvoie (x, z) en unités de monde.
static func ground_from_screen(p: Vector2, cam: Vector2, px: int, screen: Vector2) -> Vector2:
	return Vector2((p.x - screen.x / 2.0) / (K * px) + cam.x, (p.y - screen.y * CENTER_Y) / (K * px) + cam.y)


## Facteur de pixel initial : un cran plus proche que le cadrage du prototype.
static func initial_px(screen_width: float) -> int:
	return clampi(maxi(2, roundi(screen_width / 640.0)), 1, 6)
