extends Node2D
@onready var wave_manager = $WaveManager
@onready var upgrade_ui = $UI/UpgradeUI

var story_chapter: int = 0
var story_cleared: Dictionary = {}

func _ready() -> void:
	Engine.time_scale = 1.0
	GameData.story_chapter = 3
	# 부대 자동 공격 타이머
	var unit_attack_timer = Timer.new()
	unit_attack_timer.wait_time = 5.0
	unit_attack_timer.autostart = true
	unit_attack_timer.timeout.connect(_on_unit_attack)
	add_child(unit_attack_timer)
	# load_game은 로비/로그인에서 이미 호출됨. 여기서는 인게임 초기화만
	GameData.current_level = 1
	GameData.enemies_killed = 0
	GameData.stage_xp_pending = 0
	
	# 배경 이미지 (챕터3: 동굴20 = 60스테이지, 농경 시작 장면)
	var bg_path = "res://배경_스토리동굴.png"
	
	if bg_path != "" and ResourceLoader.exists(bg_path):
		
		var bg_img = Sprite2D.new()
		bg_img.texture = load(bg_path)
		bg_img.centered = false
		bg_img.position = Vector2(0, 0)
		bg_img.z_index = -10
		var tex_size = bg_img.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			bg_img.scale = Vector2(1296.0 / tex_size.x, 1152.0 / tex_size.y)
		add_child(bg_img)
	
	GameData.player_max_hp = GameData.get_level_max_hp()
	GameData.player_attack = GameData.get_level_base_attack()
	GameData.connect("level_up", _on_char_level_up)
	wave_manager.connect("stage_clear", _on_stage_clear)
	upgrade_ui.hide()
	upgrade_ui.connect("upgrade_chosen", _on_upgrade_chosen)

	# 적 자동 스폰 비활성화 (대사 진행 중에는 전투 없음)
	wave_manager.set_process(false)

	await get_tree().process_frame
	_start_story_chapter3()

func _on_char_level_up(new_level: int) -> void:
	_show_level_up_popup(new_level)

func _show_level_up_popup(new_level: int) -> void:
	var label = Label.new()
	label.text = str(new_level) + "등급 달성!"
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.2))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_top = -200
	label.z_index = 20
	add_child(label)
	var tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _on_stage_clear() -> void:
	for node in get_tree().get_nodes_in_group("effects"):
		node.queue_free()

	# ── 스토리 시퀀스: 목표 단계(레벨) 도달 시 콜백 ──
	if _story_sequence_end > 0 and GameData.current_level >= _story_sequence_end:
		wave_manager.set_process(false)
		var cb = _story_sequence_callback
		_story_sequence_end = -1
		cb.call()
		return

	if GameData.current_level >= GameData.max_level:
		# 10단계 완료 → 경험치 + 재화 지급
		var clear_xp = GameData.get_stage_clear_xp(GameData.current_stage)
		GameData.stage_xp_pending = 0
		GameData.total_xp += clear_xp
		GameData.apply_stage_xp()
		var reward = 100 + (50 * (GameData.current_stage - 1))
		GameData.food += reward
		GameData.wood += reward
		GameData.stone += int(reward * 0.1)
		GameData.record_stage_clear(GameData.current_stage, GameData.enemies_killed)
		GameData.save_game()
		show_clear_screen(false)
		return

	GameData.current_level += 1

	# 스토리: 화염/화살 해금(4단계) 후 5단계부터는 강화카드만
	if GameData.story_card_filter == "flame_unlock_only" and GameData.current_level >= 5:
		GameData.story_card_filter = "flame_only"
	if GameData.story_card_filter == "arrow_unlock_only" and GameData.current_level >= 5:
		GameData.story_card_filter = "arrow_only"

	# 단계 변경 시 보스 스폰 초기화
	var boss_wm = get_tree().get_first_node_in_group("wave_manager")
	if boss_wm:
		boss_wm.boss_spawned = false
	if GameData.current_stage >= 11 and GameData.current_level >= 6:
		var wm = get_tree().get_first_node_in_group("wave_manager")
		if wm:
			wm._spawn_health_item()
	upgrade_ui.show_upgrades()

func _get_stage_name(stage: int) -> String:
	if stage <= 15:
		return "평원 " + str(stage)
	elif stage <= 30:
		return "냇가 " + str(stage - 15)
	elif stage <= 45:
		return "동굴 " + str(stage - 30)
	elif stage <= 60:
		return "검은모루 " + str(stage - 45)
	elif stage <= 75:
		return "미송리 " + str(stage - 60)
	elif stage <= 85:
		return "열수 " + str(stage - 75)
	elif stage <= 95:
		return "신단수 " + str(stage - 85)
	elif stage <= 105:
		return "아사달 " + str(stage - 95)
	elif stage <= 115:
		return "왕검성 " + str(stage - 105)
	elif stage <= 125:
		return "북방 산악지대 " + str(stage - 115)
	elif stage <= 135:
		return "교역로 " + str(stage - 125)
	elif stage <= 145:
		return "왕검성 상업지대 " + str(stage - 135)
	elif stage <= 155:
		return "패수 도하 방어전 " + str(stage - 145)
	elif stage <= 165:
		return "협곡 매복작전 " + str(stage - 155)
	elif stage <= 175:
		return "왕검성 공성전 " + str(stage - 165)
	else:
		return "스테이지 " + str(stage)

func show_clear_screen(is_final: bool) -> void:
	get_tree().paused = true
	
	var existing = get_tree().root.get_node_or_null("ClearBG")
	if existing:
		existing.queue_free()
	
	var canvas = CanvasLayer.new()
	canvas.name = "ClearBG"
	canvas.add_to_group("clear_bg")
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(bg)
	
	var label = Label.new()
	var stage_name = _get_stage_name(GameData.current_stage)
	label.text = "최종 클리어!" if is_final else stage_name + " 성공!"
	label.add_theme_font_size_override("font_size", 55)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_top = -700
	bg.add_child(label)
	
	var xp_label = Label.new()
	xp_label.text = str(GameData.char_level) + "등급  |  경험치 +" + str(GameData.get_stage_clear_xp(GameData.current_stage))
	xp_label.add_theme_font_size_override("font_size", 26)
	xp_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.offset_top = -580
	bg.add_child(xp_label)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.offset_top = -50
	hbox.offset_bottom = -50
	hbox.add_theme_constant_override("separation", 40)
	bg.add_child(hbox)
	
	var reward = 100 + (50 * (GameData.current_stage - 1))

	# 보스 보석 보상 표시 (보스 스테이지 + 보석 획득한 경우)
	if GameData.current_stage % 5 == 0 and GameData.boss_gem_reward > 0:
		var gem_row = HBoxContainer.new()
		gem_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
		gem_row.offset_top = -140
		gem_row.offset_bottom = -100
		gem_row.add_theme_constant_override("separation", 10)
		bg.add_child(gem_row)

		if ResourceLoader.exists("res://보석.png"):
			var gem_img = TextureRect.new()
			gem_img.texture = load("res://보석.png")
			gem_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			gem_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gem_img.custom_minimum_size = Vector2(50, 50)
			gem_row.add_child(gem_img)

		var gem_lbl = Label.new()
		gem_lbl.text = "보석 +" + str(GameData.boss_gem_reward) + "개 획득!"
		gem_lbl.add_theme_font_size_override("font_size", 28)
		gem_lbl.add_theme_color_override("font_color", Color(0.2, 0.5, 1.0))
		gem_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		gem_lbl.add_theme_constant_override("outline_size", 3)
		gem_row.add_child(gem_lbl)

		# 표시 후 초기화
		GameData.boss_gem_reward = 0

	var wood_box = HBoxContainer.new()
	var wood_img = TextureRect.new()
	wood_img.texture = load("res://목재.png")
	wood_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wood_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wood_img.custom_minimum_size = Vector2(60, 60)
	var wood_label = Label.new()
	wood_label.text = "x " + str(reward)
	wood_label.add_theme_font_size_override("font_size", 30)
	wood_box.add_child(wood_img)
	wood_box.add_child(wood_label)
	hbox.add_child(wood_box)
	
	var food_box = HBoxContainer.new()
	var food_img = TextureRect.new()
	food_img.texture = load("res://식량.png")
	food_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	food_img.custom_minimum_size = Vector2(60, 60)
	var food_label = Label.new()
	food_label.text = "x " + str(reward)
	food_label.add_theme_font_size_override("font_size", 30)
	food_box.add_child(food_img)
	food_box.add_child(food_label)
	hbox.add_child(food_box)
	
	var stone_box = HBoxContainer.new()
	var stone_img = TextureRect.new()
	stone_img.texture = load("res://석재.png")
	stone_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stone_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone_img.custom_minimum_size = Vector2(60, 60)
	var stone_label = Label.new()
	stone_label.text = "x " + str(int(reward * 0.1))
	stone_label.add_theme_font_size_override("font_size", 30)
	stone_box.add_child(stone_img)
	stone_box.add_child(stone_label)
	hbox.add_child(stone_box)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.65, 0.1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	
	# ── 피해량 통계 ──
	var stats_hbox = HBoxContainer.new()
	stats_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.offset_top = 800
	stats_hbox.offset_bottom = 200
	stats_hbox.add_theme_constant_override("separation", 40)
	bg.add_child(stats_hbox)

	# 총 피해량 계산
	var total_skill_dmg = 0.0
	for v in GameData.skill_damage.values():
		total_skill_dmg += v
	var total_unit_dmg = 0.0
	for v in GameData.unit_damage.values():
		total_unit_dmg += v
	var total_all_dmg = total_skill_dmg + total_unit_dmg

	# 왼쪽: 스킬 피해량
	var skill_vbox = VBoxContainer.new()
	skill_vbox.add_theme_constant_override("separation", 6)
	stats_hbox.add_child(skill_vbox)

	var skill_title = Label.new()
	skill_title.text = "[ 스킬 피해량 ]"
	skill_title.add_theme_font_size_override("font_size", 18)
	skill_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	skill_vbox.add_child(skill_title)

	var skill_order = ["주먹", "돌멩이", "나무막대", "화염", "화살", "그물"]
	for skill_name in skill_order:
		var dmg = GameData.skill_damage.get(skill_name, 0.0)
		if dmg <= 0:
			continue
		var pct = int(dmg / max(total_all_dmg, 1.0) * 100.0)
		var row = Label.new()
		row.text = skill_name + "   " + str(int(dmg)) + "  (" + str(pct) + "%)"
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		skill_vbox.add_child(row)

	# 오른쪽: 부대 피해량
	var unit_vbox = VBoxContainer.new()
	unit_vbox.add_theme_constant_override("separation", 6)
	stats_hbox.add_child(unit_vbox)

	var unit_title = Label.new()
	unit_title.text = "[ 부대 피해량 ]"
	unit_title.add_theme_font_size_override("font_size", 18)
	unit_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	unit_vbox.add_child(unit_title)

	if GameData.unit_damage.is_empty():
		var no_unit = Label.new()
		no_unit.text = "출전 부대 없음"
		no_unit.add_theme_font_size_override("font_size", 16)
		no_unit.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		unit_vbox.add_child(no_unit)
	else:
		for unit_name in GameData.unit_damage:
			var dmg = GameData.unit_damage[unit_name]
			var pct = int(dmg / max(total_all_dmg, 1.0) * 100.0)
			var row = Label.new()
			row.text = unit_name + "   " + str(int(dmg)) + "  (" + str(pct) + "%)"
			row.add_theme_font_size_override("font_size", 16)
			row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			unit_vbox.add_child(row)
	var retry_btn = Button.new()
	retry_btn.text = "재도전"
	retry_btn.set_anchors_preset(Control.PRESET_CENTER)
	retry_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	retry_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	retry_btn.position = Vector2(-225, 80)
	retry_btn.size = Vector2(135, 60)
	retry_btn.add_theme_font_size_override("font_size", 16)
	retry_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	retry_btn.add_theme_stylebox_override("normal", style.duplicate())
	retry_btn.pressed.connect(_on_retry)
	bg.add_child(retry_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "나가기"
	quit_btn.set_anchors_preset(Control.PRESET_CENTER)
	quit_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	quit_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	quit_btn.position = Vector2(-67, 80)
	quit_btn.size = Vector2(135, 60)
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_btn.add_theme_stylebox_override("normal", style.duplicate())
	quit_btn.pressed.connect(_on_quit)
	bg.add_child(quit_btn)
	
	if not is_final:
		var next_btn = Button.new()
		next_btn.text = "다음단계"
		next_btn.set_anchors_preset(Control.PRESET_CENTER)
		next_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		next_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
		next_btn.position = Vector2(90, 80)
		next_btn.size = Vector2(135, 60)
		next_btn.add_theme_font_size_override("font_size", 16)
		next_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		next_btn.add_theme_stylebox_override("normal", style.duplicate())
		next_btn.pressed.connect(_on_next_stage)
		bg.add_child(next_btn)

func _on_retry() -> void:
	get_tree().paused = false
	GameData.enemies_killed = 0
	GameData.stage_xp_pending = 0
	
	# 스테이지별 배경 이미지
	var bg_path = ""
	if GameData.current_stage <= 15:
		bg_path = "res://배경_평원.png"
	elif GameData.current_stage <= 30:
		bg_path = "res://배경_냇가.png"
	elif GameData.current_stage <= 45:
		bg_path = "res://배경_동굴.png"
	elif GameData.current_stage <= 60:
		bg_path = "res://배경_검은모루.png"
	elif GameData.current_stage <= 75:
		bg_path = "res://배경_미송리.png"
	elif GameData.current_stage <= 85:
		bg_path = "res://배경_열수.png"
	elif GameData.current_stage <= 95:
		bg_path = "res://배경_신단수.png"
	elif GameData.current_stage <= 105:
		bg_path = "res://배경_아사달.png"
	elif GameData.current_stage <= 115:
		bg_path = "res://배경_왕검성.png"
	elif GameData.current_stage <= 125:
		bg_path = "res://배경_북방산악지대.png"
	elif GameData.current_stage <= 135:
		bg_path = "res://배경_교역로.png"
	elif GameData.current_stage <= 145:
		bg_path = "res://배경_왕검성상업지대.png"
	elif GameData.current_stage <= 155:
		bg_path = "res://배경_패수도하방어전.png"
	elif GameData.current_stage <= 165:
		bg_path = "res://배경_협곡매복작전.png"
	elif GameData.current_stage <= 175:
		bg_path = "res://배경_왕검성공성전.png"
	
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var bg_img = Sprite2D.new()
		bg_img.texture = load(bg_path)
		bg_img.centered = false
		bg_img.position = Vector2(0, 0)
		bg_img.z_index = -10
		var tex_size = bg_img.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			bg_img.scale = Vector2(1296.0 / tex_size.x, 1152.0 / tex_size.y)
		add_child(bg_img)
	GameData.save_game()
	for node in get_tree().get_nodes_in_group("clear_bg"):
		node.queue_free()
	var canvas = get_tree().root.get_node_or_null("ClearBG")
	if canvas:
		canvas.queue_free()
	get_tree().reload_current_scene()

func _on_next_stage() -> void:
	get_tree().paused = false
	# 시대별 최대 스테이지 제한
	var max_stage = 45
	if GameData.current_era >= 1: max_stage = 85
	if GameData.current_era >= 2: max_stage = 155
	if GameData.current_era >= 3: max_stage = 155

	if GameData.current_stage >= max_stage:
		# 마지막 스테이지 - 로비로 이동
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		return

	GameData.current_stage += 1
	GameData.current_level = 1
	GameData.enemies_killed = 0
	GameData.stage_xp_pending = 0
	GameData.skill_damage = {}
	GameData.unit_damage = {}
	GameData.save_game()
	for node in get_tree().get_nodes_in_group("clear_bg"):
		node.queue_free()
	var canvas = get_tree().root.get_node_or_null("ClearBG")
	if canvas:
		canvas.queue_free()
	get_tree().reload_current_scene()

func _on_quit() -> void:
	get_tree().paused = false
	for node in get_tree().get_nodes_in_group("clear_bg"):
		node.queue_free()
	var canvas = get_tree().root.get_node_or_null("ClearBG")
	if canvas:
		canvas.queue_free()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_upgrade_chosen() -> void:
	await get_tree().process_frame
	wave_manager.reset()


func _get_unit_base_pct(unit_name: String) -> int:
	match unit_name:
		"돌멩이병": return 80
		"죽창병":   return 150
		"돌도끼병": return 120
		"돌칼병":   return 130
		"활병":     return 140
		"돌창병":   return 110
		"청동검병": return 160
		"청동활병": return 170
		"청동창병": return 150
		"기마병":   return 200
	return 100


func _on_unit_attack() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var all_units = [
		{"name": "돌멩이병", "base_dmg_pct": 70},
		{"name": "죽창병",   "base_dmg_pct": 130},
		{"name": "돌도끼병", "base_dmg_pct": 160},
		{"name": "돌칼병",   "base_dmg_pct": 160},
		{"name": "활병",     "base_dmg_pct": 0},
		{"name": "돌창병",   "base_dmg_pct": 160},
		{"name": "청동검병", "base_dmg_pct": 190},
		{"name": "청동활병", "base_dmg_pct": 190},
		{"name": "청동창병", "base_dmg_pct": 190},
		{"name": "기마병",   "base_dmg_pct": 190},
	]
	var attacked_enemies = []
	var all_enemies_sorted = get_tree().get_nodes_in_group("enemies")
	all_enemies_sorted.sort_custom(func(a, b):
		return player.global_position.distance_to(a.global_position) < player.global_position.distance_to(b.global_position)
	)
	for u in all_units:
		# 부대별 사거리 설정
		var unit_range = 160.0
		if u["name"] in ["돌멩이병", "활병"]:
			unit_range = 320.0

		var enemies = []
		for e in all_enemies_sorted:
			if is_instance_valid(e) and player.global_position.distance_to(e.global_position) <= unit_range:
				enemies.append(e)
		var ud = GameData.get_unit(u["name"])
		if not ud.get("deployed", false):
			continue
		var population = int(ud.get("population", 1))
		var dmg_lv = int(ud.get("damage_lv", 0))
		var total_pct = u["base_dmg_pct"] + dmg_lv * 10
		var damage = GameData.get_total_attack() * float(total_pct) / 100.0

		var valid_enemies = []
		for e in enemies:
			if is_instance_valid(e) and not e in attacked_enemies:
				valid_enemies.append(e)

		if valid_enemies.is_empty():
			if enemies.size() > 0 and is_instance_valid(enemies[0]):
				for _i in range(population):
					if is_instance_valid(enemies[0]) and enemies[0].has_method("take_damage"):
						if u["name"] == "활병":
							_unit_archer_extra_shots(enemies[0], GameData.get_total_attack() * 0.8)
							_show_unit_attack_effect(u["name"], enemies[0].global_position)
							continue
						enemies[0].take_damage(damage)
						_show_unit_attack_effect(u["name"], enemies[0].global_position)
						GameData.unit_damage[u["name"]] = GameData.unit_damage.get(u["name"], 0.0) + damage
		else:
			var count = 0
			while count < population:
				if valid_enemies.is_empty():
					break
				var e = valid_enemies[count % valid_enemies.size()]
				if is_instance_valid(e) and e.has_method("take_damage"):
					if u["name"] == "활병":
						_unit_archer_extra_shots(e, GameData.get_total_attack() * 0.8)
						_show_unit_attack_effect(u["name"], e.global_position)
						if not e in attacked_enemies:
							attacked_enemies.append(e)
						count += 1
						continue

					e.take_damage(damage)
					_show_unit_attack_effect(u["name"], e.global_position)
					GameData.unit_damage[u["name"]] = GameData.unit_damage.get(u["name"], 0.0) + damage

					if u["name"] == "돌멩이병":
						var splash_range = 32.0
						var all_e = get_tree().get_nodes_in_group("enemies")
						for nearby in all_e:
							if is_instance_valid(nearby) and nearby != e:
								if e.global_position.distance_to(nearby.global_position) <= splash_range:
									nearby.take_damage(damage * 0.5)
					elif u["name"] == "돌칼병":
						if e.has_method("apply_burn"):
							e.apply_burn(GameData.get_total_attack() * 0.2, 5, false, 0, false)
							e.modulate = Color(1.0, 0.4, 0.4)
							var burn_visual_timer = get_tree().create_timer(0.5 * 5)
							burn_visual_timer.timeout.connect(func():
								if is_instance_valid(e):
									e.modulate = Color(1.0, 1.0, 1.0)
							)
					elif u["name"] == "돌창병":
						_unit_apply_vulnerable(e, 5.0, 0.5)
					elif u["name"] == "돌도끼병":
						_unit_apply_stun(e, 2.0)

					if not e in attacked_enemies:
						attacked_enemies.append(e)
				count += 1

func _find_nearest_enemy(from_pos: Vector2) -> Node:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var dist = from_pos.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = e
	return nearest

func _show_unit_attack_effect(unit_name: String, pos: Vector2) -> void:
	var img_path = "res://" + unit_name + "_공격.png"
	if not ResourceLoader.exists(img_path):
		return

	var effect = TextureRect.new()
	effect.texture = load(img_path)
	effect.custom_minimum_size = Vector2(40, 40)
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.position = pos - Vector2(32, 32)
	effect.z_index = 20
	effect.add_to_group("effects")
	get_parent().add_child(effect)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "position:y", effect.position.y - 30, 0.5)
	tween.tween_property(effect, "modulate:a", 0.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)

# ── 활병: 작은 화살 2개 추가 발사 ──
func _unit_archer_extra_shots(target: Node2D, dmg: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not is_instance_valid(target):
		return
	for i in range(2):
		var small_arrow = Sprite2D.new()
		if ResourceLoader.exists("res://활병_공격.png"):
			small_arrow.texture = load("res://활병_공격.png")
		elif ResourceLoader.exists("res://화살.png"):
			small_arrow.texture = load("res://화살.png")
		small_arrow.scale = Vector2(0.4, 0.4)
		small_arrow.global_position = player.global_position
		var direction = (target.global_position - player.global_position).normalized()
		small_arrow.rotation = direction.angle()
		small_arrow.z_index = 5
		get_parent().add_child(small_arrow)

		var tween = get_tree().create_tween()
		tween.tween_property(small_arrow, "global_position", target.global_position, 0.25)
		tween.tween_callback(func():
			if is_instance_valid(target):
				target.take_damage(dmg)
				GameData.unit_damage["활병"] = GameData.unit_damage.get("활병", 0.0) + dmg
			if is_instance_valid(small_arrow):
				small_arrow.queue_free()
		)

# ── 창병: 받는 피해 증가 디버프 ──
func _unit_apply_vulnerable(target: Node2D, duration: float, increase_ratio: float) -> void:
	if not is_instance_valid(target):
		return
	target.set_meta("vulnerable_multiplier", 1.0 + increase_ratio)
	target.modulate = Color(1.0, 0.4, 0.4)

	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(target):
			target.set_meta("vulnerable_multiplier", 1.0)
			target.modulate = Color(1.0, 1.0, 1.0)
	)

func _unit_apply_stun(target: Node2D, duration: float) -> void:
	if not is_instance_valid(target):
		return
	if "move_speed" in target and "original_speed" in target:
		if not target.has_meta("is_stunned"):
			target.set_meta("is_stunned", false)
		if not target.get_meta("is_stunned"):
			target.set_meta("is_stunned", true)
			target.move_speed = 0.0
			var timer = get_tree().create_timer(duration)
			timer.timeout.connect(func():
				if is_instance_valid(target):
					target.move_speed = target.original_speed
					target.set_meta("is_stunned", false)
			)

func _start_story_chapter1() -> void:
	GameData.story_card_filter = "early"
	# 1단계: 습격 대사
	_show_story_dialog([
		"사방에서 굶주린 늑대들의 눈빛이 번뜩인다.",
		"손에 쥔 것은 낡은 막대기 하나와 거친 돌멩이뿐.",
		"어둠이 우리를 삼키려 한다. 살기 위해서는 싸워야 한다."
	], func():
		_start_stage_sequence(1, 3, _on_stage3_complete)
	)

func _show_lightning_event() -> void:
	# 번개+화재 이펙트
	_play_lightning_vfx()
	_show_story_dialog([
		"그때, 하늘이 찢어지듯 벼락이 내리꽂혔다.",
		"신단수(神壇樹)에 붉은 꽃이 피어난다.",
		"타오르는 저것은... 너무 뜨겁다.. 저걸 사용할 수 있다면..."
	], _show_awakening_scene)

func _show_awakening_scene() -> void:
	# 배경을 화염 각성(손) 이미지로 교체 (648x1152, 화면 중앙에 1:1 표시)
	var awaken_bg_path = "res://화염_각성.png"
	var screen = get_viewport().get_visible_rect().size
	if ResourceLoader.exists(awaken_bg_path):
		for node in get_children():
			if node is Sprite2D and node.z_index == -10:
				node.texture = load(awaken_bg_path)
				var tex_size = node.texture.get_size()
				node.scale = Vector2(1.0, 1.0)
				node.position = Vector2((screen.x - tex_size.x) / 2.0, (screen.y - tex_size.y) / 2.0)
				break

	# 캐릭터를 화면 중앙으로 이동
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.global_position = Vector2(screen.x / 2.0, screen.y / 2.0)

	_show_story_dialog([
		"불꽃을 쥔 손에서 뜨거운 갈망이 느껴진다.",
		"더 이상 도망치지 않는다. 이제 어둠이 우리를 두려워할 차례다.",
		"화염(火焰)의 힘이 깨어났다!"
	], _unlock_flame)

func _unlock_flame() -> void:
	# 잔여 오버레이 정리 (남아있는 페이드/캔버스 제거)
	for child in get_children():
		if child is CanvasLayer and child.layer >= 40:
			child.queue_free()

	# 배경을 화염 전투용으로 교체
	var flame_bg_path = "res://배경_스토리평원_화염.png"
	if ResourceLoader.exists(flame_bg_path):
		for node in get_children():
			if node is Sprite2D and node.z_index == -10:
				node.texture = load(flame_bg_path)
				var tex_size = node.texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					node.scale = Vector2(1296.0 / tex_size.x, 1152.0 / tex_size.y)
				break

	GameData.story_card_filter = "flame_unlock_only"
	_show_skill_acquired_popup("화염", func():
		_start_stage_sequence(4, 10, _on_chapter1_complete)
	)

func _on_chapter1_complete() -> void:
	_show_story_dialog([
		"불꽃은 이제 나의 의지이자, 부족을 지키는 등불이 되었다.",
		"우리는 평원의 주인이다.",
		"[화염] 기술을 완벽하게 습득했다!"
	], func():
		_show_skill_complete_popup("화염", "res://4. 불.png", func():
			GameData.story_cleared["1"] = true
			GameData.story_card_filter = ""
			GameData.save_game()
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		)
	)
	
func _show_story_dialog(lines: Array, on_complete: Callable) -> void:
	var screen = get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.layer = 50
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# 대화창 배경
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.position = Vector2(0, screen.y - 180)
	bg.size = Vector2(screen.x, 180)
	canvas.add_child(bg)

	# 대사 텍스트
	var label = Label.new()
	label.position = Vector2(30, 30)
	label.size = Vector2(screen.x - 60, 120)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.add_child(label)

	# 안내 텍스트 (터치하라는 표시)
	var hint = Label.new()
	hint.text = "▼ 터치하여 계속"
	hint.position = Vector2(screen.x - 160, 150)
	hint.size = Vector2(140, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	bg.add_child(hint)

	var idx_box = [0]
	label.text = lines[idx_box[0]]

	# 전체화면 터치 감지 (Control + gui_input)
	var touch_area = Control.new()
	touch_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_area.process_mode = Node.PROCESS_MODE_ALWAYS
	touch_area.z_index = 100
	touch_area.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			idx_box[0] += 1
			if idx_box[0] < lines.size():
				label.text = lines[idx_box[0]]
			else:
				canvas.queue_free()
				on_complete.call()
	)
	canvas.add_child(touch_area)

var _story_sequence_end: int = -1
var _story_sequence_callback: Callable

func _start_stage_sequence(start_level: int, end_level: int, on_complete: Callable) -> void:
	GameData.current_stage = 1
	GameData.current_level = start_level
	if start_level == 1:
		GameData.enemies_killed = 0
		GameData.stage_xp_pending = 0
		GameData.skill_damage = {}
		GameData.unit_damage = {}

	_story_sequence_end = end_level
	_story_sequence_callback = on_complete

	# 전투 시작
	wave_manager.set_process(true)
	wave_manager.reset()
	upgrade_ui.show_upgrades()

func _force_defeat() -> void:
	wave_manager.set_process(false)
	get_tree().paused = false

	# 화면 어둡게 페이드
	var canvas = CanvasLayer.new()
	canvas.layer = 40
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)

	var tween = create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 0.85), 1.0)

	# 적들 제거 (화면 정리)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()	

func _play_lightning_vfx() -> void:
	# 화면 플래시
	var canvas = CanvasLayer.new()
	canvas.layer = 41
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 1.0, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.4)
	tween.tween_callback(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
	)

	# 배경 이미지를 번개 맞은 버전으로 교체
	var lightning_bg_path = "res://배경_스토리평원_번개.png"
	if ResourceLoader.exists(lightning_bg_path):
		for node in get_children():
			if node is Sprite2D and node.z_index == -10:
				node.texture = load(lightning_bg_path)
				break

func _show_skill_acquired_popup(skill_name: String, on_complete: Callable) -> void:
	var screen = get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.layer = 45
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = Vector2(0, 0)
	bg.size = screen
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(0, 0)
	vbox.size = screen
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(vbox)

	var title = Label.new()
	title.text = "새로운 기술을 습득하였습니다."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title)

	var skill_lbl = Label.new()
	skill_lbl.text = "[" + skill_name + "] 기술을 사용하여 적들을 물리치세요"
	skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_lbl.add_theme_font_size_override("font_size", 26)
	skill_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	skill_lbl.add_theme_color_override("font_outline_color", Color(0,0,0))
	skill_lbl.add_theme_constant_override("outline_size", 3)
	vbox.add_child(skill_lbl)

	var hint = Label.new()
	hint.text = "▼ 터치하여 계속"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	vbox.add_child(hint)

	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			canvas.queue_free()
			var defeat_fade = get_node_or_null("DefeatFadeCanvas")
			if is_instance_valid(defeat_fade):
				defeat_fade.queue_free()
			on_complete.call()
	)

func _show_skill_complete_popup(skill_name: String, skill_img: String, on_complete: Callable) -> void:
	var screen = get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.layer = 45
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = Vector2(0, 0)
	bg.size = screen
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(0, 0)
	vbox.size = screen
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(vbox)

	# 이미지
	if skill_img != "" and ResourceLoader.exists(skill_img):
		var img_bg = PanelContainer.new()
		img_bg.custom_minimum_size = Vector2(100, 100)
		img_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var img_st = StyleBoxFlat.new()
		img_st.bg_color = Color(0.30, 0.20, 0.08)
		img_st.border_color = Color(1.0, 0.6, 0.2)
		img_st.border_width_top    = 3
		img_st.border_width_bottom = 3
		img_st.border_width_left   = 3
		img_st.border_width_right  = 3
		img_st.corner_radius_top_left     = 12
		img_st.corner_radius_top_right    = 12
		img_st.corner_radius_bottom_left  = 12
		img_st.corner_radius_bottom_right = 12
		img_bg.add_theme_stylebox_override("panel", img_st)
		vbox.add_child(img_bg)

		var tex = TextureRect.new()
		tex.texture = load(skill_img)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_bg.add_child(tex)

	# 텍스트
	var title = Label.new()
	title.text = "새로운 기술 [" + skill_name + "]을 습득하였습니다"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0,0,0))
	title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title)

	var hint = Label.new()
	hint.text = "▼ 터치하여 계속"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	vbox.add_child(hint)

	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			canvas.queue_free()
			on_complete.call()
	)

func _show_chat_dialog(lines: Array, on_complete: Callable) -> void:
	var screen = get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.layer = 50
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.position = Vector2(0, screen.y - 200)
	bg.size = Vector2(screen.x, 200)
	canvas.add_child(bg)

	# 캐릭터 이미지 영역 (왼쪽: 내 캐릭터, 오른쪽: 신석기인 3명)
	var char_size = 110.0

	var my_char = TextureRect.new()
	my_char.position = Vector2(10, 10)
	my_char.size = Vector2(char_size, char_size)
	my_char.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	my_char.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists("res://char_0.png"):
		my_char.texture = load("res://char_0.png")
	bg.add_child(my_char)
	my_char.visible = false

	# 신석기인 3명 겹친 이미지 (오른쪽)
	var npc_group = Control.new()
	npc_group.position = Vector2(screen.x - 190, 0)
	npc_group.size = Vector2(180, 200)
	bg.add_child(npc_group)
	npc_group.visible = false

	var npc_imgs = ["res://스토리3_1.png", "res://스토리3_2.png", "res://스토리3_3.png"]
	var npc_offsets = [Vector2(0, 8), Vector2(45, 0), Vector2(90, 8)]
	for i in range(npc_imgs.size()):
		if ResourceLoader.exists(npc_imgs[i]):
			var npc_tex = TextureRect.new()
			npc_tex.texture = load(npc_imgs[i])
			npc_tex.position = npc_offsets[i]
			npc_tex.size = Vector2(131, 192) * 0.6
			npc_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			npc_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			npc_tex.z_index = i
			npc_group.add_child(npc_tex)

	# 대사 텍스트
	var label = Label.new()
	label.position = Vector2(30, 30)
	label.size = Vector2(screen.x - 60, 120)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bg.add_child(label)

	var hint = Label.new()
	hint.text = "▼ 터치하여 계속"
	hint.position = Vector2(screen.x - 160, 170)
	hint.size = Vector2(140, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	bg.add_child(hint)

	var idx_box = [0]

	var update_line = func():
		var line = lines[idx_box[0]]
		var speaker = line["speaker"]
		var text = line["text"]

		if speaker == "me":
			my_char.visible = true
			npc_group.visible = false
			label.position = Vector2(char_size + 30, 30)
			label.size = Vector2(screen.x - char_size - 60, 120)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		else:
			my_char.visible = false
			npc_group.visible = true
			label.position = Vector2(30, 30)
			label.size = Vector2(screen.x - 220, 120)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		label.text = text

	update_line.call()

	var touch_area = Control.new()
	touch_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_area.process_mode = Node.PROCESS_MODE_ALWAYS
	touch_area.z_index = 100
	var completed = [false]
	touch_area.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			idx_box[0] += 1
			if idx_box[0] < lines.size():
				update_line.call()
			else:
				if not completed[0]:
					completed[0] = true
					canvas.queue_free()
					on_complete.call()
	)
	canvas.add_child(touch_area)

func _start_story_chapter3() -> void:
	GameData.story_card_filter = "early"
	_show_story_dialog([
		"땅에 씨앗을 뿌리고 잘 자라면 좋은 식량이 되더라구.",
		"그러면 우리는 사냥에 실패해도 배고프지 않아도 돼!",
		"그런데 저 멧돼지들.. 정말 끈질기네.",
		"돌멩이, 막대기만으로는 도저히 감당이 안되는데.. 어떡하지?"
	], func():
		_start_stage_sequence(1, 3, _on_stage3_complete)
	)

func _on_stage3_complete() -> void:
	_force_defeat()
	_show_chat_dialog([
		{"speaker": "npc", "text": "이보시오. 우리는 옆 마을에서 온 사람들이오."},
		{"speaker": "npc", "text": "당신들도 씨앗을 뿌리고 있구려. 근데 왜 이렇게 작물이 적소?"},
		{"speaker": "me", "text": "멧돼지들이 자꾸 와서 애써 키워놓은 작물을 다 뺏어먹고 있어서 저희도 고민이 이만저만이 아니에요"},
		{"speaker": "npc", "text": "그럼 한번 이걸 써 보시오. 연습만 충분히 한다면 저깟 멧돼지 따위 아무것도 아닐 거요."},
		{"speaker": "me", "text": "이건.. 어떻게 사용하는 거지..?"}
	], _unlock_arrow)

func _unlock_arrow() -> void:
	# 잔여 오버레이 정리
	for child in get_children():
		if child is CanvasLayer and child.layer >= 40:
			child.queue_free()

	GameData.story_card_filter = "arrow_unlock_only"
	_show_skill_acquired_popup("화살", func():
		_start_stage_sequence(4, 10, _on_chapter3_complete)
	)

func _on_chapter3_complete() -> void:
	_show_story_dialog([
		"이제 이 활과 화살로 멧돼지들을 막아낼 수 있겠어.",
		"농사도 사냥도, 화살이 있으니 두렵지 않다.",
		"화살의 기술을 완벽하게 습득했다!"
	], func():
		_show_skill_complete_popup("화살", "res://화살.png", func():
			GameData.story_cleared["3"] = true
			GameData.story_card_filter = ""
			GameData.save_game()
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		)
	)
