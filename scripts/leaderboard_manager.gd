extends Node

signal sync_completed(success: bool)

const ENCRYPTION_KEY: String = "Codemon_Encrypted_Leaderboard_2026_Key#99"
const SAVE_PATH: String = "user://records.enc"

var http_post: HTTPRequest = null
var http_get: HTTPRequest = null
var is_syncing: bool = false
var pending_get_callbacks: Array = []

func _ready() -> void:
	http_post = HTTPRequest.new()
	http_post.name = "HTTP_Post"
	add_child(http_post)
	http_post.request_completed.connect(_on_post_completed)

	http_get = HTTPRequest.new()
	http_get.name = "HTTP_Get"
	add_child(http_get)
	http_get.request_completed.connect(_on_get_completed)

	# Attempt to sync any unsynced local records on startup if online
	sync_pending_records()

func record_run(player_name: String, elapsed_time: float, bugs_defeated: int = 15, auto_upload: bool = false) -> Dictionary:
	var date_dict = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d %02d:%02d" % [
		date_dict["year"], date_dict["month"], date_dict["day"],
		date_dict["hour"], date_dict["minute"]
	]
	
	var clean_name = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Anonymous"
		
	var new_record = {
		"player_name": clean_name,
		"completion_time": elapsed_time,
		"formatted_time": GameManager.format_run_time(elapsed_time),
		"date": date_str,
		"bugs_defeated": bugs_defeated,
		"uploaded": false
	}
	
	var records = get_local_records()
	records.append(new_record)
	save_local_records(records)
	
	if auto_upload:
		sync_pending_records()
	return new_record

func get_local_records() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
		
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
	if not file:
		print("Leaderboard: Failed to open encrypted file or tampered with.")
		return []
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		print("Leaderboard: JSON parse error in local records.")
		return []
		
	if json.data is Array:
		var list: Array = json.data
		# Sort by completion_time ascending (fastest first)
		list.sort_custom(func(a, b): 
			return a.get("completion_time", 999999.0) < b.get("completion_time", 999999.0)
		)
		return list
		
	return []

func save_local_records(records: Array) -> void:
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if not file:
		print("Leaderboard: Failed to open encrypted file for writing.")
		return
		
	var json_str = JSON.stringify(records, "\t")
	file.store_string(json_str)
	file.close()

func sync_pending_records() -> void:
	if is_syncing:
		return
	if GameManager.leaderboard_api_url.strip_edges().is_empty():
		sync_completed.emit(false)
		return
		
	var records = get_local_records()
	var pending_items = []
	for r in records:
		if not r.get("uploaded", false):
			pending_items.append(r)
			
	if pending_items.is_empty():
		sync_completed.emit(true)
		return
		
	is_syncing = true
	var url = GameManager.leaderboard_api_url.strip_edges()
	var headers = ["Content-Type: application/json"]
	if not GameManager.leaderboard_api_key.strip_edges().is_empty():
		headers.append("x-api-key: " + GameManager.leaderboard_api_key.strip_edges())
	var body = JSON.stringify({
		"records": pending_items
	})
	
	var err = http_post.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		is_syncing = false
		print("Leaderboard: POST request failed to dispatch: ", err)

func _on_post_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	is_syncing = false
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		print("Leaderboard: Online sync successful! Updating local flags.")
		var records = get_local_records()
		for r in records:
			r["uploaded"] = true
		save_local_records(records)
		sync_completed.emit(true)
	else:
		print("Leaderboard: Online sync failed (offline or server error). Code: ", response_code)
		sync_completed.emit(false)

var is_fetching_online: bool = false

func fetch_online_leaderboard(callback: Callable) -> void:
	if GameManager.leaderboard_api_url.strip_edges().is_empty():
		_invoke_callback(callback, false, [], "Leaderboard URL is empty.")
		return
		
	pending_get_callbacks.append(callback)
	if is_fetching_online:
		return
		
	is_fetching_online = true
	var url = GameManager.leaderboard_api_url.strip_edges()
	var headers = ["Accept: application/json"]
	if not GameManager.leaderboard_api_key.strip_edges().is_empty():
		headers.append("x-api-key: " + GameManager.leaderboard_api_key.strip_edges())
	
	var err = http_get.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		is_fetching_online = false
		pending_get_callbacks.erase(callback)
		_invoke_callback(callback, false, [], "Failed to dispatch GET request: " + str(err))

func _on_get_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_fetching_online = false
	var callbacks = pending_get_callbacks.duplicate()
	pending_get_callbacks.clear()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var err_msg = "Could not connect to online leaderboard (Code %d)" % response_code
		for cb in callbacks:
			_invoke_callback(cb, false, [], err_msg)
		return
		
	var json_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		for cb in callbacks:
			_invoke_callback(cb, false, [], "Failed to parse online leaderboard response.")
		return
		
	var records: Array = []
	if json.data is Array:
		records = json.data
	elif json.data is Dictionary and json.data.has("records") and json.data["records"] is Array:
		records = json.data["records"]
		
	records.sort_custom(func(a, b): 
		return a.get("completion_time", 999999.0) < b.get("completion_time", 999999.0)
	)
	
	for cb in callbacks:
		_invoke_callback(cb, true, records, "")

func _invoke_callback(cb: Callable, success: bool, records: Array, err_msg: String) -> void:
	if not cb.is_valid():
		return
	var obj = cb.get_object()
	if obj != null and not is_instance_valid(obj):
		return
	cb.call(success, records, err_msg)
