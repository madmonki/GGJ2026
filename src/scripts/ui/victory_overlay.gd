extends Control

@onready var time_label = $CenterContainer/VBoxContainer/TimeLabel
@onready var menu_button = $CenterContainer/VBoxContainer/MenuButton

func _ready():
	GameEvents.victory.connect(_on_victory)
	menu_button.pressed.connect(_on_menu_pressed)
	visible = false

func _on_victory(total_time: float):
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Format time: 00:00.00
	var minutes = int(total_time / 60)
	var seconds = int(total_time) % 60
	var msec = int((total_time - int(total_time)) * 100)
	time_label.text = "TIME: %02d:%02d.%02d" % [minutes, seconds, msec]
	
	menu_button.grab_focus()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://src/scenes/ui/difficulty_menu.tscn")
