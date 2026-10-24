class_name Landmark
extends Node3D
## A place in the solar system the player can head for: a planet, a moon, a station, a base or the asteroid belt
## (design doc, "World"). It says how far its surface is from a point, so the cruise drive (CruiseDrive) can slow down
## near it and drop out when the ship arrives, and where the HUD marker for it goes (LandmarkMarkers). Its size is a
## sphere of `radius` around it unless a kind of landmark knows better (AsteroidBelt). Placed by hand in the solar
## system's scene, like everything authored, and moved with the rest of the world by the floating origin.

## Its name, as the HUD and messages show it. Every name is in DESIGN.md's naming list.
@export var display_name: String = ""
## How far (m) its surface is from its centre, for a plain sphere.
@export var radius: float = 100.0
## How close (m) to its surface the cruise drive drops out on arrival.
@export var drop_distance: float = 2000.0
## Something the ship could fly into: the cruise drive slows down near it and never runs into it.
@export var obstacle: bool = true
## Shows a marker with its name and distance on the HUD.
@export var marker: bool = true


## How far (m) `point` (world space) is from its surface; zero on or inside it.
func surface_distance(point: Vector3) -> float:
	return maxf(point.distance_to(global_position) - radius, 0.0)


## Where its HUD marker points (world space).
func marker_position() -> Vector3:
	return global_position


## The distance (m) its HUD marker shows from `point`: to its surface, which is what the player flies to.
func marker_distance(point: Vector3) -> float:
	return surface_distance(point)

