extends Camera3D

@onready var player = $"../Player"

var radius: float = 5.0          # Distance from player
var height: float = 5.0          # Fixed Y height
var angle_y: float = 0.0         # Current orbit angle (in radians)
var rotate_speed: float = 0.005  # Mouse sensitivity
var tilt_angle: float = deg_to_rad(45.0)

var mouse_locked := true

func _ready():
	# Lock and hide cursor at start
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	rotation.x = -tilt_angle

func _unhandled_input(event):
	# Handle camera rotation from mouse motion
	if mouse_locked and event is InputEventMouseMotion:
		angle_y -= event.relative.x * rotate_speed

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
		var offset = Vector3(
			radius * sin(angle_y),
			height,
			radius * cos(angle_y)
		)

		global_position = player.global_position + offset
		look_at(player.global_position, Vector3.UP)
