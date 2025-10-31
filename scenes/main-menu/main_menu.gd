extends Control

func _ready():
	$Control/Button.pressed.connect(_on_play_pressed)

func _on_play_pressed():
	var loading_scene = preload("res://scenes/loader/loading-screen.tscn").instantiate()
	get_tree().root.add_child(loading_scene)
	loading_scene.start_loading("res://scenes/open-world/open-world.tscn")
