extends Area3D

@export var dialogue_line: String = "I have nothing to say."

func interact():
	DialogueUI.show_message(dialogue_line)
