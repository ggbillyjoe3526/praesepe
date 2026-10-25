class_name StarterShips
extends Resource
## The ships a new game offers (design doc, "Ships"), in the order the new-game screen shows them. The first playable
## has one; the Interceptor and the Surveyor are added here when they are built.

@export var ships: Array[ShipClass] = []


## The ship whose id is `id`, or null.
func find(id: StringName) -> ShipClass:
	for s: ShipClass in ships:
		if s.id == id:
			return s
	return null
