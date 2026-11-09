extends CanvasLayer

signal battle_won()

@onready var main_layout: Control = $MainLayout
@onready var monster_sprite: TextureRect = %MonsterSprite
@onready var bottom_half_terminal: Control = %BottomHalf_Terminal
@onready var code_question: RichTextLabel = %CodeQuestion
@onready var btn_a: Button = %OptionA
@onready var btn_b: Button = %OptionB
@onready var btn_c: Button = %OptionC
@onready var btn_d: Button = %OptionD
@onready var btn_skip: Button = %SkipButton 
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var level_label = %LevelLbl
@onready var language_label = %LanguageLbl
var current_correct_answer: String = ""
const ANSWER_FEEDBACK_DIALOGUE = preload("res://dialogues/answer_feedback.dialogue") 

# INJECTED VARIABLES FROM EVENT TRIGGER
var reward_event: String = ""
var is_sudden_death: bool = false

# We changed this to a Dictionary to hold our JSON data!
var questions_db: Dictionary = {}
var current_level: int = 1
var answer_scroll_container: ScrollContainer = null
var answer_grid: GridContainer = null

# FULLSCREEN TERMINAL SYSTEM
var is_terminal_fullscreen: bool = false
var btn_fullscreen: Button = null
var fullscreen_backdrop: ColorRect = null
var question_container: Control = null

# QUESTION COUNTDOWN TIMER SYSTEM
var question_time_left: float = 30.0
var question_total_time: float = 30.0
var timer_active: bool = false
var timer_label: Label = null
var timer_bar: ProgressBar = null
var timer_container: Control = null

var original_question_pos: Vector2 = Vector2(14, -92)
var original_question_size: Vector2 = Vector2(234, 78)
var original_scroll_pos: Vector2 = Vector2(162, 24)
var original_scroll_size: Vector2 = Vector2(310, 102)
var original_btn_fullscreen_pos: Vector2 = Vector2(448, 6)
var original_btn_fullscreen_size: Vector2 = Vector2(24, 24)

func _ready() -> void:
	add_to_group("battle_scene")
	GameManager.register_battle_instance(self)
	_setup_scrollable_answers()
	_setup_fullscreen_system()
	_setup_timer_ui()
	_update_skip_button()
	GameManager.dev_mode_toggled.connect(_on_dev_mode_toggled)

	if btn_skip:
		btn_skip.pressed.connect(_on_skip_clicked)
		btn_skip.mouse_entered.connect(btn_skip.grab_focus)

	main_layout.hide()
	bottom_half_terminal.hide()
	if btn_fullscreen:
		btn_fullscreen.hide()
	
	# Play encounter SFX
	var audio = get_node_or_null("/root/AudioManager")
	#if audio and audio.has_method("play_battle_encounter"):
		#audio.play_battle_encounter()
	
	if audio:
		if is_sudden_death and audio.has_method("play_bgm_boss"):
			audio.play_bgm_boss()
		elif audio.has_method("play_bgm_battle"):
			audio.play_bgm_battle()
	
	# 1. LOAD THE JSON AND SETUP THE LEVEL
	_load_database()
	_setup_level()
	
	anim_player.play("flash")
	await anim_player.animation_finished
	
	anim_player.play("fade_to_black")
	await anim_player.animation_finished
	
	await get_tree().create_timer(0.5).timeout
	
	# Start Battle or Boss BGM
	
	
	# 2. LOAD QUESTION BASED ON LEVEL
	_load_random_question()
	level_label.text = "Lv.%s" % str(GameManager.total_bugs_defeated + 1)
	main_layout.show()
	
	anim_player.play("fade_to_battle")
	await anim_player.animation_finished
	
	var battle_dialogue = preload("res://dialogues/battle_scene_intro.dialogue")
	DialogueManager.show_example_dialogue_balloon(battle_dialogue, "encounter_start")
	await DialogueManager.dialogue_ended
	
	bottom_half_terminal.show()
	_start_question_timer()
	if btn_fullscreen:
		btn_fullscreen.show()
	
	$Flash.hide()
	$BlackBarTop.hide()
	$BlackBarBottom.hide()
	
	btn_a.grab_focus()

func _exit_tree() -> void:
	GameManager.unregister_battle_instance(self)


# NEW: LEVEL & JSON LOGIC

func _load_database() -> void:
	var file = FileAccess.open("res://data/questions.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			questions_db = json.data
			print("Questions DB Loaded Successfully!")
		else:
			print("JSON Parse Error: ", json.get_error_message())
	else:
		print("Failed to open JSON file!")

func _setup_level() -> void:
	# Calculate level based on kills. 
	# 0 kills = Level 1. ... 14 kills = Level 15 (Boss).
	current_level = clamp(GameManager.total_bugs_defeated + 1, 1, 15)
	
	# If this is sudden death or the 15th encounter, this is the Boss battle!
	var is_boss_battle = is_sudden_death or current_level == 15
	if is_boss_battle:
		current_level = 15
		
	print("Starting Battle! Level: ", current_level, " | Boss: ", is_boss_battle)
	
	# Swap the monster sprite dynamically:
	# The Boss (Level 15 / sudden death) ALWAYS unconditionally loads monster_10.png (dragon glitch)!
	var sprite_path = ""
	if is_boss_battle:
		sprite_path = "res://assets/monsters/monster_10.png"
	elif current_level <= 9:
		sprite_path = "res://assets/monsters/monster_%d.png" % current_level
	else:
		# For levels 10 to 14, pick from existing assets monster11.png through monster15.png
		sprite_path = "res://assets/monsters/monster%d.png" % (current_level + 1)
		if not ResourceLoader.exists(sprite_path):
			sprite_path = "res://assets/monsters/monster_%d.png" % ((current_level % 9) + 1)
			
	if ResourceLoader.exists(sprite_path):
		monster_sprite.texture = load(sprite_path)
	else:
		print("Sprite not found, using default!")

func _load_random_question() -> void:
	var level_key = str(current_level)
	
	# Fallback if the level isn't in the JSON yet
	if not questions_db.has(level_key) or questions_db[level_key].size() == 0:
		print("ERROR: No questions found for Level ", level_key)
		return
		
	# Pick a random question from THIS specific level's array
	var q = questions_db[level_key].pick_random()
	
	current_correct_answer = q["correct"]
	code_question.text = q["code"]
	
	language_label.text = "Language: " + q["language"]
	
	var all_options: Array = []
	all_options.append(current_correct_answer)
	all_options.append_array(q["wrong"])
	all_options.shuffle()
	
	var buttons = [btn_a, btn_b, btn_c, btn_d]
	for i in range(buttons.size()):
		buttons[i].text = all_options[i]
		if not buttons[i].mouse_entered.is_connected(buttons[i].grab_focus):
			buttons[i].mouse_entered.connect(buttons[i].grab_focus)
		if not buttons[i].focus_entered.is_connected(_on_choice_focused):
			buttons[i].focus_entered.connect(_on_choice_focused)
		if buttons[i].pressed.is_connected(_on_answer_clicked):
			buttons[i].pressed.disconnect(_on_answer_clicked)
		buttons[i].pressed.connect(_on_answer_clicked.bind(all_options[i]))
		
	if answer_scroll_container:
		answer_scroll_container.scroll_vertical = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and not event.ctrl_pressed and not event.alt_pressed:
			if bottom_half_terminal and bottom_half_terminal.visible:
				toggle_fullscreen_terminal()

func _setup_scrollable_answers() -> void:
	if not btn_a:
		return
		
	answer_grid = btn_a.get_parent() as GridContainer
	if not answer_grid:
		return
		
	var parent_node = answer_grid.get_parent()
	if parent_node is ScrollContainer:
		answer_scroll_container = parent_node
	else:
		# Automatically wrap AnswerButtons in a fixed-size ScrollContainer
		answer_scroll_container = ScrollContainer.new()
		answer_scroll_container.name = "AnswerScrollContainer"
		
		# Transfer exact layout position and dimensions (310 x 102)
		var original_pos = answer_grid.position
		var original_size = answer_grid.size
		if original_size == Vector2.ZERO:
			original_size = Vector2(310, 102)
			
		answer_scroll_container.position = original_pos
		answer_scroll_container.size = original_size
		answer_scroll_container.custom_minimum_size = original_size
		answer_scroll_container.z_index = answer_grid.z_index
		
		if answer_grid.theme:
			answer_scroll_container.theme = answer_grid.theme
		elif ResourceLoader.exists("res://dialogue.tres"):
			answer_scroll_container.theme = load("res://dialogue.tres")
			
		var idx = answer_grid.get_index()
		parent_node.remove_child(answer_grid)
		parent_node.add_child(answer_scroll_container)
		parent_node.move_child(answer_scroll_container, idx)
		answer_scroll_container.add_child(answer_grid)
		
		answer_grid.position = Vector2.ZERO
		
	# Configure ScrollContainer: fixed size, disable horizontal scroll, auto vertical scroll
	answer_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	answer_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	answer_scroll_container.follow_focus = true
	
	# Configure grid inside to expand horizontally
	answer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answer_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	answer_grid.add_theme_constant_override("h_separation", 6)
	answer_grid.add_theme_constant_override("v_separation", 6)
	
	# Refined Choice Button StyleBoxes (Clean emerald borders with amber gold focus rings)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(1.0, 1.0, 1.0, 0.96)
	btn_normal.border_color = Color(0.28, 0.50, 0.35, 1.0)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	btn_normal.content_margin_left = 8
	btn_normal.content_margin_right = 8
	btn_normal.content_margin_top = 4
	btn_normal.content_margin_bottom = 4

	var btn_focus = StyleBoxFlat.new()
	btn_focus.bg_color = Color(0.93, 0.99, 0.95, 1.0)
	btn_focus.border_color = Color(0.96, 0.74, 0.20, 1.0) # Warm amber gold focus ring
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(6)
	btn_focus.content_margin_left = 8
	btn_focus.content_margin_right = 8
	btn_focus.content_margin_top = 4
	btn_focus.content_margin_bottom = 4

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.78, 0.92, 0.82, 1.0)
	btn_pressed.border_color = Color(0.18, 0.42, 0.25, 1.0)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(6)
	btn_pressed.content_margin_left = 8
	btn_pressed.content_margin_right = 8
	btn_pressed.content_margin_top = 4
	btn_pressed.content_margin_bottom = 4

	for btn in [btn_a, btn_b, btn_c, btn_d]:
		if btn:
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.add_theme_font_size_override("font_size", 16)
			btn.add_theme_color_override("font_color", Color(0.08, 0.12, 0.10, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.04, 0.08, 0.05, 1.0))
			btn.add_theme_color_override("font_focus_color", Color(0.04, 0.08, 0.05, 1.0))
			btn.add_theme_color_override("font_pressed_color", Color(0.04, 0.08, 0.05, 1.0))
			btn.add_theme_stylebox_override("normal", btn_normal)
			btn.add_theme_stylebox_override("hover", btn_focus)
			btn.add_theme_stylebox_override("focus", btn_focus)
			btn.add_theme_stylebox_override("pressed", btn_pressed)

var icon_fullscreen: Texture2D = null
var icon_restore: Texture2D = null

func _create_fullscreen_icon() -> ImageTexture:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c = Color(0.75, 0.95, 0.82, 1.0) # Bright cyber mint
	# 4 outward corners (Expand / Fullscreen)
	# Top-Left corner
	for x in range(1, 6):
		img.set_pixel(x, 1, c)
		img.set_pixel(x, 2, c)
	for y in range(1, 6):
		img.set_pixel(1, y, c)
		img.set_pixel(2, y, c)
	# Top-Right corner
	for x in range(10, 15):
		img.set_pixel(x, 1, c)
		img.set_pixel(x, 2, c)
	for y in range(1, 6):
		img.set_pixel(13, y, c)
		img.set_pixel(14, y, c)
	# Bottom-Left corner
	for x in range(1, 6):
		img.set_pixel(x, 13, c)
		img.set_pixel(x, 14, c)
	for y in range(10, 15):
		img.set_pixel(1, y, c)
		img.set_pixel(2, y, c)
	# Bottom-Right corner
	for x in range(10, 15):
		img.set_pixel(x, 13, c)
		img.set_pixel(x, 14, c)
	for y in range(10, 15):
		img.set_pixel(13, y, c)
		img.set_pixel(14, y, c)
	return ImageTexture.create_from_image(img)

func _create_normal_mode_icon() -> ImageTexture:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c = Color(0.75, 0.95, 0.82, 1.0) # Bright cyber mint
	# 4 inward corners (Contract / Normal View)
	# Top-Left inward corner
	for x in range(1, 6):
		img.set_pixel(x, 4, c)
		img.set_pixel(x, 5, c)
	for y in range(1, 6):
		img.set_pixel(4, y, c)
		img.set_pixel(5, y, c)
	# Top-Right inward corner
	for x in range(10, 15):
		img.set_pixel(x, 4, c)
		img.set_pixel(x, 5, c)
	for y in range(1, 6):
		img.set_pixel(10, y, c)
		img.set_pixel(11, y, c)
	# Bottom-Left inward corner
	for x in range(1, 6):
		img.set_pixel(x, 10, c)
		img.set_pixel(x, 11, c)
	for y in range(10, 15):
		img.set_pixel(4, y, c)
		img.set_pixel(5, y, c)
	# Bottom-Right inward corner
	for x in range(10, 15):
		img.set_pixel(x, 10, c)
		img.set_pixel(x, 11, c)
	for y in range(10, 15):
		img.set_pixel(10, y, c)
		img.set_pixel(11, y, c)
	return ImageTexture.create_from_image(img)

func _setup_fullscreen_system() -> void:
	if not bottom_half_terminal:
		return
		
	icon_fullscreen = _create_fullscreen_icon()
	icon_restore = _create_normal_mode_icon()
		
	# Find QuestionContainer
	if code_question:
		question_container = code_question.get_parent() as Control
	if not question_container and bottom_half_terminal.has_node("QuestionContainer"):
		question_container = bottom_half_terminal.get_node("QuestionContainer") as Control
		
	if question_container:
		original_question_pos = Vector2(14, -92)
		original_question_size = Vector2(234, 78)
		_apply_control_rect(question_container, original_question_pos, original_question_size)
		
		# Refined 2px crisp border for Question Container
		var q_style = StyleBoxFlat.new()
		q_style.bg_color = Color(0.99, 1.0, 0.99, 0.98)
		q_style.border_color = Color(0.28, 0.52, 0.35, 1.0)
		q_style.set_border_width_all(2)
		q_style.set_corner_radius_all(6)
		q_style.content_margin_left = 10
		q_style.content_margin_right = 10
		q_style.content_margin_top = 8
		q_style.content_margin_bottom = 8
		question_container.add_theme_stylebox_override("panel", q_style)
			
	if answer_scroll_container:
		original_scroll_pos = Vector2(162, 24)
		original_scroll_size = Vector2(310, 102)
		_apply_control_rect(answer_scroll_container, original_scroll_pos, original_scroll_size)
			
	# Find or dynamically create FullScreenButton (placed at upper-most right corner)
	btn_fullscreen = get_node_or_null("%FullScreenButton")
	if not btn_fullscreen:
		btn_fullscreen = get_node_or_null("FullScreenButton")
		
	if not btn_fullscreen:
		btn_fullscreen = Button.new()
		btn_fullscreen.name = "FullScreenButton"
		btn_fullscreen.text = ""
		btn_fullscreen.icon = icon_fullscreen
		btn_fullscreen.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_fullscreen.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn_fullscreen.z_index = 15
		add_child(btn_fullscreen)
		
	# Cyber glass button styling for FullScreenButton
	var btn_glass = StyleBoxFlat.new()
	btn_glass.bg_color = Color(0.06, 0.10, 0.08, 0.85)
	btn_glass.border_color = Color(0.30, 0.55, 0.38, 0.9)
	btn_glass.set_border_width_all(1)
	btn_glass.set_corner_radius_all(4)

	var btn_glass_hover = StyleBoxFlat.new()
	btn_glass_hover.bg_color = Color(0.12, 0.18, 0.14, 0.95)
	btn_glass_hover.border_color = Color(0.96, 0.74, 0.20, 1.0) # Warm amber focus
	btn_glass_hover.set_border_width_all(1)
	btn_glass_hover.set_corner_radius_all(4)
	
	btn_fullscreen.add_theme_stylebox_override("normal", btn_glass)
	btn_fullscreen.add_theme_stylebox_override("hover", btn_glass_hover)
	btn_fullscreen.add_theme_stylebox_override("focus", btn_glass_hover)
		
	original_btn_fullscreen_pos = Vector2(448, 6)
	original_btn_fullscreen_size = Vector2(24, 24)
	_apply_control_rect(btn_fullscreen, original_btn_fullscreen_pos, original_btn_fullscreen_size)
	btn_fullscreen.tooltip_text = "Fullscreen (F)"
	
	if not btn_fullscreen.pressed.is_connected(toggle_fullscreen_terminal):
		btn_fullscreen.pressed.connect(toggle_fullscreen_terminal)
	if not btn_fullscreen.mouse_entered.is_connected(btn_fullscreen.grab_focus):
		btn_fullscreen.mouse_entered.connect(btn_fullscreen.grab_focus)
		
	# Create fullscreen dark backdrop overlay (behind question and choices)
	fullscreen_backdrop = bottom_half_terminal.get_node_or_null("FullscreenBackdrop") as ColorRect
	if not fullscreen_backdrop:
		fullscreen_backdrop = ColorRect.new()
		fullscreen_backdrop.name = "FullscreenBackdrop"
		fullscreen_backdrop.color = Color(0.06, 0.09, 0.08, 0.96)
		fullscreen_backdrop.z_index = 1
		bottom_half_terminal.add_child(fullscreen_backdrop)
		bottom_half_terminal.move_child(fullscreen_backdrop, 0)
	fullscreen_backdrop.hide()

func toggle_fullscreen_terminal() -> void:
	set_terminal_fullscreen(not is_terminal_fullscreen)

func set_terminal_fullscreen(enable: bool) -> void:
	is_terminal_fullscreen = enable
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()
		
	var origin_y: float = bottom_half_terminal.position.y
	if is_zero_approx(origin_y):
		origin_y = 135.0
		
	if is_terminal_fullscreen:
		# 1. Fullscreen dark backdrop overlay
		if fullscreen_backdrop:
			_apply_control_rect(fullscreen_backdrop, Vector2(0, -origin_y), Vector2(480, 270))
			fullscreen_backdrop.show()
			
		# 2. Left ~3/4: Question Container
		if question_container:
			_apply_control_rect(question_container, Vector2(10, 32 - origin_y), Vector2(326, 230))
			
		# 3. Right ~1/4: Choices ScrollContainer in vertical layout (128 x 230)
		if answer_scroll_container:
			_apply_control_rect(answer_scroll_container, Vector2(342, 32 - origin_y), Vector2(128, 230))
			
		if answer_grid:
			answer_grid.columns = 1
			for btn in [btn_a, btn_b, btn_c, btn_d]:
				if btn:
					btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn.custom_minimum_size = Vector2(0, 36)
					
		# 4. Upper-most right button: stays at Vector2(448, 6), updates to restore icon, no text
		if btn_fullscreen:
			btn_fullscreen.text = ""
			btn_fullscreen.icon = icon_restore
			btn_fullscreen.tooltip_text = "Restore Normal View (F)"
			_apply_control_rect(btn_fullscreen, Vector2(448, 6), Vector2(24, 24))
					
		if btn_a and btn_fullscreen:
			btn_a.focus_neighbor_top = btn_fullscreen.get_path()
			btn_fullscreen.focus_neighbor_bottom = btn_a.get_path()
	else:
		# 1. Hide backdrop overlay
		if fullscreen_backdrop:
			fullscreen_backdrop.hide()
			
		# 2. Restore Question Container
		if question_container:
			_apply_control_rect(question_container, original_question_pos, original_question_size)
			
		# 3. Restore Choices ScrollContainer and 2-column grid
		if answer_scroll_container:
			_apply_control_rect(answer_scroll_container, original_scroll_pos, original_scroll_size)
			
		if answer_grid:
			answer_grid.columns = 2
			for btn in [btn_a, btn_b, btn_c, btn_d]:
				if btn:
					btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn.custom_minimum_size = Vector2.ZERO
					
		# 4. Upper-most right button: stays at Vector2(448, 6), updates to fullscreen icon, no text
		if btn_fullscreen:
			btn_fullscreen.text = ""
			btn_fullscreen.icon = icon_fullscreen
			btn_fullscreen.tooltip_text = "Fullscreen (F)"
			_apply_control_rect(btn_fullscreen, Vector2(448, 6), Vector2(24, 24))
					
		if btn_a and btn_fullscreen:
			btn_a.focus_neighbor_top = NodePath("")
			btn_fullscreen.focus_neighbor_bottom = NodePath("")

	_update_timer_layout()
	if answer_scroll_container:
		answer_scroll_container.scroll_vertical = 0

func _apply_control_rect(ctrl: Control, pos: Vector2, sz: Vector2) -> void:
	if not ctrl:
		return
	ctrl.position = pos
	ctrl.size = sz
	ctrl.custom_minimum_size = sz
	ctrl.offset_left = pos.x
	ctrl.offset_top = pos.y
	ctrl.offset_right = pos.x + sz.x
	ctrl.offset_bottom = pos.y + sz.y

func _on_choice_focused() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_battle_choice_hover"):
		audio.play_battle_choice_hover()


# QUESTION COUNTDOWN TIMER LOGIC

func _setup_timer_ui() -> void:
	if not bottom_half_terminal:
		return
		
	timer_container = PanelContainer.new()
	timer_container.name = "TimerContainer"
	timer_container.z_index = 9
	
	var timer_bg = StyleBoxFlat.new()
	timer_bg.bg_color = Color(0.04, 0.08, 0.06, 0.90) # Dark cyber translucent glass
	timer_bg.border_color = Color(0.24, 0.46, 0.32, 0.9)
	timer_bg.set_border_width_all(1)
	timer_bg.set_corner_radius_all(4)
	timer_bg.content_margin_left = 8
	timer_bg.content_margin_right = 8
	timer_bg.content_margin_top = 2
	timer_bg.content_margin_bottom = 2
	timer_container.add_theme_stylebox_override("panel", timer_bg)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	timer_container.add_child(hbox)
	
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "TIME: 30s"
	timer_label.custom_minimum_size = Vector2(75, 16)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1.0))
	if ResourceLoader.exists("res://dialogue.tres"):
		timer_label.theme = load("res://dialogue.tres")
	hbox.add_child(timer_label)

	timer_bar = ProgressBar.new()
	timer_bar.name = "TimerBar"
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_bar.custom_minimum_size = Vector2(0, 8)
	timer_bar.show_percentage = false
	timer_bar.max_value = 100.0
	timer_bar.value = 100.0
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.14, 0.10, 1.0)
	bg_style.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.25, 0.90, 0.45, 1.0)
	fill_style.set_corner_radius_all(3)
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	hbox.add_child(timer_bar)
	
	bottom_half_terminal.add_child(timer_container)
	_update_timer_layout()
	timer_container.hide()

func _update_timer_layout() -> void:
	if not timer_container or not bottom_half_terminal:
		return
	var origin_y: float = bottom_half_terminal.position.y
	if is_zero_approx(origin_y):
		origin_y = 135.0
		
	if is_terminal_fullscreen:
		_apply_control_rect(timer_container, Vector2(10, 8 - origin_y), Vector2(326, 20))
	else:
		_apply_control_rect(timer_container, Vector2(162, 2), Vector2(310, 20))

func _start_question_timer() -> void:
	if not GameManager.timer_enabled:
		if timer_container:
			timer_container.hide()
		timer_active = false
		return
		
	question_total_time = GameManager.base_question_time + (current_level - 1) * GameManager.time_per_level
	question_time_left = question_total_time
	timer_active = true
	_update_timer_display()
	if timer_container:
		timer_container.show()

func _process(delta: float) -> void:
	if timer_active and GameManager.timer_enabled:
		question_time_left -= delta
		if question_time_left <= 0.0:
			question_time_left = 0.0
			timer_active = false
			_update_timer_display()
			_on_timer_timeout()
		else:
			_update_timer_display()

func _update_timer_display() -> void:
	if not timer_label or not timer_bar:
		return
	var secs = int(ceil(question_time_left))
	timer_label.text = "TIME: %ds" % secs
	var pct = (question_time_left / max(question_total_time, 0.001)) * 100.0
	timer_bar.value = pct
	
	var fill_style = timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if pct <= 20.0 or question_time_left <= 5.0:
		timer_label.add_theme_color_override("font_color", Color(0.95, 0.30, 0.30, 1.0))
		if fill_style:
			fill_style.bg_color = Color(0.95, 0.30, 0.30, 1.0)
	elif pct <= 40.0:
		timer_label.add_theme_color_override("font_color", Color(0.96, 0.74, 0.20, 1.0))
		if fill_style:
			fill_style.bg_color = Color(0.96, 0.74, 0.20, 1.0)
	else:
		timer_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1.0))
		if fill_style:
			fill_style.bg_color = Color(0.25, 0.90, 0.45, 1.0)

func _on_timer_timeout() -> void:
	print("TIME EXPIRED! Treated as wrong answer!")
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_player_attacked"):
		audio.play_player_attacked()
	_on_answer_clicked("") # Empty string indicates timeout/wrong answer


# COMBAT EVALUATION LOGIC

func _on_skip_clicked() -> void:
	_on_answer_clicked(current_correct_answer)

func _on_answer_clicked(player_choice: String) -> void:
	timer_active = false
	if timer_container:
		timer_container.hide()
	bottom_half_terminal.hide()
	if btn_fullscreen:
		btn_fullscreen.hide()
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_battle_choice_select"):
		audio.play_battle_choice_select()
	
	if player_choice == current_correct_answer:
		print("COMPILE SUCCESS! Bug squashed!")
		QuestManager.report_enemy_defeated("alpha_glitch")
		
		# Play compile success and glitch hurt audio
		if audio:
			
			if audio.has_method("play_glitch_attacked"):
				audio.play_glitch_attacked()
		
		# THIS IS WHERE LEVEL UPS HAPPEN!
		GameManager.total_bugs_defeated += 1
		
		anim_player.play("hurt_monster")
		await anim_player.animation_finished
		
		DialogueManager.show_example_dialogue_balloon(ANSWER_FEEDBACK_DIALOGUE, "correct")
		await DialogueManager.dialogue_ended
		
		if audio:
			if audio.has_method("play_question_correct"):
				audio.play_question_correct()
		
		# Pause briefly so the player can hear the victory chime before returning to world
		await get_tree().create_timer(2.0).timeout
		
		if reward_event != "":
			GameManager.complete_event(reward_event)
			
		_end_battle()
		
	else:
		print("SYNTAX ERROR! You took damage!")
		
		# Play syntax error and player hurt audio
		if audio:
			
			if audio.has_method("play_player_attacked"):
				audio.play_player_attacked()
		
		anim_player.play("hurt_player")
		await anim_player.animation_finished
		
		DialogueManager.show_example_dialogue_balloon(ANSWER_FEEDBACK_DIALOGUE, "wrong")
		await DialogueManager.dialogue_ended
		
		if audio:
			if audio.has_method("play_question_wrong"):
				audio.play_question_wrong()
		
		if is_sudden_death:
			GameManager.take_damage(GameManager.player_hp) 
		else:
			GameManager.take_damage(1)

		if GameManager.current_state == GameManager.GameState.GAME_OVER:
			_handle_game_over()
		else:
			await get_tree().create_timer(2.0).timeout
			_end_battle(false)

func _end_battle(is_win: bool = true) -> void:
	timer_active = false
	if timer_container:
		timer_container.hide()
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_world"):
		audio.play_bgm_world()
		
	GameManager.change_state(GameManager.GameState.EXPLORATION)
	if is_win:
		battle_won.emit()
	queue_free()

func _handle_game_over() -> void:
	timer_active = false
	if timer_container:
		timer_container.hide()
	# Hide combat controls while Game Over overlay is presented
	bottom_half_terminal.hide()
	if btn_skip:
		btn_skip.hide()
	if btn_fullscreen:
		btn_fullscreen.hide()
	# GameManager will trigger_game_over() and instantiate game_over.tscn if it exists

func _on_dev_mode_toggled(_is_enabled: bool) -> void:
	_update_skip_button()

func _update_skip_button() -> void:
	if btn_skip:
		btn_skip.visible = GameManager.dev_mode
		if btn_skip.visible:
			btn_skip.text = "Skip >"
			btn_skip.add_theme_font_size_override("font_size", 16)
			btn_skip.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88, 1.0))
			btn_skip.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			btn_skip.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
			
			var btn_glass = StyleBoxFlat.new()
			btn_glass.bg_color = Color(0.06, 0.10, 0.08, 0.85)
			btn_glass.border_color = Color(0.30, 0.55, 0.38, 0.9)
			btn_glass.set_border_width_all(1)
			btn_glass.set_corner_radius_all(4)
			btn_glass.content_margin_left = 6
			btn_glass.content_margin_right = 6
			btn_glass.content_margin_top = 2
			btn_glass.content_margin_bottom = 2
			
			var btn_glass_hover = StyleBoxFlat.new()
			btn_glass_hover.bg_color = Color(0.12, 0.18, 0.14, 0.95)
			btn_glass_hover.border_color = Color(0.96, 0.74, 0.20, 1.0) # Warm amber focus
			btn_glass_hover.set_border_width_all(1)
			btn_glass_hover.set_corner_radius_all(4)
			btn_glass_hover.content_margin_left = 6
			btn_glass_hover.content_margin_right = 6
			btn_glass_hover.content_margin_top = 2
			btn_glass_hover.content_margin_bottom = 2
			
			btn_skip.add_theme_stylebox_override("normal", btn_glass)
			btn_skip.add_theme_stylebox_override("hover", btn_glass_hover)
			btn_skip.add_theme_stylebox_override("focus", btn_glass_hover)
			btn_skip.offset_left = 372.0
			btn_skip.offset_right = 442.0
			btn_skip.offset_top = 6.0
			btn_skip.offset_bottom = 30.0
