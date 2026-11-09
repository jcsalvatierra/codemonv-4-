extends Resource
class_name QuestData

@export_group("Quest Info")
@export var quest_id: String = "quest_1"
@export var quest_name: String = "Clear the Glitches"

@export_group("Combat Objectives")
@export var target_enemy_type: String = "alpha_glitch" 
@export var required_kills: int = 0
var current_kills: int = 0

@export_group("Fetch Objectives")
@export var target_item_id: String = "" 
@export var required_items: int = 0
var current_items: int = 0

@export_group("Rewards")
@export var reward_micro_event: String = "quest_1_done"

var is_completed: bool = false

# NEW: A simple helper to check if the player has done the work!
func are_objectives_met() -> bool:
	var kills_done = current_kills >= required_kills
	var items_done = current_items >= required_items
	return kills_done and items_done


# UI FORMATTING HELPERS

func get_display_name() -> String:
	if quest_name != "" and quest_name != "Clear the Glitches":
		return quest_name
	match quest_id:
		"quest_1":
			return "Pedro's Errand"
		"quest_2":
			return "Merchant's Recovery"
		"pre_boss":
			return "Town Invasion Defense"
		_:
			return quest_name

func get_formatted_item_name() -> String:
	match target_item_id:
		"coffee_bean":
			return "Coffee Bean"
		"tech_part":
			return "Tech Parts"
		_:
			return target_item_id.capitalize()

func get_kills_text() -> String:
	if required_kills <= 0:
		return ""
	var status = " [DONE]" if current_kills >= required_kills else ""
	return "Squash Glitches: %d / %d%s" % [min(current_kills, required_kills), required_kills, status]

func get_items_text() -> String:
	if required_items <= 0:
		return ""
	var status = " [DONE]" if current_items >= required_items else ""
	return "Find %s: %d / %d%s" % [get_formatted_item_name(), min(current_items, required_items), required_items, status]

func get_objectives_summary() -> Array[String]:
	var list: Array[String] = []
	if required_kills > 0:
		list.append(get_kills_text())
	if required_items > 0:
		list.append(get_items_text())
	return list
