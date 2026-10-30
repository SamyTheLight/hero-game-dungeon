extends CanvasLayer
## Displays a battle and reports its result to the suspended exploration scene.

signal battle_finished(victory: bool)

const ENEMY_CARD: PackedScene = preload("res://scenes/combat_enemy_card.tscn")

var enemy_name: String = "Training enemy"
var enemy_max_health: int = 12
var enemy_attack: int = 3
var enemy_count: int = 1
var state: DiceBattleState
var _is_leaving: bool = false
var _enemy_cards: Array[Button] = []

@onready var _round_label: Label = %RoundLabel
@onready var _hero_health: Label = %HeroHealth
@onready var _hero_block: Label = %HeroBlock
@onready var _enemy_summary: Label = %EnemySummary
@onready var _enemy_container: HBoxContainer = %EnemyCards
@onready var _phase_label: Label = %PhaseLabel
@onready var _die_result: Label = %DieResult
@onready var _reroll_button: Button = %RerollButton
@onready var _keep_button: Button = %KeepButton
@onready var _use_button: Button = %UseButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _retreat_button: Button = %RetreatButton
@onready var _return_button: Button = %ReturnButton
@onready var _battle_log: Label = %BattleLog


func _ready() -> void:
	state = DiceBattleState.new(enemy_max_health, enemy_attack, enemy_count, enemy_name)
	_create_enemy_cards()
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_keep_button.pressed.connect(_on_keep_pressed)
	_use_button.pressed.connect(_on_use_pressed)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_retreat_button.pressed.connect(_return_to_level)
	_return_button.pressed.connect(_return_to_level)
	_refresh()


func _create_enemy_cards() -> void:
	for index in state.enemies.size():
		var card := ENEMY_CARD.instantiate() as Button
		_enemy_container.add_child(card)
		card.pressed.connect(_on_enemy_selected.bind(index))
		_enemy_cards.append(card)


func _on_enemy_selected(index: int) -> void:
	state.select_enemy(index)
	_refresh()


func _on_reroll_pressed() -> void:
	state.reroll()
	_refresh()


func _on_keep_pressed() -> void:
	state.keep_result()
	_refresh()


func _on_use_pressed() -> void:
	state.use_result()
	_refresh()


func _on_end_turn_pressed() -> void:
	state.end_turn()
	_refresh()


func _refresh() -> void:
	var rolling := state.phase == DiceBattleState.Phase.ROLLING
	var acting := state.phase == DiceBattleState.Phase.ACTING
	var finished := state.phase == DiceBattleState.Phase.FINISHED
	_round_label.text = "ROUND %d" % state.round_number
	_hero_health.text = "HP  %d / %d" % [state.hero_health, DiceBattleState.HERO_MAX_HEALTH]
	_hero_block.text = "Block: %d (this round)" % state.hero_block
	_enemy_summary.text = "Enemies: %d / %d alive  |  Incoming damage: %d" % [state.living_enemy_count(), state.enemies.size(), state.incoming_damage()]
	for index in _enemy_cards.size():
		_enemy_cards[index].refresh(state.enemies[index], state.selected_enemy_index == index, finished)
	var face := state.current_face()
	_die_result.text = "D6  [%d]     %s %d" % [state.face_index + 1, face["action"], face["value"]]
	if finished:
		_phase_label.text = "VICTORY" if state.victory else "DEFEAT"
		_enemy_summary.text = "Battle finished"
	elif rolling:
		_phase_label.text = "ROLL: reroll or keep this result."
	else:
		_phase_label.text = "ACT: use your result, then end your turn."
		if state.face_used:
			_phase_label.text = "Result used. End your turn when ready."
	_reroll_button.text = "Reroll (%d left)" % state.rerolls_left
	_reroll_button.disabled = not rolling or state.rerolls_left == 0
	_keep_button.disabled = not rolling
	_use_button.disabled = not acting or state.face_used
	_end_turn_button.disabled = not acting
	_retreat_button.visible = not finished
	_return_button.visible = finished
	_battle_log.text = "\n".join(state.history.slice(-4))


func _return_to_level() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	# Running this scene with F6 also allows returning to the test level.
	if battle_finished.get_connections().is_empty():
		get_tree().change_scene_to_file("res://scenes/Test_level.tscn")
	else:
		battle_finished.emit(state.victory)
		queue_free()
