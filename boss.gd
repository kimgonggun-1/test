extends "res://scripts/Enemy.gd"

var is_boss: bool = true

func _ready() -> void:
	var base_hp = 10.0 * pow(1.1, GameData.current_stage - 1)
	max_hp = base_hp * 100.0
	attack_damage = 2.0
	move_speed = 30.0
	food_reward = 0
	super._ready()
	$Sprite2D.scale = Vector2(2.0, 2.0)
