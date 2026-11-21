## Sit (spec 4.5, 7.3, 12.6): snap to a seat marker, collider off, stamina regen, stand at a
## validated exit point. Exits on duck, move > 0.5 or jump (the jump does not also jump).
## Works with any seat provider (built pieces, room decor): `seats`, `exits`, `free_seat`,
## `seat_regen`.
extends PlayerState

var piece: Node3D
var seat := -1
var regen := 0.5
var _acc := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var focus := player.focused_interactable()
	var host: Node = focus.get_parent() if focus else null
	piece = host as Node3D if host and host.has_method("free_seat") else null
	seat = piece.free_seat(player) if piece else -1
	_acc = 0.0
	if seat < 0:
		return
	regen = float(piece.seat_regen()) if piece.has_method("seat_regen") else Database.stamina.sit_regen_per_sec
	player.velocity = Vector3.ZERO
	player.global_position = piece.seats[seat]
	player.set_seated(true)


func physics_tick(delta: float, _f: InputFrame) -> void:
	if seat < 0:
		return
	_acc += regen * delta
	if _acc >= 1.0:
		var n := floori(_acc)
		_acc -= n
		player.session().stamina.restore(n, &"sit")


func exit() -> void:
	if seat < 0:
		return
	var exit_pos: Vector3 = piece.exits[seat] if is_instance_valid(piece) and seat < piece.exits.size() else player.global_position + Vector3(0, 0, 1)
	var seat_pos: Vector3 = player.global_position
	player.global_position = player.find_stand_position(exit_pos, seat_pos)
	player.set_seated(false)
	player.arm_resume_guard()
	seat = -1


func freezes_body() -> bool:
	return seat >= 0


func locks_tool() -> bool:
	return true
