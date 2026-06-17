extends CharacterBody2D

var joystick_active: bool = false
var joystick_origin: Vector2 = Vector2.ZERO
var joystick_touch_index: int = -1
var joystick_start: Vector2 = Vector2.ZERO
var stone_stun_duration: float = 0.6
var joystick_draw_ref: Control = null

var hp: int

func _draw() -> void:
	draw_arc(Vector2.ZERO, 160.0, 0, TAU, 64, Color(1, 1, 1, 0.3), 2.0)

func _ready() -> void:
	global_position = Vector2(648, 576)
	var camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = 1296
	camera.limit_top = 0
	camera.limit_bottom = 1152
	add_child(camera)
	# 레벨 반영된 스탯으로 시작
	GameData.player_max_hp = GameData.get_level_max_hp()
	GameData.player_attack = GameData.get_level_base_attack()
	hp = GameData.get_total_max_hp()
	hp_bar.max_value = GameData.get_total_max_hp()
	hp_bar.value = hp
	add_to_group("player")
	# 레벨업 시그널 연결
	GameData.connect("level_up", _on_level_up)
	fist_damage  = GameData.get_total_attack() * FIST_MULT  * (1.0 + GameData.skill_lv_fist  * 0.05)
	stone_damage = GameData.get_total_attack() * STONE_MULT * (1.0 + GameData.skill_lv_stone * 0.05)
	stick_damage = GameData.get_total_attack() * STICK_MULT * (1.0 + GameData.skill_lv_stick * 0.05)
	flame_damage = GameData.get_total_attack() * FLAME_MULT * (1.0 + GameData.skill_lv_flame * 0.05)
	arrow_damage = GameData.get_total_attack() * ARROW_MULT * arrow_dmg_multiplier * (1.0 + GameData.skill_lv_arrow * 0.05)
	net_damage   = GameData.get_total_attack() * NET_MULT   * net_dmg_multiplier   * (1.0 + GameData.skill_lv_net   * 0.05)

	# 캐릭터 외형 이미지 적용
	var profile = GameData.char_profile
	if not profile.is_empty():
		var img_path = "res://characters/char_%d.png" % profile.appearance
		if ResourceLoader.exists(img_path):
			sprite.texture = load(img_path)

	# 무속인 버프 아이콘 (머리 위 표시)
	_setup_shaman_buff_icons()

	# ── 가상 조이스틱 시각화 (화면 고정 레이어) ──
	var joy_canvas = CanvasLayer.new()
	joy_canvas.name = "JoystickLayer"
	joy_canvas.layer = 30
	add_child(joy_canvas)

	var joy_draw = Control.new()
	joy_draw.name = "JoystickDraw"
	joy_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_draw.draw.connect(_draw_joystick.bind(joy_draw))
	joy_canvas.add_child(joy_draw)
	joystick_draw_ref = joy_draw

func _draw_joystick(node: Control) -> void:
	if joystick_active:
		var max_radius = 60.0
		var offset = joystick_origin - joystick_start
		if offset.length() > max_radius:
			offset = offset.normalized() * max_radius
		node.draw_circle(joystick_start, max_radius, Color(0, 0, 0, 0.35))
		node.draw_circle(joystick_start + offset, 25.0, Color(0.6, 0.6, 0.6, 0.7))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y > get_viewport().get_visible_rect().size.y * 0.3:
				joystick_active = true
				joystick_origin = event.position
				joystick_start = event.position
				joystick_touch_index = event.index
		elif event.index == joystick_touch_index:
			joystick_active = false
			joystick_touch_index = -1
	
	if event is InputEventScreenDrag:
		if event.index == joystick_touch_index:
			joystick_origin = event.position

func _setup_shaman_buff_icons() -> void:
	var icon_scale = 0.5  # 기존 0.16 * scale_mult=1.0 대비 절반 수준
	var configs = [
		{"name": "shaman_atk_icon", "path": "res://빙의.png", "offset_x": -18.0},
		{"name": "shaman_spd_icon", "path": "res://접신.png", "offset_x": 0.0},
		{"name": "shaman_seal_icon", "path": "res://부적.png", "offset_x": 18.0},
	]
	for cfg in configs:
		if ResourceLoader.exists(cfg["path"]):
			var icon = Sprite2D.new()
			icon.name = cfg["name"]
			icon.texture = load(cfg["path"])
			icon.scale = Vector2(icon_scale, icon_scale)
			icon.position = Vector2(cfg["offset_x"], -68.0)
			icon.z_index = 16
			icon.visible = false
			add_child(icon)

func _process(_delta: float) -> void:
	queue_redraw()
	_update_shaman_buff_icons()
	if is_instance_valid(joystick_draw_ref):
		joystick_draw_ref.queue_redraw()

func _update_shaman_buff_icons() -> void:
	var atk_icon = get_node_or_null("shaman_atk_icon")
	var spd_icon = get_node_or_null("shaman_spd_icon")
	var seal_icon = get_node_or_null("shaman_seal_icon")
	if atk_icon:
		atk_icon.visible = GameData.shaman_atk_active
	if spd_icon:
		spd_icon.visible = shaman_spd_active
	if seal_icon:
		seal_icon.visible = shaman_seal_active

# ─── 스킬 데미지 계수 (여기서만 조정!) ───
const FIST_MULT: float = 1.0
const STONE_MULT: float = 1.7
const STICK_MULT: float = 1.2
const FLAME_MULT: float = 1.5

var fist_timer: float = 0.0
var fist_damage: float = 10.0
var fist_cooldown: float = 0.5
var fist_targets: int = 1
var fist_bonus_multiplier: float = 0.0  # 강화카드로 누적되는 보너스 %

var stone_unlocked: bool = false
var stone_timer: float = 0.0
var stone_cooldown: float = 2.7
var stone_damage: float = 8.0
var stone_count: int = 1
var stone_range: float = 160.0

var stick_unlocked: bool = false
var stick_timer: float = 0.0
var stick_cooldown: float = 1.5
var stick_damage: float = 5.0
var stick_range: float = 150.0
var stick_targets: int = 3
var stick_knockback_force: float = 150.0  # 넉백 강도
var stick_knockback_radius: float = 80.0  # 범위 넉백 반경

var flame_unlocked: bool = false
var flame_timer: float = 0.0
var flame_cooldown: float = 3.0
var flame_damage: float = 20.0
var flame_count: int = 1
var flame_range: float = 80.0
var flame_dot_ticks: int = 3
var flame_can_spread: bool = false
var flame_spread_multiplier: float = 1.5
var flame_spread_dmg_multiplier: float = 0.2
var flame_range_bonus: float = 0.0         # 화염 범위 증가 (범위 강화 카드)
# ─── 화살 ───
const ARROW_MULT: float = 3.0
var arrow_unlocked: bool = false
var arrow_timer: float = 0.0
var arrow_cooldown: float = 2.2
var arrow_damage: float = 0.0
var arrow_distance: float = 400.0
var arrow_count: int = 1
var arrow_bounce_count: int = 0  # 튕기기 화살 수 (강화카드)
var arrow_dmg_multiplier: float = 1.0  # 공격력 배율

# ─── 그물 ───
const NET_MULT: float = 0.2
var net_unlocked: bool = false
var net_timer: float = 0.0
var net_cooldown: float = 7.5
var net_duration: float = 2.5
var net_max_level: int = 10
var net_range: float = 150.0
var net_pull_force: float = 100.0
var net_damage: float = 0.0
var net_dmg_multiplier: float = 1.0
@onready var sprite = $Sprite2D
@onready var hp_bar = $HPBar

# ══════════════════════════════════════════
# ─── 무속인 ───
# ══════════════════════════════════════════
var shaman_atk_unlocked: bool = false   # 빙의 (공격력 증가)
var shaman_atk_timer: float = 0.0
var shaman_atk_cooldown: float = 12.0
var shaman_atk_duration: float = 5.0
var shaman_atk_bonus: float = 0.5

var shaman_spd_unlocked: bool = false   # 접신 (공격속도 증가)
var shaman_spd_timer: float = 0.0
var shaman_spd_cooldown: float = 11.0
var shaman_spd_duration: float = 5.0
var shaman_spd_bonus: float = 0.5

var shaman_seal_unlocked: bool = false  # 부적 (기술 공격 횟수 증가)
var shaman_seal_timer: float = 0.0
var shaman_seal_cooldown: float = 10.0
var shaman_seal_duration: float = 5.0

var shaman_spd_active: bool = false
var shaman_seal_active: bool = false

func handle_shaman_atk(delta: float) -> void:
	shaman_atk_timer += delta
	if shaman_atk_timer >= shaman_atk_cooldown:
		shaman_atk_timer = 0.0
		do_shaman_atk()

func do_shaman_atk() -> void:
	GameData.shaman_atk_active = true
	show_attack_effect(global_position, "res://빙의.png", 1.5)
	var t = get_tree().create_timer(shaman_atk_duration)
	t.timeout.connect(func():
		GameData.shaman_atk_active = false
	)

func handle_shaman_spd(delta: float) -> void:
	shaman_spd_timer += delta
	if shaman_spd_timer >= shaman_spd_cooldown:
		shaman_spd_timer = 0.0
		do_shaman_spd()

func do_shaman_spd() -> void:
	shaman_spd_active = true
	show_attack_effect(global_position, "res://접신.png", 1.5)
	var t = get_tree().create_timer(shaman_spd_duration)
	t.timeout.connect(func():
		shaman_spd_active = false
	)

func handle_shaman_seal(delta: float) -> void:
	shaman_seal_timer += delta
	if shaman_seal_timer >= shaman_seal_cooldown:
		shaman_seal_timer = 0.0
		do_shaman_seal()

func do_shaman_seal() -> void:
	show_attack_effect(global_position, "res://부적.png", 2.0)
	shaman_seal_active = true
	var t = get_tree().create_timer(get_shaman_seal_duration())
	t.timeout.connect(func():
		shaman_seal_active = false
	)

func get_dmg_mult() -> float:
	return 1.0 + (shaman_atk_bonus if GameData.shaman_atk_active else 0.0)

# 부적 활성 시 추가 공격 횟수
func get_seal_bonus_count() -> int:
	return 1 if shaman_seal_active else 0
# 무속인 강화: 전체 강화횟수를 빙의(0)/접신(1)/부적(2) 순환에 분배
# 부적이 10초(쿨타임 캡)에 도달하면 이후 강화는 빙의/접신만 순환
func get_shaman_upgrade_count(effect_idx: int) -> int:
	var seal_cap_count = 10  # (5.0 + n*0.5 >= 10.0) -> n >= 10
	var counts = [0, 0, 0]
	var remaining = GameData.skill_lv_shaman
	var cycle = [0, 1, 2]
	var cycle_idx = 0
	while remaining > 0:
		var target = cycle[cycle_idx % cycle.size()]
		# 부적이 캡에 도달했으면 빙의/접신만 순환
		if target == 2 and counts[2] >= seal_cap_count:
			cycle = [0, 1]
			cycle_idx = 0
			continue
		counts[target] += 1
		remaining -= 1
		cycle_idx += 1
	return counts[effect_idx]

func get_shaman_atk_pct() -> float:
	return 0.5 + get_shaman_upgrade_count(0) * 0.05  # 50% 기본 + 5%씩

func get_shaman_spd_pct() -> float:
	return 0.5 + get_shaman_upgrade_count(1) * 0.05

func get_shaman_seal_duration() -> float:
	var d = 5.0 + get_shaman_upgrade_count(2) * 0.5
	return min(d, shaman_seal_cooldown)  # 10초(쿨타임) 캡
	
func handle_movement() -> void:
	var dir = Vector2.ZERO
	if joystick_active:
		var touch_dir = joystick_origin - joystick_start
		if touch_dir.length() > 10:
			dir = touch_dir.normalized()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var touch_dir = get_global_mouse_position() - global_position
		if touch_dir.length() > 20:
			dir = touch_dir.normalized()
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	velocity = dir * GameData.player_move_speed


func handle_fist(delta: float) -> void:
	fist_timer += delta
	if fist_timer >= fist_cooldown:
		fist_timer = 0.0
		do_fist_attack()

func do_fist_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	# 사거리 내 적만 필터링
	var valid_enemies = []
	for e in enemies:
		if global_position.distance_to(e.global_position) <= 160.0:
			valid_enemies.append(e)
	if valid_enemies.is_empty():
		return
	var fist_icon: String
	if GameData.has_bronze_fist:
		fist_icon = "res://청동주먹.png"
	elif GameData.has_leather_fist:
		fist_icon = "res://가죽주먹.png"
	else:
		fist_icon = "res://1. 주먹.png"
	var count = 0
	while count < fist_targets + get_seal_bonus_count():
		var e = valid_enemies[count % valid_enemies.size()]
		if is_instance_valid(e):
			var dmg = fist_damage * get_dmg_mult()
			e.take_damage(dmg)
			show_attack_effect(e.global_position, fist_icon)
			GameData.skill_damage["주먹"] = GameData.skill_damage.get("주먹", 0.0) + dmg

			# 가죽주먹: 좁은 범위 추가피해 (50%)
			if GameData.has_leather_fist or GameData.has_bronze_fist:
					var splash_range = 28.0
					var splash_rate = 0.5 if GameData.has_bronze_fist else 0.3
					var all_e = get_tree().get_nodes_in_group("enemies")
					for nearby in all_e:
						if is_instance_valid(nearby) and nearby != e:
							if e.global_position.distance_to(nearby.global_position) <= splash_range:
								var splash_dmg = dmg * splash_rate
								nearby.take_damage(splash_dmg)
								GameData.skill_damage["주먹"] = GameData.skill_damage.get("주먹", 0.0) + splash_dmg
		count += 1

	# ── 가죽주먹: 강타 시스템 ──
	if GameData.has_leather_fist or GameData.has_bronze_fist:
		GameData.fist_total_hit_count += fist_targets
		var smash_threshold = 7 if GameData.has_bronze_fist else 10
		if GameData.fist_total_hit_count >= smash_threshold:
			GameData.fist_total_hit_count -= smash_threshold
			# 한 프레임 뒤에 실행해서 현재 프레임 부하 분산
			call_deferred("_do_fist_smash")

func _do_fist_smash() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	# 사정거리(160px) 내 적만 필터링 후 거리순 정렬
	var in_range_enemies = []
	for e in enemies:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 160.0:
			in_range_enemies.append(e)
	if in_range_enemies.is_empty():
		return
	# fist_targets 수만큼만 사용 (정렬 없이 랜덤)
	in_range_enemies = in_range_enemies.slice(0, fist_targets)

	# 청동주먹 > 가죽주먹 우선순위
	var is_bronze = GameData.has_bronze_fist
	var hp_rate = 0.5 if is_bronze else 0.3
	var cap_mult = 3.0  # 보스 배율 (공통 3배)
	var smash_dmg_cap = GameData.get_total_attack() * cap_mult
	var smash_icon: String
	if is_bronze:
		smash_icon = "res://청동주먹.png"
	elif GameData.has_leather_fist:
		smash_icon = "res://가죽주먹.png"
	else:
		smash_icon = "res://1. 주먹.png"

	var count = 0
	while count < fist_targets:
		var e = in_range_enemies[count % in_range_enemies.size()]
		if is_instance_valid(e):
			var smash_dmg = e.max_hp * hp_rate
			smash_dmg = min(smash_dmg, smash_dmg_cap)
			e.take_damage(smash_dmg)
			GameData.skill_damage["주먹"] = GameData.skill_damage.get("주먹", 0.0) + smash_dmg
			show_attack_effect(e.global_position, smash_icon, 1.5)
			_show_shockwave_effect(e.global_position)
		count += 1

func handle_stone(delta: float) -> void:
	stone_timer += delta
	if stone_timer >= stone_cooldown:
		stone_timer = 0.0
		do_stone_attack()

func do_stone_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	for i in range(stone_count + get_seal_bonus_count()):
		var target = enemies[i % enemies.size()]
		shoot_stone(target)

func shoot_stone(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var fx = Sprite2D.new()
	fx.texture = load("res://2. 돌멩이.png")
	fx.scale = Vector2(0.15, 0.15)
	fx.global_position = global_position
	get_parent().add_child(fx)
	var tween = get_tree().create_tween()
	tween.tween_property(fx, "global_position", target.global_position, 0.3)
	tween.tween_callback(func():
		if not is_instance_valid(fx):
			return
		var hit_pos = fx.global_position
		fx.queue_free()
		var dmg = stone_damage * get_dmg_mult()
		if is_instance_valid(target):
			target.take_damage(dmg)
			GameData.skill_damage["돌멩이"] = GameData.skill_damage.get("돌멩이", 0.0) + dmg
			if target.has_method("apply_stun"):
				var stun = stone_stun_duration
				if target.has_meta("is_boss") or target.is_in_group("boss"):
					stun *= 0.5
				target.apply_stun(stun)
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e != target:
				if hit_pos.distance_to(e.global_position) <= stone_range:
					e.take_damage(dmg * 0.5)
					GameData.skill_damage["돌멩이"] = GameData.skill_damage.get("돌멩이", 0.0) + dmg * 0.5
					if e.has_method("apply_stun"):
						var stun = stone_stun_duration
						if e.has_meta("is_boss") or e.is_in_group("boss"):
							stun *= 0.5
						e.apply_stun(stun)
	)

func handle_stick(delta: float) -> void:
	stick_timer += delta
	if stick_timer >= stick_cooldown:
		stick_timer -= stick_cooldown
		do_stick_attack()



func do_stick_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range = []
	for e in enemies:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) < stick_range:
			in_range.append(e)
	in_range.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	# 사거리 내 적만 필터링
	if in_range.is_empty():
		return
	var hit_count = 0
	while hit_count < stick_targets + get_seal_bonus_count():
		var e = in_range[hit_count % in_range.size()]
		if is_instance_valid(e):
			var dmg = stick_damage * get_dmg_mult()
			e.take_damage(dmg)
			show_attack_effect(e.global_position, "res://3. 몽둥이.png")
			GameData.skill_damage["나무막대"] = GameData.skill_damage.get("나무막대", 0.0) + dmg
			# 피격 적 기준 범위 넉백
			var hit_pos = e.global_position
			var all_enemies = get_tree().get_nodes_in_group("enemies")
			for nearby in all_enemies:
				if is_instance_valid(nearby):
					var dist = hit_pos.distance_to(nearby.global_position)
					if dist <= stick_knockback_radius:
						var knockback_dir = (nearby.global_position - global_position).normalized()
						if knockback_dir == Vector2.ZERO:
							knockback_dir = Vector2.RIGHT
						var knockback = stick_knockback_force
						if nearby.has_meta("is_boss") or nearby.is_in_group("boss"):
							knockback *= 0.5
						nearby.velocity = knockback_dir * knockback
		hit_count += 1

func handle_flame(delta: float) -> void:
	flame_timer += delta
	if flame_timer >= flame_cooldown:
		flame_timer = 0.0
		do_flame_attack()

func do_flame_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# 가장 가까운 적을 타겟으로 발사
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	var target = enemies[0]
	if not is_instance_valid(target):
		return

	# 화염 발사 이펙트 (타겟을 향해 날아가는 연출)
	var fx = Sprite2D.new()
	if ResourceLoader.exists("res://4. 불.png"):
		fx.texture = load("res://4. 불.png")
	fx.scale = Vector2(0.16, 0.16)
	fx.global_position = global_position
	get_parent().add_child(fx)

	var tween = get_tree().create_tween()
	tween.tween_property(fx, "global_position", target.global_position, 0.3)
	tween.tween_callback(func():
		if not is_instance_valid(fx):
			return
		var hit_pos = fx.global_position
		fx.queue_free()

		var actual_range = flame_range + flame_range_bonus
		var spread_range = actual_range * flame_spread_multiplier

		# 맞은 지점 기준 범위 내 모든 적에게 화염 도트
		var fdmg = flame_damage * get_dmg_mult()
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var dist = hit_pos.distance_to(e.global_position)
			if dist <= actual_range:
				if e.has_method("apply_burn"):
					e.apply_burn(fdmg, flame_dot_ticks, false, 0, false)
					GameData.skill_damage["화염"] = GameData.skill_damage.get("화염", 0.0) + fdmg * flame_dot_ticks
				show_attack_effect(e.global_position, "res://4. 불.png", 1.0)
			elif flame_can_spread and dist <= spread_range:
				if e.has_method("apply_burn"):
					var spread_dmg = max(1.0, fdmg * flame_spread_dmg_multiplier)
					e.apply_burn(spread_dmg, flame_dot_ticks, false, 0, false)
					GameData.skill_damage["화염"] = GameData.skill_damage.get("화염", 0.0) + spread_dmg * flame_dot_ticks
				show_attack_effect(e.global_position, "res://4. 불.png", 0.5)
	)

func show_attack_effect(pos: Vector2, texture_path: String, scale_mult: float = 1.0) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	var fx = Sprite2D.new()
	fx.texture = load(texture_path)
	fx.scale = Vector2(0.16 * scale_mult, 0.16 * scale_mult)
	fx.global_position = pos
	fx.z_index = 15
	fx.add_to_group("effects")
	get_parent().add_child(fx)
	var tw = get_tree().create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		if is_instance_valid(fx):
			fx.queue_free()
	)

func take_damage(amount: float) -> void:
	var actual = max(1, int(amount) - GameData.get_total_defense())
	hp -= actual

	# 스토리 모드 전체: 체력 1 이하로 떨어지지 않고 패배하지 않음
	var is_story_intro = GameData.story_chapter > 0
	if is_story_intro and hp <= 0:
		hp = 1

	hp_bar.value = hp
	var ratio = float(hp) / float(GameData.get_total_max_hp())
	if ratio > 0.5:
		hp_bar.modulate = Color(0, 1, 0)
	elif ratio > 0.3:
		hp_bar.modulate = Color(1, 1, 0)
	else:
		hp_bar.modulate = Color(1, 0, 0)
	if hp <= 0 and not is_story_intro:
		die()

func die() -> void:
	var game_over = preload("res://scenes/GameOver.tscn").instantiate()
	get_tree().root.add_child(game_over)
	queue_free()

# ─── 체력 회복 함수 (체력회복 아이템용) ───
func heal(amount: int) -> void:
	hp = min(hp + amount, GameData.get_total_max_hp())
	hp_bar.value = hp
	var ratio = float(hp) / float(GameData.get_total_max_hp())
	if ratio > 0.5:
		hp_bar.modulate = Color(0, 1, 0)
	elif ratio > 0.3:
		hp_bar.modulate = Color(1, 1, 0)
	else:
		hp_bar.modulate = Color(1, 0, 0)
		
func _on_level_up(new_level: int) -> void:
	GameData.player_max_hp = GameData.get_level_max_hp()
	GameData.player_attack = GameData.get_level_base_attack()
	var new_total_hp = GameData.get_total_max_hp()   # 레벨 HP + 장비 HP
	var hp_diff = new_total_hp - hp_bar.max_value
	hp = min(hp + hp_diff, new_total_hp)
	hp_bar.max_value = new_total_hp
	hp_bar.value = hp
	# 공격력 즉시 반영 (장비 보너스 포함)
	fist_damage  = GameData.get_total_attack() * FIST_MULT  * (1.0 + GameData.skill_lv_fist  * 0.05)
	stone_damage = GameData.get_total_attack() * STONE_MULT * (1.0 + GameData.skill_lv_stone * 0.05)
	stick_damage = GameData.get_total_attack() * STICK_MULT * (1.0 + GameData.skill_lv_stick * 0.05)
	flame_damage = GameData.get_total_attack() * FLAME_MULT * (1.0 + GameData.skill_lv_flame * 0.05)
	arrow_damage = GameData.get_total_attack() * ARROW_MULT * arrow_dmg_multiplier * (1.0 + GameData.skill_lv_arrow * 0.05)
	net_damage   = GameData.get_total_attack() * NET_MULT   * net_dmg_multiplier   * (1.0 + GameData.skill_lv_net   * 0.05)

# ══════════════════════════════════════════
# ─── 화살 ───
# ══════════════════════════════════════════
func handle_arrow(delta: float) -> void:
	arrow_timer += delta
	if arrow_timer >= arrow_cooldown:
		arrow_timer = 0.0
		do_arrow_attack()

func do_arrow_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	for i in range(arrow_count + get_seal_bonus_count()):
		var target = enemies[i % enemies.size()]
		shoot_arrow(target, arrow_damage * get_dmg_mult())

func shoot_arrow(target: Node2D, dmg: float) -> void:
	if not is_instance_valid(target):
		return

	var direction = (target.global_position - global_position).normalized()
	var angle = direction.angle()
	var end_pos = global_position + direction * arrow_distance

	# 화살 이미지 생성
	var arrow_sprite = Sprite2D.new()
	arrow_sprite.scale = Vector2(1.0, 1.0)
	arrow_sprite.global_position = global_position
	arrow_sprite.rotation = angle - PI/4 + PI/2  # 이미지가 대각선(45도) 방향이라 보정
	arrow_sprite.z_index = 5
	get_parent().add_child(arrow_sprite)
	arrow_sprite.texture = load("res://화살.png")

	# 날아가는 애니메이션
	var tween = get_tree().create_tween()
	tween.tween_property(arrow_sprite, "global_position", end_pos, 0.4)
	tween.tween_callback(func():
		if is_instance_valid(arrow_sprite):
			arrow_sprite.queue_free()
	)

	# 경로상 적 타격 (매 프레임 체크)
	var elapsed = [0.0]  # 배열로 감싸서 람다 캡처 문제 해결
	var hit_enemies = []
	var check_timer = Timer.new()
	check_timer.wait_time = 0.05
	check_timer.autostart = false
	check_timer.timeout.connect(func():
		elapsed[0] += 0.05
		if elapsed[0] >= 0.4:
			if is_instance_valid(check_timer):
				check_timer.queue_free()
			return
		if not is_instance_valid(arrow_sprite):
			if is_instance_valid(check_timer):
				check_timer.queue_free()
			return
		var arrow_pos = arrow_sprite.global_position
		var all_enemies = get_tree().get_nodes_in_group("enemies")
		for e in all_enemies:
			if not is_instance_valid(e) or e in hit_enemies:
				continue
			var dist = arrow_pos.distance_to(e.global_position)
			if dist <= 50.0:
				e.take_damage(dmg)
				hit_enemies.append(e)
				GameData.skill_damage["화살"] = GameData.skill_damage.get("화살", 0.0) + dmg
				# 최초 적중 시 1회만 튕기기 발동
				if arrow_bounce_count > 0 and hit_enemies.size() == 1:
					_do_arrow_bounce(e.global_position, dmg * 0.5, arrow_bounce_count)
	)
	get_parent().add_child(check_timer)
	check_timer.start()
	
func _do_arrow_bounce(from_pos: Vector2, dmg: float, count: int) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty() or count <= 0:
		return
	enemies.sort_custom(func(a, b):
		return from_pos.distance_to(a.global_position) < from_pos.distance_to(b.global_position)
	)
	var targets_to_hit = count
	for i in range(targets_to_hit):
		var e = enemies[i % enemies.size()]
		if not is_instance_valid(e):
			continue
		var direction = (e.global_position - from_pos).normalized()
		var angle = direction.angle()
		var bounce_distance = arrow_distance * 0.4
		var end_pos = from_pos + direction * bounce_distance

		var small_arrow = Sprite2D.new()
		small_arrow.texture = load("res://화살.png")
		small_arrow.scale = Vector2(0.4, 0.4)
		small_arrow.global_position = from_pos
		small_arrow.rotation = angle
		small_arrow.z_index = 5
		get_tree().current_scene.add_child(small_arrow)

		var tween = get_tree().create_tween()
		tween.tween_property(small_arrow, "global_position", end_pos, 0.25)
		tween.tween_callback(func():
			if is_instance_valid(small_arrow):
				small_arrow.queue_free()
		)

		# 관통 피해 체크 타이머
		var elapsed_b = [0.0]
		var hit_list = []
		var b_timer = Timer.new()
		b_timer.wait_time = 0.05
		b_timer.autostart = false
		b_timer.timeout.connect(func():
			elapsed_b[0] += 0.05
			if elapsed_b[0] >= 0.25 or not is_instance_valid(small_arrow):
				if is_instance_valid(b_timer):
					b_timer.queue_free()
				return
			if not is_instance_valid(small_arrow):
				return
			var arrow_pos = small_arrow.global_position
			var all_enemies = get_tree().get_nodes_in_group("enemies")
			for nearby in all_enemies:
				if not is_instance_valid(nearby) or nearby in hit_list:
					continue
				if arrow_pos.distance_to(nearby.global_position) <= 15.0:
					nearby.take_damage(dmg)
					hit_list.append(nearby)
					GameData.skill_damage["화살"] = GameData.skill_damage.get("화살", 0.0) + dmg
		)
		get_tree().current_scene.add_child(b_timer)
		b_timer.start()

# ══════════════════════════════════════════
# ─── 그물 ───
# ══════════════════════════════════════════
func handle_net(delta: float) -> void:
	net_timer += delta
	if net_timer >= net_cooldown:
		net_timer = 0.0
		do_net_attack()

func do_net_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# 가장 밀집한 위치 찾기
	var best_pos = Vector2.ZERO
	var best_count = 0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var nearby_count = 0
		for other in enemies:
			if is_instance_valid(other) and e.global_position.distance_to(other.global_position) <= net_range:
				nearby_count += 1
		if nearby_count > best_count:
			best_count = nearby_count
			best_pos = e.global_position

	if best_pos == Vector2.ZERO:
		return

	# 그물 이펙트 표시
	var net_effect = Sprite2D.new()
	if ResourceLoader.exists("res://그물.png"):
		net_effect.texture = load("res://그물.png")
	net_effect.global_position = best_pos
	net_effect.z_index = -1
	net_effect.scale = Vector2(net_range / 50.0, net_range / 50.0)
	get_parent().add_child(net_effect)
	
	# 지속시간 후 그물 제거
	var tween = get_tree().create_tween()
	tween.tween_interval(net_duration)
	tween.tween_property(net_effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(net_effect):
			net_effect.queue_free()
	)

	# 끌어당기기 + 피해 타이머
	var elapsed = [0.0]
	var dmg_elapsed = [0.0]
	var net_center = best_pos  # 그물 설치 위치 고정
	var net_timer_node = Timer.new()
	net_timer_node.wait_time = 0.1
	net_timer_node.autostart = false
	net_timer_node.timeout.connect(func():
		if not is_instance_valid(net_effect):
			net_timer_node.queue_free()
			return
		elapsed[0] += 0.1
		dmg_elapsed[0] += 0.1
		if elapsed[0] >= net_duration:
			net_timer_node.queue_free()
			return
		var all_enemies = get_tree().get_nodes_in_group("enemies")
		for e in all_enemies:
			if not is_instance_valid(e):
				continue
			if net_center.distance_to(e.global_position) <= net_range:
				# 끌어당기기
				var pull_dir = (net_center - e.global_position).normalized()
				e.velocity += pull_dir * net_pull_force * 0.1
				# 1초에 1회만 피해
				if dmg_elapsed[0] >= 1.0:
					var net_tick_dmg = max(1.0, net_damage) * get_dmg_mult()
					e.take_damage(net_tick_dmg)
					GameData.skill_damage["그물"] = GameData.skill_damage.get("그물", 0.0) + net_tick_dmg
		if dmg_elapsed[0] >= 1.0:
			dmg_elapsed[0] = 0.0
	)
	get_parent().add_child(net_timer_node)
	net_timer_node.start()

func _show_shockwave_effect(pos: Vector2) -> void:
	var wave = Node2D.new()
	wave.global_position = pos
	wave.z_index = 14
	get_parent().add_child(wave)

	# 그리기 콜백으로 원 그리기
	var ring = ColorRect.new()
	ring.color = Color(1.0, 0.85, 0.2, 0.8)  # 황금색 충격파
	wave.add_child(ring)

	# 원형으로 보이도록 draw 시그널 사용
	var circle_draw = func():
		pass

	# 간단하게 Sprite로 원 그리기: 코드로 원형 텍스처 생성
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(64):
		for y in range(64):
			var dx = x - 32
			var dy = y - 32
			var dist = sqrt(dx*dx + dy*dy)
			if dist >= 26 and dist <= 32:
				img.set_pixel(x, y, Color(1.0, 0.2, 0.2, 0.902))

	var tex = ImageTexture.create_from_image(img)
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(0.5, 0.5)
	wave.add_child(sprite)
	ring.queue_free()  # ColorRect 제거 (sprite로 대체)

	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(3.0, 3.0), 0.4)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.set_parallel(false)
	tween.tween_callback(func():
		if is_instance_valid(wave):
			wave.queue_free()
	)

func _physics_process(delta: float) -> void:
	var skill_delta = delta * (1.0 + get_shaman_spd_pct()) if shaman_spd_active else delta
	handle_movement()
	handle_fist(skill_delta)
	if stone_unlocked:
		handle_stone(skill_delta)
	if stick_unlocked:
		handle_stick(skill_delta)
	if flame_unlocked:
		handle_flame(skill_delta)
	if arrow_unlocked:
		handle_arrow(skill_delta)
	if net_unlocked:
		handle_net(skill_delta)
	if shaman_atk_unlocked:
		handle_shaman_atk(delta)
	if shaman_spd_unlocked:
		handle_shaman_spd(delta)
	if shaman_seal_unlocked:
		handle_shaman_seal(delta)
	move_and_slide()
	global_position.x = clamp(global_position.x, 0, 1296)
	global_position.y = clamp(global_position.y, 0, 1152)
