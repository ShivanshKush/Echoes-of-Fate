extends Node3D

@export var spawn_chunk: = Vector2(6, 6)
@export var chunk_scene_path: String = "res://models/map/chunks/chunk_{x}_{y}/Chunk_{x}_{y}.glb"
@onready var player_node = $Player
@onready var camera = $Camera3D
@export var instance_data_path: String = "res://models/map/chunks/chunk_{x}_{y}/instance_data.csv"
@export var npc_data_path: String = "res://models/map/chunks/chunk_{x}_{y}/npc_data.csv"
@export var min_height: float = 14.4214935302734
@export var max_height: float = 24.9670562744141

var heightmap_path: String = "res://models/map/chunks/chunk_{x}_{y}/HeightMap_Chunk_{x}_{y}.png"
var heightmaps: Dictionary[String, PackedFloat32Array] = {}
var heightmap_res: int = 128
var foliagemap_path = "res://models/map/chunks/chunk_{x}_{y}/FoliageMap_Chunk_{x}_{y}.png"
var foliagemaps: Dictionary[String, PackedFloat32Array] = {}
var foliagemap_res: int = 1024

### NPCs

@export var npc1_scene: PackedScene = preload("res://scenes/NPCs/NPC.tscn")
@export var npc2_scene: PackedScene = preload("res://scenes/NPCs/NPC_2.tscn")
@export var npc3_scene: PackedScene = preload("res://scenes/NPCs/NPC_3.tscn")
var npcScenesMap = {
	"Farmer": npc1_scene,
	"Lady": npc2_scene,
	"Guard": npc3_scene,
}
#### NPCs

#### GRASS
@export var grass_chunk_scene: PackedScene = preload("res://models/environment/foliage/grass/grass-chunk.tscn")
#@export var grass_mesh_source: MeshInstance3D = $Grass/Grass_1
@onready var grass_mesh_source: MeshInstance3D = $Grass/Grass_1
@export var grass_draw_radius: int = 10
@export var grass_chunk_size: float = 5.0
var half_grass_chunk_size = grass_chunk_size / 2.0
# Internal state
var loaded_grass_chunks: Dictionary = {}
var draw_distance_grass_chunks: int
var current_player_grass_chunk_coord: Vector2i = Vector2i(-999, -999)
#### GRASS

const CHUNK_SIZE = 100
const WORLD_SIZE = 1000
const HALF_CHUNK_SIZE = CHUNK_SIZE / 2.0
const HALF_WORLD_SIZE = WORLD_SIZE / 2.0

func get_chunk_pos(chunk: Vector2):
	return Vector3(
		-500 + (CHUNK_SIZE * chunk.x) + (CHUNK_SIZE / 2),
		0,
		-500 + (CHUNK_SIZE * chunk.y) + (CHUNK_SIZE / 2)
	)
func get_chunk_pos_from_player(player_pos: Vector3):
	#print("GetChunkFromPlayer: ", player_pos.x, ", ", player_pos.z)
	var chunk_x = clamp(floor(((player_pos.x + HALF_WORLD_SIZE) / WORLD_SIZE) * 10), 0, 9)
	var chunk_y = clamp(floor(((player_pos.z + HALF_WORLD_SIZE) / WORLD_SIZE) * 10), 0, 9)
	#print("GetChunkFromPlayer: ", chunk_x, ", ", chunk_y)
	return Vector2(chunk_x, chunk_y)

func _ready():
	player_node.camera_ref = camera

	var chunk_instance = load_and_spawn_chunk(spawn_chunk)
	if chunk_instance:
		var instances = read_instance_data(spawn_chunk, chunk_instance)
		var npcs = read_npc_data(spawn_chunk, chunk_instance)
		await get_tree().process_frame
		for instance_name in instances:
			#print(instance_name, " ", instances[instance_name].size())
			if setup_multimesh(instance_name):
				var shape_type = "trimesh"
				var instance_type = instance_name.substr(0, instance_name.rfind("_"))
				if instance_type == "House":
					shape_type = "simple_convex"
				var shape = generate_instance_collider(instance_name, shape_type)
				if shape:
					spawn_instances_in_chunk(instance_name, instances[instance_name], shape, chunk_instance)
		for npc_name in npcs:
			spawn_npcs_in_chunk(npc_name, npcs[npc_name], chunk_instance)
		move_player_to_spawn(spawn_chunk)
	
		#### GRASS
		if is_instance_valid(grass_mesh_source) && grass_mesh_source.mesh != null:
			draw_distance_grass_chunks = int(ceil(grass_draw_radius / grass_chunk_size))
			# Initial grid load
			var player_in_terrain_chunk = get_chunk_pos_from_player(player_node.global_position)
			var player_in_terrain_chunk_key = "{x}_{y}".format({"x": int(player_in_terrain_chunk.x), "y": int(player_in_terrain_chunk.y)})
			#print("Player in chunk: ", player_in_terrain_chunk.x, ", ", player_in_terrain_chunk.y)
			update_grass_grid(player_node.global_position, player_in_terrain_chunk, player_in_terrain_chunk_key)
		else:
			printerr("Grass Mesh Source is invalid. Cannot start grass system.")
		#### GRASS

func _process(_delta):
	var player_pos = player_node.global_position
	# Calculate player's current chunk index
	var current_grass_chunk_x = floor(player_pos.x / grass_chunk_size)
	var current_grass_chunk_z = floor(player_pos.z / grass_chunk_size)
	var current_coord = Vector2i(current_grass_chunk_x, current_grass_chunk_z)
	
	if current_coord != current_player_grass_chunk_coord:
		current_player_grass_chunk_coord = current_coord
		var player_in_terrain_chunk = get_chunk_pos_from_player(player_pos)
		var player_in_terrain_chunk_key = "{x}_{y}".format({"x": int(player_in_terrain_chunk.x), "y": int(player_in_terrain_chunk.y)})
		update_grass_grid(player_pos, player_in_terrain_chunk, player_in_terrain_chunk_key)

func preload_heightmap_data(chunk: Vector2):
	var chunk_key = "{x}_{y}".format({"x":int(chunk.x), "y": int(chunk.y)})
	if heightmaps.has(chunk_key):
		return
	
	var heightmap_tex = ResourceLoader.load(heightmap_path.format({"x": int(chunk.x), "y": int(chunk.y)}))
	var heightmap: Image
	var heightmap_data: PackedFloat32Array
	if heightmap_tex is Texture2D:
		heightmap = heightmap_tex.get_image()
		#heightmap.resize(100, 100)
	else:
		printerr("HeightMap not found for terrain chunk: ", chunk)
		return

	var width = heightmap.get_width()
	var height = heightmap.get_height()
	heightmap_data.resize(width * height)
	
	#var min_observed_color_r = 1.0
	#var max_observed_color_r = 0.0

	#for y in range(height):
		#for x in range(width):
			#var color: Color = image.get_pixel(x, y)
			#if color.r > max_observed_color_r:
				#max_observed_color_r = color.r
			#if color.r < min_observed_color_r:
				#min_observed_color_r = color.r
	#print("Observed Color Range: ", min_observed_color_r, ", ", max_observed_color_r)

	#var min_observed_height = 1000
	#var max_observed_height = -1000
	for y in range(height):
		for x in range(width):
			# Get the grayscale value (R channel)
			var color: Color = heightmap.get_pixel(x, y)
			# Calculate the final height value
			var final_height = (color.r * (max_height - min_height)) + min_height
			#heightmap[index] = final_height + 14.420930
			#if final_height > max_observed_height:
				#max_observed_height = final_height
			#if final_height < min_observed_height:
				#min_observed_height = final_height
			# Calculate the 1D index and store the height
			var index = y * width + x
			heightmap_data[index] = final_height
	#print("Observed Height Range: ", min_observed_height, ", ", max_observed_height)
	heightmaps[chunk_key] = heightmap_data
	print("Loaded height map for chunk: ", chunk)

func preload_foliagemap_data(chunk: Vector2):
	var chunk_key = "{x}_{y}".format({"x":int(chunk.x), "y": int(chunk.y)})
	if foliagemaps.has(chunk_key):
		return
	var foliagemap_tex = ResourceLoader.load(foliagemap_path.format({"x": int(chunk.x), "y": int(chunk.y)}))
	var foliagemap: Image
	var foliagemap_data: PackedFloat32Array
	if foliagemap_tex is Texture2D:
		foliagemap = foliagemap_tex.get_image()
	else:
		printerr("FoliageMap not found for terrain chunk: ", chunk)
		return
	
	var width = foliagemap.get_width()
	var height = foliagemap.get_height()
	foliagemap_data.resize(width * height)
	for y in range(height):
		for x in range(width):
			var color: Color = foliagemap.get_pixel(x, y)
			# Calculate the 1D index and store the data
			var index = y * width + x
			foliagemap_data[index] = color.r
	foliagemaps[chunk_key] = foliagemap_data
	print("Loaded foliage map for chunk: ", chunk)

func update_grass_grid(player_pos: Vector3, terrain_chunk: Vector2, terrain_chunk_key: String):
	#print("Start")
	#print("Existing: ", loaded_grass_chunks.keys())
	#print("UpdateGrassGrid: ", player_pos.x, ", ", player_pos.z)
	var terrain_chunk_pos = get_chunk_pos(terrain_chunk)
	var player_rel_pos = player_pos - terrain_chunk_pos
	var player_in_grass_chunk_x = floor(((player_rel_pos.x + HALF_CHUNK_SIZE) / CHUNK_SIZE) * (CHUNK_SIZE / grass_chunk_size))
	var player_in_grass_chunk_y = floor(((player_rel_pos.z + HALF_CHUNK_SIZE) / CHUNK_SIZE) * (CHUNK_SIZE / grass_chunk_size))
	player_in_grass_chunk_x = clamp(player_in_grass_chunk_x, 0, 19)
	player_in_grass_chunk_y = clamp(player_in_grass_chunk_y, 0, 19)

	var center_x = player_in_grass_chunk_x
	var center_z = player_in_grass_chunk_y
	var new_keys: Array[String] = []
	var radius = draw_distance_grass_chunks
	# Determine the set of grass chunks that should be visible
	for x in range(clamp(center_x - radius, 0, 19), clamp(center_x + radius + 1, 0, 19)):
		for z in range(clamp(center_z - radius, 0, 19), clamp(center_z + radius + 1, 0, 19)):
			var key = str(int(x)) + "_" + str(int(z))
			new_keys.append(key)
			if not loaded_grass_chunks.has(key):
				load_grass_chunk(x, z, terrain_chunk, terrain_chunk_key)

	#print("New: ", new_keys)
	# Unload old grass chunks (start fade-out)
	var grass_chunks_to_remove: Array[String] = []
	for key in loaded_grass_chunks.keys():
		if not key in new_keys:
			grass_chunks_to_remove.append(key)
	for key in grass_chunks_to_remove:
		unload_grass_chunk(key)
	#print("Removed: ", grass_chunks_to_remove)

func load_grass_chunk(x: int, z: int, terrain_chunk: Vector2, terrain_chunk_key: String):
	var key = str(int(x)) + "_" + str(int(z))
	var grass_chunk_instance = grass_chunk_scene.instantiate()
	if grass_mesh_source.mesh == null:
		printerr("No grass mesh")
	grass_chunk_instance.grass_mesh = grass_mesh_source.mesh
	grass_chunk_instance.chunk_size = grass_chunk_size
	# Pass the fast Y-lookup method to the grass chunk script
	grass_chunk_instance.height_sampler = Callable(self, "get_height_from_world_xz")
	grass_chunk_instance.foliage_sampler = Callable(self, "get_foliage_from_world_xz")

	var terrain_chunk_pos = get_chunk_pos(terrain_chunk)
	var grass_chunk_pos_x = (x * grass_chunk_size) + half_grass_chunk_size - HALF_CHUNK_SIZE + terrain_chunk_pos.x
	var grass_chunk_pos_z = (z * grass_chunk_size) + half_grass_chunk_size - HALF_CHUNK_SIZE + terrain_chunk_pos.z
	grass_chunk_instance.global_position = Vector3(grass_chunk_pos_x, 0, grass_chunk_pos_z)
	grass_chunk_instance.generate_grass(x, z, terrain_chunk, terrain_chunk_key)
	# Parent the grass chunk to this manager or a dedicated grass root node
	add_child(grass_chunk_instance)
	loaded_grass_chunks[key] = grass_chunk_instance

func unload_grass_chunk(key: String):
	var grass_chunk = loaded_grass_chunks[key]
	loaded_grass_chunks.erase(key)
	# Start the fade-out in the grass chunk script
	if grass_chunk:
		grass_chunk.fade_out()

func load_and_spawn_chunk(chunk: Vector2) -> Node:
	var chunk_path = chunk_scene_path.format({"x": int(chunk.x), "y": int(chunk.y)})
	var chunk_scene = load(chunk_path)
	
	preload_heightmap_data(chunk)
	preload_foliagemap_data(chunk)
	
	if chunk_scene is PackedScene:
		var chunk_instance = chunk_scene.instantiate()
		
		var global_chunk_pos = get_chunk_pos(chunk)
		chunk_instance.global_position = Vector3(global_chunk_pos.x, 0.0, global_chunk_pos.z)

		add_child(chunk_instance)
		print("Spawned chunk: " + chunk_path)
		return chunk_instance
	else:
		printerr("Failed to load PackedScene from path: " + chunk_path)
		return null

func move_player_to_spawn(chunk: Vector2):
	if not is_instance_valid(player_node):
		printerr("Player node not found at specified path.")
		return

	var global_chunk_pos = get_chunk_pos(chunk)
	var target_xz = Vector3(global_chunk_pos.x, 0.0, global_chunk_pos.z)

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
	var node = get_node("{type}/{name}".format({
		"type": instance_name.substr(0, instance_name.rfind("_")),
		"name": instance_name})
	)
	var mesh = null
	if node is MeshInstance3D:
		mesh = node.mesh
	return mesh

func setup_multimesh(instance_name: String) -> MultiMeshInstance3D:
	var instance_mesh = get_mesh(instance_name)
	
	if instance_mesh == null:
		push_warning("MeshInstance3D not found: %s" % instance_name)
		return null

	var multi_mesh_node = MultiMeshInstance3D.new()
	multi_mesh_node.name = "MultiMesh_%s" % instance_name
	add_child(multi_mesh_node)
	if instance_mesh:
		multi_mesh_node.multimesh = MultiMesh.new()
		var multimesh_resource = multi_mesh_node.multimesh
		multimesh_resource.mesh = instance_mesh
		multimesh_resource.transform_format = MultiMesh.TRANSFORM_3D
		multimesh_resource.instance_count = 0 
		#print("Successfully initialized MultiMesh.")
		return multi_mesh_node
	else:
		printerr("Failed to extract mesh. MultiMesh remains unassigned.")
		return null

func read_instance_data(chunk: Vector2, chunk_instance: Node) -> Dictionary:
	var file = FileAccess.open(instance_data_path.format({"x": int(chunk.x), "y": int(chunk.y)}), FileAccess.READ)
	if not file:
		printerr("Failed to open instance data: ", chunk.x, ",", chunk.y)
		return {}
	var data = file.get_as_text()
	var lines = data.split('\n', false)
	
	var instances = {}
	for idx in range(lines.size()):
		# Skip CSV header
		if idx == 0:
			continue

		var line = lines[idx]
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
		
		var pos_x_godot_relative = pos_x			# Godot X = Blender X
		var pos_y_godot_relative = pos_z			# Godot Y = Blender Z (Height)
		var pos_z_godot_relative = pos_y * -1.0 	# Godot Z = Blender Y (Inverted)
		var correctedPos = Vector3(pos_x_godot_relative, pos_y_godot_relative, pos_z_godot_relative)

		var pos = chunk_instance.global_position + correctedPos
		var rot = Vector3(rot_x, rot_y, rot_z)
		var sca = Vector3(sca_x, sca_y, sca_z)
		
		instances[instance_type_name].append({"pos": pos, "rel_pos": correctedPos, "rot": rot, "sca": sca})
	
	return instances

func read_npc_data(chunk: Vector2, chunk_instance: Node) -> Dictionary:
	var file = FileAccess.open(npc_data_path.format({"x": int(chunk.x), "y": int(chunk.y)}), FileAccess.READ)
	if not file:
		printerr("Failed to open npc data: ", chunk.x, ",", chunk.y)
		return {}
	var data = file.get_as_text()
	var lines = data.split('\n', false)
	
	var npcs = {}
	for idx in range(lines.size()):
		# Skip CSV header
		if idx == 0:
			continue

		var line = lines[idx]
		var values = line.split(',', false)

		var npc_type_name = values[0].strip_edges()
		if !npcs.has(npc_type_name):
			npcs[npc_type_name] = []
		
		var pos_x = float(values[1].strip_edges())
		var pos_y = float(values[2].strip_edges())
		var pos_z = float(values[3].strip_edges())
		var rot_x = float(values[4].strip_edges())
		var rot_y = float(values[5].strip_edges())
		var rot_z = float(values[6].strip_edges())
		var sca_x = float(values[7].strip_edges())
		var sca_y = float(values[8].strip_edges())
		var sca_z = float(values[9].strip_edges())
		
		#var pos_x_godot_relative = pos_x			# Godot X = Blender X
		#var pos_y_godot_relative = pos_z			# Godot Y = Blender Z (Height)
		#var pos_z_godot_relative = pos_y * -1.0 	# Godot Z = Blender Y (Inverted)
		var correctedPos = Vector3(pos_x, pos_y, pos_z)

		var pos = chunk_instance.global_position + correctedPos
		var rot = Vector3(rot_x, rot_y, rot_z)
		var sca = Vector3(sca_x, sca_y, sca_z)
		
		npcs[npc_type_name].append({"pos": pos, "rel_pos": correctedPos, "rot": rot, "sca": sca})
	
	return npcs

func spawn_instances_in_chunk(instance_name: String, instance_transforms: Array, shape: Shape3D, chunk_instance: Node):
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
		create_instance_collider(inst_transform, shape, chunk_instance)

	var multimesh = multi_mesh_node.multimesh
	multimesh.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	#print("Finished setting up MultiMesh with %d instances." % multimesh.instance_count)

func spawn_npcs_in_chunk(instance_name: String, instance_transforms: Array, chunk_instance: Node):	
	for inst_transform in instance_transforms:
		var transform_basis = Basis()
		transform_basis = transform_basis.rotated(Vector3.UP, inst_transform.rot.y)
		transform_basis = transform_basis.scaled(inst_transform.sca)
		var instance_transform = Transform3D(transform_basis, inst_transform.pos)

		var npc_scene = npcScenesMap[instance_name]
		var npc_instance = npc_scene.instantiate()
		npc_instance.transform = instance_transform
		add_child(npc_instance)

func generate_instance_collider(instance_name: String, shape_type: String):
	var instance_mesh: ArrayMesh = get_mesh(instance_name)
	
	if instance_mesh:
		var new_shape: Shape3D = null
		if shape_type == "trimesh":
			new_shape = instance_mesh.create_trimesh_shape()
		elif shape_type == "simple_convex":
			new_shape = instance_mesh.create_convex_shape()
		
		if new_shape:
			#print("Dynamically generated Shape3D (Trimesh).")
			return new_shape
		else:
			printerr("Could not generate Trimesh shape: create_trimesh_shape() returned null. Check if the mesh geometry is valid (e.g., uses Mesh.PRIMITIVE_TRIANGLES).")
			return null
	else:
		printerr("Could not generate Trimesh shape: Mesh is null.")
		return null

func create_instance_collider(inst_transform: Dictionary, shape: Shape3D, chunk_instance: Node):
	var collider_instance = StaticBody3D.new()
	var collision_shape_node = CollisionShape3D.new()
	collision_shape_node.shape = shape
	collider_instance.add_child(collision_shape_node)

	collider_instance.global_position = inst_transform.rel_pos
	collider_instance.rotation = Vector3(0, inst_transform.rot.y, 0)
	#collider_instance.rotation = inst_transform.rot
	collider_instance.scale = inst_transform.sca
	
	chunk_instance.add_child(collider_instance)

func get_height_from_world_xz(chunk_rel_pos: Vector3, chunk_key: String) -> float:
	var heightmap: PackedFloat32Array = heightmaps[chunk_key]
	if not heightmap:
		printerr("No height map")
		return 0.0

	#print("Chunk: ", chunk.x, ", ", chunk.y)
	#print("Chunk Global Pos: ", chunk_global_position.x, ",", chunk_global_position.z)
	#print("GrassBlade Pos: ", x, ", ", z)
	#print("Relative Pos: ", relative_pos.x, ", ", relative_pos.z)
	# Godot X (World) corresponds to Texture Y (Height)
	#var lookup_x = x # Use the inverted Z-coordinate for the lookup's X-axis
	#var lookup_y = -z # Use the X-coordinate for the lookup's Y-axis
	
	# Calculate UV_X based on the Z-coordinate (Blender's Y-axis)
	var lookup_x = (chunk_rel_pos.x + HALF_CHUNK_SIZE) / CHUNK_SIZE
	# Calculate UV_Z based on the X-coordinate (Blender's X-axis)
	var lookup_y = (chunk_rel_pos.z + HALF_CHUNK_SIZE) / CHUNK_SIZE
	
	var uv = Vector2(lookup_x, lookup_y)
	
	#uv_x = 1 - uv_x
	#uv_y = 1 - uv_y
	
	# 3. UV to Pixel Index Conversion
	var px = int(uv.x * heightmap_res)
	var py = int(uv.y * heightmap_res)
	
	# Clamp indices to bounds
	px = clamp(px, 0, heightmap_res - 1)
	py = clamp(py, 0, heightmap_res - 1)
	
	# 4. CRITICAL FAST LOOKUP
	#py = int(image_height) - 1 - py
	#px = int(image_width) - 1 - pxdone
	var index = py * heightmap_res + px
	#print(heightmap[index])
	return heightmap[index]

func get_foliage_from_world_xz(chunk_rel_pos: Vector3, chunk_key: String) -> float:
	var foliagemap: PackedFloat32Array = foliagemaps[chunk_key]
	if not foliagemap:
		printerr("No foliage map")
		return 0.0

	var lookup_x = (chunk_rel_pos.x + HALF_CHUNK_SIZE) / CHUNK_SIZE
	var lookup_y = (chunk_rel_pos.z + HALF_CHUNK_SIZE) / CHUNK_SIZE
	var uv = Vector2(1 - lookup_x, 1 - lookup_y)
	var px = int(uv.x * foliagemap_res)
	var py = int(uv.y * foliagemap_res)
	var index = py * foliagemap_res + px
	return foliagemap[index]
