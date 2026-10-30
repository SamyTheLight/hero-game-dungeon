class_name BattleEnemyState
extends RefCounted
## Per-enemy combat stats. Exploration nodes remain unchanged until battle ends.

var display_name: String
var max_health: int
var health: int
var attack_damage: int


func _init(enemy_name: String, starting_health: int, damage: int) -> void:
	display_name = enemy_name
	max_health = maxi(1, starting_health)
	health = max_health
	attack_damage = maxi(1, damage)


func is_alive() -> bool:
	return health > 0
