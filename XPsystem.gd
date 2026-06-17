extends Node

const UPGRADES = [
	{"id": "atk",      "name": "공격력 증가",  "desc": "+5 공격력"},
	{"id": "spd",      "name": "이동속도 증가", "desc": "+20 이동속도"},
	{"id": "atkspd",   "name": "공격속도 증가", "desc": "+0.2 공격속도"},
	{"id": "hp",       "name": "체력 증가",    "desc": "+30 최대 체력"},
	{"id": "hp_regen", "name": "체력 회복",    "desc": "HP 20 회복"},
]

func get_random_choices(count: int = 3) -> Array:
	var pool = UPGRADES.duplicate()
	pool.shuffle()
	return pool.slice(0, count)

func apply_upgrade(id: String) -> void:
	match id:
		"atk":     GameData.player_attack += 5.0
		"spd":     GameData.player_move_speed += 20.0
		"atkspd":  GameData.player_attack_speed += 0.2
		"hp":
			GameData.player_max_hp += 30
			var p = get_tree().get_first_node_in_group("player")
			if p:
				p.hp = min(p.hp + 30, GameData.player_max_hp)
				p.hp_bar.max_value = GameData.player_max_hp
				p.hp_bar.value = p.hp
		"hp_regen":
			var p = get_tree().get_first_node_in_group("player")
			if p:
				p.hp = min(p.hp + 20, GameData.player_max_hp)
				p.hp_bar.value = p.hp
