extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.3 

@onready var camera_pivot = $CameraPivot
@onready var anim_player = $combined/AnimationPlayer

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	anim_player.play("Armature|Idle")


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(_delta):
	#if anim_player.current_animation != "Idle":
		#print(anim_player.current_animation)
		#anim_player.play("Idle")
	if not is_on_floor():
		velocity.y -= gravity * _delta
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		#anim_player.play("Jump")
	
	#if anim_player.current_animation == "Jump" and is_on_floor():
		#anim_player.play("Idle")
	

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction = (transform.basis.z * input_dir.y + transform.basis.x * input_dir.x).normalized()

	if direction:
		velocity.x = direction.x * speed
		#anim_player.play("Walking")
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		anim_player.stop()


	move_and_slide()
