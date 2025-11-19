extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5

@onready var anim_player = $Player/combined/AnimationPlayer
@onready var raycast = $Player/RayCast3D
var camera_ref: Camera3D = null

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var move_speed: float = 5.0
var rotation_speed: float = 8.0 # smoothing factor

func _ready():
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if DialogueUI:
		DialogueUI.hide_box()
	add_to_group("player")

func _unhandled_input(event):
	#if event.is_action_pressed("ui_cancel"):
		#if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			#return
	
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
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		#if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	# --- Stop ALL movement and input if dialogue is active ---
	if DialogueUI.is_active:
		# Release mouse so user can click (if we add buttons later)
		#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Stop all velocity
		velocity.x = 0
		velocity.z = 0
		move_and_slide() # Apply the zero velocity
		return # Skip the rest of the physics process
	#else:
		# Make sure mouse is captured if dialogue is closed
		#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Jumping ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	input_dir = input_dir.normalized()
	# get camera's forward/right on XZ plane
	var cam_forward = camera_ref.global_transform.basis.z
	var cam_right = camera_ref.global_transform.basis.x
	cam_forward.y = 0
	cam_right.y = 0
	# ignore Y component to stay flat on ground
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	# move direction relative to camera
	var move_dir = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()
	if input_dir.length() > 0:
		# move player
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		# smoothly rotate player towards move direction
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	else:
		# stop horizontal movement
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
	move_and_slide()
	# --- Update Animations (After moving) ---
	_update_animations(move_dir)

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
