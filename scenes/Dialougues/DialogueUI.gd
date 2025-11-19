extends Control
@onready var label: Label = $Panel/TextLabel

var is_active = false 

func _ready():
	hide_box() 

func show_message(text: String):
	is_active = true
	label.text = text
	visible = true

func hide_box():
	is_active = false
	visible = false
	label.text = "" 
