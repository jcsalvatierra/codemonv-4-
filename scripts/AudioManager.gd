extends Node


# BACKGROUND MUSIC (BGM)

@export_group("Background Music (BGM)")
@export var bgm_main_menu: AudioStream
@export var bgm_world_exploration: AudioStream
@export var bgm_battle: AudioStream
@export var bgm_boss: AudioStream
@export var bgm_victory: AudioStream
@export var bgm_game_over: AudioStream
@export var loop_all_bgm: bool = true # Kapag true, nagloops all background music tracks continuously


# COMBAT SOUND EFFECTS (SFX)

@export_group("Combat Sound Effects (SFX)")
@export var sfx_battle_choice_hover: AudioStream
@export var sfx_battle_choice_select: AudioStream
@export var sfx_player_attacked: AudioStream
@export var sfx_glitch_attacked: AudioStream
@export var sfx_question_correct: AudioStream
@export var sfx_question_wrong: AudioStream
@export var sfx_battle_encounter: AudioStream


# WORLD & INTERACTION SOUND EFFECTS (SFX)

@export_group("World & Interaction Sound Effects (SFX)")
@export var sfx_door_enter: AudioStream
@export var sfx_dialogue_interact: AudioStream
@export var sfx_item_obtained: AudioStream
@export var sfx_checkpoint_saved: AudioStream
@export var sfx_quest_accepted: AudioStream
@export var sfx_quest_complete: AudioStream
@export var sfx_ui_click: AudioStream


# VOLUME SETTINGS & AUDIO DUCKING (DOCKING)

@export_group("Volume Controls (dB)")
@export_range(-80.0, 6.0) var bgm_volume_db: float = -6.0
@export_range(-80.0, 6.0) var sfx_volume_db: float = 0.0

@export_group("Audio Ducking")
@export var enable_ducking: bool = true
@export var duck_on_all_sfx: bool = false # If true un, every SFX ducks BGM. If false, only combat/event SFX duck.
@export_range(0.0, 30.0) var duck_reduction_db: float = 10.0 # How many dB to lower BGM by during SFX
@export_range(0.01, 1.0) var duck_fade_in_time: float = 0.08  # How fast BGM ducks down
@export_range(0.05, 2.0) var duck_fade_out_time: float = 0.4 # How smoothly BGM returns to normal
@export_range(0.0, 1.0) var duck_release_delay: float = 0.1   # Hold time after SFX ends before fading back

# Internal player references
var bgm_player: AudioStreamPlayer = null
var sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8
var current_sfx_index: int = 0
var bgm_tween: Tween = null
var duck_tween: Tween = null
var is_ducked: bool = false
var ducking_players: Array[AudioStreamPlayer] = []
var is_bgm_playing: bool = false

func _ready() -> void:
	# Keep playing yung audio even when scene changes or game pauses
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_ensure_all_bgms_loop()

func _setup_audio_players() -> void:
	# 1. BGM Player
	bgm_player = get_node_or_null("BGMPlayer")
	if not bgm_player:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BGMPlayer"
		bgm_player.bus = "Master"
		add_child(bgm_player)
	bgm_player.volume_db = bgm_volume_db
	if not bgm_player.finished.is_connected(_on_bgm_finished):
		bgm_player.finished.connect(_on_bgm_finished)

	# 2. SFX Pool (inallows overlapping sound effects without clipping)
	for i in range(SFX_POOL_SIZE):
		var p = get_node_or_null("SFXPlayer%d" % i)
		if not p:
			p = AudioStreamPlayer.new()
			p.name = "SFXPlayer%d" % i
			p.bus = "Master"
			add_child(p)
		p.volume_db = sfx_volume_db
		if not p.finished.is_connected(_on_sfx_finished):
			p.finished.connect(_on_sfx_finished)
		sfx_pool.append(p)


# BGM PLAYBACK & LOOPING LOGIC

func play_bgm(stream: AudioStream, fade_duration: float = 0.6) -> void:
	if stream == null or bgm_player == null:
		return
		
	_ensure_stream_looping(stream)
	is_bgm_playing = true
		
	# If already playing this exact track, keep playing
	if bgm_player.playing and bgm_player.stream == stream:
		return

	if bgm_tween and bgm_tween.is_valid():
		bgm_tween.kill()
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	is_ducked = false
	ducking_players.clear()

	if bgm_player.playing and fade_duration > 0.0:
		# Smooth crossfade
		bgm_tween = create_tween()
		bgm_tween.tween_property(bgm_player, "volume_db", -80.0, fade_duration * 0.5)
		bgm_tween.tween_callback(func():
			bgm_player.stream = stream
			_ensure_stream_looping(stream)
			bgm_player.play()
		)
		bgm_tween.tween_property(bgm_player, "volume_db", bgm_volume_db, fade_duration * 0.5)
	else:
		bgm_player.stream = stream
		_ensure_stream_looping(stream)
		bgm_player.volume_db = bgm_volume_db
		bgm_player.play()

func stop_bgm(fade_duration: float = 0.5) -> void:
	is_bgm_playing = false
	if bgm_player == null or not bgm_player.playing:
		return
		
	if bgm_tween and bgm_tween.is_valid():
		bgm_tween.kill()
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	is_ducked = false
	ducking_players.clear()

	if fade_duration > 0.0:
		bgm_tween = create_tween()
		bgm_tween.tween_property(bgm_player, "volume_db", -80.0, fade_duration)
		bgm_tween.tween_callback(bgm_player.stop)
	else:
		bgm_player.stop()

func _on_bgm_finished() -> void:
	# Automatically replay BGM when it reaches the end if looping is enabled
	if is_bgm_playing and loop_all_bgm and bgm_player and bgm_player.stream != null:
		_replay_bgm.call_deferred()

func _replay_bgm() -> void:
	if is_bgm_playing and loop_all_bgm and bgm_player and bgm_player.stream != null:
		bgm_player.play(0.0)

func _ensure_all_bgms_loop() -> void:
	if not loop_all_bgm:
		return
	for stream in [bgm_main_menu, bgm_world_exploration, bgm_battle, bgm_boss, bgm_victory, bgm_game_over]:
		_ensure_stream_looping(stream)

func _ensure_stream_looping(stream: AudioStream) -> void:
	if stream == null or not loop_all_bgm:
		return
		
	# 1. MP3
	if stream is AudioStreamMP3:
		stream.loop = true
	# 2. OGG Vorbis
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	# 3. WAV
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# 4. Fallback for custom or newly imported streams
	else:
		if stream.get("loop") != null:
			stream.set("loop", true)
		if stream.get("loop_mode") != null:
			stream.set("loop_mode", 1)

# Convenient BGM Helpers
func play_bgm_main_menu() -> void:
	play_bgm(bgm_main_menu)

func play_bgm_world() -> void:
	play_bgm(bgm_world_exploration)

func play_bgm_battle() -> void:
	play_bgm(bgm_battle)

func play_bgm_boss() -> void:
	play_bgm(bgm_boss)

func play_bgm_victory() -> void:
	play_bgm(bgm_victory)

func play_bgm_game_over() -> void:
	play_bgm(bgm_game_over)


# SFX PLAYBACK & AUDIO DUCKING (DOCKING)

func play_sfx(stream: AudioStream, pitch_variance: float = 0.0, should_duck: bool = true) -> void:
	if stream == null or sfx_pool.is_empty():
		return

	var player = sfx_pool[current_sfx_index]
	current_sfx_index = (current_sfx_index + 1) % SFX_POOL_SIZE

	player.stream = stream
	player.volume_db = sfx_volume_db
	
	if pitch_variance > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0
		
	player.play()
	
	if enable_ducking and (duck_on_all_sfx or should_duck):
		if not ducking_players.has(player):
			ducking_players.append(player)
		_apply_ducking()
	else:
		ducking_players.erase(player)


# DUCKING CONTROL INTERNALS

func _apply_ducking() -> void:
	if not enable_ducking or bgm_player == null or not bgm_player.playing:
		return
		
	var target_db = max(-80.0, bgm_volume_db - duck_reduction_db)
	
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
		
	is_ducked = true
	duck_tween = create_tween()
	duck_tween.tween_property(bgm_player, "volume_db", target_db, duck_fade_in_time)

func _on_sfx_finished() -> void:
	if not enable_ducking or not is_ducked:
		return
		
	# Only restore BGM when all ducking SFX have finished playing
	if not is_any_ducking_sfx_playing():
		_restore_bgm_volume()

func is_any_ducking_sfx_playing() -> bool:
	var still_active: Array[AudioStreamPlayer] = []
	for p in ducking_players:
		if is_instance_valid(p) and p.playing:
			still_active.append(p)
	ducking_players = still_active
	return not ducking_players.is_empty()

func _restore_bgm_volume() -> void:
	if bgm_player == null or not bgm_player.playing:
		is_ducked = false
		return
		
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
		
	duck_tween = create_tween()
	if duck_release_delay > 0.0:
		duck_tween.tween_interval(duck_release_delay)
	duck_tween.tween_property(bgm_player, "volume_db", bgm_volume_db, duck_fade_out_time)
	duck_tween.tween_callback(func():
		is_ducked = false
	)

func duck_bgm(custom_reduction: float = -1.0, fade_time: float = -1.0) -> void:
	if bgm_player == null or not bgm_player.playing:
		return
	var reduction = duck_reduction_db if custom_reduction < 0.0 else custom_reduction
	var time = duck_fade_in_time if fade_time < 0.0 else fade_time
	var target_db = max(-80.0, bgm_volume_db - reduction)
	
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
		
	is_ducked = true
	duck_tween = create_tween()
	duck_tween.tween_property(bgm_player, "volume_db", target_db, time)

func unduck_bgm(fade_time: float = -1.0) -> void:
	ducking_players.clear()
	var time = duck_fade_out_time if fade_time < 0.0 else fade_time
	if bgm_player == null or not bgm_player.playing:
		is_ducked = false
		return
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	duck_tween = create_tween()
	duck_tween.tween_property(bgm_player, "volume_db", bgm_volume_db, time)
	duck_tween.tween_callback(func():
		is_ducked = false
	)


# CONVENIENT SFX HELPERS

func play_door_enter() -> void:
	play_sfx(sfx_door_enter, 0.0, true)

func play_dialogue_interact() -> void:
	play_sfx(sfx_dialogue_interact, 0.05, false)

func play_battle_choice_hover() -> void:
	play_sfx(sfx_battle_choice_hover, 0.0, false)

func play_battle_choice_select() -> void:
	play_sfx(sfx_battle_choice_select, 0.0, false)

func play_player_attacked() -> void:
	play_sfx(sfx_player_attacked, 0.0, true)

func play_glitch_attacked() -> void:
	play_sfx(sfx_glitch_attacked, 0.0, true)

func play_item_obtained() -> void:
	play_sfx(sfx_item_obtained, 0.0, true)

func play_question_correct() -> void:
	play_sfx(sfx_question_correct, 0.0, true)

func play_question_wrong() -> void:
	play_sfx(sfx_question_wrong, 0.0, true)

func play_battle_encounter() -> void:
	play_sfx(sfx_battle_encounter, 0.0, true)

func play_checkpoint_saved() -> void:
	play_sfx(sfx_checkpoint_saved, 0.0, true)

func play_quest_accepted() -> void:
	play_sfx(sfx_quest_accepted, 0.0, true)

func play_quest_complete() -> void:
	play_sfx(sfx_quest_complete, 0.0, true)

func play_ui_click() -> void:
	play_sfx(sfx_ui_click, 0.0, false)


# RUNTIME VOLUME CONTROLS (Linear 0.0 to 1.0)

func set_master_volume(linear_val: float) -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		if linear_val <= 0.001:
			AudioServer.set_bus_mute(master_idx, true)
		else:
			AudioServer.set_bus_mute(master_idx, false)
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(clampf(linear_val, 0.001, 1.0)))

func get_master_volume() -> float:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		if AudioServer.is_bus_mute(master_idx):
			return 0.0
		return clampf(db_to_linear(AudioServer.get_bus_volume_db(master_idx)), 0.0, 1.0)
	return 1.0

func set_music_volume(linear_val: float) -> void:
	if linear_val <= 0.001:
		bgm_volume_db = -80.0
	else:
		bgm_volume_db = linear_to_db(clampf(linear_val, 0.001, 1.0))
		
	if bgm_player:
		if not is_ducked:
			bgm_player.volume_db = bgm_volume_db
		else:
			bgm_player.volume_db = max(-80.0, bgm_volume_db - duck_reduction_db)

func get_music_volume() -> float:
	if bgm_volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(bgm_volume_db), 0.0, 1.0)

func set_sfx_volume(linear_val: float) -> void:
	if linear_val <= 0.001:
		sfx_volume_db = -80.0
	else:
		sfx_volume_db = linear_to_db(clampf(linear_val, 0.001, 1.0))
		
	for p in sfx_pool:
		if is_instance_valid(p):
			p.volume_db = sfx_volume_db

func get_sfx_volume() -> float:
	if sfx_volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(sfx_volume_db), 0.0, 1.0)
