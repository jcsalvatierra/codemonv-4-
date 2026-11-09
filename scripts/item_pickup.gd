extends StaticBody2D

@export_group("Item Settings")
@export var item_id: String = "tech_part" 
# Optional: Add a dialogue ID so the player gets a message when picking it up!
@export var dialogue_id: String = "found_item" 

@export_group("Spawn Rules (Micro-Events)")
@export var requires_event_to_appear: String = ""
@export var disappears_on_event: String = "" 

func _ready() -> void:
	_check_visibility()

func _process(delta: float) -> void:
	_check_visibility()

func _get_effective_disappear_event() -> String:
	if disappears_on_event != "":
		return disappears_on_event
	return "collected_" + name.to_lower()

func _check_visibility() -> void:
	var should_hide = false
	if requires_event_to_appear != "" and not GameManager.completed_events.has(requires_event_to_appear):
		should_hide = true
	var disappear_key = _get_effective_disappear_event()
	if disappear_key != "" and GameManager.completed_events.has(disappear_key):
		should_hide = true
		
	visible = not should_hide
	$CollisionShape2D.disabled = should_hide

# 
func interact() -> void:
	if not visible:
		return
		
	# 1. Tell the QuestManager we found the item!
	QuestManager.report_item_collected(item_id)
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_item_obtained"):
		audio.play_item_obtained()
	
	# 2. Add the micro-event so it stays gone unless checkpoint restores it
	var disappear_key = _get_effective_disappear_event()
	if disappear_key != "":
		GameManager.complete_event(disappear_key)
		
	# 3. Show a quick dialogue box to tell the player they found it!
	var dialogue_file = preload("res://dialogues/events.dialogue")
	GameManager.change_state(GameManager.GameState.DIALOGUE)
	DialogueManager.show_example_dialogue_balloon(dialogue_file, dialogue_id)
	await DialogueManager.dialogue_ended
	
	GameManager.change_state(GameManager.GameState.EXPLORATION)
	
	# 4. Delete the item from the map
	queue_free()
