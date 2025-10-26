extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.3 

@onready var camera_pivot = $CameraPivot
@onready var anim_player = $combined/AnimationPlayer 
@onready var raycast = $RayCast3D


var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if DialogueUI:
		DialogueUI.hide_box()


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
	
	if event.is_action_pressed("interact"):
		if DialogueUI.is_active:
			DialogueUI.hide_box()
			return
			
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider.has_method("interact"):
				collider.interact() 
		return 
		

	# --- Handle Left Click to re-capture mouse ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Handle Mouse Look (only when mouse is captured) ---
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		# Horizontal look (rotates the whole player)
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		# Vertical look (rotates only the camera pivot)
		camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		# Clamp vertical look to prevent flipping
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-90), deg_to_rad(90))


func _physics_process(_delta):
	# --- Stop ALL movement and input if dialogue is active ---
	if DialogueUI.is_active:
		# Release mouse so user can click (if we add buttons later)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Stop all velocity
		velocity.x = 0
		velocity.z = 0
		move_and_slide() # Apply the zero velocity
		return # Skip the rest of the physics process
	else:
		# Make sure mouse is captured if dialogue is closed
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * _delta

	# --- Jumping ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# --- Walking ---
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis.z * input_dir.y + transform.basis.x * input_dir.x).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Slow down (friction)
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# --- Apply Movement ---
	move_and_slide()
	
	# --- Update Animations (After moving) ---
	_update_animations(direction)


# This function handles all animation logic
func _update_animations(move_direction):
	# Priority 1: Jumping
	if not is_on_floor():
		if anim_player.current_animation != "Jump":
			anim_player.play("Jump")
		return # Don't play any other animation
		
	# Priority 2: Walking
	if move_direction.length() > 0.1: # Check if moving
		if anim_player.current_animation != "Walking":
			anim_player.play("Walking")
		return # Don't play idle

	# Priority 3: Idle
	if anim_player.current_animation != "Idle":
		anim_player.play("Idle")
