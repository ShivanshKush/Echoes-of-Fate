@tool
extends Node3D

#@export var output_image_path: String = "res://HeightMap_Chunk_6_6.png"
@export var output_image_path: String = "res://HeightMap_Chunk_6_6.png"
@export var map_width_meters: float = 100.0
@export var map_depth_meters: float = 100.0
@export var resolution: int = 128
@export var ray_y_offset: int = 200
@onready var temporary_raycast: RayCast3D = $RayCast3D

func _ready():
	if Engine.is_editor_hint():
		print("--- Triggering Bake in Editor ---")
		await get_tree().create_timer(2.0).timeout
		await bake_heightmap()

func bake_heightmap():
	if !Engine.is_editor_hint() && OS.has_feature("editor"):
		printerr("Bake should be run in the editor for safety/simplicity.")

	print("--- Starting Raycast Heightmap Bake ---")
	
	var baked_results = await generate_height_data()
	
	if baked_results.size() > 0:
		# Instead of saving the resource, call the PNG export function
		save_height_data_as_png(baked_results)
		# You can still save the raw resource if you need the data array
		# save_height_data(baked_results.data)

func generate_height_data() -> Dictionary:
	if !is_instance_valid(temporary_raycast):
		printerr("No raycast found")
		return {}

	var height_data: PackedFloat32Array = PackedFloat32Array()
	height_data.resize(resolution * resolution)

	const EPSILON = 0.01 
	var adjusted_width = map_width_meters - 2.0 * EPSILON
	var adjusted_depth = map_depth_meters - 2.0 * EPSILON

	var step_x = adjusted_width / float(resolution - 1)
	var step_z = adjusted_depth / float(resolution - 1)
	
	var half_w = map_width_meters / 2.0
	var half_d = map_depth_meters / 2.0
	
	var start_x = -half_w + EPSILON 
	var start_z = -half_d + EPSILON	

	var min_y = 1e9
	var max_y = -1e9
	
	print("Baking...")

	for i in range(resolution):
		print("Row: ", i)
		for j in range(resolution):
			var current_x = start_x + float(i) * step_x
			var current_z = start_z + float(j) * step_z

			# Set the RayCast3D node's starting position (Global Position)
			temporary_raycast.global_position = Vector3(current_x, ray_y_offset, current_z)
			# Set the RayCast3D's target direction (Cast To property)
			# We cast down a huge distance from the start point
			temporary_raycast.target_position = Vector3(0, -ray_y_offset * 2.0, 0)
			# Force the update and check for collision
			#await get_tree().process_frame
			temporary_raycast.force_raycast_update()
			#await get_tree().process_frame

			var y_hit = 0.0
			if temporary_raycast.is_colliding():
				var collision_point = temporary_raycast.get_collision_point()
				y_hit = collision_point.y
				min_y = min(min_y, y_hit)
				max_y = max(max_y, y_hit)
			else:
				y_hit = min_y
				min_y = min(min_y, y_hit)
				max_y = max(max_y, y_hit)
			
			var index = j * resolution + i
			height_data[index] = y_hit

	print("Bake Complete.")

	var final_heights = PackedFloat32Array()
	final_heights.resize(height_data.size())
	
	var height_range = max_y - min_y
	if height_range < 0.001:
		printerr("Bake Failed: Height range is too small. Check terrain Y position.")
		return {}

	final_heights[0] = map_width_meters
	final_heights[1] = map_depth_meters
	final_heights[2] = float(resolution)
	final_heights[3] = height_range
	
	for i in range(height_data.size()):
		var normalized_height = (height_data[i] - min_y) / height_range
		final_heights[i] = height_data[i]
	var results = {
		"data": height_data,
		"min_y": min_y,
		"max_y": max_y,
		"resolution": resolution
	}
	return results

func save_height_data_as_png(baked_results: Dictionary):
	var height_data: PackedFloat32Array = baked_results.data
	var res: int = baked_results.resolution
	var min_y: float = baked_results.min_y
	var max_y: float = baked_results.max_y
	print(res, ", ", min_y, ", ", max_y)
	
	var height_range = max_y - min_y
	if height_range < 0.01:
		printerr("Cannot export PNG: Height range is too small.")
		return

	# 1. Create a new Image resource (use FORMAT_RF for 16-bit-like precision)
	var image = Image.create(res, res, false, Image.FORMAT_L8)

	# 2. Convert Raw Y-Values to Normalized 0.0-1.0 Color

	for i in range(height_data.size()):
		var raw_y = height_data[i]
		# Shift the lowest point to 0 and normalize to 0.0 - 1.0 range
		var normalized_value = (raw_y - min_y) / height_range
		# Clamp to ensure it stays within 0.0 and 1.0 boundaries
		normalized_value = clamp(normalized_value, 0.0, 1.0)
		# Create a grayscale color (R=G=B)
		var color = Color(normalized_value, normalized_value, normalized_value, 1.0)
		# Calculate X and Y pixel coordinates
		var px = i % res
		var py = i / res
		image.set_pixel(px, py, color)
	# 3. Save the Image
	var error = image.save_png(output_image_path)
	if error == OK:
		print("Successfully exported heightmap PNG")
	else:
		printerr("Failed to save PNG. Error code: ", error)
