extends CharacterBody2D

var max_hp: float = 30.0
var hp: float
var move_speed: float = 60.0
var attack_damage: float = 5.0
var attack_cooldown: float = 1.5
var food_reward: int = 3
var xp_reward: int = 0
var attack_timer: float = 0.0
var player: Node2D = null

var is_burning: bool = false
var burn_timer: float = 0.0
var burn_tick_interval: float = 0.5
var burn_ticks_left: int = 0
var burn_dmg_per_tick: float = 0.0

var can_spread_burn: bool = false
var spread_targets_count: int = 1
var is_slowed_by_burn: bool = false
var original_speed: float = 0.0

@onready var hp_bar = $HPBar

func _ready() -> void:
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	if "speed" in self:
		original_speed = self.speed
	elif GameData.get("enemy_speed") != null:
		original_speed = GameData.enemy_speed
	else:
		original_speed = 100.0

var is_stunned: bool = false

func _process(delta: float) -> void:
	if is_burning:
		burn_timer += delta
		if burn_timer >= burn_tick_interval:
			burn_timer = 0.0
			trigger_burn_tick()

func apply_burn(dmg: float, ticks: int, spread: bool, max_targets: int, slow: bool) -> void:
	is_burning = true
	burn_timer = 0.0
	burn_ticks_left = ticks
	burn_dmg_per_tick = dmg
	can_spread_burn = spread
	spread_targets_count = max_targets
	is_slowed_by_burn = slow
	
	if is_slowed_by_burn and "move_speed" in self:
		self.move_speed = original_speed * 0.5
		
	trigger_burn_tick()

func trigger_burn_tick() -> void:
	if burn_ticks_left <= 0:
		extinguish_burn()
		return
		
	take_damage(burn_dmg_per_tick)
	burn_ticks_left -= 1
	
	var p = get_tree().get_first_node_in_group("player")
	if p and p.has_method("show_attack_effect"):
		if can_spread_burn:
			p.show_attack_effect(global_position, "res://4. 불.png", 0.5)
		else:
			p.show_attack_effect(global_position, "res://출혈.png", 0.5)
			
	if can_spread_burn and burn_ticks_left > 0:
		spread_fire_to_nearby()

func spread_fire_to_nearby() -> void:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var valid_nearby = []
	for e in all_enemies:
		if is_instance_valid(e) and e != self and not e.is_burning and not e.is_queued_for_deletion():
			valid_nearby.append(e)
			
	valid_nearby.sort_custom(
		func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	
	for i in range(spread_targets_count):
		if i >= valid_nearby.size():
			break
			
		var target_enemy = valid_nearby[i]
		if is_instance_valid(target_enemy) and target_enemy.has_method("apply_burn"):
			target_enemy.apply_burn(burn_dmg_per_tick, 3, false, 0, is_slowed_by_burn)
			
func extinguish_burn() -> void:
	is_burning = false
	if "move_speed" in self:
		self.move_speed = original_speed

func apply_stun(duration: float) -> void:
	is_stunned = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		is_stunned = false

func _physics_process(delta: float) -> void:
	if is_stunned:
		return
		
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return
		
	var dist = global_position.distance_to(player.global_position)
	var min_dist = 48.0  # 캐릭터와 최소 유지 거리
	
	var dir: Vector2
	if dist < 1.0:
		# 완전히 겹쳤을 때 랜덤 방향으로 밀어냄
		dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	elif dist < min_dist:
		# 너무 가까우면 멈춤 (공격 범위 내)
		dir = Vector2.ZERO
	else:
		dir = (player.global_position - global_position).normalized()
	
	var target_velocity = dir * move_speed
	velocity = velocity.lerp(target_velocity, 0.15)
	move_and_slide()
	
	attack_timer += delta
	if attack_timer >= attack_cooldown and dist < 80.0:
		attack_timer = 0.0
		player.take_damage(attack_damage)

func take_damage(amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if has_meta("vulnerable_multiplier"):
		amount *= get_meta("vulnerable_multiplier")

	# 스토리 무적 보스: 데미지 표시는 되지만 체력은 줄지 않음
	var is_invincible = get_meta("story_invincible", false)
	if not is_invincible:
		hp -= amount
		hp_bar.value = hp
	var ratio = hp / max_hp
	if ratio > 0.5:
		hp_bar.modulate = Color(0, 1, 0)
	elif ratio > 0.3:
		hp_bar.modulate = Color(1, 1, 0)
	else:
		hp_bar.modulate = Color(1, 0, 0)
	modulate = Color(1, 0.3, 0.3)
	
	# 기존 데미지 라벨 개수에 따라 y 오프셋 적용
	if Engine.time_scale < 3.0:
		var existing_labels = []
		for child in get_parent().get_children():
			if child is Label and child.name.begins_with("DmgLbl_" + str(get_instance_id())):
				existing_labels.append(child)
		var y_offset = 40 + existing_labels.size() * 22
		var dmg_label = Label.new()
		dmg_label.name = "DmgLbl_" + str(get_instance_id())
		dmg_label.text = str(int(amount))
		dmg_label.add_theme_font_size_override("font_size", 20)
		dmg_label.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
		dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		dmg_label.add_theme_constant_override("outline_size", 2)
		dmg_label.position = global_position - Vector2(15, y_offset)
		dmg_label.z_index = 10
		get_parent().add_child(dmg_label)
		var dmg_tween = get_tree().create_tween()
		dmg_tween.tween_property(dmg_label, "position", dmg_label.position - Vector2(0, 40), 0.6)
		dmg_tween.parallel().tween_property(dmg_label, "modulate:a", 0.0, 0.6)
		dmg_tween.tween_callback(func():
			if is_instance_valid(dmg_label):
				dmg_label.queue_free()
		)
	
	if knockback_force != Vector2.ZERO and not is_queued_for_deletion():
		velocity = knockback_force
	if hp <= 0 and not is_invincible:
		die()
	else:
		var target_color = Color(1, 1, 1)
		if get_meta("vulnerable_multiplier", 1.0) != 1.0 or is_burning:
			target_color = Color(1.0, 0.4, 0.4)
		var tw = get_tree().create_tween()
		tw.tween_property(self, "modulate", target_color, 0.1)

func die() -> void:
	GameData.enemies_killed += 1
	queue_free()
