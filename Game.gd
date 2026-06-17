extends Node2D
@onready var wave_manager = $WaveManager
@onready var upgrade_ui = $UI/UpgradeUI


func _ready() -> void:
	Engine.time_scale = 1.0
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
	
	# 배경 이미지
	# 배경 이미지
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
	
	GameData.player_max_hp = GameData.get_level_max_hp()
	GameData.player_attack = GameData.get_level_base_attack()
	GameData.connect("level_up", _on_char_level_up)
	upgrade_ui.hide()
	upgrade_ui.connect("upgrade_chosen", _on_upgrade_chosen)

	GameData.stage_xp_pending_mult = 1.0
	GameData.reward_bonus_mult = 1.0
	_roll_stage_modifier()
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_stage_modifier()

	# wave_manager 일시 정지 후 연결
	wave_manager.set_process(false)
	wave_manager.connect("stage_clear", _on_stage_clear)
	_resource_spawn_done = false
	_schedule_resource_spawn()
	upgrade_ui.show_upgrades()

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

var _bonus_food: int = 0
var _bonus_wood: int = 0
var _resource_spawn_done: bool = false

func _on_stage_clear() -> void:
	for node in get_tree().get_nodes_in_group("effects"):
		node.queue_free()
	
	if GameData.current_level >= GameData.max_level:
		# 10단계 완료 → 경험치 + 재화 지급
		var clear_xp = int(GameData.get_stage_clear_xp(GameData.current_stage) * GameData.stage_xp_pending_mult)
		GameData.stage_xp_pending = 0
		GameData.total_xp += clear_xp
		GameData.apply_stage_xp()
		var reward = int((100 + (50 * (GameData.current_stage - 1))) * GameData.reward_bonus_mult)
		GameData.food += reward + _bonus_food
		GameData.wood += reward + _bonus_wood
		GameData.stone += int(reward * 0.1)
		_bonus_food = 0
		_bonus_wood = 0
		GameData.record_stage_clear(GameData.current_stage, GameData.enemies_killed)
		GameData.save_game()
		show_clear_screen(false)
		return
	
	GameData.current_level += 1
	_resource_spawn_done = false
	_schedule_resource_spawn()
	var boss_wm = get_tree().get_first_node_in_group("wave_manager")
	if boss_wm:
		boss_wm.boss_spawned = false
	if GameData.current_stage >= 11 and GameData.current_level >= 6:
		var wm = get_tree().get_first_node_in_group("wave_manager")
		if wm:
			wm._spawn_health_item()
	upgrade_ui.show_upgrades()

func _schedule_resource_spawn() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	if _resource_spawn_done:
		return
	_resource_spawn_done = true
	_spawn_stage_resources()

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
	# 배경 이미지
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
	var max_stage = 60
	if GameData.current_era >= 1: max_stage = 120
	if GameData.current_era >= 2: max_stage = 300
	if GameData.current_era >= 3: max_stage = 999

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
	wave_manager.set_process(true)
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
						e.set_meta("vulnerable_multiplier", 1.5)
						var svt = get_tree().create_timer(5.0)
						svt.timeout.connect(func():
							if is_instance_valid(e):
								e.set_meta("vulnerable_multiplier", 1.0)
						)
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

# ── 스테이지 모디파이어 ──
const MODIFIER_NAMES = [
	"근접 공격 피해",      # 0
	"원거리 공격 피해",    # 1
	"밀려남 효과",         # 2
	"경직 시간",           # 3
	"피해 지속 횟수",      # 4
	"공격 거리",           # 5
	"공격 범위",           # 6
]
const BUFF_ONLY_NAMES = [
	"경험치 획득",         # 7
	"재화 획득",           # 8
]

func _roll_stage_modifier() -> void:
	# 불리: 0~6 중 랜덤
	var debuff = randi() % 7
	# 유리: 0~8 중 랜덤, 단 debuff와 같은 번호(0~6) 제외
	var buff_pool = []
	for i in range(9):
		if i != debuff:
			buff_pool.append(i)
	var buff = buff_pool[randi() % buff_pool.size()]
	GameData.stage_modifier_debuff = debuff
	GameData.stage_modifier_buff = buff

func _apply_stage_modifier() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var d = GameData.stage_modifier_debuff
	var b = GameData.stage_modifier_buff

	# 불리 적용 (50% 감소)
	match d:
		0: player.fist_damage           *= 0.5
		1:
			player.stone_damage         *= 0.5
			player.flame_damage         *= 0.5
			player.arrow_damage         *= 0.5
			player.net_damage           *= 0.5
			player.stick_damage         *= 0.5
		2: player.stick_knockback_force *= 0.5
		3: player.stone_cooldown        *= 1.5  # 경직시간 없으므로 돌멩이 쿨타임 증가로 대체
		4:
			player.flame_dot_ticks      = max(1, int(player.flame_dot_ticks * 0.5))
			player.net_duration         *= 0.5
		5:
			player.stone_range          *= 0.5
			player.stick_range          *= 0.5
			player.flame_range          *= 0.5
			player.arrow_distance       *= 0.5
			player.net_range            *= 0.5
		6:
			player.stick_knockback_radius *= 0.5
			player.flame_range          *= 0.5
			player.net_range            *= 0.5

	match b:
		0: player.fist_damage           *= 1.5
		1:
			player.stone_damage         *= 1.5
			player.flame_damage         *= 1.5
			player.arrow_damage         *= 1.5
			player.net_damage           *= 1.5
			player.stick_damage         *= 1.5
		2: player.stick_knockback_force *= 1.5
		3: player.stone_cooldown        *= 0.67  # 경직시간 없으므로 돌멩이 쿨타임 감소로 대체
		4:
			player.flame_dot_ticks      = int(player.flame_dot_ticks * 1.5)
			player.net_duration         *= 1.5
		5:
			player.stone_range          *= 1.5
			player.stick_range          *= 1.5
			player.flame_range          *= 1.5
			player.arrow_distance       *= 1.5
			player.net_range            *= 1.5
		6:
			player.stick_knockback_radius *= 1.5
			player.flame_range          *= 1.5
			player.net_range            *= 1.5
		7: GameData.stage_xp_pending_mult = 1.5
		8: GameData.reward_bonus_mult = 1.5

func _spawn_stage_resources() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var reward = 100 + (50 * (GameData.current_stage - 1))
	var bonus_per_item = max(1, int(reward * 0.01))

	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 80.0

	# 식량 2개, 목재 1개 랜덤 위치에 스폰
	var items = [
		{"type": "food", "img": "res://식량.png", "color": Color(0.3, 0.9, 0.3)},
		{"type": "food", "img": "res://식량.png", "color": Color(0.3, 0.9, 0.3)},
		{"type": "wood", "img": "res://목재.png", "color": Color(0.9, 0.6, 0.2)},
	]
	items.shuffle()

	for item in items:
		var pos = Vector2(
			randf_range(margin, viewport_size.x - margin),
			randf_range(margin, viewport_size.y - margin)
		)
		_create_resource_item(item["type"], item["img"], item["color"], bonus_per_item, pos)

func _create_resource_item(type: String, img_path: String, color: Color, amount: int, spawn_pos: Vector2) -> void:
	var item_node = Node2D.new()
	item_node.name = "ResourceItem"
	item_node.global_position = spawn_pos
	item_node.z_index = 10

	# 이미지
	var sprite = Sprite2D.new()
	if ResourceLoader.exists(img_path):
		sprite.texture = load(img_path)
	sprite.scale = Vector2(0.08, 0.08)
	item_node.add_child(sprite)

	# 반짝임 효과
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.4, 0.5)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.5)

	# 충돌 감지 타이머
	var collected = [false]
	var check_timer = Timer.new()
	check_timer.wait_time = 0.1
	check_timer.autostart = true
	check_timer.timeout.connect(func():
		if not is_instance_valid(item_node) or collected[0]:
			return
		var player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return
		if item_node.global_position.distance_to(player.global_position) <= 80.0:
			collected[0] = true
			if type == "food":
				GameData.food += amount
				_bonus_food += amount
			else:
				GameData.wood += amount
				_bonus_wood += amount
			_show_resource_pickup_effect(img_path, amount, item_node.global_position)
			tween.kill()
			item_node.queue_free()
	)
	item_node.add_child(check_timer)

	# 30초 후 자동 제거 (다음 단계 전에)
	var auto_remove = Timer.new()
	auto_remove.wait_time = 19.0
	auto_remove.autostart = true
	auto_remove.one_shot = true
	auto_remove.timeout.connect(func():
		if is_instance_valid(item_node) and not collected[0]:
			tween.kill()
			item_node.queue_free()
	)
	item_node.add_child(auto_remove)

	add_child(item_node)

func _show_resource_pickup_effect(img_path: String, amount: int, pos: Vector2) -> void:
	var screen = get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var player = get_tree().get_first_node_in_group("player")
	var show_pos = Vector2(screen.x / 2.0 - 60, screen.y / 2.0 - 100)
	if is_instance_valid(player):
		show_pos = player.global_position - Vector2(30, 80)
	var hbox = HBoxContainer.new()
	hbox.position = show_pos
	hbox.add_theme_constant_override("separation", 6)
	canvas.add_child(hbox)

	if ResourceLoader.exists(img_path):
		var icon = TextureRect.new()
		icon.texture = load(img_path)
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hbox.add_child(icon)

	var lbl = Label.new()
	lbl.text = "x" + str(amount)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	hbox.add_child(lbl)

	var tw = create_tween()
	tw.tween_property(hbox, "position:y", hbox.position.y - 60, 1.2)
	tw.parallel().tween_property(hbox, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.tween_callback(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
	)
