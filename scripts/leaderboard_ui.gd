extends CanvasLayer

signal closed

enum ViewMode { LOCAL, ONLINE }
var current_mode: ViewMode = ViewMode.LOCAL

var panel: PanelContainer = null
var title_label: Label = null
var status_label: Label = null
var records_container: VBoxContainer = null
var scroll_container: ScrollContainer = null

var btn_local: Button = null
var btn_online: Button = null
var btn_refresh: Button = null
var btn_close: Button = null

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_local_records()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	# Full-screen semi-transparent backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.07, 0.05, 0.94)
	add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 246)
	if ResourceLoader.exists("res://dialogue.tres"):
		panel.theme = load("res://dialogue.tres")
		
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.11, 0.08, 0.98)
	panel_style.border_color = Color(0.28, 0.55, 0.35, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(main_vbox)

	# 1. Header (Title & Subtitle)
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	title_label = Label.new()
	title_label.text = "SPEEDRUN LEADERBOARD"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	if ResourceLoader.exists("res://dialogue.tres"):
		title_label.theme = load("res://dialogue.tres")
	header_hbox.add_child(title_label)

	btn_close = Button.new()
	btn_close.text = "Close [ESC]"
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(_on_close_pressed)
	if ResourceLoader.exists("res://dialogue.tres"):
		btn_close.theme = load("res://dialogue.tres")
	header_hbox.add_child(btn_close)

	# 2. Controls Toolbar (Tabs & Refresh)
	var tool_hbox = HBoxContainer.new()
	tool_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(tool_hbox)

	btn_local = Button.new()
	btn_local.text = "Local Best"
	btn_local.add_theme_font_size_override("font_size", 16)
	btn_local.pressed.connect(_on_local_tab_pressed)
	if ResourceLoader.exists("res://dialogue.tres"):
		btn_local.theme = load("res://dialogue.tres")
	tool_hbox.add_child(btn_local)

	btn_online = Button.new()
	btn_online.text = "Online World"
	btn_online.add_theme_font_size_override("font_size", 16)
	btn_online.pressed.connect(_on_online_tab_pressed)
	if ResourceLoader.exists("res://dialogue.tres"):
		btn_online.theme = load("res://dialogue.tres")
	tool_hbox.add_child(btn_online)

	btn_refresh = Button.new()
	btn_refresh.text = "Refresh"
	btn_refresh.add_theme_font_size_override("font_size", 16)
	btn_refresh.pressed.connect(_on_refresh_pressed)
	if ResourceLoader.exists("res://dialogue.tres"):
		btn_refresh.theme = load("res://dialogue.tres")
	tool_hbox.add_child(btn_refresh)

	status_label = Label.new()
	status_label.text = "Displaying verified completion logs"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	if ResourceLoader.exists("res://dialogue.tres"):
		status_label.theme = load("res://dialogue.tres")
	tool_hbox.add_child(status_label)

	var divider = HSeparator.new()
	main_vbox.add_child(divider)

	# 3. Column Header
	var col_header = HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(col_header)

	var h_rank = Label.new()
	h_rank.text = "RANK"
	h_rank.custom_minimum_size = Vector2(40, 16)
	h_rank.add_theme_font_size_override("font_size", 16)
	h_rank.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 1.0))
	col_header.add_child(h_rank)

	var h_name = Label.new()
	h_name.text = "CODER"
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_name.add_theme_font_size_override("font_size", 16)
	h_name.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 1.0))
	col_header.add_child(h_name)

	var h_time = Label.new()
	h_time.text = "TIME"
	h_time.custom_minimum_size = Vector2(75, 16)
	h_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_time.add_theme_font_size_override("font_size", 16)
	h_time.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 1.0))
	col_header.add_child(h_time)

	var h_date = Label.new()
	h_date.text = "DATE"
	h_date.custom_minimum_size = Vector2(100, 16)
	h_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_date.add_theme_font_size_override("font_size", 16)
	h_date.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 1.0))
	col_header.add_child(h_date)

	var h_status = Label.new()
	h_status.text = "STATUS"
	h_status.custom_minimum_size = Vector2(55, 16)
	h_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h_status.add_theme_font_size_override("font_size", 16)
	h_status.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6, 1.0))
	col_header.add_child(h_status)

	# 4. Scrollable Records Container
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll_container)

	records_container = VBoxContainer.new()
	records_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records_container.add_theme_constant_override("separation", 4)
	scroll_container.add_child(records_container)

	btn_close.grab_focus()

func _update_tab_styling() -> void:
	if current_mode == ViewMode.LOCAL:
		btn_local.disabled = true
		btn_online.disabled = false
	else:
		btn_local.disabled = false
		btn_online.disabled = true

func _show_local_records() -> void:
	current_mode = ViewMode.LOCAL
	_update_tab_styling()
	_clear_records()
	
	var lm = get_node_or_null("/root/LeaderboardManager")
	var records: Array = []
	if lm and lm.has_method("get_local_records"):
		records = lm.get_local_records()
		
	status_label.text = "Local Secure Store: %d record(s)" % records.size()
	
	if records.is_empty():
		_display_empty_message("No completion records found yet. Finish a 15-glitch run to record your speedrun!")
		return
		
	for i in range(records.size()):
		_add_record_row(i + 1, records[i], true)

func _show_online_records() -> void:
	current_mode = ViewMode.ONLINE
	_update_tab_styling()
	_clear_records()
	status_label.text = "Connecting to online server..."
	
	var lm = get_node_or_null("/root/LeaderboardManager")
	if not lm or not lm.has_method("fetch_online_leaderboard"):
		status_label.text = "LeaderboardManager unavailable."
		_display_empty_message("Could not initialize online leaderboard service.")
		return
		
	lm.fetch_online_leaderboard(_on_online_leaderboard_fetched)

func _on_online_leaderboard_fetched(success: bool, records: Array, err_msg: String) -> void:
	if not is_inside_tree():
		return
	if not success:
		status_label.text = "Offline / Connection Error"
		_display_empty_message(err_msg if not err_msg.is_empty() else "Server unreachable. Records will upload once online.")
		return
		
	status_label.text = "Online World Records: %d entries" % records.size()
	if records.is_empty():
		_display_empty_message("No online entries yet. Be the first to conquer Localhost Town!")
		return
		
	for i in range(records.size()):
		_add_record_row(i + 1, records[i], false)

func _clear_records() -> void:
	for child in records_container.get_children():
		child.queue_free()

func _display_empty_message(msg: String) -> void:
	_clear_records()
	var lbl = Label.new()
	lbl.text = "\n" + msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.70, 1.0))
	if ResourceLoader.exists("res://dialogue.tres"):
		lbl.theme = load("res://dialogue.tres")
	records_container.add_child(lbl)

func _add_record_row(rank: int, data: Dictionary, is_local_view: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var player_name = str(data.get("player_name", "Anonymous"))
	var time_val = data.get("completion_time", 0.0)
	var formatted_time = str(data.get("formatted_time", GameManager.format_run_time(time_val)))
	var date_str = str(data.get("date", "Unknown"))
	var uploaded = data.get("uploaded", false)

	var text_color = Color(0.9, 0.9, 0.9, 1.0)
	if rank == 1:
		text_color = Color(1.0, 0.85, 0.2, 1.0) # Gold
	elif rank == 2:
		text_color = Color(0.85, 0.9, 0.95, 1.0) # Silver
	elif rank == 3:
		text_color = Color(0.8, 0.6, 0.4, 1.0) # Bronze

	var lbl_rank = Label.new()
	lbl_rank.text = "#%d" % rank
	lbl_rank.custom_minimum_size = Vector2(40, 16)
	lbl_rank.add_theme_font_size_override("font_size", 16)
	lbl_rank.add_theme_color_override("font_color", text_color)
	row.add_child(lbl_rank)

	var lbl_name = Label.new()
	lbl_name.text = player_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_size_override("font_size", 16)
	lbl_name.add_theme_color_override("font_color", text_color)
	row.add_child(lbl_name)

	var lbl_time = Label.new()
	lbl_time.text = formatted_time
	lbl_time.custom_minimum_size = Vector2(75, 16)
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_time.add_theme_font_size_override("font_size", 16)
	lbl_time.add_theme_color_override("font_color", text_color)
	row.add_child(lbl_time)

	var lbl_date = Label.new()
	lbl_date.text = date_str
	lbl_date.custom_minimum_size = Vector2(100, 16)
	lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date.add_theme_font_size_override("font_size", 16)
	lbl_date.add_theme_color_override("font_color", text_color)
	row.add_child(lbl_date)

	var lbl_status = Label.new()
	if is_local_view:
		lbl_status.text = "Synced" if uploaded else "Local"
		lbl_status.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0) if uploaded else Color(0.9, 0.7, 0.3, 1.0))
	else:
		lbl_status.text = "Verified"
		lbl_status.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0))
	lbl_status.custom_minimum_size = Vector2(55, 16)
	lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl_status)

	records_container.add_child(row)

func _on_local_tab_pressed() -> void:
	_play_click_sfx()
	_show_local_records()

func _on_online_tab_pressed() -> void:
	_play_click_sfx()
	_show_online_records()

func _on_refresh_pressed() -> void:
	_play_click_sfx()
	var lm = get_node_or_null("/root/LeaderboardManager")
	if lm and lm.has_method("sync_pending_records"):
		lm.sync_pending_records()
	if current_mode == ViewMode.LOCAL:
		_show_local_records()
	else:
		_show_online_records()

func _on_close_pressed() -> void:
	_play_click_sfx()
	closed.emit()
	queue_free()

func _play_click_sfx() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()
