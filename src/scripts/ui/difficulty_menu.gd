extends Control

@onready var regular_btn = $CenterContainer/VBoxContainer/Regular
@onready var fast_btn = $CenterContainer/VBoxContainer/Fast
@onready var faster_btn = $CenterContainer/VBoxContainer/Faster
@onready var extreme_btn = $CenterContainer/VBoxContainer/Extreme

func _ready():
	# Vibrant visuals initialization
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	regular_btn.pressed.connect(_on_difficulty_selected.bind(20.0))
	fast_btn.pressed.connect(_on_difficulty_selected.bind(15.0))
	faster_btn.pressed.connect(_on_difficulty_selected.bind(10.0))
	extreme_btn.pressed.connect(_on_difficulty_selected.bind(7.0))
	
	# Focus the regular button by default for controller/keyboard support
	regular_btn.grab_focus()

func _on_difficulty_selected(duration: float):
	GameEvents.selected_doom_duration = duration
	get_tree().change_scene_to_file("res://levels/main.tscn")
