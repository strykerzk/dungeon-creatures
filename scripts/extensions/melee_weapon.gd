class_name MeleeWeapon extends Weapon

@export_group("Melee Settings")
@export var is_tackle_modifier: bool = false
@export var hitbox: Hitbox # Scene-specific hitbox (sword arc, etc.)
@export var swing_sprite: Sprite2D
@export var animation_player: AnimationPlayer
var is_swinging: bool = false

func activate(base_damage: float, p_attacker: Creature) -> void:
	super(base_damage,p_attacker)
	
	is_swinging = true
	var target_hb = hitbox
	
	# If this weapon is a Tackle Modifier (like Spikes), use the creature's body hitbox
	if is_tackle_modifier and attacker.get("body_hitbox"):
		target_hb = attacker.get("body_hitbox")
	
	if not target_hb: return
	
	target_hb.damage_value = base_damage
	target_hb.attacker = attacker
	
	if animation_player:
		animation_player.play("attack")
		await animation_player.animation_finished
	else:
		_toggle_hitbox(target_hb, true)
		await get_tree().create_timer(0.2).timeout
		_toggle_hitbox(target_hb, false)
	is_swinging = false

func _toggle_hitbox(hb: Area2D, active: bool) -> void:
	hb.monitoring = active

func look_at_direction(look_direction: Vector2) -> void:
	var look_angle = look_direction.angle()
	if is_swinging:
		sprite.rotation = look_angle
	swing_sprite.rotation = look_angle
	hitbox.rotation = look_angle
	sprite.flip_h = look_direction.x > 0
