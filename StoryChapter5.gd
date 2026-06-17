extends Node2D
@onready var wave_manager = $WaveManager
@onready var upgrade_ui = $UI/UpgradeUI

var _story_sequence_end: int = -1
var _story_sequence_callback: Callable

func _ready() -> void:
	Engine.time_scale = 1.0
	GameData.story_chapter = 5
	var unit_attack_timer = Timer.new()
	unit_attack_timer.wait_time = 5.0
	unit_attack_timer.autostart = true
	unit_attack_timer.timeout.connect(_on_unit_attack)
	add_child(unit_attack_timer)
	GameData.current_level = 1
	GameData.enemies_killed = 0
	GameData.stage_xp_pending = 0
	GameData.skill_damage = {}
	GameData.unit_damage = {}

	# 배경: 신단수(86스테이지)
	var bg_path = "res://배경_신단수.png"
	if ResourceLoader.exists(bg_path):
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
	wave_manager.set_process(false)

	# HUD 숨기기
	for hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(hud):
			hud.visible = false

	await get_tree().process_frame
	_start_chapter5()

func _on_char_level_up(new_level: int) -> void:
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
		if is_instance_valid(label): label.queue_free()
	)

func _start_chapter5() -> void:
	GameData.story_card_filter = ""
	# 나레이션 1~6
	_show_story_dialog([
		"무속인: 당신이 지금까지 짐승들로부터 이 신단수를 지켜주시는 모습을 계속 지켜봐 왔습니다.",
		"무속인: 지난 밤, 꿈에서 오늘 이곳에 고귀한 존재가 오실 거라는 계시를 받았습니다.",
		"무속인: 그분을 맞이할 준비를 해야 하는데, 짐승들이 자꾸 몰려들어 혼자 힘으로는 너무 힘에 부칩니다.",
		"무속인: 저를 도와 주실 수 있으시겠습니까?",
		GameData.char_profile.get("name", "영웅") + ": 물론이죠. 저와 제 부족원들이 함께 힘을 합쳐 도와 드리겠습니다.",
		"무속인: 고맙습니다. 제가 준비를 마칠 때까지 짐승들이 다가오지 못하게 저를 지켜 주세요",
	], _start_battle)

func _start_battle() -> void:
	# HUD 표시
	for hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(hud):
			hud.visible = true

	# 무속인 이미지를 화면 가운데에 배치
	_spawn_shaman_npc()

	GameData.current_stage = 86
	_start_stage_sequence(1, 10, _on_battle_complete)

func _spawn_shaman_npc() -> void:
	var shaman = Sprite2D.new()
	shaman.name = "ShamanNPC"
	if ResourceLoader.exists("res://스토리무속인.png"):
		shaman.texture = load("res://스토리무속인.png")
	shaman.scale = Vector2(1.5, 1.5)
	shaman.z_index = 5
	add_child(shaman)
	await get_tree().process_frame
	# 플레이어 위치 기준으로 가운데 배치 (월드 좌표)
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		shaman.global_position = Vector2(player.global_position.x, player.global_position.y - 100)
	else:
		shaman.global_position = Vector2(648, 576)  # 1296/2, 1152/2

var _battle_complete_handled: bool = false

func _on_battle_complete() -> void:
	if _battle_complete_handled:
		return
	_battle_complete_handled = true
	wave_manager.set_process(false)
	get_tree().paused = false
	# 무속인 NPC 제거
	var shaman = get_node_or_null("ShamanNPC")
	if is_instance_valid(shaman):
		shaman.queue_free()

	# 환웅 일행 등장 연출
	# 캐릭터를 화면 가운데로 강제 이동
	var player_node = get_tree().get_first_node_in_group("player")
	var screen = get_viewport().get_visible_rect().size
	if is_instance_valid(player_node):
		player_node.global_position = Vector2(screen.x / 2.0, screen.y / 2.0)

	# 환웅 일행 등장 연출
	_spawn_heavenly_beings(func():
		# 나레이션 7~15
		_show_story_dialog([
			"환웅: 그대들은 누구인가?",
			"무속인: 저는 신단수를 지키는 무속인입니다. 지난 밤, 꿈에서 오늘 이곳에 고귀한 존재가 오실 거라는 계시를 받고 이렇게 나왔습니다.",
			"환웅: 그런가. 훌륭한 자가 있었군",
			"환웅: 나는 환인의 아들 환웅일세. 이곳 사람들을 교화하고 이곳을 다스리러 풍백, 우사, 운사와 함께 내려왔네.",
			"환웅: 보아하니 나를 맞이하기 위해 이곳 주변을 정리하고 있던데, 기특하구나.",
			"환웅: 내가 이곳을 잘 다스릴 수 있도록 자네들이 나를 도와주겠는가?",
			GameData.char_profile.get("name", "영웅") + ": 저와 저희 부족인들은 환웅님을 따르겠습니다.",
			"환웅: 든든하구나. 앞으로 잘 부탁하겠네.",
			GameData.char_profile.get("name", "영웅") + ": 알겠습니다.",
			"무속인: " + GameData.char_profile.get("name", "영웅") + "님, 고맙습니다.",
			"무속인: 당신은 정말 강하고 대담한 분이시군요.",
			"무속인: 앞으로 당신의 길에 제가 함께 하겠습니다.",
		], _on_chapter5_complete)
	)

func _spawn_heavenly_beings(on_complete: Callable) -> void:
	var screen = get_viewport().get_visible_rect().size
	# 환웅, 풍백, 우사, 운사 4명 위에서 내려오는 연출
	var names = ["환웅", "풍백", "우사", "운사"]
	var imgs = ["res://환웅.png", "res://풍백.png", "res://우사.png", "res://운사.png"]
	var total_w = 300.0
	var player = get_tree().get_first_node_in_group("player")
	var center_x = player.global_position.x if is_instance_valid(player) else 648.0
	var start_x = center_x - total_w / 2.0
	var beings = []

	for i in range(names.size()):
		var being = Sprite2D.new()
		being.name = names[i]
		# 이미지 있으면 로드, 없으면 레이블로 대체
		if ResourceLoader.exists(imgs[i]):
			being.texture = load(imgs[i])
			being.scale = Vector2(1.2, 1.2)
		else:
			# 이미지 없을 때 텍스트로 대체
			var lbl = Label.new()
			lbl.text = names[i]
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
			being.add_child(lbl)
		var player_y = player.global_position.y if is_instance_valid(player) else 576.0
		being.global_position = Vector2(start_x + i * (total_w / 3.0), player_y - 600)
		being.z_index = 6
		add_child(being)
		beings.append(being)

	# 화면 가운데로 내려오는 tween
	var tween = create_tween()
	tween.set_parallel(true)
	for i in range(beings.size()):
		var player_y2 = player.global_position.y if is_instance_valid(player) else 576.0
		tween.tween_property(beings[i], "global_position:y", player_y2 - 100, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		on_complete.call()
	)

func _on_chapter5_complete() -> void:
	_show_skill_complete_popup("무속인", "res://무속인.png", func():
		GameData.story_cleared["5"] = true
		GameData.story_card_filter = ""
		GameData.has_shaman = true  # ← 이 줄 추가
		GameData.save_game()
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	)

# ── 공통 헬퍼들 (StoryChapter4와 동일 구조) ──

func _start_stage_sequence(start_level: int, end_level: int, on_complete: Callable) -> void:
	GameData.current_level = start_level
	if start_level == 1:
		GameData.enemies_killed = 0
		GameData.stage_xp_pending = 0
		GameData.skill_damage = {}
		GameData.unit_damage = {}
	_story_sequence_end = end_level
	_story_sequence_callback = on_complete
	wave_manager.set_process(true)
	wave_manager.reset()
	upgrade_ui.show_upgrades()

func _on_stage_clear() -> void:
	for node in get_tree().get_nodes_in_group("effects"):
		node.queue_free()
	if _story_sequence_end > 0 and GameData.current_level >= _story_sequence_end:
		wave_manager.set_process(false)
		var cb = _story_sequence_callback
		_story_sequence_end = -1
		cb.call()
		return
	if GameData.current_level >= GameData.max_level:
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
	var boss_wm = get_tree().get_first_node_in_group("wave_manager")
	if boss_wm:
		boss_wm.boss_spawned = false
	upgrade_ui.show_upgrades()

func _on_upgrade_chosen() -> void:
	await get_tree().process_frame
	wave_manager.reset()

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
	label.text = "최종 클리어!" if is_final else _get_stage_name(GameData.current_stage) + " 성공!"
	label.add_theme_font_size_override("font_size", 55)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_top = -700
	bg.add_child(label)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.65, 0.1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
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
	retry_btn.pressed.connect(func():
		get_tree().paused = false
		GameData.enemies_killed = 0
		GameData.stage_xp_pending = 0
		get_tree().reload_current_scene()
	)
	bg.add_child(retry_btn)
	var quit_btn = Button.new()
	quit_btn.text = "나가기"
	quit_btn.set_anchors_preset(Control.PRESET_CENTER)
	quit_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	quit_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	quit_btn.position = Vector2(10, 80)
	quit_btn.size = Vector2(135, 60)
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_btn.add_theme_stylebox_override("normal", style.duplicate())
	quit_btn.pressed.connect(func():
		get_tree().paused = false
		for node in get_tree().get_nodes_in_group("clear_bg"):
			node.queue_free()
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	)
	bg.add_child(quit_btn)

func _show_story_dialog(lines: Array, on_complete: Callable) -> void:
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

	# 왼쪽 화자 이미지 (무속인, 환웅 등)
	var char_img_left = TextureRect.new()
	char_img_left.position = Vector2(10, -20)
	char_img_left.size = Vector2(80, 180)
	char_img_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_img_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_img_left.visible = false
	bg.add_child(char_img_left)

	# 오른쪽 화자 이미지 (영웅)
	var char_img_right = TextureRect.new()
	char_img_right.position = Vector2(screen.x - 90, -20)
	char_img_right.size = Vector2(80, 180)
	char_img_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_img_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_img_right.visible = false
	bg.add_child(char_img_right)

	# 화자 이름
	var speaker_lbl = Label.new()
	speaker_lbl.size = Vector2(210, 30)
	speaker_lbl.add_theme_font_size_override("font_size", 18)
	speaker_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	speaker_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	speaker_lbl.add_theme_constant_override("outline_size", 2)
	bg.add_child(speaker_lbl)

	# 대사 텍스트
	var label = Label.new()
	label.size = Vector2(screen.x - 200, 140)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bg.add_child(label)

	var hint = Label.new()
	hint.text = "▼ 터치하여 계속"
	hint.position = Vector2(screen.x - 160, 170)
	hint.size = Vector2(140, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	bg.add_child(hint)

	# 화자별 이미지 매핑
	var speaker_imgs = {
		"무속인": "res://스토리무속인.png",
		"환웅":   "res://환웅.png",
		"풍백":   "res://풍백.png",
		"우사":   "res://우사.png",
		"운사":   "res://운사.png",
	}
	var hero_name = GameData.char_profile.get("name", "영웅")
	var hero_img_path = "res://characters/char_%d.png" % GameData.char_profile.get("appearance", 0)

	# 영웅 화자 목록
	var hero_speakers = [hero_name, "영웅"]

	var update_line = func(text: String):
		var speaker = ""
		var dialogue = text
		if ": " in text:
			var parts = text.split(": ", true, 1)
			speaker = parts[0]
			dialogue = parts[1]

		var is_hero = speaker in hero_speakers
		speaker_lbl.text = speaker

		# 영웅이면 오른쪽 정렬, 나머지는 왼쪽 정렬
		if is_hero:
			# 오른쪽: 이미지는 오른쪽, 텍스트는 이미지 왼쪽
			char_img_left.visible = false
			char_img_right.visible = false
			if ResourceLoader.exists(hero_img_path):
				char_img_right.texture = load(hero_img_path)
				char_img_right.visible = true
			speaker_lbl.position = Vector2(screen.x - 310, 10)
			speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.position = Vector2(100, 50)
			label.size = Vector2(screen.x - 200, 130)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			# 왼쪽: 이미지는 왼쪽, 텍스트는 이미지 오른쪽
			char_img_right.visible = false
			char_img_left.visible = false
			var img_path = speaker_imgs.get(speaker, "")
			if img_path != "" and ResourceLoader.exists(img_path):
				char_img_left.texture = load(img_path)
				char_img_left.visible = true
			speaker_lbl.position = Vector2(100, 10)
			speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.position = Vector2(100, 50)
			label.size = Vector2(screen.x - 200, 130)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

		label.text = dialogue

	var idx_box = [0]
	update_line.call(lines[idx_box[0]])

	var touch_area = Control.new()
	touch_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_area.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_area.process_mode = Node.PROCESS_MODE_ALWAYS
	touch_area.z_index = 100
	var completed = [false]
	touch_area.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and not completed[0]:
			idx_box[0] += 1
			if idx_box[0] < lines.size():
				update_line.call(lines[idx_box[0]])
			else:
				completed[0] = true
				canvas.queue_free()
				await get_tree().process_frame
				on_complete.call()
	)
	canvas.add_child(touch_area)

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
	var title = Label.new()
	title.text = "새로운 기술 [" + skill_name + "]을 습득하였습니다"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
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

# 부대 공격 (다른 챕터와 동일)
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
	for u in all_units:
		var ud = GameData.get_unit(u["name"])
		if not ud.get("deployed", false):
			continue
		var enemies = get_tree().get_nodes_in_group("enemies")
		var population = int(ud.get("population", 1))
		var dmg_lv = int(ud.get("damage_lv", 0))
		var total_pct = u["base_dmg_pct"] + dmg_lv * 10
		var damage = GameData.get_total_attack() * float(total_pct) / 100.0
		for _i in range(population):
			if enemies.is_empty():
				break
			var e = enemies[0]
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(damage)
				GameData.unit_damage[u["name"]] = GameData.unit_damage.get(u["name"], 0.0) + damage
