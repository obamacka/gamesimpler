## Builds the VoxelBlockyLibrary from Database materials (spec 3.4): model index = voxel_id,
## index 0 is air. Placeholder colors until block textures exist.
class_name VoxelLibraryBuilder
extends RefCounted


static func build() -> VoxelBlockyLibrary:
	var lib := VoxelBlockyLibrary.new()
	lib.add_model(VoxelBlockyModelEmpty.new())
	var max_id := 0
	for m in Database.materials.values():
		max_id = maxi(max_id, m.voxel_id)
	for id in range(1, max_id + 1):
		var cube := VoxelBlockyModelCube.new()
		var mat := StandardMaterial3D.new()
		var def := Database.material_by_voxel(id)
		mat.albedo_color = def.color if def else Color.MAGENTA
		cube.set_material_override(0, mat)
		lib.add_model(cube)
	lib.bake()
	return lib
