extends Node3D

var player: Node3D
#var radius: float = 16.0          # Distance from player
#var height: float = 25.0          # Fixed Y height
#var angle_y: float = 0.0         # Current orbit angle (in radians)
#var rotate_speed: float = 0.003  # Mouse sensitivity
var tilt_angle: float = deg_to_rad(30.0)
@onready var camera: Camera3D = $Camera3D

var mouse_locked := true

func _ready():
	# Lock and hide cursor at start
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	rotation.x = -tilt_angle
	add_to_group("camera")
	deferred_init()

func deferred_init():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		printerr("Player not found")

func _unhandled_input(event):
	# Handle camera rotation from mouse motion
	#if mouse_locked and event is InputEventMouseMotion:
		#angle_y -= event.relative.x * rotate_speed

	# Handle cursor locking toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		mouse_locked = !mouse_locked
		Input.set_mouse_mode(
			mouse_locked if Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_VISIBLE
		)

func _process(delta):
	if mouse_locked:
		#var mouse_delta = Input.get_last_mouse_velocity()
		#angle_y -= mouse_delta.x * rotate_speed

		# Compute orbit offset (XZ plane)
		#var offset = Vector3(
			#radius * sin(angle_y),
			#height,
			#radius * cos(angle_y)
		#)

		global_position = player.global_position
		#look_at(player.global_position, Vector3.UP)
