extends BaseSkill
class_name FireballSkill

@export_group("Fireball Settings")
@export var projectile_scene: PackedScene
@export var spell_damage: float = 15.0

func execute(target: Creature, attack_dir: Vector2) -> void:
	current_cooldown = cooldown_time
	if not creature or not is_instance_valid(target) or not projectile_scene: return
	
	# Tell the clients to snap their visuals to point at the target
	creature.rpc("rpc_play_weapon_effects", 0.0, attack_dir)

	# Spawn the projectile (Only Host handles physical spawns)
	if multiplayer.is_server():
		var proj = projectile_scene.instantiate()
		creature.get_parent().add_child(proj)
		
		# Spawn it slightly above their feet
		proj.global_position = creature.global_position + Vector2(0, -30)
		
		if proj.has_method("launch"):
			proj.launch(attack_dir, spell_damage + creature.damage, creature)

	# Brief pause so they don't instantly start running
	await get_tree().create_timer(0.3).timeout
