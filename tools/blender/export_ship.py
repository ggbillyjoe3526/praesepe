"""Exports a ship's "Exterior" and "Cockpit" collections from Blender as the glTF files the game loads.

Run it inside Blender with the ship's .blend open, or from Python with Blender's `bpy` module:
	export_ship.export("C:/path/to/praesepe/game/ship/models", "hauler")
writes hauler_exterior.glb and hauler_cockpit.glb there. Only those two collections go out (never "Reference"),
with modifiers applied, Y up and the nose along -Z as Godot expects, and no cameras or lights.
Parts are joined into one mesh per material on the way out (named after the collection and the material, like Exterior_Glass), so the game draws each
collection in a handful of draw calls while the .blend keeps every part separate and named.
"""

import os

import bmesh
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


def _joined(coll, into):
	"""One object per material in `into` (named <collection>_<material>), holding every mesh of `coll` with its modifiers applied, in world space."""
	depsgraph = bpy.context.evaluated_depsgraph_get()
	by_material = {}
	parts = [obj for obj in coll.all_objects if obj.type == "MESH" and not obj.hide_render]
	for obj in parts:
		evaluated = obj.evaluated_get(depsgraph)
		mesh = evaluated.to_mesh()
		mesh.transform(obj.matrix_world)
		for index, mat in enumerate(mesh.materials):
			bm = by_material.setdefault(mat.name, (mat, bmesh.new()))[1]
			part = bmesh.new()
			part.from_mesh(mesh)
			bmesh.ops.delete(part, geom=[f for f in part.faces if f.material_index != index], context="FACES")
			loose = [v for v in part.verts if not v.link_faces]
			bmesh.ops.delete(part, geom=loose, context="VERTS")
			scratch = bpy.data.meshes.new("_part")
			part.to_mesh(scratch)
			bm.from_mesh(scratch)
			bpy.data.meshes.remove(scratch)
			part.free()
		evaluated.to_mesh_clear()
	made = []
	for name, (mat, bm) in sorted(by_material.items()):
		mesh = bpy.data.meshes.new("%s_%s" % (coll.name, name))
		bm.to_mesh(mesh)
		bm.free()
		mesh.materials.clear()
		mesh.materials.append(mat)
		for poly in mesh.polygons:
			poly.material_index = 0
		obj = bpy.data.objects.new(mesh.name, mesh)
		into.objects.link(obj)
		made.append(obj)
	return made


def export(folder, ship):
	"""Writes <ship>_exterior.glb and <ship>_cockpit.glb into `folder`. Returns the paths written."""
	view_layer = bpy.context.view_layer
	was_active = view_layer.active_layer_collection
	written = []
	try:
		for coll_name, part in PARTS.items():
			source = bpy.data.collections.get(coll_name)
			if source is None or not source.all_objects:
				raise RuntimeError("no objects in the %s collection" % coll_name)
			staging = bpy.data.collections.new("_Export" + coll_name)
			bpy.context.scene.collection.children.link(staging)
			made = _joined(source, staging)
			layer = _layer_collection(view_layer.layer_collection, staging.name)
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
			for obj in made:
				mesh = obj.data
				bpy.data.objects.remove(obj, do_unlink=True)
				bpy.data.meshes.remove(mesh)
			bpy.data.collections.remove(staging)
	finally:
		view_layer.active_layer_collection = was_active
	return written
