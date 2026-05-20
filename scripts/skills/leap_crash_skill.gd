extends BaseSkill
class_name LeapCrashSkill

@export_group("Leap Settings")
@export var leap_duration: float = 0.5
@export var leap_height: float = 120.0
@export var base_damage: float = 20.0
@export var impact_radius: float = 90.0

func execute(target: Creature, attack_dir: Vector2) -> void:
	current_cooldown = cooldown_time
	if not creature or not is_instance_valid(target): return

	var start_pos = creature.global_position
	var end_pos = target.global_position

	# 1. Takeoff
	creature.is_invulnerable = true # Avoid taking damage mid-air!
	creature.is_dodging = true # Triggers the procedural spin animation
	
	# 2. The Arc (Using Godot Tweens)
	var tween = create_tween().set_parallel(true)
	
	# Move the physical body toward the target
	tween.tween_property(creature, "global_position", end_pos, leap_duration).set_trans(Tween.TRANS_LINEAR)
	
	# Move the PaperDoll UP then DOWN to simulate a jump arc
	if creature.paper_doll:
		tween.tween_property(creature.paper_doll, "position:y", -leap_height, leap_duration / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(creature.paper_doll, "position:y", 0.0, leap_duration / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# Wait for the landing
	await get_tree().create_timer(leap_duration).timeout

	# 3. The Impact
	creature.is_invulnerable = false
	creature.is_dodging = false
	
	creature.rpc("client_trigger_shake", 12.0)
	if get_node_or_null("SFXCrash"): $SFXCrash.play()
	if get_node_or_null("CrashParticles"): $CrashParticles.restart()
	
	# Deal Area-of-Effect Damage
	if multiplayer.is_server():
		var all_creatures = get_tree().get_nodes_in_group("creature")
		var final_dmg = base_damage + (creature.damage * 0.5) # Scales slightly with creature stats
		
		for c in all_creatures:
			if c != creature and is_instance_valid(c) and c.current_health > 0:
				if c.global_position.distance_to(creature.global_position) <= impact_radius:
					c.take_damage(final_dmg, creature)

	# Tiny recovery delay before the AI resumes
	await get_tree().create_timer(0.2).timeout
