class_name DiceBattleState
extends RefCounted
## Rules for a single-hero D6 battle, independent of the battle interface.

enum Phase { ROLLING, ACTING, FINISHED }

const HERO_MAX_HEALTH: int = 20
const REROLLS_PER_ROUND: int = 2
const DIE_FACES: Array[Dictionary] = [
	{"action": "Attack", "value": 1},
	{"action": "Attack", "value": 2},
	{"action": "Attack", "value": 3},
	{"action": "Block", "value": 2},
	{"action": "Block", "value": 3},
	{"action": "Heal", "value": 2},
]

var hero_health: int = HERO_MAX_HEALTH
var hero_block: int = 0
var enemies: Array[BattleEnemyState] = []
var selected_enemy_index: int = 0
var round_number: int = 1
var rerolls_left: int = REROLLS_PER_ROUND
var face_index: int = 0
var face_used: bool = false
var victory: bool = false
var phase: Phase = Phase.ROLLING
var history: Array[String] = []
var random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(max_enemy_health: int = 12, enemy_damage: int = 3, enemy_count: int = 1, enemy_name: String = "Training enemy") -> void:
	for index in maxi(1, enemy_count):
		var display_name := enemy_name
		if enemy_count > 1:
			display_name += " %d" % (index + 1)
		enemies.append(BattleEnemyState.new(display_name, max_enemy_health, enemy_damage))
	random.randomize()
	_start_round()


func current_face() -> Dictionary:
	return DIE_FACES[face_index]


func select_enemy(index: int) -> bool:
	if phase == Phase.FINISHED or index < 0 or index >= enemies.size():
		return false
	if not enemies[index].is_alive():
		return false
	selected_enemy_index = index
	return true


func living_enemy_count() -> int:
	var count: int = 0
	for enemy in enemies:
		if enemy.is_alive():
			count += 1
	return count


func incoming_damage() -> int:
	var damage: int = 0
	for enemy in enemies:
		if enemy.is_alive():
			damage += enemy.attack_damage
	return damage


func reroll() -> bool:
	if phase != Phase.ROLLING or rerolls_left == 0:
		return false
	rerolls_left -= 1
	_roll_die()
	return true


func keep_result() -> bool:
	if phase != Phase.ROLLING:
		return false
	phase = Phase.ACTING
	return true


func use_result() -> bool:
	if phase != Phase.ACTING or face_used:
		return false
	face_used = true
	var face := current_face()
	var value: int = face["value"]
	match face["action"]:
		"Attack":
			var target := enemies[selected_enemy_index]
			target.health = maxi(0, target.health - value)
			_record("Hero attacks %s for %d damage." % [target.display_name, value])
			if not target.is_alive():
				_record("%s is defeated." % target.display_name)
				_select_next_living_enemy()
		"Block":
			hero_block += value
			_record("Hero gains %d block for this round." % value)
		"Heal":
			var restored := mini(value, HERO_MAX_HEALTH - hero_health)
			hero_health += restored
			_record("Hero restores %d health." % restored)
	if living_enemy_count() == 0:
		phase = Phase.FINISHED
		victory = true
		_record("Victory! All enemies are defeated.")
	return true


func end_turn() -> bool:
	if phase != Phase.ACTING:
		return false
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		var blocked := mini(enemy.attack_damage, hero_block)
		hero_block -= blocked
		var damage := enemy.attack_damage - blocked
		hero_health = maxi(0, hero_health - damage)
		_record("%s attacks: %d damage, %d blocked." % [enemy.display_name, damage, blocked])
		if hero_health == 0:
			break
	# One shared block pool protects against all attacks this round, then expires.
	hero_block = 0
	if hero_health == 0:
		phase = Phase.FINISHED
		_record("Defeat. Return to the level to try again.")
	else:
		round_number += 1
		_start_round()
	return true


func _start_round() -> void:
	phase = Phase.ROLLING
	rerolls_left = REROLLS_PER_ROUND
	face_used = false
	_roll_die()
	_record("Round %d: %d enemies, %d incoming damage." % [round_number, living_enemy_count(), incoming_damage()])


func _select_next_living_enemy() -> void:
	for index in enemies.size():
		if enemies[index].is_alive():
			selected_enemy_index = index
			return


func _roll_die() -> void:
	face_index = random.randi_range(0, DIE_FACES.size() - 1)


func _record(message: String) -> void:
	history.append(message)
	if history.size() > 5:
		history.pop_front()
