extends SceneTree
## Run with: godot --headless --path . --fixed-fps 60 --script res://tests/test_combat.gd

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error(description)
		_failures += 1


func _run() -> void:
	_test_rules()
	_test_group_rules()
	await _test_exploration_battle_round_trip()
	await _test_group_encounter()
	print("Combat checks complete. Failures: %d" % _failures)
	quit(0 if _failures == 0 else 1)


func _test_rules() -> void:
	var state := DiceBattleState.new()
	_expect(not state.use_result() and not state.end_turn(), "rolling prevents acting early")
	_expect(state.reroll() and state.reroll() and not state.reroll(), "exactly two rerolls per round")
	_expect(state.face_index >= 0 and state.face_index < 6, "D6 produces a valid face")
	state.face_index = 2
	state.keep_result()
	_expect(not state.reroll(), "keeping a result locks out rerolls")
	state.use_result()
	_expect(state.enemies[0].health == 9 and not state.use_result(), "attack applies once per round")
	state.end_turn()
	_expect(state.hero_health == 17 and state.rerolls_left == 2, "enemy attacks and next round restores rerolls")
	state.face_index = 3
	state.keep_result()
	state.use_result()
	state.end_turn()
	_expect(state.hero_health == 16 and state.hero_block == 0, "block absorbs damage and expires")
	state.face_index = 4
	state.keep_result()
	state.use_result()
	state.end_turn()
	_expect(state.hero_health == 16, "full block prevents all incoming damage")
	state.hero_health = 19
	state.face_index = 5
	state.keep_result()
	state.use_result()
	_expect(state.hero_health == 20, "healing respects maximum health")
	var winning := DiceBattleState.new(1, 3)
	winning.face_index = 0
	winning.keep_result()
	winning.use_result()
	_expect(winning.victory and winning.enemies[0].health == 0 and not winning.end_turn(), "lethal attack wins without retaliation")
	var losing := DiceBattleState.new()
	losing.hero_health = 1
	losing.keep_result()
	losing.end_turn()
	_expect(losing.phase == DiceBattleState.Phase.FINISHED and losing.hero_health == 0, "defeat ends combat without negative health")
	_expect(not losing.reroll() and not losing.use_result() and not losing.end_turn(), "finished battles reject further actions")


func _test_group_rules() -> void:
	var state := DiceBattleState.new(3, 2, 3, "Raider")
	_expect(state.enemies.size() == 3 and state.incoming_damage() == 6, "group encounter creates three independent enemies")
	_expect(not state.select_enemy(-1) and not state.select_enemy(3), "invalid target indices are rejected")
	state.select_enemy(1)
	state.face_index = 2
	state.keep_result()
	state.use_result()
	_expect(state.enemies[1].health == 0 and state.enemies[0].health == 3, "attack damages only the selected enemy")
	_expect(not state.victory and state.living_enemy_count() == 2, "one defeated enemy does not end a group battle")
	_expect(not state.select_enemy(1) and state.selected_enemy_index == 0, "dead targets are rejected and selection advances")
	state.end_turn()
	_expect(state.hero_health == 16 and state.incoming_damage() == 4, "only surviving enemies retaliate")
	var blocking := DiceBattleState.new(6, 2, 3)
	blocking.face_index = 4
	blocking.keep_result()
	blocking.use_result()
	blocking.end_turn()
	_expect(blocking.hero_health == 17 and blocking.hero_block == 0, "block is shared once across all enemy attacks")
	for turn in 2:
		state.face_index = 2
		state.keep_result()
		state.use_result()
		if not state.victory:
			state.end_turn()
	_expect(state.victory and state.living_enemy_count() == 0, "victory requires defeating the entire group")


func _test_exploration_battle_round_trip() -> void:
	root.size = Vector2i(1152, 648)
	var level = load("res://scenes/Test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player = level.get_node("Player")
	var enemy = level.get_node("Enemy")
	player.global_position = enemy.global_position - Vector2(300, 0)
	await physics_frame
	_expect(not enemy.can_interact(player), "interaction requires proximity")
	_press_interact(player)
	await process_frame
	_expect(current_scene == level, "E outside interaction range does not open a battle")
	player.global_position = enemy.global_position - Vector2(180, 0)
	await physics_frame
	_expect(enemy.can_interact(player), "nearby enemy is interactable")
	var saved_position: Vector2 = player.global_position
	_press_interact(player)
	await process_frame
	await process_frame
	var battle = current_scene
	_expect(battle != level and battle is CanvasLayer, "E opens the separate battle scene")
	if battle == level:
		return
	_expect(not level.visible and level.process_mode == Node.PROCESS_MODE_DISABLED, "exploration is suspended during battle")
	await process_frame
	var layout: VBoxContainer = battle.get_node("Screen/Margin/Layout")
	_expect(layout.get_combined_minimum_size().y <= 612.0, "battle interface fits the default window height")
	battle.get_node("%RerollButton").pressed.emit()
	_expect(battle.state.rerolls_left == 1, "reroll UI updates the battle state")
	for turn in 4:
		battle.state.face_index = 2
		battle.get_node("%KeepButton").pressed.emit()
		battle.get_node("%UseButton").pressed.emit()
		if not battle.state.victory:
			battle.get_node("%EndTurnButton").pressed.emit()
	_expect(battle.state.victory, "battle UI supports a complete victory")
	battle.get_node("%ReturnButton").pressed.emit()
	await process_frame
	_expect(current_scene == level and level.visible, "return restores exploration")
	_expect(player.global_position.is_equal_approx(saved_position), "return preserves the player's position")
	_expect(not is_instance_valid(enemy), "victory removes only the defeated enemy")
	# Spawn another enemy to test click-to-approach, defeat, retreat, and retry.
	enemy = load("res://scenes/enemy.tscn").instantiate()
	enemy.position = Vector2(1850, 1050)
	level.add_child(enemy)
	player.global_position = Vector2(1500, 1050)
	await physics_frame
	await process_frame
	var mouse_position: Vector2 = enemy.get_global_transform_with_canvas().origin
	var motion := InputEventMouseMotion.new()
	motion.position = mouse_position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = mouse_position
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	for frame in 240:
		if current_scene != level:
			break
		await physics_frame
	await process_frame
	battle = current_scene
	_expect(battle != level, "clicking a distant enemy approaches and opens battle")
	if battle == level:
		return
	battle.state.hero_health = 1
	battle.get_node("%KeepButton").pressed.emit()
	battle.get_node("%EndTurnButton").pressed.emit()
	_expect(not battle.state.victory and battle.state.hero_health == 0, "battle UI supports defeat")
	battle.get_node("%ReturnButton").pressed.emit()
	await process_frame
	_expect(is_instance_valid(enemy) and enemy.can_interact(player), "defeat leaves the enemy available for a retry")
	_press_interact(player)
	await process_frame
	await process_frame
	battle = current_scene
	_expect(battle != level, "enemy can be engaged again")
	if battle == level:
		return
	_expect(battle.state.hero_health == 20 and battle.state.enemies[0].health == 12, "retry starts with fresh battle health")
	battle.get_node("%RetreatButton").pressed.emit()
	await process_frame
	_expect(current_scene == level and is_instance_valid(enemy), "retreat restores the level and keeps the enemy")


func _test_group_encounter() -> void:
	var level = current_scene
	var player = level.get_node("Player")
	var encounter = level.get_node("Enemy2")
	var other_enemy: Node
	for enemy in get_nodes_in_group("enemies"):
		if enemy != encounter:
			other_enemy = enemy
			break
	player.global_position = encounter.global_position - Vector2(180, 0)
	await physics_frame
	var saved_position: Vector2 = player.global_position
	_press_interact(player)
	await process_frame
	await process_frame
	var battle = current_scene
	_expect(battle != level, "Enemy2 interaction opens the group battle")
	if battle == level:
		return
	_expect(battle.state.enemies.size() == 3, "Enemy2 supplies its three-enemy roster")
	var cards: HBoxContainer = battle.get_node("%EnemyCards")
	_expect(cards.get_child_count() == 3, "all three enemies appear as selectable cards")
	await process_frame
	var layout: VBoxContainer = battle.get_node("Screen/Margin/Layout")
	_expect(layout.get_combined_minimum_size().y <= 612.0, "multi-enemy interface fits the default window height")
	cards.get_child(1).pressed.emit()
	_expect(battle.state.selected_enemy_index == 1, "clicking a card selects that enemy")
	battle.state.face_index = 2
	battle.get_node("%KeepButton").pressed.emit()
	battle.get_node("%UseButton").pressed.emit()
	_expect(battle.state.enemies[1].health == 3 and battle.state.enemies[0].health == 6, "selected card receives the attack")
	battle.get_node("%EndTurnButton").pressed.emit()
	_expect(battle.state.hero_health == 17, "all three raiders act in their turn")
	for turn in 5:
		battle.state.face_index = 2
		battle.get_node("%KeepButton").pressed.emit()
		battle.get_node("%UseButton").pressed.emit()
		if not battle.state.victory:
			battle.get_node("%EndTurnButton").pressed.emit()
	_expect(battle.state.victory, "group battle UI supports defeating every enemy")
	_expect(cards.get_child(0).disabled and cards.get_child(1).disabled and cards.get_child(2).disabled, "defeated enemy cards cannot be selected")
	battle.get_node("%ReturnButton").pressed.emit()
	await process_frame
	_expect(current_scene == level and player.global_position.is_equal_approx(saved_position), "group victory restores the saved exploration position")
	_expect(not is_instance_valid(encounter) and is_instance_valid(other_enemy), "group victory removes only the Enemy2 encounter")


func _press_interact(player: Node) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	player._unhandled_input(event)
