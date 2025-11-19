extends CharacterBody3D

# --- Tunable Settings ---
@export var speed = 2.5         # Walking speed
@export var jump_velocity = 4.0 # Max height force
@export var jump_windup_time = 0.2 # DELAY before leaving ground (matches crouch animation)
@export var jump_rise_time = 0.2 # Time to reach max velocity (The "Gradual" rise)
@export var rotation_speed = 8.0 

# --- Node References ---
@onready var anim_player = $Player/AnimationPlayer 
@onready var raycast = $Player/RayCast3D

# --- Internal Variables ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_ref: Camera3D = null

# Jump State Variables
enum JumpState { GROUNDED, WINDUP, RISING, FALLING }
var current_jump_state = JumpState.GROUNDED
var jump_timer = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if DialogueUI:
		DialogueUI.hide_box()

	camera_ref = get_viewport().get_camera_3d()
	if not camera_ref:
		push_warning("Player.gd: No Camera3D found in scene!")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("interact"):
		if DialogueUI.is_active:
			DialogueUI.hide_box()
			return
			
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider.has_method("interact"):
				collider.interact()

func _physics_process(delta):
	# --- 1. Dialogue Freeze ---
	if DialogueUI.is_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --- 2. Jump Logic State Machine ---
	if Input.is_action_just_pressed("jump") and is_on_floor() and current_jump_state == JumpState.GROUNDED:
		# PHASE 1: Start Animation, but DON'T move up yet
		current_jump_state = JumpState.WINDUP
		jump_timer = 0.0
		_play_anim("idle_jump")
	
	# Handle Jump States
	if current_jump_state == JumpState.WINDUP:
		# Wait for the animation to "crouch"
		jump_timer += delta
		if jump_timer >= jump_windup_time:
			# Windup finished, start moving up!
			current_jump_state = JumpState.RISING
			jump_timer = 0.0 # Reset timer for the rise phase
			
	elif current_jump_state == JumpState.RISING:
		# Gradually increase upward speed
		jump_timer += delta
		var progress = clamp(jump_timer / jump_rise_time, 0.0, 1.0)
		velocity.y = lerp(0.0, jump_velocity, progress)
		
		if progress >= 1.0:
			current_jump_state = JumpState.FALLING
			
	elif current_jump_state == JumpState.FALLING:
		# Apply gravity
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			# We landed!
			current_jump_state = JumpState.GROUNDED
	else:
		# Normal Grounded State (Apply gravity just in case we walk off ledge)
		if not is_on_floor():
			velocity.y -= gravity * delta

	# --- 3. Movement Logic ---
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	input_dir = input_dir.normalized()

	if input_dir.length() > 0 and camera_ref:
		var cam_forward = camera_ref.global_transform.basis.z
		var cam_right = camera_ref.global_transform.basis.x
		cam_forward.y = 0
		cam_right.y = 0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()
		
		var move_dir = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()
		
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		
		var target_rot = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
		
		# Only play walking anim if on ground and NOT winding up
		if current_jump_state == JumpState.GROUNDED:
			_play_anim("walking_1")
			
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		if current_jump_state == JumpState.GROUNDED:
			_play_anim("idle_1")

	move_and_slide()
	
	# Safety reset if we glitch out
	if is_on_floor() and current_jump_state == JumpState.FALLING:
		current_jump_state = JumpState.GROUNDED

func _play_anim(anim_name):
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
