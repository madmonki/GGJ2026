extends CanvasLayer

@onready var top_bar = $TopBar
@onready var bottom_bar = $BottomBar
@onready var game_over_ui = $GameOverUI
@onready var retry_button = $GameOverUI/RetryButton

const MAX_MASKLESS_TIME = 3.0
var maskless_timer = MAX_MASKLESS_TIME
var is_game_over = false

func _ready():
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)

func _process(delta):
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
	
	# Check if character is transitioning or dead logic handled here
	if character.get("is_transitioning"): return
	
	var has_mask = false
	if character.has_method("has_attached_mask"):
		has_mask = character.has_attached_mask()
	
	if has_mask:
		maskless_timer = MAX_MASKLESS_TIME
	else:
		maskless_timer -= delta
		if maskless_timer <= 0:
			_trigger_game_over(character)
	
	_update_ui(clamp(maskless_timer / MAX_MASKLESS_TIME, 0.0, 1.0))

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
