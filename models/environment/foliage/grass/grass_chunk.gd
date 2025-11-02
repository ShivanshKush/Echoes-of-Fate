extends Node3D

@export var chunk_size: float = 5.0
@export var density_per_sq_m: float = 10.0
@export var grass_mesh: Mesh
@export var height_sampler: Callable
@export var foliage_sampler: Callable
var multimesh_node: MultiMeshInstance3D = null

var half_chunk_size = chunk_size / 2.0
var is_active: bool = false
const BLADE_HEIGHT_HALF = 0.15
const TAU = 6.283185307
const TERRAIN_CHUNK_SIZE = 100
const HALF_TERRAIN_CHUNK_SIZE = 50

func _ready():
	if !grass_mesh:
		printerr("No grass mesh")

func generate_grass(chunk_x: int, chunk_z: int, terrain_chunk: Vector2, terrain_chunk_key: String):
	#print("GeneratingGrass: ", terrain_chunk.x, ", ", terrain_chunk.y, " : ", chunk_x, ", ", chunk_z)

	multimesh_node = find_child("MultiMesh_Grass_Chunk") as MultiMeshInstance3D

	if !multimesh_node:
		printerr("Grass chunk generation failed: MultiMeshInstance3D node not found.")
		return
	if multimesh_node.multimesh == null:
		multimesh_node.multimesh = MultiMesh.new()
		multimesh_node.multimesh.mesh = grass_mesh
		multimesh_node.multimesh.transform_format = MultiMesh.TRANSFORM_3D

	if !grass_mesh || !height_sampler.is_valid():
		printerr("Grass chunk generation failed: Missing Mesh or Height Sampler.")
		return

	var total_blades = int(chunk_size * chunk_size * density_per_sq_m)
	var terrain_chunk_pos = get_terrain_chunk_pos(terrain_chunk)
	var transforms: Array[Transform3D] = []

	for i in range(total_blades):
		var local_x = randf() * chunk_size - half_chunk_size
		var local_z = randf() * chunk_size - half_chunk_size
		
		var grass_chunk_pos_x = (chunk_x * chunk_size) + half_chunk_size - HALF_TERRAIN_CHUNK_SIZE + terrain_chunk_pos.x
		var grass_chunk_pos_z = (chunk_z * chunk_size) + half_chunk_size - HALF_TERRAIN_CHUNK_SIZE + terrain_chunk_pos.z
		var grass_chunk_pos = Vector3(grass_chunk_pos_x, 0, grass_chunk_pos_z)

		var world_pos_xz = grass_chunk_pos + Vector3(local_x, 0.0, local_z)
		var world_chunk_rel_pos_xz = world_pos_xz - terrain_chunk_pos

		if should_place_grass(world_chunk_rel_pos_xz, terrain_chunk_key):
			var world_y: float = height_sampler.call(world_chunk_rel_pos_xz, terrain_chunk_key)
			var local_y = world_y
			var pos = Vector3(local_x, local_y + BLADE_HEIGHT_HALF, local_z)

			var inst_basis = Basis().rotated(Vector3.UP, randf_range(0, TAU))
			inst_basis = inst_basis.scaled(Vector3(1.0, randf_range(0.8, 1.2), 1.0))
			var inst_transform = Transform3D(inst_basis, pos)
			transforms.append(inst_transform)

	multimesh_node.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh_node.multimesh.set_instance_transform(i, transforms[i])

	is_active = true
	fade_in()

func should_place_grass(chunk_rel_pos: Vector3, terrain_chunk_key: String) -> bool:
	var alpha: float = foliage_sampler.call(chunk_rel_pos, terrain_chunk_key)
	return alpha > 0.75

func fade_in():
	multimesh_node.set_instance_shader_parameter("fade", 0)
	var tween = create_tween()
	tween.tween_method(
		func(value): multimesh_node.set_instance_shader_parameter("fade", value),
		0.0, 1.0, 1
	);

func fade_out():
	multimesh_node.set_instance_shader_parameter("fade", 0)
	var tween = create_tween()
	tween.tween_method(
		func(value): multimesh_node.set_instance_shader_parameter("fade", value),
		1.0, 0.0, 1
	);

func get_terrain_chunk_pos(terrain_chunk: Vector2):
	return Vector3(
		-500 + (TERRAIN_CHUNK_SIZE * terrain_chunk.x) + HALF_TERRAIN_CHUNK_SIZE,
		0,
		-500 + (TERRAIN_CHUNK_SIZE * terrain_chunk.y) + HALF_TERRAIN_CHUNK_SIZE
	)
