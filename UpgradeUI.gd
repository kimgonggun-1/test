extends CanvasLayer


var fist_texture = preload("res://1. 주먹.png")
var stone_texture = preload("res://2. 돌멩이.png")
var stick_texture = preload("res://3. 몽둥이.png")

const UPGRADES = [
	{"name": "주먹 강화", "desc": "주먹 공격력 +15%\n공격속도 +30%", "id": "fist_dmg", "req": ""},
	{"name": "연타", "desc": "동시 타격 대상 +1", "id": "fist_targets", "req": ""},
	{"name": "돌 던지기 습득", "desc": "돌 던지기 공격 해금!\n<경직>", "id": "stone_unlock", "req": ""},
	{"name": "돌 추가", "desc": "동시 발사 +1\n피해량 -15%", "id": "stone_count", "req": "stone_unlock"},
	{"name": "큰 돌 던지기", "desc": "돌 범위 +30\n경직시간 +0.5초", "id": "stone_range", "req": "stone_unlock"},
	{"name": "천하장사", "desc": "돌 공격력 +50%", "id": "stone_dmg", "req": "stone_unlock"},
	{"name": "나무막대 습득", "desc": "나무막대 공격 해금!\n<밀려남>", "id": "stick_unlock", "req": ""},
	{"name": "통나무", "desc": "공격력 +50%", "id": "stick_range", "req": "stick_unlock"},
	{"name": "몰아치기", "desc": "동시 타격 대상 x2\n공격력 -15%", "id": "stick_targets", "req": "stick_unlock"},
	{"name": "휩쓸기 강화", "desc": "공격 범위 +50", "id": "stick_sweep", "req": "stick_unlock"},
	{"name": "화염 습득", "desc": "화염 공격 해금!\n<범위 적에게 화상 3회>", "id": "flame_unlock", "req": ""},
	{"name": "화염 범위", "desc": "화염 공격 범위 +30%", "id": "flame_range", "req": "flame_unlock"},
	{"name": "전이", "desc": "화상 전이", "id": "flame_spread", "req": "flame_unlock"},
	{"name": "확산", "desc": "전이 범위 +50%", "id": "flame_spread_range", "req": "flame_spread"},
	{"name": "화살 습득", "desc": "화살 공격 해금!\n<경로 관통>", "id": "arrow_unlock", "req": ""},
	{"name": "화살 분열", "desc": "명중 시 작은 화살 2개\n추가 발사 (피해 50%)", "id": "arrow_bounce", "req": "arrow_unlock"},
	{"name": "추가 분열", "desc": "작은 화살 +2개", "id": "arrow_bounce2", "req": "arrow_bounce"},
	{"name": "화살 추가", "desc": "동시 발사 +1\n피해량 -15%", "id": "arrow_count", "req": "arrow_unlock"},
	{"name": "화살 공격력", "desc": "화살 피해량 +30%", "id": "arrow_dmg", "req": "arrow_unlock"},
	{"name": "그물 습득", "desc": "그물 공격 해금!\n<끌어당기기+지속피해>", "id": "net_unlock", "req": ""},
	{"name": "더 큰 그물", "desc": "그물 범위 +80", "id": "net_range", "req": "net_unlock"},
	{"name": "굵은 그물", "desc": "끌어당기는 힘 +60", "id": "net_pull", "req": "net_unlock"},
	{"name": "튼튼한 그물", "desc": "지속시간 +1초", "id": "net_duration", "req": "net_unlock"},
	{"name": "빙의 습득", "desc": "5초간 공격력 +50%\n(쿨타임 12초)", "id": "shaman_atk_unlock", "req": ""},
	{"name": "접신 습득", "desc": "5초간 공격속도 +50%\n(쿨타임 11초)", "id": "shaman_spd_unlock", "req": ""},
	{"name": "부적 습득", "desc": "5초간 모든 기술 공격 횟수 +1\n(쿨타임 10초)", "id": "shaman_seal_unlock", "req": ""},
]

var current_choices = []
var upgrade_counts = {}  # 각 카드 선택 횟수 추적
var is_first_card: bool = true  # 첫 번째 카드 선택 여부

@onready var card1 = $Background/Card1
@onready var card2 = $Background/Card2
@onready var card3 = $Background/Card3
@onready var card1_img = $Background/Card1/Icon
@onready var card2_img = $Background/Card2/Icon
@onready var card3_img = $Background/Card3/Icon
@onready var card1_label = $Background/Card1/CardLabel
@onready var card2_label = $Background/Card2/CardLabel
@onready var card3_label = $Background/Card3/CardLabel

signal upgrade_chosen

var flame_texture = preload("res://4. 불.png")

func get_texture_for(id: String) -> Texture2D:
	if id in ["fist_dmg", "fist_targets"]:
		return fist_texture
	elif id in ["stone_unlock", "stone_count", "stone_range", "stone_dmg"]:
		return stone_texture
	elif id in ["stick_unlock", "stick_range", "stick_targets", "stick_sweep"]:
		return stick_texture
	elif id in ["flame_unlock", "flame_range", "flame_spread", "flame_spread_range"]:
		return flame_texture
	elif id in ["arrow_unlock", "arrow_bounce", "arrow_bounce2", "arrow_count", "arrow_dmg"]:
		return load("res://화살.png")
	elif id in ["net_unlock", "net_range", "net_pull", "net_duration"]:
		return load("res://그물.png")
	elif id == "shaman_atk_unlock":
		return load("res://빙의.png")
	elif id == "shaman_spd_unlock":
		return load("res://접신.png")
	elif id == "shaman_seal_unlock":
		return load("res://부적.png")
	return null

func show_upgrades() -> void:
	# 조이스틱 상태 초기화
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		p.joystick_active = false
		p.velocity = Vector2.ZERO
	get_tree().paused = true
	show()
	
	var screen_size = get_viewport().get_visible_rect().size
	var card_w = (screen_size.x - 60) / 3
	var card_h = card_w * 1.5
	var gap = 10.0
	var total_width = card_w * 3 + gap * 2
	var start_x = (screen_size.x - total_width) / 2
	var card_y = screen_size.y / 2 - card_h / 2
	
	$Background.position = Vector2.ZERO
	$Background.size = screen_size
	
	$Background/Card1.position = Vector2(start_x, card_y)
	$Background/Card1.size = Vector2(card_w, card_h)
	$Background/Card2.position = Vector2(start_x + card_w + gap, card_y)
	$Background/Card2.size = Vector2(card_w, card_h)
	$Background/Card3.position = Vector2(start_x + card_w * 2 + gap * 2, card_y)
	$Background/Card3.size = Vector2(card_w, card_h)
	
	$Background/Title.position = Vector2(0, card_y - 50)
	$Background/Title.size = Vector2(screen_size.x, 40)
	$Background/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Background/Title.add_theme_font_size_override("font_size", 36)
	
	var player = get_tree().get_first_node_in_group("player")
	var pool = []
	
	if not is_instance_valid(player):
		hide()
		get_tree().paused = false
		return
	
	if is_first_card:
		# 첫 카드: 아직 해금 안 된 기술만 표시
		for u in UPGRADES:
			var id = u["id"]
			if id == "stone_unlock" and not player.stone_unlocked:
				pool.append(u)
			elif id == "stick_unlock" and not player.stick_unlocked:
				pool.append(u)
			elif id == "flame_unlock" and not player.flame_unlocked and GameData.story_cleared.get("1", false):
				pool.append(u)
			elif id == "net_unlock" and not player.net_unlocked and GameData.story_cleared.get("3", false):
				pool.append(u)
			elif id in ["shaman_atk_unlock", "shaman_spd_unlock", "shaman_seal_unlock"] and GameData.story_cleared.get("5", false):
				if id == "shaman_atk_unlock" and not player.shaman_atk_unlocked:
					pool.append(u)
				elif id == "shaman_spd_unlock" and not player.shaman_spd_unlocked:
					pool.append(u)
				elif id == "shaman_seal_unlock" and not player.shaman_seal_unlocked:
					pool.append(u)
		# 풀이 3개 미만이면 일반 카드로 나머지 채우기
		if pool.size() < 3:
			for u in UPGRADES:
				if pool.size() >= 3:
					break
				var id = u["id"]
				if id in ["fist_dmg", "fist_targets"]:
					continue
				if id in ["stone_unlock", "stick_unlock", "flame_unlock"]:
					continue
				if upgrade_counts.get(id, 0) >= 3:
					continue
				# req 조건 확인
				if u["req"] == "":
					if id == "flame_unlock" and not GameData.story_cleared.get("1", false):
						continue
					if id == "arrow_unlock" and not GameData.story_cleared.get("3", false):
						continue
					if id == "net_unlock" and not GameData.story_cleared.get("3", false):
						continue
					if id in ["shaman_atk_unlock", "shaman_spd_unlock", "shaman_seal_unlock"] and not GameData.story_cleared.get("5", false):
						continue
					pool.append(u)
				elif u["req"] == "stone_unlock" and player.stone_unlocked:
					pool.append(u)
				elif u["req"] == "stick_unlock" and player.stick_unlocked:
					pool.append(u)
				elif u["req"] == "flame_unlock" and player.flame_unlocked:
					pool.append(u)
				elif u["req"] == "flame_spread" and player.flame_can_spread:
					pool.append(u)
				elif u["req"] == "arrow_unlock" and player.arrow_unlocked:
					pool.append(u)
				elif u["req"] == "arrow_bounce" and player.arrow_bounce_count >= 2:
					pool.append(u)
				elif u["req"] == "net_unlock" and player.net_unlocked:
					pool.append(u)
		if pool.is_empty():
			is_first_card = false
	
	if not is_first_card:
		for u in UPGRADES:
			var id = u["id"]
			# 3회 이상 선택한 카드 제외
			if upgrade_counts.get(id, 0) >= 3:
				continue
			# 이미 해금된 해금 카드 제외
			if id == "stone_unlock" and player.stone_unlocked:
				continue
			if id == "stick_unlock" and player.stick_unlocked:
				continue
			if id == "flame_unlock" and player.flame_unlocked:
				continue
			if id == "flame_spread" and player.flame_can_spread:
				continue
			if id == "arrow_unlock" and player.arrow_unlocked:
				continue
			if id == "net_unlock" and player.net_unlocked:
				continue
			if id == "shaman_atk_unlock" and player.shaman_atk_unlocked:
				continue
			if id == "shaman_spd_unlock" and player.shaman_spd_unlocked:
				continue
			if id == "shaman_seal_unlock" and player.shaman_seal_unlocked:
				continue
			if id == "shaman_atk_unlock" and player.shaman_atk_unlocked:
				continue
			if id == "shaman_spd_unlock" and player.shaman_spd_unlocked:
				continue
			if id == "shaman_seal_unlock" and player.shaman_seal_unlocked:
				continue
			# 화살 분열: 1회만 획득 가능
			if id == "arrow_bounce" and player.arrow_bounce_count > 0:
				continue
			# 3회 이상 선택한 카드 제외
			if upgrade_counts.get(id, 0) >= 3:
				continue
			# req 조건 확인
			if u["req"] == "":
				if id == "flame_unlock" and not GameData.story_cleared.get("1", false):
					continue
				if id == "arrow_unlock" and not GameData.story_cleared.get("3", false):
					continue
				if id == "net_unlock" and not GameData.story_cleared.get("3", false):
					continue
				if id in ["shaman_atk_unlock", "shaman_spd_unlock", "shaman_seal_unlock"] and not GameData.story_cleared.get("5", false):
					continue
				pool.append(u)
			elif u["req"] == "stone_unlock" and player.stone_unlocked:
				pool.append(u)
			elif u["req"] == "stick_unlock" and player.stick_unlocked:
				pool.append(u)
			elif u["req"] == "flame_unlock" and player.flame_unlocked:
				pool.append(u)
			elif u["req"] == "flame_spread" and player.flame_can_spread:
				pool.append(u)
			elif u["req"] == "arrow_unlock" and player.arrow_unlocked:
				pool.append(u)
			elif u["req"] == "net_unlock" and player.net_unlocked:
				pool.append(u)
			elif u["req"] == "arrow_bounce" and player.arrow_bounce_count >= 2:
				pool.append(u)
	
		# ── 스토리 모드 카드 필터 ──
	if GameData.story_card_filter == "early":
		# 1~3스테이지: 주먹/돌멩이/나무막대 카드만
		var filtered = []
		for u in pool:
			if u["id"] in ["fist_dmg", "fist_targets", "stone_unlock", "stone_count", "stone_range", "stone_dmg", "stick_unlock", "stick_range", "stick_targets", "stick_sweep"]:
				filtered.append(u)
		if not filtered.is_empty():
			pool = filtered
	elif GameData.story_card_filter == "flame_unlock_only":
		# 4단계: 화염 해금 카드만 등장
		var flame_cards = []
		for u in UPGRADES:
			if u["id"] == "flame_unlock":
				flame_cards.append(u)
		pool = flame_cards
	elif GameData.story_card_filter == "flame_only":
		# 5~10단계: 화염 강화 카드만 반복 등장
		# 전이(flame_spread): 미획득 시에만 등장
		# 확산(flame_spread_range): 전이 획득 후에만 등장
		var flame_cards = []
		for u in UPGRADES:
			if u["id"] == "flame_range":
				flame_cards.append(u)
			elif u["id"] == "flame_spread" and not player.flame_can_spread:
				flame_cards.append(u)
			elif u["id"] == "flame_spread_range" and player.flame_can_spread:
				flame_cards.append(u)
		pool = flame_cards
	elif GameData.story_card_filter == "arrow_unlock_only":
		# 4단계: 화살 해금 카드만 등장
		var arrow_cards = []
		for u in UPGRADES:
			if u["id"] == "arrow_unlock":
				arrow_cards.append(u)
		pool = arrow_cards
	elif GameData.story_card_filter == "fist_only":
		# 챕터4: 주먹 강화 카드만 반복 등장
		var fist_cards = []
		for u in UPGRADES:
			if u["id"].begins_with("fist"):
				fist_cards.append(u)
		pool = fist_cards
	elif GameData.story_card_filter == "arrow_only":
		# 5~10단계: 화살 강화 카드만 반복 등장 (req 조건 무시)
		var arrow_cards = []
		for u in UPGRADES:
			if u["id"] in ["arrow_bounce", "arrow_bounce2", "arrow_count", "arrow_dmg"]:
				arrow_cards.append(u)
		pool = arrow_cards

	pool.shuffle()
	current_choices = pool.slice(0, min(3, pool.size()))
	
	var cards = [card1, card2, card3]
	var labels = [card1_label, card2_label, card3_label]
	var imgs = [card1_img, card2_img, card3_img]
	
	for i in range(3):
		if i < current_choices.size():
			cards[i].visible = true
			labels[i].text = current_choices[i]["name"] + "\n" + current_choices[i]["desc"]
			imgs[i].texture = get_texture_for(current_choices[i]["id"])
		else:
			cards[i].visible = false
	

	var t1 = get_texture_for(current_choices[0]["id"]) if current_choices.size() > 0 else null
	var t2 = get_texture_for(current_choices[1]["id"]) if current_choices.size() > 1 else null
	var t3 = get_texture_for(current_choices[2]["id"]) if current_choices.size() > 2 else null
		
	card1_img.texture = t1
	card1_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card1_img.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	card1_img.size = Vector2(80, 80)
	card1_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card1_img.position = Vector2(card_w / 2 - 40, card_h / 2 - 60)

	card2_img.texture = t2
	card2_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card2_img.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	card2_img.size = Vector2(80, 80)
	card2_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card2_img.position = Vector2(card_w / 2 - 40, card_h / 2 - 60)

	card3_img.texture = t3
	card3_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card3_img.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	card3_img.size = Vector2(80, 80)
	card3_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card3_img.position = Vector2(card_w / 2 - 40, card_h / 2 - 60)

	card1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card1_label.size = Vector2(card_w, 80)
	card1_label.position = Vector2(0, card_h / 2 + 30)

	card2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card2_label.size = Vector2(card_w, 80)
	card2_label.position = Vector2(0, card_h / 2 + 30)

	card3_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card3_label.size = Vector2(card_w, 80)
	card3_label.position = Vector2(0, card_h / 2 + 30)
	
	card1.clip_contents = true
	card2.clip_contents = true
	card3.clip_contents = true

	# ── 스테이지 모디파이어 표시 ──
	_show_modifier_banner()

func _on_card1_pressed() -> void:
	apply_upgrade(current_choices[0]["id"])

func _on_card2_pressed() -> void:
	apply_upgrade(current_choices[1]["id"])

func _on_card3_pressed() -> void:
	apply_upgrade(current_choices[2]["id"])

func apply_upgrade(id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	upgrade_counts[id] = upgrade_counts.get(id, 0) + 1
	is_first_card = false
	
	if id == "none":
		is_first_card = false
		hide()
		get_tree().paused = false
		emit_signal("upgrade_chosen")
		return
	match id:
		"fist_dmg":
			player.fist_bonus_multiplier += 0.3
			player.fist_damage = GameData.get_total_attack() * (1.0 + player.fist_bonus_multiplier)
			player.fist_cooldown *= 0.7
		"fist_targets":
			player.fist_targets += 1
		"stone_unlock": player.stone_unlocked = true
		"stone_count":
			player.stone_count += 1
			player.stone_damage *= 0.85
		"stone_range":
			player.stone_range += 30.0
			player.stone_stun_duration += 0.5
		"stone_dmg":
			player.stone_damage *= 1.5
		"stick_unlock": player.stick_unlocked = true
		"stick_range":
			player.stick_damage *= 1.5
		"stick_targets":
			player.stick_targets *= 2
			player.stick_damage *= 0.85
		"stick_sweep":
			player.stick_range += 50.0
		"flame_unlock":
			player.flame_unlocked = true
		"flame_range":
			player.flame_range_bonus += player.flame_range * 0.3
		"flame_spread":
			player.flame_can_spread = true
		"flame_spread_range":
			player.flame_spread_multiplier *= 1.5
		"arrow_unlock":
			player.arrow_unlocked = true
		"arrow_bounce":
			player.arrow_bounce_count += 2
		"arrow_bounce2":
			player.arrow_bounce_count += 2
		"arrow_count":
			player.arrow_count += 1
			player.arrow_dmg_multiplier *= 0.85
		"arrow_dmg":
			player.arrow_dmg_multiplier *= 1.3
			player.arrow_damage = GameData.get_total_attack() * player.ARROW_MULT * player.arrow_dmg_multiplier
		"net_unlock":
			player.net_unlocked = true
		"net_range":
			player.net_range += 80.0
		"net_pull":
			player.net_pull_force += 60.0
		"net_duration":
			player.net_duration += 1.0
		"shaman_atk_unlock":
			player.shaman_atk_unlocked = true
		"shaman_spd_unlock":
			player.shaman_spd_unlocked = true
		"shaman_seal_unlock":
			player.shaman_seal_unlocked = true
	hide()
	get_tree().paused = false
	emit_signal("upgrade_chosen")

func _on_card_1_pressed() -> void:
	pass
func _on_card_2_pressed() -> void:
	pass
func _on_card_3_pressed() -> void:
	pass

func _show_modifier_banner() -> void:
	# 최초 카드 선택시에만 표시
	if not is_first_card:
		return

	# 기존 배너 제거
	var existing = $Background.get_node_or_null("ModifierBanner")
	if existing:
		existing.queue_free()

	var d = GameData.stage_modifier_debuff
	var b = GameData.stage_modifier_buff
	if d == -1 or b == -1:
		return

	var screen_size = get_viewport().get_visible_rect().size
	var card_y = screen_size.y / 2 - (screen_size.x - 60) / 3 * 1.5 / 2

	var container = VBoxContainer.new()
	container.name = "ModifierBanner"
	container.position = Vector2(0, card_y - 230)
	container.custom_minimum_size = Vector2(screen_size.x, 0)
	container.add_theme_constant_override("separation", 6)
	$Background.add_child(container)

	# 안내 문구
	var title_lbl = Label.new()
	title_lbl.text = "이번 전투에서 선택된 무작위 효과"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_lbl.add_theme_constant_override("outline_size", 2)
	container.add_child(title_lbl)

	var banner = HBoxContainer.new()
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_theme_constant_override("separation", 20)
	container.add_child(banner)

	var debuff_names = ["근접 피해 -50%", "원거리 피해 -50%", "밀려남 -50%",
		"경직 시간 -50%", "지속피해 횟수 -50%", "공격 거리 -50%", "공격 범위 -50%"]
	var debuff_panel = _make_modifier_card(debuff_names[d], Color(0.8, 0.2, 0.2), Color(1.0, 0.4, 0.4))
	banner.add_child(debuff_panel)

	var buff_names = ["근접 피해 +50%", "원거리 피해 +50%", "밀려남 +50%",
		"경직 시간 +50%", "지속피 횟수 +50%", "공격 거리 +50%", "공격 범위 +50%",
		"경험치 +50%", "재화 +50%"]
	var buff_panel = _make_modifier_card(buff_names[b], Color(0.1, 0.4, 0.1), Color(0.3, 0.9, 0.3))
	banner.add_child(buff_panel)

func _make_modifier_card(text: String, bg_color: Color, border_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 52)
	var st = StyleBoxFlat.new()
	st.bg_color = bg_color
	st.border_color = border_color
	st.border_width_top    = 2
	st.border_width_bottom = 2
	st.border_width_left   = 2
	st.border_width_right  = 2
	st.corner_radius_top_left     = 10
	st.corner_radius_top_right    = 10
	st.corner_radius_bottom_left  = 10
	st.corner_radius_bottom_right = 10
	st.content_margin_left  = 12
	st.content_margin_right = 12
	st.content_margin_top   = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", st)
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	panel.add_child(lbl)
	return panel
