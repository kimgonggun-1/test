extends Node2D

var hp: float = 999999999.0
var max_hp: float = 999999999.0
var velocity: Vector2 = Vector2.ZERO
var parent_mammoth: Node2D = null

func take_damage(amount: float) -> void:
	if is_instance_valid(parent_mammoth):
		parent_mammoth._register_hit(amount, global_position)
		
func apply_burn(dmg: float, ticks: int, _can_spread: bool, _spread_count: int, _is_slowed: bool) -> void:
	if is_instance_valid(parent_mammoth):
		parent_mammoth._register_hit(dmg, global_position)  # 즉발 1틱
	for i in range(ticks - 1):
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(parent_mammoth):
			parent_mammoth._register_hit(dmg, global_position)
