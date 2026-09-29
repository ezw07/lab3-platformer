extends CharacterBody2D

enum State { IDLE, RUN, AIR }

@export var speed: float = 300.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

const TEXTURES := {
	State.IDLE: preload("res://assets/player-idle.png"),
	State.RUN: preload("res://assets/player-run.png"),
	State.AIR: preload("res://assets/player-jump.png"),
}

var state: State = State.IDLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	if direction != 0.0:
		$Sprite2D.flip_h = direction < 0

	match state:
		State.IDLE:
			if Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
			if not is_on_floor():
				_change_state(State.AIR)
			elif direction != 0.0:
				_change_state(State.RUN)
		State.RUN:
			if Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
			if not is_on_floor():
				_change_state(State.AIR)
			elif direction == 0.0:
				_change_state(State.IDLE)
		State.AIR:
			if is_on_floor():
				_change_state(State.IDLE if direction == 0.0 else State.RUN)

	move_and_slide()

func _change_state(new_state: State) -> void:
	state = new_state
	$Sprite2D.texture = TEXTURES[new_state]
