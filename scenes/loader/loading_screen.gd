extends Control

@onready var progress_bar = $Control/ProgressBar
@onready var label = $Control/Label

var target_scene_path: String
var _load_state : String = ""

func start_loading(scene_path: String):
	target_scene_path = scene_path
	progress_bar.value = 0
	label.text = "Loading..."
	ResourceLoader.load_threaded_request(scene_path)
	_load_state = "loading"
	set_process(true)

func _process(_delta):
	if _load_state == "loading":
		var progress = []
		var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
		progress_bar.value = progress[0] * 100.0

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource = ResourceLoader.load_threaded_get(target_scene_path)
			_on_scene_loaded(resource)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			label.text = "Failed to load scene"
			set_process(false)

func _on_scene_loaded(resource: Resource):
	label.text = "Starting..."
	await get_tree().create_timer(0.2).timeout

	var scene = resource.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene.free()
	get_tree().current_scene = scene

	queue_free()
