class_name FlightOrder
## The order things run in each physics tick (process_physics_priority, lowest first): whoever flies the ship fills
## its input, then the ship acts on it, then the floating origin re-centres the world around where the ship ended up.

const CONTROLS := -10
const SHIP := 0
const ORIGIN := 10
