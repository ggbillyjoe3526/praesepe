class_name BeltTuning
extends Resource
## The shape of one asteroid belt and how many rocks it holds (design doc, "The tiny solar system"). The belt's place is
## authored; where each rock sits comes from the world seed (BeltLayout). The values and the reasons for them are in
## DESIGN.md, "Belt tuning". Change a value there and here together.

## The world feature its rocks are drawn from (Game.world_rng): a different name gives a different belt.
@export var feature: StringName = &"belt"

@export_group("Shape (m)")
## The ring's radius around its centre, to the middle of the band.
@export var ring_radius: float = 50000.0
## How far the band reaches either side of that radius.
@export var half_width: float = 3000.0
## How far it reaches above and below the ring's plane.
@export var half_height: float = 400.0

@export_group("Rocks")
## Rocks scattered thinly all round the ring.
@export var scattered: int = 3000
## Dense clusters (pockets) along the ring, where the rocks are close together.
@export var pockets: int = 10
@export var rocks_per_pocket: int = 220
## How far (m) a pocket's rocks reach from its middle, sideways; up and down it reaches `pocket_flatten` of that.
@export var pocket_radius: float = 1200.0
@export var pocket_flatten: float = 0.3
## Where the first pocket sits, the one the belt's HUD marker points to: degrees round the ring from its +x axis
## towards +z, on the band's inner edge.
@export var home_angle: float = -53.13
## The smallest and biggest rock (m, radius). Small ones are much commoner.
@export var rock_min_radius: float = 15.0
@export var rock_max_radius: float = 110.0

@export_group("Drawing")
## How many pieces the ring is drawn in, so only the pieces in view are drawn.
@export var chunks: int = 64
## Within this distance (m) of the camera a piece's rocks are drawn in detail; beyond it as simple shapes.
@export var near_distance: float = 9000.0
## Beyond this distance (m) a piece's rocks aren't drawn; the belt's haze shows where it is.
@export var far_distance: float = 70000.0

@export_group("Collision")
## How many rocks can be solid at once: the ones nearest the ship (pooled, never more).
@export var solid_rocks: int = 48
## Rocks within this distance (m) of the ship are made solid.
@export var solid_reach: float = 2500.0
## How often (physics ticks) the solid rocks are picked again.
@export var solid_every: int = 10
