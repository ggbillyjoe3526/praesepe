"""Exports a ship's "Exterior" and "Cockpit" collections from Blender as the glTF files the game loads.

Run it inside Blender with the ship's .blend open, or from Python with Blender's `bpy` module:
	export_ship.export("C:/path/to/project-praesepe/game/ship/models", "hauler")
writes hauler_exterior.glb and hauler_cockpit.glb there. Only those two collections go out (never "Reference"),
with modifiers applied, Y up and the nose along -Z as Godot expects, and no cameras or lights.
"""

import os

import bpy

PARTS = {"Exterior": "exterior", "Cockpit": "cockpit"}


def _layer_collection(layer, name):
	if layer.name == name:
		return layer
	for child in layer.children:
		found = _layer_collection(child, name)
		if found is not None:
			return found
	return None


def export(folder, ship):
	"""Writes <ship>_exterior.glb and <ship>_cockpit.glb into `folder`. Returns the paths written."""
	view_layer = bpy.context.view_layer
	was_active = view_layer.active_layer_collection
	written = []
	try:
		for coll_name, part in PARTS.items():
			layer = _layer_collection(view_layer.layer_collection, coll_name)
			if layer is None or not layer.collection.all_objects:
				raise RuntimeError("no objects in the %s collection" % coll_name)
			view_layer.active_layer_collection = layer
			path = os.path.join(folder, "%s_%s.glb" % (ship, part))
			bpy.ops.export_scene.gltf(
				filepath=path,
				export_format="GLB",
				use_active_collection=True,
				use_active_collection_with_nested=True,
				export_apply=True,
				export_yup=True,
				export_cameras=False,
				export_lights=False,
				export_extras=False,
				export_animations=False,
			)
			written.append(path)
	finally:
		view_layer.active_layer_collection = was_active
	return written
