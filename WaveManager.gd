extends Node

var rat_scene = preload("res://scenes/enemies/Rat.tscn")
var boss_spawned: bool = false
var boss_reward_given: bool = false


var spawn_radius: float = 400.0
var spawn_timer: float = 0.0
var time_elapsed: float = 0.0
var is_active: bool = true
var stage_cleared: bool = false
var current_enemy_texture_path: String = "res://쥐.png"

# ─── 체력회복 아이템 관련 ───
var health_item_timer: float = 0.0
var health_item_interval: float = 8.0
var health_item_active: bool = false

signal stage_clear

const RANDOM_ENEMY_LIST = [
	"res://쥐.png", "res://병아리.png", "res://토끼.png",
	"res://뱀.png", "res://개.png", "res://양.png",
	"res://돼지.png", "res://원숭이.png", "res://큰쥐.png",
	"res://큰토끼.png", "res://큰뱀.png", "res://큰개.png",
	"res://큰양.png", "res://큰원숭이.png", "res://큰사슴.png",
	"res://염소.png", "res://큰염소.png", "res://박쥐.png",
	"res://빨간박쥐.png", "res://저팔계.png", "res://백사자.png"
]

func _ready() -> void:
	add_to_group("wave_manager")
	GameData.story_chapter = 0  # 일반 스테이지 진입 시 스토리 챕터 초기화
	if GameData.current_stage >= 43:
		current_enemy_texture_path = RANDOM_ENEMY_LIST[randi() % RANDOM_ENEMY_LIST.size()]
		
func get_enemy_texture() -> Texture2D:
	# 스토리 모드: 챕터별 적 (current_stage 값과 무관하게 story_chapter로 분기)
	if GameData.story_chapter == 5:
		var chapter5_enemies = [
			"res://enemies_3/신단수까마귀.png",
			"res://enemies_3/신단수들개.png",
			"res://enemies_3/신단수살쾡이.png",
		]
		return load(chapter5_enemies[randi() % chapter5_enemies.size()])
	if GameData.story_chapter == 4:
		return load("res://enemies_2/들개.png")
	if GameData.story_chapter == 3:
		return load("res://enemies_2/멧돼지.png")
	if GameData.story_chapter == 2:
		return load("res://enemies_3/아사달멧돼지2.png")
	if GameData.story_chapter == 1:
		return load("res://enemies_3/아사달늑대.png")
	
	# 평원 1~15
	if GameData.current_stage <= 3:
		return load("res://enemies_1/쥐.png")
	elif GameData.current_stage <= 6:
		return load("res://enemies_1/다람쥐.png")
	elif GameData.current_stage <= 9:
		return load("res://enemies_1/메추라기.png")
	elif GameData.current_stage <= 12:
		return load("res://enemies_1/병아리.png")
	elif GameData.current_stage <= 15:
		return load("res://enemies_1/토끼.png")
	# 냇가 16~30
	elif GameData.current_stage <= 18:
		return load("res://enemies_1/닭.png")
	elif GameData.current_stage <= 21:
		return load("res://enemies_1/사슴.png")
	elif GameData.current_stage <= 24:
		return load("res://enemies_1/염소.png")
	elif GameData.current_stage <= 27:
		return load("res://enemies_1/뱀.png")
	elif GameData.current_stage <= 30:
		return load("res://enemies_1/비둘기.png")
	# 동굴 31~45
	elif GameData.current_stage <= 33:
		return load("res://enemies_1/벌.png")
	elif GameData.current_stage <= 36:
		return load("res://enemies_1/박쥐.png")
	elif GameData.current_stage <= 39:
		return load("res://enemies_1/빨간박쥐.png")
	elif GameData.current_stage <= 42:
		return load("res://enemies_1/지네.png")
	elif GameData.current_stage <= 45:
		return load("res://enemies_1/거미.png")
	# 검은모루 46~60
	elif GameData.current_stage <= 48:
		return load("res://enemies_2/동굴거미.png")
	elif GameData.current_stage <= 51:
		return load("res://enemies_2/동굴쥐.png")
	elif GameData.current_stage <= 54:
		return load("res://enemies_2/동굴두더지.png")
	elif GameData.current_stage <= 57:
		return load("res://enemies_2/동굴박쥐.png")
	elif GameData.current_stage <= 60:
		return load("res://enemies_2/동굴뱀.png")
	# 미송리 61~75
	elif GameData.current_stage <= 63:
		return load("res://enemies_2/멧토끼.png")
	elif GameData.current_stage <= 66:
		return load("res://enemies_2/족제비.png")
	elif GameData.current_stage <= 69:
		return load("res://enemies_2/사슴.png")
	elif GameData.current_stage <= 72:
		return load("res://enemies_2/늑대.png")
	elif GameData.current_stage <= 75:
		return load("res://enemies_2/멧돼지.png")
	# 열수 76~85
	elif GameData.current_stage <= 78:
		return load("res://enemies_2/수달.png")
	elif GameData.current_stage <= 81:
		return load("res://enemies_2/여우.png")
	elif GameData.current_stage <= 85:
		return load("res://enemies_2/호랑이.png")
	# 신단수 86~95
	elif GameData.current_stage <= 88:
		return load("res://enemies_3/신단수까마귀.png")
	elif GameData.current_stage <= 91:
		return load("res://enemies_3/신단수들개.png")
	elif GameData.current_stage <= 95:
		return load("res://enemies_3/신단수살쾡이.png")
	# 아사달 96~105
	elif GameData.current_stage <= 98:
		return load("res://enemies_3/아사달구렁이.png")
	elif GameData.current_stage <= 101:
		return load("res://enemies_3/아사달멧돼지.png")
	elif GameData.current_stage <= 105:
		return load("res://enemies_3/아사달늑대.png")
	# 왕검성 106~115
	elif GameData.current_stage <= 108:
		return load("res://enemies_3/왕검성신석기인.png")
	elif GameData.current_stage <= 111:
		return load("res://enemies_3/왕검성야만인.png")
	elif GameData.current_stage <= 115:
		return load("res://enemies_3/왕검성도끼병.png")
	# 북방 산악지대 116~125: 담비1~5
	elif GameData.current_stage <= 117:
		return load("res://enemies_4/담비1.png")
	elif GameData.current_stage <= 119:
		return load("res://enemies_4/담비2.png")
	elif GameData.current_stage <= 121:
		return load("res://enemies_4/담비3.png")
	elif GameData.current_stage <= 123:
		return load("res://enemies_4/담비4.png")
	elif GameData.current_stage <= 125:
		return load("res://enemies_4/담비5.png")
	# 교역로 126~135: 약탈자1~5
	elif GameData.current_stage <= 127:
		return load("res://enemies_4/약탈자1.png")
	elif GameData.current_stage <= 129:
		return load("res://enemies_4/약탈자2.png")
	elif GameData.current_stage <= 131:
		return load("res://enemies_4/약탈자3.png")
	elif GameData.current_stage <= 133:
		return load("res://enemies_4/약탈자4.png")
	elif GameData.current_stage <= 135:
		return load("res://enemies_4/약탈자5.png")
	# 왕검성 상업지대 136~145: 강도1~5
	elif GameData.current_stage <= 137:
		return load("res://enemies_4/강도1.png")
	elif GameData.current_stage <= 139:
		return load("res://enemies_4/강도2.png")
	elif GameData.current_stage <= 141:
		return load("res://enemies_4/강도3.png")
	elif GameData.current_stage <= 143:
		return load("res://enemies_4/강도4.png")
	elif GameData.current_stage <= 145:
		return load("res://enemies_4/강도5.png")
	# 패수 도하 방어전 146~155: 패수1~5
	elif GameData.current_stage <= 147:
		return load("res://enemies_4/패수1.png")
	elif GameData.current_stage <= 149:
		return load("res://enemies_4/패수2.png")
	elif GameData.current_stage <= 151:
		return load("res://enemies_4/패수3.png")
	elif GameData.current_stage <= 153:
		return load("res://enemies_4/패수4.png")
	elif GameData.current_stage <= 155:
		return load("res://enemies_4/패수5.png")
	# 협곡 매복작전 156~165: 협곡1~5
	elif GameData.current_stage <= 157:
		return load("res://enemies_4/협곡1.png")
	elif GameData.current_stage <= 159:
		return load("res://enemies_4/협곡2.png")
	elif GameData.current_stage <= 161:
		return load("res://enemies_4/협곡3.png")
	elif GameData.current_stage <= 163:
		return load("res://enemies_4/협곡4.png")
	elif GameData.current_stage <= 165:
		return load("res://enemies_4/협곡5.png")
	# 왕검성 공성전 166~175: 공성1~5
	elif GameData.current_stage <= 167:
		return load("res://enemies_4/공성1.png")
	elif GameData.current_stage <= 169:
		return load("res://enemies_4/공성2.png")
	elif GameData.current_stage <= 171:
		return load("res://enemies_4/공성3.png")
	elif GameData.current_stage <= 173:
		return load("res://enemies_4/공성4.png")
	elif GameData.current_stage <= 175:
		return load("res://enemies_4/공성5.png")		
	else:
		return load(current_enemy_texture_path)

var story_spawn_paused: bool = false

func _process(delta: float) -> void:
	if not is_active:
		# 10단계에서만 남은 적 전멸 시 클리어
		if not stage_cleared:
			var enemies = get_tree().get_nodes_in_group("enemies")
			if enemies.is_empty():
				stage_cleared = true
				emit_signal("stage_clear")
		return
	
	time_elapsed += delta

	if story_spawn_paused:
		return

	spawn_timer += delta
	
	if time_elapsed >= GameData.stage_time:
		if GameData.current_level >= GameData.max_level:
			# 마지막 10단계: 스폰 중지 후 적 전멸 대기
			is_active = false
			health_item_active = false
		else:
			# 1~9단계: 바로 다음 단계로
			time_elapsed = 0.0
			spawn_timer = 0.0
			emit_signal("stage_clear")
		return
	
	if spawn_timer >= 2.0:
		spawn_timer = 0.0
		spawn_enemy()
# 보스 스폰 조건: 5의 배수 스테이지 + 5단계에서만 1회
	if GameData.current_stage % 5 == 0 and GameData.current_level == 5 and not boss_spawned:
		boss_spawned = true
		spawn_boss()

func check_final_clear() -> void:
	if stage_cleared:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		stage_cleared = true
		emit_signal("stage_clear")


func get_spawn_count() -> int:
	return GameData.current_level * 2

func spawn_enemy() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	if current_enemies.size() >= 100:
		return
	var count = get_spawn_count()
	for i in range(count):
		if get_tree().get_nodes_in_group("enemies").size() >= 100:
			break
		var enemy = rat_scene.instantiate()
		enemy.get_node("Sprite2D").texture = get_enemy_texture()
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
		enemy.global_position = player.global_position + offset
		get_parent().add_child(enemy)

func spawn_boss() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var boss = rat_scene.instantiate()
	var sprite = boss.get_node("Sprite2D")

	# 스테이지별 보스 이미지
	var boss_img_path = "res://보스_" + str(GameData.current_stage) + ".png"
	if ResourceLoader.exists(boss_img_path):
		sprite.texture = load(boss_img_path)
	else:
		sprite.texture = get_enemy_texture()

	# 보스 크기 2배
	sprite.scale = Vector2(2.0, 2.0)

	# 플레이어 주변 스폰
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	boss.global_position = player.global_position + offset
	get_parent().add_child(boss)
	boss.set_meta("is_boss", true)

	# _ready() 이후 스탯 덮어쓰기
	await get_tree().process_frame
	if is_instance_valid(boss):
		var base_hp = 10.0 * pow(1.1, GameData.current_stage - 1)
		boss.max_hp  = base_hp * 50.0
		boss.hp      = boss.max_hp
		boss.attack_damage = 8.0
		if is_instance_valid(boss.get_node_or_null("HPBar")):
			boss.get_node("HPBar").max_value = boss.max_hp
			boss.get_node("HPBar").value     = boss.max_hp

# 보스 처치 시 보상
	if is_instance_valid(boss):
		boss.tree_exited.connect(func():
			if boss_reward_given:
				return
			boss_reward_given = true
			_give_boss_reward()
		)

func _give_boss_reward() -> void:
	var stage = GameData.current_stage
	var key = str(stage)
	var is_first = not GameData.boss_first_clear.get(key, false)

	var gem_amount = 0
	if is_first:
		gem_amount = stage
		GameData.boss_first_clear[key] = true
		_show_boss_reward_msg("보석 " + str(gem_amount) + "개 획득!")
	else:
		gem_amount = randi_range(int(stage / 2.0), stage)
		_show_boss_reward_msg("보석 " + str(gem_amount) + "개 획득!")
	GameData.gems += gem_amount
	GameData.boss_gem_reward = gem_amount
	GameData.save_game()

func _show_boss_reward_msg(msg: String) -> void:
	if not is_inside_tree():
		return
	var screen = get_viewport().get_visible_rect().size
	# CanvasLayer에 추가해서 카메라와 무관하게 화면 중앙에 표시
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	get_parent().add_child(canvas)

	var lbl = Label.new()
	lbl.text = msg
	lbl.position = Vector2(screen.x / 2 - 200, screen.y / 2 - 30)
	lbl.size = Vector2(400, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.5, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 5)
	canvas.add_child(lbl)

	var tween = get_tree().create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
	)
	
# ─── 체력회복 아이템 스폰 ───
func _spawn_health_item() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# 플레이어 주변 필드 내 랜덤 위치 (화면 크기 기준)
	var viewport_size = get_viewport().get_visible_rect().size
	var margin: float = 80.0
	var spawn_pos = Vector2(
		randf_range(margin, viewport_size.x - margin),
		randf_range(margin, viewport_size.y - margin)
	)
	
	# HealthItem 씬이 없으면 코드로 직접 생성
	var item = _create_health_item()
	item.global_position = spawn_pos
	get_parent().add_child(item)

func _create_health_item() -> Node2D:
	var item_node = Node2D.new()
	item_node.name = "HealthItem"
	item_node.add_to_group("health_items")
	
	var meat_img = Sprite2D.new()
	if ResourceLoader.exists("res://고기.png"):
		meat_img.texture = load("res://고기.png")
	meat_img.scale = Vector2(0.15, 0.15)
	item_node.add_child(meat_img)
	
	# Area2D 충돌 감지
	var area = Area2D.new()
	area.name = "Area2D"
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	area.add_child(col)
	item_node.add_child(area)
	
	# 매 프레임 플레이어와 거리 체크
	var collected = false
	item_node.set_meta("collected", false)
	
	# process 함수를 직접 연결하는 대신 타이머로 체크
	var check_timer = Timer.new()
	check_timer.wait_time = 0.1
	check_timer.autostart = true
	check_timer.timeout.connect(func():
		if not is_instance_valid(item_node) or item_node.get_meta("collected"):
			return
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		if item_node.global_position.distance_to(player.global_position) <= 40.0:
			item_node.set_meta("collected", true)
			var max_hp = GameData.get_total_max_hp()
			var heal_amount = int(max_hp * 0.1)
			player.hp = min(player.hp + heal_amount, max_hp)
			player.hp_bar.value = player.hp
			var ratio = float(player.hp) / float(max_hp)
			if ratio > 0.5:
				player.hp_bar.modulate = Color(0, 1, 0)
			elif ratio > 0.3:
				player.hp_bar.modulate = Color(1, 1, 0)
			var offsets = [-20, 0, 20]
			if not is_instance_valid(item_node):
				return
			var parent_node = item_node.get_parent()
			if not is_instance_valid(parent_node):
				return
			for i in range(3):
				var cross = Label.new()
				cross.text = "✚"
				cross.add_theme_font_size_override("font_size", 22)
				cross.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3))
				cross.global_position = player.global_position + Vector2(offsets[i], -50)
				cross.z_index = 20
				parent_node.add_child(cross)
				var tw = get_tree().create_tween()
				tw.tween_interval(i * 0.08)
				tw.tween_property(cross, "position:y", cross.position.y - 50, 0.8)
				tw.parallel().tween_interval(0.3)
				tw.parallel().tween_property(cross, "modulate:a", 0.0, 0.8)
				tw.tween_callback(func():
					if is_instance_valid(cross):
						cross.queue_free()
				)
			
			item_node.queue_free()
	)
	item_node.add_child(check_timer)
	
	return item_node


func reset() -> void:
	time_elapsed = 0.0
	spawn_timer = 0.0
	health_item_timer = 0.0
	is_active = true
	stage_cleared = false
	boss_spawned = false
	boss_reward_given = false
