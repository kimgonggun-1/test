extends Node2D
@onready var wave_manager = $WaveManager
@onready var upgrade_ui = $UI/UpgradeUI

var story_chapter: int = 0
var story_cleared: Dictionary = {}

var _boss_ref: Node = null

func _start_story_chapter2() -> void:
	_spawn_chapter2_boss()

func _spawn_chapter2_boss() -> void:
	GameData.current_stage = 30  # 30스테이지 스펙 적용
	wave_manager.set_process(false)
	get_tree().paused = false

	# HUD 상단 표시(스테이지/타이머/적수) 숨기기
	for hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(hud):
			hud.visible = false

	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var boss = wave_manager.rat_scene.instantiate()
	var sprite = boss.get_node("Sprite2D")
	if ResourceLoader.exists("res://enemies_3/아사달멧돼지2.png"):
		sprite.texture = load("res://enemies_3/아사달멧돼지2.png")
	sprite.scale = Vector2(2.0, 2.0)

	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * 100.0
	boss.global_position = player.global_position + offset
	get_parent().add_child(boss)
	boss.add_to_group("story_boss")

	await get_tree().process_frame
	if is_instance_valid(boss):
		var base_hp = 10.0 * pow(1.1, 29)  # 30스테이지 기준
		boss.max_hp = base_hp * 50.0
		boss.hp = boss.max_hp
		boss.attack_damage = 8.0
		boss.set_meta("story_invincible", true)
		if is_instance_valid(boss.get_node_or_null("HPBar")):
			boss.get_node("HPBar").max_value = boss.max_hp
			boss.get_node("HPBar").value = boss.max_hp

	_boss_ref = boss

	await get_tree().create_timer(20.0, true, false, false).timeout
	_on_boss_intro_timeout()

func _on_boss_intro_timeout() -> void:
	get_tree().paused = true
	_show_story_dialog([
		"멧돼지 한 마리를 쫓는 일도 목숨을 건 사투다.",
		"혼자 던지는 돌멩이로는 녀석의 가죽을 뚫을 수 없다.",
		"짐승은 날 비웃듯 숲으로 사라진다. 내 배고픔은 그치지 않는다.",
		"사냥도 제대로 못하고 오늘 아무 것도 못 먹었는데.. 언제까지 이렇게 굶주림과 싸워야 하지?",
		"함께 싸울 사람이 필요해."
	], _on_intro_dialog_complete)

func _on_intro_dialog_complete() -> void:
	get_tree().paused = false
	# 보스를 화면에서 제거
	if is_instance_valid(_boss_ref):
		_boss_ref.queue_free()
	_start_tutorial()

func _ready() -> void:
	Engine.time_scale = 1.0
	GameData.story_chapter = 2
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
	
	# 배경 이미지 (챕터2: 냇가20 = 40스테이지)
	var bg_path = "res://배경_냇가.png"
	
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
	_start_story_chapter2()

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

	# 스토리: 화염 해금(4단계) 후 5단계부터는 화염 강화카드만
	if GameData.story_card_filter == "flame_unlock_only" and GameData.current_level >= 5:
		GameData.story_card_filter = "flame_only"

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
	var completed = [false]
	touch_area.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			idx_box[0] += 1
			if idx_box[0] < lines.size():
				label.text = lines[idx_box[0]]
			else:
				if not completed[0]:
					completed[0] = true
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

	var popup_done = [false]
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and not popup_done[0]:
			popup_done[0] = true
			canvas.queue_free()
			on_complete.call()
	)

# ── 튜토리얼 공통 헬퍼 ──

# 화면 전체를 가리는 오버레이 + 지정 영역만 클릭 가능 + 그 영역에 깜빡이는 화살표
func _show_tutorial_highlight(target_rect: Rect2, message: String, on_tap: Callable) -> Dictionary:
	var screen = get_viewport().get_visible_rect().size

	var overlay_canvas = CanvasLayer.new()
	overlay_canvas.layer = 70
	overlay_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_canvas)

	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_canvas.add_child(overlay)

	# 어두운 배경 (전체 차단)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	# 강조 영역(클릭 가능, 내부를 밝게 표시)
	var highlight = Control.new()
	highlight.position = target_rect.position
	highlight.size = target_rect.size
	highlight.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(highlight)

	# 밝은 배경 (어두운 dim을 뚫는 효과)
	var bright_bg = ColorRect.new()
	bright_bg.color = Color(1, 1, 1, 0.25)
	bright_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bright_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.add_child(bright_bg)

	# 테두리 강조 박스
	var border = PanelContainer.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = Color(1.0, 0.9, 0.2)
	border_style.border_width_top    = 4
	border_style.border_width_bottom = 4
	border_style.border_width_left   = 4
	border_style.border_width_right  = 4
	border_style.corner_radius_top_left     = 8
	border_style.corner_radius_top_right    = 8
	border_style.corner_radius_bottom_left  = 8
	border_style.corner_radius_bottom_right = 8
	border.add_theme_stylebox_override("panel", border_style)
	highlight.add_child(border)

	# 깜빡임 애니메이션 (border 노드에 바인딩 → 노드 해제 시 자동 중단)
	var blink_tween = border.create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(border, "modulate:a", 0.3, 0.4)
	blink_tween.tween_property(border, "modulate:a", 1.0, 0.4)

	# 화살표 (강조 영역 위에 표시)
	var arrow = Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", 32)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	arrow.add_theme_color_override("font_outline_color", Color(0,0,0))
	arrow.add_theme_constant_override("outline_size", 3)
	arrow.position = Vector2(target_rect.position.x + target_rect.size.x/2 - 16, target_rect.position.y - 44)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(arrow)

	# 화살표 애니메이션 (arrow 노드에 바인딩 → 노드 해제 시 자동 중단)
	var arrow_tween = arrow.create_tween()
	arrow_tween.set_loops()
	arrow_tween.tween_property(arrow, "position:y", arrow.position.y + 10, 0.4)
	arrow_tween.tween_property(arrow, "position:y", arrow.position.y, 0.4)

	# 상단 안내 팝업 카드
	if message != "":
		var pw = min(screen.x * 0.9, 460.0)
		var msg_card = PanelContainer.new()
		msg_card.position = Vector2((screen.x - pw) / 2.0, 24)
		msg_card.size = Vector2(pw, 0)
		msg_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var msg_style = StyleBoxFlat.new()
		msg_style.bg_color = Color(0.90, 0.82, 0.65)
		msg_style.border_color = Color(0.55, 0.38, 0.18)
		msg_style.border_width_top    = 4
		msg_style.border_width_bottom = 4
		msg_style.border_width_left   = 4
		msg_style.border_width_right  = 4
		msg_style.corner_radius_top_left     = 14
		msg_style.corner_radius_top_right    = 14
		msg_style.corner_radius_bottom_left  = 14
		msg_style.corner_radius_bottom_right = 14
		msg_card.add_theme_stylebox_override("panel", msg_style)
		overlay.add_child(msg_card)

		var msg_margin = MarginContainer.new()
		msg_margin.add_theme_constant_override("margin_left", 18)
		msg_margin.add_theme_constant_override("margin_right", 18)
		msg_margin.add_theme_constant_override("margin_top", 14)
		msg_margin.add_theme_constant_override("margin_bottom", 14)
		msg_card.add_child(msg_margin)

		var msg_lbl = Label.new()
		msg_lbl.text = message
		msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg_lbl.add_theme_font_size_override("font_size", 19)
		msg_lbl.add_theme_color_override("font_color", Color(0.20, 0.10, 0.02))
		msg_margin.add_child(msg_lbl)

	var tapped = [false]
	highlight.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and not tapped[0]:
			tapped[0] = true
			overlay_canvas.queue_free()
			await get_tree().process_frame
			on_tap.call()
	)

	return {"overlay": overlay_canvas, "highlight": highlight}

# ── 튜토리얼 시작 ──
var _tuto_house_lv: int = 0
var _tuto_pop_lv: int = 0
var _tuto_stone_unlocked: bool = false
var _tuto_stone_pop: int = 1
var _tuto_spear_unlocked: bool = false
var _tuto_spear_pop: int = 1
var _tuto_stone_deployed: bool = false
var _tuto_spear_deployed: bool = false

func _start_tutorial() -> void:
	GameData.story_card_filter = ""
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_로비.png")

	var btn_w = screen.x / 6.0
	var manage_rect = Rect2(3 * btn_w, screen.y - 100, btn_w, 100)
	_show_tutorial_highlight(manage_rect, "관리 탭을 선택하세요", func():
		canvas.queue_free()
		_show_tutorial_step2()
	)

# ── 튜토리얼15: 마지막 안내 ──
func _show_final_tutorial_message() -> void:
	_show_story_dialog([
		"이제 모집한 부대들과 함께 멧돼지를 처치하세요!"
	], _start_real_boss_fight)
	
var _real_boss_fight_started: bool = false

func _start_real_boss_fight() -> void:
	if _real_boss_fight_started:
		return
	_real_boss_fight_started = true
	# 튜토리얼에서 진행한 부대 데이터를 실제 GameData에 반영
	GameData.unit_data["돌멩이병"] = {
		"unlocked": _tuto_stone_unlocked,
		"population": _tuto_stone_pop,
		"damage_lv": 0,
		"deployed": _tuto_stone_deployed
	}
	GameData.unit_data["죽창병"] = {
		"unlocked": _tuto_spear_unlocked,
		"population": _tuto_spear_pop,
		"damage_lv": 0,
		"deployed": _tuto_spear_deployed
	}
	GameData.save_game()

	# HUD 재생성 (부대 아이콘 바가 갱신되도록)
	for hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(hud):
			var hud_scene = hud.scene_file_path
			var hud_parent = hud.get_parent()
			hud.queue_free()
			await get_tree().process_frame
			if hud_scene != "":
				var new_hud = load(hud_scene).instantiate()
				hud_parent.add_child(new_hud)

	# 전투 통계 초기화
	GameData.current_stage = 30
	GameData.current_level = 5
	GameData.enemies_killed = 0
	GameData.skill_damage = {}
	GameData.unit_damage = {}

	# 보스 재스폰 (무적 해제)
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var boss = wave_manager.rat_scene.instantiate()
	var sprite = boss.get_node("Sprite2D")
	if ResourceLoader.exists("res://enemies_3/아사달멧돼지2.png"):
		sprite.texture = load("res://enemies_3/아사달멧돼지2.png")
	sprite.scale = Vector2(2.0, 2.0)

	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * 100.0
	boss.global_position = player.global_position + offset
	get_parent().add_child(boss)
	boss.add_to_group("story_boss")

	await get_tree().process_frame
	if is_instance_valid(boss):
		var base_hp = 10.0 * pow(1.1, 29)
		boss.max_hp = base_hp * 50.0
		boss.hp = boss.max_hp
		boss.attack_damage = 8.0
		# story_invincible 설정 안 함 → 무적 해제
		if is_instance_valid(boss.get_node_or_null("HPBar")):
			boss.get_node("HPBar").max_value = boss.max_hp
			boss.get_node("HPBar").value = boss.max_hp

	_boss_ref = boss

	# 보스 처치 감지
	boss.tree_exited.connect(func():
		if is_instance_valid(self):
			_on_real_boss_defeated()
	)

	# 적 자동 스폰은 막되, 시간/타이머는 진행
	wave_manager.set_process(false)
	get_tree().paused = false

var _boss_defeated_handled: bool = false

func _on_real_boss_defeated() -> void:
	if _boss_defeated_handled:
		return
	_boss_defeated_handled = true
	_show_story_dialog([
		"드디어... 멧돼지를 쓰러뜨렸다.",
		"함께라면, 우리는 더 강해질 수 있다.",
		"이제 부대와 함께 부족을 지킬 수 있다."
	], func():
		_show_skill_complete_popup("부대 모집", "res://돌멩이병.png", func():
			GameData.story_cleared["2"] = true
			GameData.story_card_filter = ""
			GameData.save_game()
			get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		)
	)
	
func _show_tutorial_image_bg(img_path: String) -> CanvasLayer:
	var screen = get_viewport().get_visible_rect().size
	var canvas = CanvasLayer.new()
	canvas.layer = 60
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	if ResourceLoader.exists(img_path):
		var img = TextureRect.new()
		img.texture = load(img_path)
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		canvas.add_child(img)
	else:
		var bg = ColorRect.new()
		bg.color = Color(0.5, 0.5, 0.5)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(bg)

	return canvas


func _show_tutorial_step2() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_관리.png")

	var house_rect = Rect2(497, 340, 92, 66)
	_show_tutorial_highlight(house_rect, "주택을 강화하세요", func():
		_tuto_house_lv += 1
		canvas.queue_free()
		_show_tutorial_step3()
	)

# ── 튜토리얼3: 주택 강화 안내 ──
func _show_tutorial_step3() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_관리.png")

	var house_rect = Rect2(497, 340, 92, 66)
	_show_tutorial_highlight(house_rect, "주택을 강화할 때마다 인구수를 2만큼 올릴 수 있습니다. 구석기시대에서는 5단계까지 강화됩니다.", func():
		_tuto_house_lv = 5
		canvas.queue_free()
		_show_tutorial_step4()
	)

# ── 튜토리얼4: 인구수 강화 ──
func _show_tutorial_step4() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_관리.png")

	var pop_rect = Rect2(497, 776, 92, 59)
	_show_tutorial_highlight(pop_rect, "인구수를 10단계까지 강화하세요", func():
		_tuto_pop_lv = 10
		canvas.queue_free()
		_show_tutorial_step5()
	)

# ── 튜토리얼5: 부대 모집 안내 ──
func _show_tutorial_step5() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_관리.png")

	var pop_rect = Rect2(497, 776, 92, 59)
	_show_tutorial_highlight(pop_rect, "이제 인구수만큼 부대를 모집하세요!", func():
		canvas.queue_free()
		_show_tutorial_step6()
	)

# ── 튜토리얼6: 로비 → 부대 탭 ──
func _show_tutorial_step6() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_로비.png")

	var unit_rect = Rect2(216, 1044, 108, 104)
	_show_tutorial_highlight(unit_rect, "부대 탭을 선택하세요", func():
		canvas.queue_free()
		_show_tutorial_step7()
	)

# ── 튜토리얼7: 돌멩이병 선택 ──
func _show_tutorial_step7() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대1.png")

	var slot_rect = Rect2(9, 643, 120, 170)
	_show_tutorial_highlight(slot_rect, "돌멩이병을 선택하세요", func():
		canvas.queue_free()
		_show_tutorial_step8()
	)

# ── 튜토리얼8: 돌멩이병 해금 ──
func _show_tutorial_step8() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대2.png")

	var unlock_rect = Rect2(166, 639, 204, 54)
	_show_tutorial_highlight(unlock_rect, "돌멩이병을 해금하세요", func():
		_tuto_stone_unlocked = true
		canvas.queue_free()
		_show_tutorial_step9()
	)

# ── 튜토리얼9: 돌멩이병 인구수 5명까지 ──
func _show_tutorial_step9() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대3.png")

	var pop_btn_rect = Rect2(375, 564, 113, 43)
	_show_tutorial_highlight(pop_btn_rect, "돌멩이병의 인구수를 5명까지 증가하세요", func():
		_tuto_stone_pop = 5
		canvas.queue_free()
		_show_tutorial_step10()
	)

# ── 튜토리얼10: 죽창병 선택 ──
func _show_tutorial_step10() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대1.png")

	var slot_rect = Rect2(134, 643, 122, 170)
	_show_tutorial_highlight(slot_rect, "죽창병을 선택하세요", func():
		canvas.queue_free()
		_show_tutorial_step11()
	)

# ── 튜토리얼11: 죽창병 해금 ──
func _show_tutorial_step11() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대4.png")

	var unlock_rect = Rect2(166, 639, 204, 54)
	_show_tutorial_highlight(unlock_rect, "죽창병을 해금하세요", func():
		_tuto_spear_unlocked = true
		canvas.queue_free()
		_show_tutorial_step12()
	)

# ── 튜토리얼12: 죽창병 인구수 5명까지 ──
func _show_tutorial_step12() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대5.png")

	var pop_btn_rect = Rect2(375, 564, 113, 43)
	_show_tutorial_highlight(pop_btn_rect, "죽창병의 인구수를 5명까지 증가하세요", func():
		_tuto_spear_pop = 5
		canvas.queue_free()
		_show_tutorial_step13()
	)

# ── 튜토리얼13: 돌멩이병 출전 ──
func _show_tutorial_step13() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대6.png")

	var slot_rect = Rect2(164, 696, 99, 52)
	_show_tutorial_highlight(slot_rect, "돌멩이병을 출전하세요", func():
		_tuto_stone_deployed = true
		canvas.queue_free()
		_show_tutorial_step14()
	)

# ── 튜토리얼14: 죽창병 출전 ──
func _show_tutorial_step14() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대7.png")

	var slot_rect = Rect2(164, 696, 99, 52)
	_show_tutorial_highlight(slot_rect, "죽창병을 출전하세요", func():
		_tuto_spear_deployed = true
		canvas.queue_free()
		_show_tutorial_step15()
	)

# ── 튜토리얼15: 마지막 안내 ──
func _show_tutorial_step15() -> void:
	var screen = get_viewport().get_visible_rect().size
	var canvas = _show_tutorial_image_bg("res://튜토리얼_부대8.png")

	var full_rect = Rect2(0, 0, screen.x, screen.y)
	_show_tutorial_highlight(full_rect, "이제 모집한 부대들과 함께 멧돼지를 처치하세요!", func():
		canvas.queue_free()
		_start_real_boss_fight()
	)
