class_name MeleeWeapon extends Weapon

@export_group("Melee Settings")
@export var is_tackle_modifier: bool = false
@export var hitbox: Hitbox # Scene-specific hitbox (sword arc, etc.)
@export var visual_sprite: Sprite2D
@export var attack_sprite: Sprite2D
@export var animation_player: AnimationPlayer

@onready var sfx_swing: AudioStreamPlayer2D = $SFXSwing

var is_swinging: bool = false


func activate(p_combat_data: CombatData) -> void:
	super(p_combat_data) # combat_data = p_combat_data
	
	is_swinging = true
	var target_hb: Hitbox = hitbox
	
	# If this weapon is a Tackle Modifier (like Spikes), use the creature's body hitbox
	if is_tackle_modifier and owner_creature and owner_creature.get("body_hitbox"):
		target_hb = owner_creature.body_hitbox
	
	if not target_hb: return
	
	target_hb.combat_data = combat_data
	
	if animation_player:
		animation_player.play("attack")
		if visual_sprite: visual_sprite.visible = false
		sfx_swing.play()
		await animation_player.animation_finished
		if visual_sprite: visual_sprite.visible = true
		sfx_swing.stop()
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
	attack_sprite.rotation = look_angle
	hitbox.rotation = look_angle
	sprite.flip_h = look_direction.x < 0
	if visual_sprite: visual_sprite.flip_h = look_direction.x < 0

func reposition_visual(destination: Node) -> void:
	visual_sprite.reparent(destination, false)

func _exit_tree() -> void:
	visual_sprite.queue_free()
