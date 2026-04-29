# Creature Combat Stat Guide
This document outlines the current combat statistics used in the project, categorized by their source and functionality.

## 1. Core Creature Stats
These are the foundational values defined in CreatureData and modified by creature.gd

A. Vitality and Mobility

Stat			Baseline	Range		Description
Max Health		100.0		1 - 500+	Total hit points. Recalculated on equip.
Speed			200.0		50 - 600	Base movement speed (pixels/sec). Influences dash distances.
Base Damage		10.0		1 - 100		Raw power before weapon multipliers are applied.

B. AI & Behavioral Stats

Stat			Baseline	Range		Description
IQ				5			1 - 10		Dodge Chance: 0.15 + (IQ * 0.07).
										Persistence: High IQ makes behaviors change slower
Aggression		0.5			0.0 - 1.0	Low (0.0): Cowardly. Stays far away, retreats often.
										High (1.0): Relentless. Stays close, never retreats.
Dexterity		1.0			0.1 - 3.0	Wind-up: 0.3 / dexterity
										Cooldown: Divides the base attack cooldown by max(0.1, (1.0 + (dexterity * 0.5)))
Precision		0.3			0.0 - 1.0	Accuracy: 1.0 is perfect aim. 0.0 has ±30° jitter.
Size			1.0			0.5 - 5.0	Physics: Scale and Acceleration (10.0 / size).

## 2. Equipment Resource Stats
Defined in EquipmentData.gd (.tres files). These modify the Creature's stats.

Stat			Type		Effect
Health Bonus	Flat		max_health += health_bonus
Speed Mult		Multiplier	speed *= speed_mult
Dex Bonus		Flat		dexterity += dexterity_bonus
Flat Damage		Flat		damage += flat_damage_bonus (Applied before Weapon Mult)
Attack CD		Float		Overrides the default 3.0s weapon cooldown.

## 3. Weapon Specific Stats
Stored in EquipmentData but utilized by specific weapon scripts.

A. Universal Weapon Stats

Stat			Description
Attack Range	The "Stand-off" distance the AI tries to maintain to attack.
Damage Mult		Multiplies the creature's total damage (Base + Flat).
Attack CD		The base time (seconds) between attacks. Defaults to 3.0.

B. Melee Specific (Tackle/Swing)

- is_tackle_modifier: (Boolean) If true, the weapon modifies the creature's body_hitbox (e.g., Spiked Armor).
- custom_hitbox_scale: (Float) Scales the size of the Area2D collision shape.
- Animation Timing: Uses AnimationPlayer to sync monitoring (active frames) with the lunge.

C. Ranged Specific

- Projectile Scene: The .tscn file to be instantiated.
- Muzzle Offset: Marker2D position where the projectile is spawned.
- Look Lock: Logic determines if the visual sprite rotates with the look_direction.

## 4. Derived Combat Formulas

These calculations happen in real-time within creature.gd.

Movement & Lunging
- Acceleration: 10.0 / size
- Retreat Threshold: attack_range * (1.1 - aggression)
- Lunge Speed: (attack_range * 1.3) / 0.25 (Distance covered during the 0.25s dash).

Timings
- Telegraph Duration: max(0.05, 0.3 / dexterity)
- Attack Cooldown: base_cooldown / max(0.1, (1.0 + (dexterity * 0.5)))
-- Note: base_cooldown is pulled from the weapon node or defaults to 3.0.

Damage Handshake
- Final Hit Value: (Creature.damage + Equipment.flat_damage_bonus) * Weapon.damage_mult
