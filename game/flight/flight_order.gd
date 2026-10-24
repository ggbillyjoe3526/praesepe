class_name FlightOrder
## The order things run in each physics tick (process_physics_priority, lowest first): whoever flies the ship fills
## its input, then the ship acts on it, then the floating origin re-centres the world around where the ship ended up,
## then the cameras look for anything in the way from where the ship now is.

const CONTROLS := -10
const SHIP := 0
const ORIGIN := 10
const CAMERAS := 20
## Each frame (process_priority, lowest first), the cameras move before anything that draws over them, such as the
## HUD's markers.
const CAMERAS_DRAW := -10
