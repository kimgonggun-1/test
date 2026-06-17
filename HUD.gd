extends CanvasLayer

@onready var stage_label = $StageLabel
@onready var timer_label = $TimerLabel

var joystick_base: Panel
var joystick_knob: Panel
var joystick_radius: float = 60.0

# 레벨 UI 요소
var level_label: Label
var xp_bar: ProgressBar
var xp_label: Label

func _ready() -> void:
	add_to_group("hud")
	var screen_size = get_viewport().get_visible_rect().size
	
	stage_label.position = Vector2(0, 10)
	stage_label.size = Vector2(screen_size.x, 50)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 36)
	
	timer_label.position = Vector2(0, 95)
	timer_label.size = Vector2(screen_size.x, 50)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 36)
	
	var enemy_label = Label.new()
	enemy_label.name = "EnemyLabel"
	enemy_label.position = Vector2(0, 145)
	enemy_label.size = Vector2(screen_size.x, 40)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.add_theme_font_size_override("font_size", 24)
	enemy_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	add_child(enemy_label)
	
	# ─── 좌측 상단 레벨 UI ───
	var left_panel = VBoxContainer.new()
	left_panel.name = "LevelPanel"
	left_panel.position = Vector2(10, 10)
	left_panel.custom_minimum_size = Vector2(200, 0)
	add_child(left_panel)
	
# 닉네임 표시
	var name_label = Label.new()
	name_label.name = "NameLabel"
	var profile = GameData.char_profile
	name_label.text = profile.get("name", "용사")
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(0.459, 0.094, 0.0, 1.0))
	left_panel.add_child(name_label)
	
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "1등급"
	level_label.add_theme_font_size_override("font_size", 28)
	level_label.add_theme_color_override("font_color", Color(1, 0.95, 0.3))
	left_panel.add_child(level_label)
	
	# XP 바 컨테이너
	var xp_container = HBoxContainer.new()
	xp_container.add_theme_constant_override("separation", 4)
	left_panel.add_child(xp_container)
	
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(90, 12)
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	# XP 바 색상 스타일
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.2, 0.8, 1.0)
	xp_fill.corner_radius_top_left = 3
	xp_fill.corner_radius_top_right = 3
	xp_fill.corner_radius_bottom_left = 3
	xp_fill.corner_radius_bottom_right = 3
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_container.add_child(xp_bar)
	
	xp_label = Label.new()
	xp_label.name = "XPLabel"
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	xp_container.add_child(xp_label)
	
	# 일시정지 버튼
	var pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 24)
	pause_btn.size = Vector2(50, 50)
	pause_btn.position = Vector2(screen_size.x - 60, 10)
	pause_btn.pressed.connect(_on_pause_pressed)
	add_child(pause_btn)
	
	# 배속 버튼
	var speed_btn = Button.new()
	speed_btn.name = "SpeedBtn"
	speed_btn.text = "1x"
	speed_btn.size = Vector2(80, 50)          # ← 크기 조정
	speed_btn.position = Vector2(screen_size.x - 140, 6)
	speed_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	speed_btn.add_theme_font_size_override("font_size", 28)  # ← 글자 크기
	speed_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))  # ← 글자 색상
	var speed_style = StyleBoxFlat.new()
	speed_style.bg_color = Color(0.2, 0.2, 0.6)             # ← 배경 색상
	speed_style.border_color = Color(0.4, 0.4, 1.0)         # ← 테두리 색상
	speed_style.border_width_top    = 3
	speed_style.border_width_bottom = 3
	speed_style.border_width_left   = 3
	speed_style.border_width_right  = 3
	speed_style.corner_radius_top_left     = 8
	speed_style.corner_radius_top_right    = 8
	speed_style.corner_radius_bottom_left  = 8
	speed_style.corner_radius_bottom_right = 8
	speed_btn.add_theme_stylebox_override("normal", speed_style)
	speed_btn.pressed.connect(_on_speed_pressed)
	add_child(speed_btn)
	
# ── 출전 부대 아이콘 바 (하단) ──
	var deployed_units = _get_deployed_units_for_hud()
	if deployed_units.size() > 0:
		var unit_bar_h = 80.0
		var unit_bar = Control.new()
		unit_bar.position = Vector2(0, screen_size.y - unit_bar_h - 10)
		unit_bar.size = Vector2(screen_size.x, unit_bar_h)
		unit_bar.z_index = 10
		add_child(unit_bar)

		var icon_size = 64.0
		var gap = 8.0
		var total_w = deployed_units.size() * (icon_size + gap) - gap
		var start_x = (screen_size.x - total_w) / 2.0

		for i in range(deployed_units.size()):
			var u = deployed_units[i]
			var ud = GameData.get_unit(u["name"])

			var icon_bg = PanelContainer.new()
			icon_bg.position = Vector2(start_x + i * (icon_size + gap), 0)
			icon_bg.custom_minimum_size = Vector2(icon_size, icon_size)
			var icon_st = StyleBoxFlat.new()
			icon_st.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			icon_st.border_color = Color(0.4, 0.75, 1.0)
			icon_st.border_width_top    = 2
			icon_st.border_width_bottom = 2
			icon_st.border_width_left   = 2
			icon_st.border_width_right  = 2
			icon_st.corner_radius_top_left     = 8
			icon_st.corner_radius_top_right    = 8
			icon_st.corner_radius_bottom_left  = 8
			icon_st.corner_radius_bottom_right = 8
			icon_bg.add_theme_stylebox_override("panel", icon_st)
			unit_bar.add_child(icon_bg)

			if u["img"] != "" and ResourceLoader.exists(u["img"]):
				var tex = TextureRect.new()
				tex.texture = load(u["img"])
				tex.set_anchors_preset(Control.PRESET_FULL_RECT)
				tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_bg.add_child(tex)

			var pop_lbl = Label.new()
			pop_lbl.text = str(int(ud.get("population", 1)))
			pop_lbl.position = Vector2(start_x + i * (icon_size + gap) + icon_size - 22, icon_size - 20)
			pop_lbl.add_theme_font_size_override("font_size", 14)
			pop_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			pop_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			pop_lbl.add_theme_constant_override("outline_size", 3)
			unit_bar.add_child(pop_lbl)

			var name_lbl = Label.new()
			name_lbl.text = u["name"]
			name_lbl.position = Vector2(start_x + i * (icon_size + gap), icon_size + 2)
			name_lbl.custom_minimum_size = Vector2(icon_size, 16)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			name_lbl.add_theme_constant_override("outline_size", 2)
			unit_bar.add_child(name_lbl)

	joystick_base = Panel.new()
	joystick_base.size = Vector2(joystick_radius * 2, joystick_radius * 2)
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.938, 0.428, 0.86, 0.2)
	base_style.corner_radius_top_left = 60
	base_style.corner_radius_top_right = 60
	base_style.corner_radius_bottom_left = 60
	base_style.corner_radius_bottom_right = 60
	joystick_base.add_theme_stylebox_override("panel", base_style)
	add_child(joystick_base)
	joystick_base.visible = false
	
	joystick_knob = Panel.new()
	joystick_knob.size = Vector2(40, 40)
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.5)
	knob_style.corner_radius_top_left = 20
	knob_style.corner_radius_top_right = 20
	knob_style.corner_radius_bottom_left = 20
	knob_style.corner_radius_bottom_right = 20
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	add_child(joystick_knob)
	joystick_knob.visible = false
	
	# GameData XP 시그널 연결
	GameData.connect("xp_changed", _update_xp_ui)
	_update_xp_ui()

func _update_xp_ui() -> void:
	if not is_instance_valid(level_label):
		return
	level_label.text = str(GameData.char_level) + "등급"
	var cur_xp = GameData.get_current_level_xp() + GameData.stage_xp_pending
	var needed = GameData.get_xp_to_next_level()
	var fill_pct = float(cur_xp) / float(needed) * 100.0
	xp_bar.value = clamp(fill_pct, 0, 100)
	xp_label.text = str(cur_xp) + "/" + str(needed)

func _on_pause_pressed() -> void:
	get_tree().paused = true
	var screen_size = get_viewport().get_visible_rect().size
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.name = "PauseBG"
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(screen_size.x / 2 - 100, screen_size.y / 2 - 110)
	vbox.add_theme_constant_override("separation", 15)
	bg.add_child(vbox)
	
	var resume_btn = Button.new()
	resume_btn.text = "게임재개"
	resume_btn.custom_minimum_size = Vector2(200, 60)
	resume_btn.add_theme_font_size_override("font_size", 22)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(func():
		bg.queue_free()
		get_tree().paused = false
	)
	vbox.add_child(resume_btn)
	
	var setting_btn = Button.new()
	setting_btn.text = "설정"
	setting_btn.custom_minimum_size = Vector2(200, 60)
	setting_btn.add_theme_font_size_override("font_size", 22)
	setting_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	setting_btn.pressed.connect(func():
		print("설정 준비중")
	)
	vbox.add_child(setting_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "나가기"
	quit_btn.custom_minimum_size = Vector2(200, 60)
	quit_btn.add_theme_font_size_override("font_size", 22)
	quit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	)
	vbox.add_child(quit_btn)

func _on_speed_pressed() -> void:
	var btn = get_node("SpeedBtn")
	if Engine.time_scale == 1.0:
		Engine.time_scale = 2.0
		btn.text = "2x"
	elif Engine.time_scale == 2.0:
		Engine.time_scale = 3.0
		btn.text = "3x"
	elif Engine.time_scale == 3.0:
		Engine.time_scale = 4.0
		btn.text = "4x"
	elif Engine.time_scale == 4.0:
		Engine.time_scale = 5.0
		btn.text = "5x"
	else:
		Engine.time_scale = 1.0
		btn.text = "1x"

func _process(_delta: float) -> void:
	var stage_name = ""
	var stage = GameData.current_stage
	if stage <= 15:
		stage_name = "평원 " + str(stage)
	elif stage <= 30:
		stage_name = "냇가 " + str(stage - 15)
	elif stage <= 45:
		stage_name = "동굴 " + str(stage - 30)
	elif stage <= 60:
		stage_name = "검은모루 " + str(stage - 45)
	elif stage <= 75:
		stage_name = "미송리 " + str(stage - 60)
	elif stage <= 85:
		stage_name = "열수 " + str(stage - 75)
	elif stage <= 95:
		stage_name = "신단수 " + str(stage - 85)
	elif stage <= 105:
		stage_name = "아사달 " + str(stage - 95)
	elif stage <= 115:
		stage_name = "왕검성 " + str(stage - 105)
	elif stage <= 125:
		stage_name = "북방 산악지대 " + str(stage - 115)
	elif stage <= 135:
		stage_name = "교역로 " + str(stage - 125)
	elif stage <= 145:
		stage_name = "왕검성 상업지대 " + str(stage - 135)
	elif stage <= 155:
		stage_name = "패수 도하 방어전 " + str(stage - 145)
	elif stage <= 165:
		stage_name = "협곡 매복작전 " + str(stage - 155)
	elif stage <= 175:
		stage_name = "왕검성 공성전 " + str(stage - 165)
	else:
		stage_name = "스테이지 " + str(stage)
	stage_label.text = stage_name + "\n" + str(GameData.current_level) + " / 10 단계"
	
	var wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager:
		var time_left = GameData.stage_time - wave_manager.time_elapsed
		timer_label.text = str(int(max(0, time_left))) + "초"
	
	var enemy_label = get_node_or_null("EnemyLabel")
	if enemy_label:
		var enemies = get_tree().get_nodes_in_group("enemies")
		enemy_label.text = "적: %d   처치: %d" % [enemies.size(), GameData.enemies_killed]
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.joystick_active:
		joystick_base.visible = true
		joystick_knob.visible = true
		joystick_base.position = player.joystick_start - Vector2(joystick_radius, joystick_radius)
		var dir = (player.joystick_origin - player.joystick_start).normalized()
		var dist = min((player.joystick_origin - player.joystick_start).length(), joystick_radius - 20)
		joystick_knob.position = player.joystick_start + dir * dist - Vector2(20, 20)
	else:
		joystick_base.visible = false
		joystick_knob.visible = false

func _get_deployed_units_for_hud() -> Array:
	var all_units = [
		{"name": "돌멩이병", "img": "res://돌멩이병.png"},
		{"name": "죽창병",   "img": "res://죽창병.png"},
		{"name": "돌도끼병", "img": "res://units/돌도끼병.png"},
		{"name": "돌칼병",   "img": "res://units/돌칼병.png"},
		{"name": "활병",     "img": "res://units/활병.png"},
		{"name": "돌창병",   "img": "res://units/돌창병.png"},
		{"name": "청동검병", "img": "res://units/청동검병.png"},
		{"name": "청동활병", "img": "res://units/청동활병.png"},
		{"name": "청동창병", "img": "res://units/청동창병.png"},
		{"name": "기마병",   "img": "res://units/기마병.png"},
	]
	# 이미지 없으면 표시 안 함 처리는 ResourceLoader.exists에서 자동 처리됨
	var deployed = []
	for u in all_units:
		var ud = GameData.get_unit(u["name"])
		if ud.get("deployed", false):
			deployed.append(u)
	return deployed
