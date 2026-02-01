extends CanvasLayer

@onready var top_bar = $TopBar
@onready var bottom_bar = $BottomBar
@onready var game_over_ui = $GameOverUI
@onready var retry_button = $GameOverUI/RetryButton
@onready var power_label = $PowerLabel


var is_game_over = false
var last_character = null
var active_tween: Tween
var default_power_label_pos: Vector2 = Vector2.ZERO

func _ready():
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	GameEvents.game_over.connect(_on_game_over_signal)
	GameEvents.victory.connect(_on_victory_signal)

func _on_victory_signal(_time: float):
	is_game_over = true
	visible = true
	if top_bar: top_bar.visible = false
	if bottom_bar: bottom_bar.visible = false

func _on_game_over_signal():
	is_game_over = true
	if game_over_ui:
		game_over_ui.visible = true
	visible = true
	if top_bar: top_bar.visible = false
	if bottom_bar: bottom_bar.visible = false

func _process(_delta):
	if is_game_over: return
	
	var character = GameEvents.current_character
	
	# Find character
	if not is_instance_valid(character):
		character = get_tree().get_first_node_in_group("controlled")
		if character:
			GameEvents.current_character = character
	
	if not is_instance_valid(character):
		_update_ui(1.0)
		return
	
	# Detect character switch and reset
	if character != last_character:
		last_character = character
		_show_power_notification(character)
	
	# Check if character is transitioning or dead logic handled here
	if character.get("is_transitioning"): return
	
	# Doom timer UI
	var current_time = 0.0
	var max_time
	
	if character.get("doom_timer") != null:
		current_time = character.doom_timer
		if character.get("doom_duration") != null:
			max_time = character.doom_duration
	
	if current_time <= 0 and not is_game_over:
		_trigger_game_over(character)
	
	var pct = clamp(current_time / max_time, 0.0, 1.0)
	
	_update_ui(pct)

func _update_ui(pct):
	visible = pct < 1.0
	
	var is_critical = pct <= 0.3 and pct > 0.0
	var pulse = 0.0
	var bar_color = Color.WHITE
	var bar_height = 20.0
	
	if is_critical:
		pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) / 2.0
		bar_color = Color.WHITE.lerp(Color.RED, pulse)
		bar_height = 20.0 + (pulse * 20.0)
	
	if top_bar:
		top_bar.anchor_right = pct
		top_bar.offset_bottom = bar_height
		top_bar.color = bar_color
		
	if bottom_bar:
		bottom_bar.anchor_right = pct
		bottom_bar.offset_top = - bar_height
		bottom_bar.color = bar_color

func _trigger_game_over(character):
	is_game_over = true
	if character.has_method("die"):
		character.die()
	
	if game_over_ui:
		game_over_ui.visible = true
	
	visible = true
	if top_bar: top_bar.visible = false
	if bottom_bar: bottom_bar.visible = false

func _on_retry_pressed():
	get_tree().change_scene_to_file("res://src/scenes/ui/difficulty_menu.tscn")

func _show_power_notification(character):
	if not power_label: return
	
	var text = ""
	var color = Color.WHITE
	
	# Determine power and color
	if character.get("char_color"):
		color = character.char_color
	
	if character.get("can_ever_dash") == true:
		text = "THE POWER OF DASH"
	elif character.get("jump_velocity") and character.jump_velocity > 9.0:
		text = "THE POWER OF JUMP"
	elif character.get("can_sprint") == true:
		text = "THE POWER OF SPRINT"
	else:
		return # No special power or unknown
		
	power_label.text = text
	power_label.add_theme_color_override("font_color", color)
	power_label.visible = true
	
	# Shake animation
	if active_tween:
		active_tween.kill()
		power_label.position = default_power_label_pos # Reset to valid position if interrupted
		power_label.modulate.a = 1.0
		
	# Store default pos if not stored yet (or reset to it)
	if default_power_label_pos == Vector2.ZERO:
		default_power_label_pos = power_label.position

	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_ELASTIC)
	active_tween.set_ease(Tween.EASE_OUT)
	
	# Shake effect
	var shake_strength = 10.0
	for i in range(5):
		var shake_offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		active_tween.tween_property(power_label, "position", default_power_label_pos + shake_offset, 0.05)
		
	active_tween.tween_property(power_label, "position", default_power_label_pos, 0.05)
	
	# Wait then fade out
	active_tween.tween_interval(2.0)
	active_tween.tween_property(power_label, "modulate:a", 0.0, 1.0)
	active_tween.tween_callback(func(): power_label.visible = false; power_label.modulate.a = 1.0)
