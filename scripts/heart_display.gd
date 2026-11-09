extends HBoxContainer


@export var heart_full: Texture2D
@export var heart_empty: Texture2D

func _ready() -> void:
	# Run tto start to draw the initial hearts
	update_hearts(GameManager.player_hp, GameManager.max_hp)
	GameManager.player_hp_changed.connect(update_hearts) 

# Call yung function whenever the player takes damage or heals
func update_hearts(current_hp: int, max_hp: int) -> void:
	# 1. Create missing hearts if our max HP increased
	while get_child_count() < max_hp:
		var new_heart = TextureRect.new()
		new_heart.stretch_mode = TextureRect.STRETCH_KEEP # Keeps pixel art crisp
		add_child(new_heart)
		
	# 2. Remove extra hearts if our max HP decreased
	while get_child_count() > max_hp:
		var extra = get_child(get_child_count() - 1)
		remove_child(extra)
		extra.queue_free()

	# 3. Loop through all the hearts and set them to full or empty
	for i in range(max_hp):
		var heart = get_child(i) as TextureRect
		if i < current_hp:
			heart.texture = heart_full
		else:
			heart.texture = heart_empty
