extends Control

func _ready():
	set_process_input(true);

func _input(ie):
	if ie.type == InputEvent.KEY:
		if ie.pressed && ie.scancode == KEY_ESCAPE:
			get_tree().call_deferred("quit");