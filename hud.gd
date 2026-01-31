extends CanvasLayer

@onready var top_bar = $TopBar
@onready var bottom_bar = $BottomBar
@onready var game_over_ui = $GameOverUI
@onready var retry_button = $GameOverUI/RetryButton


var is_game_over = false
var last_character = null

func _ready():
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	GameEvents.game_over.connect(_on_game_over_signal)

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
	
	# If no character tracked yet, try to find one
	if not is_instance_valid(character):
		character = get_tree().get_first_node_in_group("controlled")
		if character:
			GameEvents.current_character = character
	
	if not is_instance_valid(character):
		_update_ui(1.0) # Show full bars if no character
		return
	
	# Detect character switch and reset
	if character != last_character:
		last_character = character
	
	# Check if character is transitioning or dead logic handled here
	if character.get("is_transitioning"): return
	
	# Unified logic: Visualize current character's doom timer
	# The timer logic is now handled in player.gd
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
	
	if top_bar:
		top_bar.anchor_right = pct
		top_bar.offset_right = 0
		top_bar.offset_left = 0
		
	if bottom_bar:
		bottom_bar.anchor_right = pct
		bottom_bar.offset_right = 0
		bottom_bar.offset_left = 0

func _trigger_game_over(character):
	is_game_over = true
	if character.has_method("die"):
		character.die()
	
	if game_over_ui:
		game_over_ui.visible = true
	
	visible = true # Ensure HUD layer is visible for Game Over
	# Hide bars during game over? Or keep them empty.
	# Let's hide bars to focus on Game Over text
	if top_bar: top_bar.visible = false
	if bottom_bar: bottom_bar.visible = false

func _on_retry_pressed():
	get_tree().reload_current_scene()
