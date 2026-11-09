# Dev Checkpoint Configuration Implementation Plan

## Goal
Replace the hardcoded `jump_to_dev_checkpoint()` logic in `GameManager.gd` with a data-driven, Inspector-configurable Resource system. When developers use the "Jump to Checkpoint" dropdown, the game will properly seed the current micro-events, the specific active quest, and the required glitch stats based on the custom Resource configuration.

## 1. Create Data Models (Custom Resources)
We will create two new scripts to define our configuration structure:
- **`DevCheckpoint.gd`**: A single checkpoint definition containing:
  - `checkpoint_id`: String (matches the `Marker2D` in the scene)
  - `display_name`: String (User-friendly name for the UI dropdown)
  - `completed_events`: Array of Strings (The micro-events that have already happened by this point)
  - `total_bugs_defeated`: int (Expected glitch kills)
  - `story_phase`: GameManager.StoryPhase (The overarching phase index)
  - `active_quest`: QuestData (Optional. The quest that should be active right now)
  - `quest_progress`: int (Optional. If the active quest is partially done, seed how many kills/items it has)
  - `completed_quests`: Array of QuestData (Optional. Quests that are already done and dusted)

- **`DevCheckpointConfig.gd`**: A wrapper resource that holds an `Array[DevCheckpoint]`. This is the single file we will edit in the Inspector.

## 2. Generate the Configuration File
- Create `res://resources/dev_checkpoint_config.tres` based on `DevCheckpointConfig`.
- Open it in the Godot Inspector and pre-seed the 9 existing checkpoints (`met_npc_1`, `start_errand_1`, etc.) using the exact logic we currently have hardcoded, but mapping the appropriate `QuestData` resources to them!

## 3. Update GameManager.gd
- Add a new exported/loaded variable to `GameManager.gd`:
  `var dev_config: DevCheckpointConfig = preload("res://resources/dev_checkpoint_config.tres")`
- Rewrite `jump_to_dev_checkpoint()` to simply look up the ID in `dev_config` and apply its data dynamically:
  - Clear `completed_events` and append the configured array.
  - Set `total_bugs_defeated` and `current_story_phase`.
  - Clear `QuestManager.active_quests`.
  - If `active_quest` is configured, call `QuestManager.accept_quest()` and apply `quest_progress`.
  - If `completed_quests` is configured, add them to `active_quests` with `is_completed = true`.

## 4. Update the Dev UI (ui.gd)
- Modify the `_setup_dev_jump_dropdown()` to read from `GameManager.dev_config` instead of the old hardcoded `AUTO_CHECKPOINT_EVENTS` array.
- Display the friendly `display_name` in the dropdown but use the `checkpoint_id` when jumping.

## Seed Data Investigation
Based on current data:
1. **met_npc_1**: Events `[met_npc_1]`, Phase `PHASE_1_GO_TO_LAB`, Bugs `0`, Quest: None
2. **met_leader**: Events `[met_npc_1, met_leader]`, Phase `PHASE_2_ERRAND_1`, Bugs `0`, Quest: None
3. **start_errand_1**: Events `[..., start_errand_1]`, Phase `PHASE_2_ERRAND_1`, Bugs `0`, Quest: `quest_1` (0/3)
4. **end_errand_1**: Events `[..., end_errand_1]`, Phase `PHASE_3_GO_TO_MERCHANT`, Bugs `3`, Quest: `quest_1` (Done)
5. **pre_meet_merchant**: Events `[..., pre_meet_merchant]`, Phase `PHASE_4_ERRAND_2`, Bugs `3`, Quest: None
6. **start_errand_2**: Events `[..., start_errand_2]`, Phase `PHASE_4_ERRAND_2`, Bugs `3`, Quest: `quest_2` (0/3)
7. **end_errand_2**: Events `[..., end_errand_2]`, Phase `PHASE_5_TOWN_INVASION`, Bugs `6`, Quest: `quest_2` (Done)
8. **start_pre_boss**: Events `[..., start_pre_boss]`, Phase `PHASE_6_BOSS_FIGHT`, Bugs `6`, Quest: None
9. **end_pre_boss**: Events `[..., end_pre_boss]`, Phase `PHASE_6_BOSS_FIGHT`, Bugs `6`, Quest: None
