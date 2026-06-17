extends Node2D

var hp: float = 999999999.0
var max_hp: float = 999999999.0
var move_speed: float = 40.0
var velocity: Vector2 = Vector2.ZERO
var hit_offsets: Array = [
	Vector2(-80, -40), Vector2(-40, -60), Vector2(0, -50), Vector2(40, -60), Vector2(80, -40),
	Vector2(-80, 20), Vector2(-40, 30), Vector2(0, 20), Vector2(40, 30), Vector2(80, 20),
]
var hit_nodes: Array = []

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp

	var sprite = Sprite2D.new()
	if ResourceLoader.exists("res://mammoth_hunt.png"):
		sprite.texture = load("res://mammoth_hunt.png")
	sprite.scale = Vector2(1.0, 1.0)
	add_child(sprite)

	# 타격 지점마다 별도 노드 생성 (각각 take_damage 보유, 같은 group "enemies"에 등록)
	for offset in hit_offsets:
		var hp_node = Node2D.new()
		hp_node.set_script(load("res://scripts/MammothHitPoint.gd"))
		hp_node.position = offset
		hp_node.set("parent_mammoth", self)
		add_child(hp_node)
		hp_node.add_to_group("enemies")
		hit_nodes.append(hp_node)

func _process(delta: float) -> void:
	global_position += Vector2(sin(Time.get_ticks_msec() * 0.0003 + get_instance_id()), cos(Time.get_ticks_msec() * 0.0002 + get_instance_id())) * move_speed * delta
	var screen = get_viewport().get_visible_rect().size
	global_position.x = clamp(global_position.x, 100, screen.x - 100)
	global_position.y = clamp(global_position.y, 100, screen.y - 100)

func take_damage(amount: float) -> void:
	_register_hit(amount, global_position)

func apply_burn(dmg: float, ticks: int, _can_spread: bool, _spread_count: int, _is_slowed: bool) -> void:
	for i in range(ticks):
		await get_tree().create_timer(0.5).timeout
		_register_hit(dmg, global_position)

func _register_hit(amount: float, hit_pos: Vector2) -> void:
	var game = get_tree().current_scene
	if game.has_method("_on_mammoth_hit"):
		game._on_mammoth_hit(amount)

	var dmg_label = Label.new()
	dmg_label.text = str(int(amount))
	dmg_label.add_theme_font_size_override("font_size", 18)
	dmg_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	dmg_label.add_theme_constant_override("outline_size", 2)
	dmg_label.global_position = hit_pos - Vector2(15, 30)
	dmg_label.z_index = 10
	get_parent().add_child(dmg_label)
	var tween = get_tree().create_tween()
	tween.tween_property(dmg_label, "position", dmg_label.position - Vector2(0, 30), 0.5)
	tween.parallel().tween_property(dmg_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(dmg_label):
			dmg_label.queue_free()
	)
