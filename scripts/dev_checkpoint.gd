extends Resource
class_name DevCheckpoint

@export var checkpoint_id: String = ""
@export var display_name: String = ""
@export var completed_events: Array[String] = []
@export var total_bugs_defeated: int = 0

# Match this to GameManager.StoryPhase manually, or just use int
@export var story_phase: int = 0

@export_group("Quest Configuration")
@export var active_quest: QuestData = null
@export var quest_progress: int = 0
@export var completed_quests: Array[QuestData] = []
