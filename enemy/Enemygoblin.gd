extends CharacterBody2D

const MOTION_SPEED = 80
const PATROL_SPEED = 40
const CHASE_RANGE = 200
const KNOCKBACK_FORCE = 300
const MAX_HITS = 3  # Enemy dies after 3 hits

@onready var Player: CharacterBody2D = $"../Goblin"
@export var patrol_points: Array[Node] = []
@onready var hitbox: Area2D = $hitBox

var current_patrol_index = 0
var last_direction = Vector2(1, 0)
var player_position = Vector2()
var hits_taken = 0
var is_being_knocked_back = false
var knockback_timer = 0.0
const KNOCKBACK_DURATION = 0.3

var anim_directions = {
	"idle": [
		["side_right_idle", false],
		["45front_right_idle", false],
		["front_idle", false],
		["45front_left_idle", false],
		["side_left_idle", false],
		["45back_left_idle", false],
		["back_idle", false],
		["45back_right_idle", false],
	],
	"walk": [
		["side_right_walk", false],
		["45front_right_walk", false],
		["front_walk", false],
		["45front_left_walk", false],
		["side_left_walk", false],
		["45back_left_walk", false],
		["back_walk", false],
		["45back_right_walk", false],
	],
}

func _ready():
	add_to_group("enemy")
	# Connect hitbox signal


func _physics_process(delta):
	if is_being_knocked_back:
		knockback_timer -= delta
		if knockback_timer <= 0:
			is_being_knocked_back = false
			velocity = Vector2.ZERO
		move_and_slide()
		return
	if !is_instance_valid(Player):
		patrol()  # Default to patrol behavior if player doesn't exist
		return
		
	# Check if Player still exists in the scene tree
	if !Player or !Player.is_inside_tree():
		patrol()
		return
	player_position = Player.global_position
	if global_position.distance_to(player_position) <= CHASE_RANGE:
		chase_player()
	else:
		patrol()

func patrol():
	if patrol_points.size() == 0:
		return

	var target_position = patrol_points[current_patrol_index].global_position
	var direction_to_target = (target_position - global_position).normalized()
	var motion = direction_to_target * PATROL_SPEED
	
	set_velocity(motion)
	move_and_slide()
	last_direction = direction_to_target
	
	if global_position.distance_to(target_position) < 10:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	
	if motion.length() > 0:
		update_animation("walk")
	else:
		update_animation("idle")

func chase_player():
	var direction_to_player = (player_position - global_position).normalized()
	var motion = direction_to_player * MOTION_SPEED
	
	set_velocity(motion)
	move_and_slide()
	last_direction = direction_to_player
	update_animation("walk")

func update_animation(anim_set):
	var angle = rad_to_deg(last_direction.angle()) + 22.5
	angle = fmod(angle + 360, 360)  # Ensure angle is positive and within 360 degrees
	var slice_dir = int(angle / 45) % 8  # Ensure index is within bounds
	
	if slice_dir >= 0 and slice_dir < anim_directions[anim_set].size():
		$Sprite2D.play(anim_directions[anim_set][slice_dir][0])
		$Sprite2D.flip_h = anim_directions[anim_set][slice_dir][1]

func apply_knockback(direction: Vector2):
	hits_taken += 1
	if hits_taken >= MAX_HITS:
		die()
		return
		
	is_being_knocked_back = true
	knockback_timer = KNOCKBACK_DURATION
	velocity = direction

func die():
	# Add death animation or effects here if needed
	queue_free()

func _on_hit_box_body_entered(body: Node2D) -> void:
	if !is_instance_valid(body):  # Check if body is still valid
		return
	if body.is_in_group("player") and not is_being_knocked_back:
		if body.has_method("apply_knockback"):  # Check if method exists
			var knockback_direction = (body.global_position - global_position).normalized()
			body.apply_knockback(knockback_direction * KNOCKBACK_FORCE)
