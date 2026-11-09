extends CanvasLayer

# Toggle to show/hide checkpoint restart
@export var show_checkpoint_restart: bool = true

@onready var btn_retry: Button = get_node_or_null("%RetryButton")
@onready var btn_play_again: Button = get_node_or_null("%PlayAgainButton")
@onready var btn_main_menu: Button = get_node_or_null("%MainMenuButton")
@onready var checkpoint_lbl: Label = get_node_or_null("%CheckpointInfo")

func _ready() -> void:
	if btn_retry:
		btn_retry.pressed.connect(_on_retry_pressed)
		btn_retry.visible = show_checkpoint_restart
		if show_checkpoint_restart:
			if GameManager.has_checkpoint:
				btn_retry.disabled = false
				btn_retry.grab_focus()
			else:
				btn_retry.disabled = true
			
	if checkpoint_lbl:
		checkpoint_lbl.visible = show_checkpoint_restart
		if GameManager.has_checkpoint:
			checkpoint_lbl.text = "Last Checkpoint: " + GameManager.checkpoint_name
		else:
			checkpoint_lbl.text = "No Checkpoint Available"

	if btn_play_again:
		btn_play_again.pressed.connect(_on_play_again_pressed)
		if not show_checkpoint_restart or not GameManager.has_checkpoint:
			btn_play_again.grab_focus()
			
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
		
	# Fallback if no nodes are placed in scene
	if not btn_play_again and not btn_main_menu:
		_build_fallback_game_over()

func _play_click_sfx() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()

func _cleanup_self() -> void:
	if get_parent() and (get_parent().name == "DynamicGameOver" or get_parent().name == "GameOver"):
		get_parent().queue_free()
	else:
		queue_free()

func _on_retry_pressed() -> void:
	_play_click_sfx()
	print("Game Over: Retrying from checkpoint...")
	_cleanup_self()
	GameManager.respawn_at_checkpoint()

func _on_play_again_pressed() -> void:
	_play_click_sfx()
	print("Game Over: Starting New Game (Play Again)...")
	_cleanup_self()
	GameManager.start_new_game()

func _on_main_menu_pressed() -> void:
	_play_click_sfx()
	print("Game Over: Returning to Main Menu...")
	_cleanup_self()
	GameManager.go_to_main_menu()

# ==========================================
# DYNAMIC FALLBACK BUILDER
# ==========================================
func _build_fallback_game_over() -> void:
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://dialogue.tres"):
		root_ctrl.theme = load("res://dialogue.tres")
	add_child(root_ctrl)
	
	# Dark red tint overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.12, 0.02, 0.02, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 160)
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "CRITICAL SYSTEM FAILURE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "0 Hearts Remaining - Memory Corrupted"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7, 1.0))
	vbox.add_child(subtitle)
	
	if show_checkpoint_restart:
		checkpoint_lbl = Label.new()
		if GameManager.has_checkpoint:
			checkpoint_lbl.text = "Last Checkpoint: " + GameManager.checkpoint_name
			checkpoint_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1.0))
		else:
			checkpoint_lbl.text = "No Checkpoint Available"
			checkpoint_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		checkpoint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		checkpoint_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(checkpoint_lbl)
		
		btn_retry = Button.new()
		btn_retry.text = "Restart from Checkpoint"
		btn_retry.add_theme_font_size_override("font_size", 16)
		btn_retry.disabled = not GameManager.has_checkpoint
		btn_retry.pressed.connect(_on_retry_pressed)
		vbox.add_child(btn_retry)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	btn_play_again = Button.new()
	btn_play_again.text = "Play Again"
	btn_play_again.add_theme_font_size_override("font_size", 16)
	btn_play_again.pressed.connect(_on_play_again_pressed)
	vbox.add_child(btn_play_again)
	
	btn_main_menu = Button.new()
	btn_main_menu.text = "Return to Main Menu"
	btn_main_menu.add_theme_font_size_override("font_size", 16)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(btn_main_menu)
	
	if show_checkpoint_restart and GameManager.has_checkpoint:
		btn_retry.grab_focus()
	else:
		btn_play_again.grab_focus()
