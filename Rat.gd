extends "res://scripts/Enemy.gd"
func _ready() -> void:
	var stage = GameData.current_stage

	# 스토리 모드: 챕터별 체력 스펙
	if GameData.story_chapter == 4:
		stage = 70
	elif GameData.story_chapter == 3:
		if GameData.current_level <= 3:
			stage = 98
		else:
			stage = 40
	elif GameData.story_chapter == 2:
		stage = 30
	elif GameData.story_chapter == 1:
		if GameData.current_level <= 3:
			stage = 140
		else:
			stage = 20

	if stage <= 60:
		max_hp = 10.0 * pow(1.1, stage - 1)
	elif stage <= 120:
		var base60 = 10.0 * pow(1.1, 59)
		max_hp = base60 * pow(1.06, stage - 60)
	else:
		var base120 = (10.0 * pow(1.1, 59)) * pow(1.06, 60)
		max_hp = base120 * pow(1.04, stage - 120)
	move_speed = 40.0
	attack_damage = 1.0
	food_reward = 3
	super._ready()
