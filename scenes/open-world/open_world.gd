extends Node3D

@export var spawn_chunk: = Vector2(6, 6)
@export var chunk_scene_path: String = "res://models/map/chunks/chunk_{x}_{y}/Chunk_{x}_{y}.glb"
@onready var player_node = $Player

@export var instance_data_path: String = "res://models/map/chunks/chunk_{x}_{y}/instance_data.csv"

const CHUNK_SIZE = 100

var spawn_chunk_position_xz = Vector2(
	-500 + (CHUNK_SIZE * spawn_chunk.x) + (CHUNK_SIZE / 2),
	-500 + (CHUNK_SIZE * spawn_chunk.y) + (CHUNK_SIZE / 2)
)

func _ready():
	var spawned_chunk = load_and_spawn_chunk(int(spawn_chunk.x), int(spawn_chunk.y))
	if spawned_chunk:
		var instances = read_instance_data(spawn_chunk, spawned_chunk)
		await get_tree().process_frame
		for instance_name in instances:
			print(instance_name)
			if setup_multimesh(instance_name):
				print("Spawning")
				spawn_instances_in_chunk(instance_name, instances[instance_name], spawn_chunk, spawned_chunk)
		move_player_to_spawn()
	
func load_and_spawn_chunk(x: int, y: int) -> Node:
	var chunk_path = chunk_scene_path.format({"x": int(spawn_chunk.x), "y": int(spawn_chunk.y)})
	var chunk_scene = load(chunk_path)
	
	if chunk_scene is PackedScene:
		var chunk_instance = chunk_scene.instantiate()
		
		chunk_instance.global_position = Vector3(spawn_chunk_position_xz.x, 0.0, spawn_chunk_position_xz.y)

		add_child(chunk_instance)
		print("Spawned chunk: " + chunk_path)
		return chunk_instance
	else:
		printerr("Failed to load PackedScene from path: " + chunk_path)
		return null

func move_player_to_spawn():
	if not is_instance_valid(player_node):
		printerr("Player node not found at specified path.")
		return

	var target_xz = Vector3(spawn_chunk_position_xz.x, 0.0, spawn_chunk_position_xz.y)

	var ray_start = target_xz + Vector3(0, 500.0, 0)
	var ray_end = target_xz + Vector3(0, -500.0, 0)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [player_node.get_rid()] 
	
	var result = space_state.intersect_ray(query)

	if result:
		var ground_y = result.position.y
		var player_offset_y = 1.0
		
		player_node.global_position = Vector3(target_xz.x, ground_y + player_offset_y, target_xz.z)
		print("Player moved to spawn position: " + str(player_node.global_position))
	else:
		printerr("Raycast missed terrain.")

func get_mesh(instance_name: String) -> Mesh:
	var node = get_node("Trees/%s" % instance_name)
	var mesh = null
	if node is MeshInstance3D:
		mesh = node.mesh
	return mesh

func setup_multimesh(instance_name: String) -> MultiMeshInstance3D:
	var tree_mesh = get_mesh(instance_name)
	
	if tree_mesh == null:
		push_warning("MeshInstance3D not found: %s" % instance_name)
		return null

	var multi_mesh_node = MultiMeshInstance3D.new()
	multi_mesh_node.name = "MultiMesh_%s" % instance_name
	add_child(multi_mesh_node)
	if tree_mesh:
		multi_mesh_node.multimesh = MultiMesh.new()
		var multimesh_resource = multi_mesh_node.multimesh
		multimesh_resource.mesh = tree_mesh
		multimesh_resource.transform_format = MultiMesh.TRANSFORM_3D
		multimesh_resource.instance_count = 0 
		print("Successfully initialized MultiMesh.")
		return multi_mesh_node
	else:
		printerr("Failed to extract mesh. MultiMesh remains unassigned.")
		return null

func read_instance_data(chunk: Vector2, spawned_chunk: Node) -> Dictionary:
	var file = FileAccess.open(instance_data_path.format({"x": int(chunk.x), "y": int(chunk.y)}), FileAccess.READ)
	if not file:
		printerr("Failed to open instance data: ", chunk.x, ",", chunk.y)
		return {}
	file.get_line()
	var data = file.get_as_text()
	var lines = data.split('\n', false)
	
	var instances = {}
	for line in lines:
		var values = line.split(',', false)

		var instance_type_name = values[0].strip_edges()
		if !instances.has(instance_type_name):
			instances[instance_type_name] = []
		
		var pos_x = float(values[1].strip_edges())
		var pos_y = float(values[2].strip_edges())
		var pos_z = float(values[3].strip_edges())
		var rot_x = float(values[4].strip_edges())
		var rot_y = float(values[5].strip_edges())
		var rot_z = float(values[6].strip_edges())
		var sca_x = float(values[7].strip_edges())
		var sca_y = float(values[8].strip_edges())
		var sca_z = float(values[9].strip_edges())
		
		var pos_x_godot_relative = pos_x                          # Godot X = Blender X
		var pos_y_godot_relative = pos_z                          # Godot Y = Blender Z (Height)
		var pos_z_godot_relative = pos_y * -1.0
		var correctedPos = Vector3(pos_x_godot_relative, pos_y_godot_relative, pos_z_godot_relative)

		var pos = spawned_chunk.global_position + correctedPos
		var rot = Vector3(rot_x, rot_y, rot_z)
		var sca = Vector3(sca_x, sca_y, sca_z)
		
		instances[instance_type_name].append({"pos": pos, "rot": rot, "sca": sca})
	
	return instances

func spawn_instances_in_chunk(instance_name: String, instance_transforms: Array, chunk: Vector2, spawned_chunk: Node):
	var multi_mesh_node = get_node("MultiMesh_%s" % instance_name)
	if multi_mesh_node == null or multi_mesh_node.multimesh == null:
		printerr("MultiMeshInstance3D or its MultiMesh resource is not set up correctly.")
		return

	var transforms: Array[Transform3D] = []
	
	for inst_transform in instance_transforms:
		var transform_basis = Basis()
		transform_basis = transform_basis.rotated(Vector3.UP, inst_transform.rot.y)
		transform_basis = transform_basis.scaled(inst_transform.sca)
		var instance_transform = Transform3D(transform_basis, inst_transform.pos)
		transforms.append(instance_transform)

	var multimesh = multi_mesh_node.multimesh
	multimesh.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	print("Finished setting up MultiMesh with %d trees." % multimesh.instance_count)
