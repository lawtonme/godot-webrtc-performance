extends Node2D

export(Color) var color := Color.white

const USE_WEBRTC := false

const _RUN_SPEED = 132.0
const _GRAVITY: float = 900.0
const _JUMP_VELOCITY: float = -582.0
const _TERMINAL_VELOCITY: float = 420.0

var velocity := Vector2.ZERO

class PlayerInput extends Reference:
	var run_direction: int
	var jump: bool
	var frame: int



class PlayerState extends Reference:
	var position: Vector2
	var frame: int



func process_input(delta: float, input: PlayerInput) -> void:
	velocity.x = input.run_direction * _RUN_SPEED
	position.x += velocity.x * delta
	position.x = clamp(position.x, 0.0, 1024.0)

	var is_on_ground = position.y >= 549.0
	if is_on_ground:
		position.y = 549.0
		velocity.y = 0

	if is_on_ground and input.jump:
		velocity.y = _JUMP_VELOCITY
	else:
		velocity.y += _GRAVITY * delta

	if velocity.y > _TERMINAL_VELOCITY:
		velocity.y = _TERMINAL_VELOCITY

	position.y += velocity.y * delta


func _draw():
	draw_rect(Rect2(-14.0, -57.0, 28.0, 58.0), color)
