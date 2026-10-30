extends Button
## A selectable combatant, including health, intent, and defeated state.

@onready var _name_label: Label = $Layout/EnemyName
@onready var _health_label: Label = $Layout/Health
@onready var _intent_label: Label = $Layout/Intent
@onready var _status_label: Label = $Layout/Status
@onready var _icon: TextureRect = $Layout/Icon


func refresh(enemy: BattleEnemyState, selected: bool, battle_finished: bool) -> void:
	_name_label.text = enemy.display_name
	_health_label.text = "HP  %d / %d" % [enemy.health, enemy.max_health]
	_intent_label.text = "Attack: %d damage" % enemy.attack_damage
	disabled = not enemy.is_alive() or battle_finished
	set_pressed_no_signal(selected and enemy.is_alive())
	_icon.modulate = Color(1, 0.55, 0.47) if enemy.is_alive() else Color(0.4, 0.4, 0.4)
	if not enemy.is_alive():
		_status_label.text = "DEFEATED"
		_intent_label.text = "Will not act"
	elif selected:
		_status_label.text = "SELECTED TARGET"
	else:
		_status_label.text = "Click to target"
	tooltip_text = "%s - %d HP, %d attack" % [enemy.display_name, enemy.health, enemy.attack_damage]
