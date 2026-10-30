class_name DungeonEnemy
extends CharacterBody2D

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle.tscn")

@export var display_name: String = "Training enemy"
@export_range(1, 100, 1) var max_health: int = 12
@export_range(1, 20, 1) var attack_damage: int = 3
## Number of combatants represented by this encounter in the exploration scene.
@export_range(1, 6, 1) var encounter_size: int = 1
@export_range(128.0, 400.0, 1.0) var interaction_distance: float = 192.0

var _battle_pending: bool = false

@onready var _interaction_hint: Label = $InteractionHint


func _ready() -> void:
	add_to_group("enemies")


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	_interaction_hint.visible = is_instance_valid(player) and can_interact(player)


func can_interact(player: CharacterBody2D) -> bool:
	if _battle_pending or global_position.distance_to(player.global_position) > interaction_distance:
		return false
	# Nearby enemies cannot be engaged through a wall.
	var query := PhysicsRayQueryParameters2D.create(player.global_position, global_position)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == self


func start_battle() -> void:
	if _battle_pending:
		return
	_battle_pending = true
	# Scene changes must happen outside the physics callback.
	_open_battle.call_deferred()


func _open_battle() -> void:
	var level := get_tree().current_scene as Node2D
	if level == null:
		_battle_pending = false
		return
	var battle := BATTLE_SCENE.instantiate()
	battle.enemy_name = display_name
	battle.enemy_max_health = max_health
	battle.enemy_attack = attack_damage
	battle.enemy_count = encounter_size
	battle.battle_finished.connect(_on_battle_finished.bind(level, level.process_mode))
	# Keep the level in memory so positions and other NPCs survive the battle.
	level.hide()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle


func _on_battle_finished(victory: bool, level: Node2D, previous_process_mode: int) -> void:
	get_tree().current_scene = level
	level.process_mode = previous_process_mode
	level.show()
	_battle_pending = false
	if victory:
		queue_free()
