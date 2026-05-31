extends RefCounted
class_name CombatData 

var attacker_id: int = -1
var team_id: int = 0
var damage: float = 0.0

func is_enemy(entity: Node) -> bool:
	if entity.get("player_id") == attacker_id:
		return false
	if team_id != 0 and entity.get("team_id") == team_id:
		return false
	return true
