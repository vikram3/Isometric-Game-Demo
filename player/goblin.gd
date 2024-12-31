extends CharacterBody2D

const MOTION_SPEED = 160
const KNOCKBACK_FORCE = 300
const MAX_HITS = 5  # Player dies after 5 hits
const ATTACK_RANGE = 100

var last_direction = Vector2(1, 0)
var hits_taken = 0
var is_being_knocked_back = false
var knockback_timer = 0.0
const KNOCKBACK_DURATION = 0.3
var can_attack = true
const ATTACK_COOLDOWN = 0.5
var attack_timer = 0.0

@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null

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
	add_to_group("player")

func _physics_process(delta):
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	if is_being_knocked_back:
		knockback_timer -= delta
		if knockback_timer <= 0:
			is_being_knocked_back = false
			velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var motion = Vector2()
	motion.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	motion.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	motion.y /= 2
	motion = motion.normalized() * MOTION_SPEED
	
	set_velocity(motion)
	move_and_slide()
	
	var dir = velocity
	if dir.length() > 0:
		last_direction = dir.normalized()
		update_animation("walk")
	else:
		update_animation("idle")
		
	if Input.is_action_just_pressed("attack") and can_attack:
		attack()

func update_animation(anim_set):
	var angle = rad_to_deg(last_direction.angle()) + 22.5
	angle = fmod(angle + 360, 360)
	var slice_dir = int(angle / 45) % 8
	
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
	
	# Play hit animation if available
	if animation_player:
		animation_player.play("hit")

func die():
	# Add death animation
	if animation_player:
		animation_player.play("death")
		await animation_player.animation_finished
	
	# Implement game over logic here
	var game_over_screen = load("res://Scenes/GameOver.tscn").instantiate()
	get_tree().root.add_child(game_over_screen)
	queue_free()

func attack():
	if not can_attack:
		return
		
	can_attack = false
	attack_timer = ATTACK_COOLDOWN
	
	# Play attack animation if available
	if animation_player:
		animation_player.play("attack")
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < ATTACK_RANGE:
			var attack_direction = (enemy.global_position - global_position).normalized()
			# Check if enemy is roughly in the direction we're facing
			if attack_direction.dot(last_direction) > 0.5:  # This creates roughly a 90-degree attack arc
				enemy.apply_knockback(attack_direction * KNOCKBACK_FORCE)
