extends Camera3D

# --- Settings ---
@export var player_path: NodePath = "../Player"
@export var rotate_speed: float = 0.005
@export var radius: float = 5.0
@export var min_radius: float = 2.0 # Prevent zooming inside the character model
@export var max_radius: float = 7.0
@export var zoom_speed: float = 0.5

# How high up on the character to look (1.5 is usually around chest/head height)
@export var look_height: float = 1.5 

# --- Internal Variables ---
var angle_y: float = 0.0
var mouse_locked: bool = true
var current_radius: float 

@onready var player = get_node(player_path)

func _ready():
	current_radius = radius
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	# 1. Handle Mouse Look (Orbiting)
	if mouse_locked and event is InputEventMouseMotion:
		angle_y -= event.relative.x * rotate_speed

	# 2. Handle Zooming (Scroll Wheel)
	if mouse_locked and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_radius -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_radius += zoom_speed
		
		# Clamp the zoom so we don't go too close or too far
		current_radius = clamp(current_radius, min_radius, max_radius)

	# 3. Toggle Mouse Lock (Escape)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		mouse_locked = !mouse_locked
		if mouse_locked:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta):
	if not player:
		return 
		
	# Smoothly interpolate radius
	radius = lerp(radius, current_radius, delta * 10)

	# --- DYNAMIC HEIGHT CALCULATION ---
	# Instead of a fixed height of 5.0, we calculate it based on distance.
	# At max_radius (12), you liked the view (height 5). Ratio is approx 0.4.
	# We use this ratio so the camera lowers as you get closer.
	var dynamic_height = radius * 0.4
	
	# --- FOCUS POINT ---
	# We add an offset to look at the character's head/chest, not their feet.
	var target_position = player.global_position + Vector3(0, look_height, 0)

	# Compute position
	var offset = Vector3(
		radius * sin(angle_y),
		dynamic_height, 
		radius * cos(angle_y)
	)

	global_position = target_position + offset
	look_at(target_position, Vector3.UP)
