extends Node

signal quest_updated()

var active_quests: Dictionary = {}

func accept_quest(quest: QuestData) -> void:
	if not active_quests.has(quest.quest_id):
		active_quests[quest.quest_id] = quest.duplicate()
		print("Quest Accepted: ", quest.quest_name)
		quest_updated.emit()
		
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_quest_accepted"):
			audio.play_quest_accepted()
			
		GameManager.save_checkpoint(Vector2.ZERO, "", "Quest: " + quest.quest_name)

func report_enemy_defeated(enemy_type: String) -> void:
	var updated = false
	for quest_id in active_quests.keys():
		var quest: QuestData = active_quests[quest_id]
		if not quest.is_completed and quest.target_enemy_type == enemy_type:
			quest.current_kills += 1
			updated = true
			if quest.are_objectives_met():
				print("Quest Ready to Turn In: ", quest.quest_name)
	if updated:
		quest_updated.emit()

func report_item_collected(item_id: String) -> void:
	var updated = false
	for quest_id in active_quests.keys():
		var quest: QuestData = active_quests[quest_id]
		if not quest.is_completed and quest.target_item_id == item_id:
			quest.current_items += 1
			updated = true
			if quest.are_objectives_met():
				print("Quest Ready to Turn In: ", quest.quest_name)
	if updated:
		quest_updated.emit()

# The NPC calls this when you talk to them with all the items!
func turn_in_quest(quest_id: String) -> void:
	if active_quests.has(quest_id):
		var quest = active_quests[quest_id]
		
		if quest.are_objectives_met() and not quest.is_completed:
			quest.is_completed = true
			print("Quest Fully Completed: ", quest.quest_name)
			
			var audio = get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_quest_complete"):
				audio.play_quest_complete()
			
			# Fire the micro-event to open paths/change the world!
			if quest.reward_micro_event != "":
				GameManager.complete_event(quest.reward_micro_event)
			
			quest_updated.emit()
			GameManager.save_checkpoint(Vector2.ZERO, "", "Turned In: " + quest.quest_name, quest.reward_micro_event)

# --- ENCOUNTER GATEKEEPER ---
# Returns true ONLY if the player has an active quest that needs this exact monster!
func needs_enemy(enemy_type: String) -> bool:
	for quest_id in active_quests.keys():
		var quest: QuestData = active_quests[quest_id]
		
		# If the quest is active, matches the monster, AND hasn't reached its kill quota yet:
		if not quest.is_completed and quest.target_enemy_type == enemy_type:
			if quest.current_kills < quest.required_kills:
				return true
				
	# If no quest needs this monster (or if quotas are already met), return false!
	return false


# CHECKPOINT SNAPSHOT & RESTORATION

func get_quests_snapshot() -> Dictionary:
	var snapshot = {}
	for q_id in active_quests.keys():
		var quest: QuestData = active_quests[q_id]
		snapshot[q_id] = {
			"quest_id": quest.quest_id,
			"quest_name": quest.quest_name,
			"target_enemy_type": quest.target_enemy_type,
			"required_kills": quest.required_kills,
			"current_kills": quest.current_kills,
			"target_item_id": quest.target_item_id,
			"required_items": quest.required_items,
			"current_items": quest.current_items,
			"reward_micro_event": quest.reward_micro_event,
			"is_completed": quest.is_completed
		}
	return snapshot

func restore_quests_snapshot(snapshot: Dictionary) -> void:
	active_quests.clear()
	for q_id in snapshot.keys():
		var data = snapshot[q_id]
		var q = QuestData.new()
		q.quest_id = data.get("quest_id", q_id)
		q.quest_name = data.get("quest_name", "Clear the Glitches")
		q.target_enemy_type = data.get("target_enemy_type", "alpha_glitch")
		q.required_kills = data.get("required_kills", 0)
		q.current_kills = data.get("current_kills", 0)
		q.target_item_id = data.get("target_item_id", "")
		q.required_items = data.get("required_items", 0)
		q.current_items = data.get("current_items", 0)
		q.reward_micro_event = data.get("reward_micro_event", "")
		q.is_completed = data.get("is_completed", false)
		active_quests[q_id] = q
	quest_updated.emit()

func reset_all_quests() -> void:
	active_quests.clear()
	quest_updated.emit()


# UI HELPERS

func get_current_active_quest() -> QuestData:
	for quest_id in active_quests.keys():
		var quest: QuestData = active_quests[quest_id]
		if not quest.is_completed:
			return quest
	return null

func has_active_quest() -> bool:
	return get_current_active_quest() != null
