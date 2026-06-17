extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var completed = GameData.current_level - 1
	if completed > 0:
		var partial_xp = GameData.get_partial_xp(GameData.current_stage, completed)
		GameData.total_xp += partial_xp
		GameData.stage_xp_pending = 0
		GameData.apply_stage_xp()
		var ratio = float(completed) / float(GameData.max_level)
		var base_amount = 100 + (10 * (GameData.current_stage - 1))
		GameData.food += int(base_amount * ratio)
		GameData.wood += int(base_amount * ratio)
		GameData.stone += int(base_amount * ratio * 0.1)
	GameData.save_game()

	var screen = get_viewport().get_visible_rect().size
	var ratio = float(completed) / float(GameData.max_level)
	var base_amount = 100 + (10 * (GameData.current_stage - 1))

	# 배경
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bg)

	# 실패 메시지
	var msg = Label.new()
	msg.text = "전투 실패"
	msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.offset_bottom = -450
	msg.add_theme_font_size_override("font_size", 48)
	msg.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	msg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.add_child(msg)

	# 경험치 획득 표시
	var xp_msg = Label.new()
	var partial_xp_display = GameData.get_partial_xp(GameData.current_stage, completed)
	xp_msg.text = str(GameData.char_level) + "등급  |  경험치 +" + str(partial_xp_display)
	xp_msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_msg.offset_top = -380
	xp_msg.offset_bottom = -380
	xp_msg.add_theme_font_size_override("font_size", 26)
	xp_msg.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	xp_msg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.add_child(xp_msg)

	# 보상 표시
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.offset_top = -150
	hbox.offset_bottom = -50
	hbox.add_theme_constant_override("separation", 40)
	bg.add_child(hbox)

	var wood_box = HBoxContainer.new()
	var wood_img = TextureRect.new()
	wood_img.texture = load("res://목재.png")
	wood_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wood_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wood_img.custom_minimum_size = Vector2(60, 60)
	var wood_label = Label.new()
	wood_label.text = "x " + str(int(base_amount * ratio))
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
	food_label.text = "x " + str(int(base_amount * ratio))
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
	stone_label.text = "x " + str(int(base_amount * ratio * 0.1))
	stone_label.add_theme_font_size_override("font_size", 30)
	stone_box.add_child(stone_img)
	stone_box.add_child(stone_label)
	hbox.add_child(stone_box)


# ── 피해량 통계 ──
	var stats_hbox = HBoxContainer.new()
	stats_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.offset_top = -350
	stats_hbox.offset_bottom = -150
	stats_hbox.add_theme_constant_override("separation", 40)
	bg.add_child(stats_hbox)

	var total_skill_dmg = 0.0
	for v in GameData.skill_damage.values():
		total_skill_dmg += v
	var total_unit_dmg = 0.0
	for v in GameData.unit_damage.values():
		total_unit_dmg += v
	var total_all_dmg = total_skill_dmg + total_unit_dmg

	# 왼쪽: 스킬 피해량
	var skill_vbox = VBoxContainer.new()
	skill_vbox.add_theme_constant_override("separation", 4)
	stats_hbox.add_child(skill_vbox)

	var skill_title = Label.new()
	skill_title.text = "[ 기술 피해량 ]"
	skill_title.add_theme_font_size_override("font_size", 16)
	skill_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	skill_vbox.add_child(skill_title)

	var skill_order = ["주먹", "돌멩이", "나무막대", "화염", "화살", "그물"]
	for skill_name in skill_order:
		var dmg = GameData.skill_damage.get(skill_name, 0.0)
		if dmg <= 0:
			continue
		var pct = int(dmg / max(total_all_dmg, 1.0) * 100.0)
		var row = Label.new()
		row.text = skill_name + "  " + str(int(dmg)) + "  (" + str(pct) + "%)"
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		skill_vbox.add_child(row)

	# 오른쪽: 부대 피해량
	var unit_vbox = VBoxContainer.new()
	unit_vbox.add_theme_constant_override("separation", 4)
	stats_hbox.add_child(unit_vbox)

	var unit_title = Label.new()
	unit_title.text = "[ 부대 피해량 ]"
	unit_title.add_theme_font_size_override("font_size", 16)
	unit_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	unit_vbox.add_child(unit_title)

	if GameData.unit_damage.is_empty():
		var no_unit = Label.new()
		no_unit.text = "출전 부대 없음"
		no_unit.add_theme_font_size_override("font_size", 14)
		no_unit.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		unit_vbox.add_child(no_unit)
	else:
		for unit_name in GameData.unit_damage:
			var dmg = GameData.unit_damage[unit_name]
			var pct = int(dmg / max(total_all_dmg, 1.0) * 100.0)
			var row = Label.new()
			row.text = unit_name + "  " + str(int(dmg)) + "  (" + str(pct) + "%)"
			row.add_theme_font_size_override("font_size", 14)
			row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			unit_vbox.add_child(row)

	# 버튼 스타일
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.85, 0.65, 0.1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8

	# 재도전 버튼
	var retry_btn = Button.new()
	retry_btn.text = "재도전"
	retry_btn.set_anchors_preset(Control.PRESET_CENTER)
	retry_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	retry_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	retry_btn.offset_left = -220
	retry_btn.offset_right = -20
	retry_btn.offset_top = 20
	retry_btn.offset_bottom = 100
	retry_btn.add_theme_font_size_override("font_size", 28)
	retry_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	retry_btn.add_theme_stylebox_override("normal", btn_style.duplicate())
	retry_btn.pressed.connect(func():
		get_tree().paused = false
		GameData.current_level = 1
		GameData.enemies_killed = 0
		GameData.stage_xp_pending = 0
		get_tree().reload_current_scene()
		await get_tree().process_frame
		queue_free()
	)
	bg.add_child(retry_btn)

	# 나가기 버튼
	var quit_btn = Button.new()
	quit_btn.text = "나가기"
	quit_btn.set_anchors_preset(Control.PRESET_CENTER)
	quit_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	quit_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	quit_btn.offset_left = 20
	quit_btn.offset_right = 220
	quit_btn.offset_top = 20
	quit_btn.offset_bottom = 100
	quit_btn.add_theme_font_size_override("font_size", 28)
	quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_btn.add_theme_stylebox_override("normal", btn_style.duplicate())
	quit_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
		await get_tree().process_frame
		queue_free()
	)
	bg.add_child(quit_btn)
