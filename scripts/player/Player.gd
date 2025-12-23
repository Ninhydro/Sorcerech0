class_name Player
extends CharacterBody2D

# — Player constants and exported properties —
@export var move_speed = 100.0   # Walking speed in pixels/sec
@export var jump_force = 250.0   # Jump impulse force (vertical velocity for jump)
var gravity  = 1000.0     # Gravity strength (pixels/sec^2)

#@export var allow_camouflage: bool = false
#@export var allow_time_freeze: bool = false
@export var telekinesis_enabled : bool = false
@export var current_magic_spot: MagusSpot = null
@export var canon_enabled : bool = false # Flag to indicate if player is in cannon mode
@onready var telekinesis_controller = $TelekinesisController
@export var UI_telekinesis : bool = false

var is_in_cannon = false   # True when inside a cannon (before launch)
var is_aiming = false      # True when aiming the cannon
var is_launched = false    # True when launched from a cannon and in flight
var launch_direction = Vector2.ZERO # Direction of cannon launch
var launch_speed = 500.0 # Adjust as needed for cannon launch velocity
var aim_angle_deg = -90 # Default straight up for cannon aim

var facing_direction := 1 # 1 for right, -1 for left

var states = {}
var current_state: BaseState = null
var state_order = [ "UltimateMagus", "Magus","Normal", "Cyber", "UltimateCyber"]
#0=ultmagus,1=magus,2=normal,3=cyber,4=ultcyber
var current_state_index = 2
var unlocked_states: Array[String] = ["Normal"]  # Start with only Normal state unlocked
# Maintain a separate dictionary to track unlocked status
var unlocked_flags = {
	"UltimateMagus": false,
	"Magus": false,
	"Normal": true,
	"Cyber": false,
	"UltimateCyber": false
}

var combat_fsm

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var can_switch_form := true
var can_attack := true
var can_skill := true
var still_animation := false

@onready var form_cooldown_timer: Timer = $FormCooldownTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var skill_cooldown_timer: Timer = $SkillCooldownTimer
@onready var player_timer: Timer = $PlayerTimer
@onready var sprite = $Sprite2D
@onready var NormalColl = $CollisionShape2D

@onready var AreaAttack = $AttackArea
@onready var AreaAttackColl = $AttackArea/CollisionShape2D
#@export var health = 100
#@export var health_max = 100
#@export var health_min = 0

@export var money = 0

@onready var Hitbox = $Hitbox
var can_take_damage: bool
var dead: bool
var player_hit: bool = false

var knockback_velocity := Vector2.ZERO
var knockback_duration := 0.2
var knockback_timer := 0.0

var is_grappling := false
var grapple_joint := Vector2.ZERO
var grapple_length := 0.0

var is_grappling_active := false # Flag to tell player.gd when grapple is active

@onready var grapple_hand_point: Marker2D = $GrappleHandPoint
@onready var grapple_line: Line2D = $GrappleLine

const FLOOR_NORMAL: Vector2 = Vector2(0, -1) # Standard for side-scrolling 2D

var wall_jump_just_happened = false
var wall_jump_timer := 0.5
const WALL_JUMP_DURATION := 0.3

@export var fireball_scene: PackedScene =  preload("res://scenes/objects/Fireball.tscn") # Will hold the preloaded Fireball.tscn
@onready var fireball_spawn_point = $FireballSpawnPoint

@export var rocket_scene: PackedScene = preload("res://scenes/objects/Rocket.tscn") # Will hold the preloaded Rocket.tscn

@onready var combo_timer = $ComboTimer
var combo_timer_flag = true

var bounced_protection_timer := 0.0
const BOUNCE_GRACE := 0.2 # How long to ignore new bounce collisions after a bounce

var inventory = []


var _should_apply_loaded_position: bool = false 


signal health_changed(health, health_max)
signal form_changed(new_form_name)

@onready var LedgeRightLower = $Raycast/LedgeGrab/LedgeRightLower
@onready var LedgeRightUpper = $Raycast/LedgeGrab/LedgeRightUpper
@onready var LedgeRightUpper2 = $Raycast/LedgeGrab/LedgeRightUpper2
@onready var LedgeLeftLower = $Raycast/LedgeGrab/LedgeLeftLower
@onready var LedgeLeftUpper = $Raycast/LedgeGrab/LedgeLeftUpper
@onready var LedgeLeftUpper2 = $Raycast/LedgeGrab/LedgeLeftUpper2


var LedgeLeftON = false
var LedgeRightON = false
var LedgeLeftON2 = false
var LedgeRightON2 = false
var is_grabbing_ledge = false
var LedgePosition: Vector2 = Vector2.ZERO # The position where the player should hang
var LedgeDirection: Vector2 = Vector2.ZERO # The direction of the ledge (+1 for right, -1 for left)

@onready var camera = $CameraPivot/Camera2D

#@export var CollisionMap: TileMapLayer
var cannon_form_switched: bool = false
var previous_form: String = ""

var not_busy = true
@onready var effects = $Effects

var current_cannon: Node = null  # Reference to the current cannon we're in

var normal_collision_mask: int = 0
var cannon_collision_mask: int = 0



var area_pass_count: int = 0
var max_area_passes: int = 2
var is_area_goal_complete: bool = false
var area_goal_locked: bool = false
var last_area_pass_time: float = 0.0
var area_pass_cooldown: float = 0.5  # Minimum time between counting passes (seconds)

# Speed increase variables
var base_launch_speed: float = 500.0  # Store the original speed
var speed_increase_multiplier: float = 1.2  # 20% speed increase each pass
var current_speed_boost: float = 1.0  # Current speed multiplier

var last_bounce_direction: Vector2 = Vector2.ZERO
var bounce_direction_change_threshold: float = 0.3  # Minimum change required to count as new bounce

signal area_goal_completed()

@export var spike_damage_percentage: float = 5.0  # Percentage of max health lost from spikes
var last_save_position: Vector2 = Vector2.ZERO
var last_save_scene: String = ""

var damage_cooldown := false
var damage_cooldown_timer: Timer

@export var use_health_as_mana: bool = false

# Health costs per form (edit these numbers directly in the script)
const ATTACK_HEALTH_COSTS := {
	"Normal": 0,
	"Magus": 3,
	"Cyber": 2,
	"UltimateMagus": 4,
	"UltimateCyber": 5,
}

const SKILL_HEALTH_COSTS := {
	"Normal": 0,
	"Magus": 5,
	"Cyber": 1,
	"UltimateMagus": 5,
	"UltimateCyber": 8,
}

# Method to disable player input
func disable_input():
	print("Player: Input disabled.")
	set_physics_process(false) # Stop _physics_process from running normal movement
	set_process(false) 


# Method to enable player input
func enable_input():
	print("Player: Input enabled.")
	set_process_input(true)
	set_physics_process(true)
	set_process(true)


func _ready():
	#Global.affinity -= 5
	#Global.affinity += 10
	#Global.reset_persistent()
	camera.zoom = Vector2(0.8,0.8)
	camera.position = Vector2(0,-40)
	jump_force = 250.0

	normal_collision_mask = collision_mask & ~(1 << 1) # Remove layer 2 from mas
	cannon_collision_mask = collision_mask
	collision_mask = normal_collision_mask
	
	print("DEBUG: Player collision_mask on load: ", collision_mask)
	print("DEBUG: normal_collision_mask: ", normal_collision_mask)
	print("DEBUG: cannon_collision_mask: ", cannon_collision_mask)
	var layer_2_enabled = (collision_mask & (1 << 1)) != 0
	print("DEBUG: Layer 2 (bounce spots) enabled on load: ", layer_2_enabled)
	
	base_launch_speed = launch_speed
	
	Global.health = 50
	Global.register_player(self)
	effects.visible = false
	enable_input()
	Global.playerBody = self
	Global.playerAlive = true
	print(Global.playerBody)
	dead = false
	can_take_damage = true
	health_changed.emit(Global.health, Global.health_max) # Initial emit

	
	AreaAttack.monitoring = false
	AreaAttackColl.disabled = true
	
	combat_fsm = CombatFSM.new(self)
	add_child(combat_fsm)
	
	anim_tree.active = true
	sprite.modulate = Color(1,1,1,1)
	
	states["Normal"] = NormalState.new(self)
	states["Magus"] = MagusState.new(self)
	states["Cyber"] = CyberState.new(self)
	states["UltimateMagus"] = UltimateMagusState.new(self)
	states["UltimateCyber"] = UltimateCyberState.new(self)
	
	set_collision_mask_value(2, true)
	
	#unlock_state("Magus")
	#unlock_state("UltimateMagus")
	#unlock_state("Cyber")
	#unlock_state("UltimateCyber")
	
	damage_cooldown_timer = Timer.new()
	damage_cooldown_timer.one_shot = true
	add_child(damage_cooldown_timer)
	damage_cooldown_timer.timeout.connect(_on_damage_cooldown_timeout)

	# Check if there's loaded data from Global
	if Global.current_loaded_player_data != null and not Global.current_loaded_player_data.is_empty():
		print("Player._ready: Loaded data detected. Setting flag for deferred application.")
		# Set the flag to apply position in _physics_process
		_should_apply_loaded_position = true
		# Don't call apply_load_data here. It will be called in _physics_process
		
		# Immediately apply non-position data here if it's safe and needed before physics_process
		# Example: Health, forms, inventory can be set now.
		Global.health = Global.current_loaded_player_data.get("health", 100)
		var loaded_unlocked_states = Global.current_loaded_player_data.get("unlocked_states", ["Normal"])
		unlocked_flags = {
			"UltimateMagus": false, "Magus": false, "Normal": false,
			"Cyber": false, "UltimateCyber": false
		}
		unlocked_states.clear()
		for state_name in loaded_unlocked_states:
			unlock_state(state_name)
	
		if not unlocked_flags["Normal"]:
			unlock_state("Normal")
		
		
		inventory = Global.current_loaded_player_data.get("inventory", [])
		#money = Global.current_loaded_player_data.get("money", 0)

		var loaded_state_name = Global.current_loaded_player_data.get("current_state_name", "Normal")
		switch_state(loaded_state_name)
		current_state_index = unlocked_states.find(loaded_state_name)
		if current_state_index == -1: current_state_index = 0
		Global.selected_form_index = Global.current_loaded_player_data.get("selected_form_index", current_state_index)
		combat_fsm.change_state(IdleState.new(self)) # Reset FSM state

	else:

		print("Player._ready: No loaded data. Setting initial default state.")
		current_state_index = unlocked_states.find("Normal")
		if current_state_index == -1:
			current_state_index = 0
		Global.selected_form_index = current_state_index
		
		switch_state("Normal") # Ensure Normal state is active for new game
		combat_fsm.change_state(IdleState.new(self))
	
	

	#switch_state("Normal")



func _physics_process(delta):

	#print(Global.timeline)
	#Global.magus_form = true
	#print(can_attack)
	#print(Global.global_time_scale)
	#Global.timeline = 11
	#print(Global.timeline)
	if Input.is_action_just_pressed("debug1"):  # Assign a key like F1
		print("Player World Position: ", global_position)
		#Global.killing =  !Global.killing
		#print(Global.killing)
	
	
	Global.playerBody = self
	Dialogic.VAR.set_variable("player_current_form", get_current_form_id())
	Global.set_player_form(get_current_form_id())
	Global.current_form = get_current_form_id()
	
	if is_nan(velocity.x) or is_nan(velocity.y):
		print("EMERGENCY: Velocity was NaN! Resetting to zero.")
		velocity = Vector2.ZERO
		
	if _should_apply_loaded_position:
		print("Player._physics_process: Applying loaded position (one-time).")
		global_position = Vector2(Global.current_loaded_player_data.get("position_x"), Global.current_loaded_player_data.get("position_y"))
		velocity = Vector2.ZERO
		_should_apply_loaded_position = false
		Global.current_loaded_player_data = {}
		print("Player.gd: Position set to loaded: ", global_position)
		collision_mask = normal_collision_mask
		print("DEBUG: Collision mask forced to normal after load: ", collision_mask)
		


	# --- CUTSCENE OVERRIDE ---
	if Global.is_cutscene_active:
		velocity = Vector2.ZERO
	# --- END CUTSCENE OVERRIDE ---


	if combat_fsm:
		combat_fsm.update_physics(delta)
	if current_state:
		current_state.physics_process(delta)

	Global.playerDamageZone = AreaAttack
	Global.playerHitbox = Hitbox

	# Telekinesis UI state management
	if telekinesis_controller and telekinesis_controller.is_ui_open:
		UI_telekinesis = true
	else:
		UI_telekinesis = false


	var is_busy = (dead or Global.is_cutscene_active or player_hit or knockback_timer > 0 or 
				  is_grappling_active or Global.dashing or is_launched or canon_enabled or 
				  telekinesis_enabled or is_grabbing_ledge or area_goal_locked or
				  Global.attacking or Global.is_dialog_open or Global.teleporting)
	



	# --- Player Input and Movement (Only if NOT busy and NOT dead) ---
	if not dead and not Global.is_cutscene_active: # <-- IMPORTANT: Add Global.is_cutscene_active check here
		var input_dir = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

		# Facing direction based on input
		if Input.is_action_pressed("move_right") and not wall_jump_just_happened and not Global.is_dialog_open:
			facing_direction = 1
		elif Input.is_action_pressed("move_left") and not wall_jump_just_happened and not Global.is_dialog_open:
			facing_direction = -1

		# Wall jump timer decrement
		if wall_jump_timer > 0:
			wall_jump_timer -= delta
			if wall_jump_timer <= 0:
				wall_jump_just_happened = false

		# Knockback (applied even during cutscene if set externally)
		if knockback_timer > 0:
			velocity = knockback_velocity
			knockback_timer -= delta
		# Special states where player input is overridden
		elif canon_enabled and not is_launched:
				
			scale = Vector2(0.5, 0.5)
			velocity = Vector2.ZERO
			
			# Only switch form once when entering cannon mode
			if get_current_form_id() != "Normal":
		# Find the index of "Normal" in unlocked_states
				var normal_index = unlocked_states.find("Normal")
				if normal_index != -1:  # Make sure Normal form is actually unlocked
					current_state_index = normal_index
					switch_state("Normal")
					combat_fsm.change_state(IdleState.new(self))

					print("Cannon mode: Switched to Normal form")
			
			# Prevent form switching while in cannon mode
			# This ensures the player stays in Normal form during cannon mode
			#can_switch_form = false
			

		elif Global.dashing:
		# Apply gravity during dash
			velocity.y += gravity * delta
			
			# Move with the dash velocity
			move_and_slide()
			
			# Gradually reduce dash velocity
			velocity.x = lerp(velocity.x, 0.0, delta * 5)
		
		# End dash when velocity becomes small
			if abs(velocity.x) < 50:
				Global.dashing = false


		else: # Normal movement and input processing

			if not is_busy:
				#print(Global.loading)
				if facing_direction == -1: # No need for !dead check here, already done above
					sprite.flip_h = true
					AreaAttackColl.position = Vector2(-16,-8.75)
					grapple_hand_point.position = Vector2(-abs(grapple_hand_point.position.x), grapple_hand_point.position.y)

				else:
					sprite.flip_h = false
					AreaAttackColl.position = Vector2(16,-8.75)
					grapple_hand_point.position = Vector2(abs(grapple_hand_point.position.x), grapple_hand_point.position.y)


				# Apply horizontal movement based on input (only if not wall-jumping, dialog, or attacking)
				if not wall_jump_just_happened and not Global.is_dialog_open and not Global.attacking and not is_grabbing_ledge and not is_grappling_active and not Global.saving and not Global.loading:
					#print("movinggggggggg")
					velocity.x = input_dir * move_speed  #* Global.global_time_scale # Use 'speed' here for normal movement 
					if input_dir != 0:
						try_push_objects(Vector2(input_dir, 0))
				elif wall_jump_just_happened: #or current_form = cyber form,
					pass
				elif is_grabbing_ledge or Global.saving or Global.loading:
					velocity.x = 0
				else:
					velocity.x = 0 # Stop horizontal movement if dialog is open or attacking

				# Jumping (only if on floor, no dialog, no attacking)
				if is_on_floor() and Input.is_action_just_pressed("jump") and not Global.is_dialog_open and not Global.attacking and not is_grabbing_ledge and not is_grappling_active and not Global.saving and not Global.loading:
					if get_current_form_id() != "UltimateCyber":
						velocity.y = -jump_force
					elif get_current_form_id() == "UltimateCyber":
						# Ultimate Cyber jump is handled in its state
						pass
					#velocity.y = -jump_force # * Global.global_time_scale
				elif is_grabbing_ledge:
					velocity.y += gravity+delta

		
		if is_launched and cannon_form_switched:
	# Restore previous form after launch
			if previous_form != "" and previous_form != "Normal":
				switch_state(previous_form)
				Global.selected_form_index = unlocked_states.find(previous_form)
			cannon_form_switched = false
			previous_form = ""
		
		#if not canon_enabled and not can_switch_form:
		#	can_switch_form = true
		#	print("Exited cannon mode: Form switching re-enabled")
	

		if not is_busy:
			#print(Global.is_dialog_open)
			#print("not busy??")
			# Attack input (only if not dialog open)
			#print(is_busy)
			#print("player press attack000000000000")
	
			if Input.is_action_just_pressed("yes") and can_attack and not Global.is_dialog_open and not Global.near_save:
				print("player press attack")
				
				# --- HP COST FOR ATTACK ---
				if not _try_pay_health_for_attack():
					print("Attack cancelled: not enough HP.")
					return
				# --- END HP COST ---

				var current_form = get_current_form_id()
				var attack_started = false
				if current_form == "Cyber":
					attack_cooldown_timer.start(0.5)
					attack_started = true
					not_busy = false
				elif current_form == "Magus":
					attack_cooldown_timer.start(0.5)
					attack_started = true
					not_busy = false
				elif current_form == "UltimateCyber":
					attack_cooldown_timer.start(2.0)
					attack_started = true
					not_busy = false
				elif current_form == "UltimateMagus" and combo_timer_flag:
					combo_timer_flag = false
					combo_timer.start(0.5)
					attack_started = true
					not_busy = false
				
				if current_state and current_state.has_method("perform_attack"):
					current_state.perform_attack()
				
				if combat_fsm:
					combat_fsm.change_state(AttackState.new(self))

				start_cooldown()
				
				if attack_started:
					can_attack = false
			# Skill input (only if not dialog open)
			if Input.is_action_just_pressed("no") and can_skill and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause:
				print("player press skill")
				
				# --- HP COST FOR SKILL ---
				if not _try_pay_health_for_skill():
					print("Skill cancelled: not enough HP.")
					return
				# --- END HP COST ---
				
				var current_form = get_current_form_id()
				var skill_started = false
				if current_form == "UltimateMagus" and not_busy: # Check for UltimateMagus first
					skill_cooldown_timer.start(1.0)
					skill_started = true
					not_busy = false

				elif current_form == "Cyber":
					skill_cooldown_timer.start(0.1)
					skill_started = true
					not_busy = false

				elif current_form == "Magus" and not_busy:
					skill_cooldown_timer.start(4.0)
					skill_started = true
					not_busy = false
					if combat_fsm:
						combat_fsm.change_state(SkillState.new(self))

				elif current_form == "UltimateCyber" and not_busy:
					skill_cooldown_timer.start(9.0)
					skill_started = true
					not_busy = false
					if combat_fsm:
						combat_fsm.change_state(SkillState.new(self))
					
				if current_state and current_state.has_method("perform_skill"):
					current_state.perform_skill()
				
				start_cooldown()
				if skill_started:
					can_skill = false


			check_hitbox() 


	# --- Dead state ---
	if dead:
		velocity = Vector2.ZERO # Stop all movement if dead

	# --- CANNON AIMING AND LAUNCHING LOGIC (Can override cutscene if desired, or add Global.is_cutscene_active here too) ---
	# For simplicity, assuming cannon can still be controlled during a cutscene if desired.
	# If cutscene should disable cannon input, add 'and not Global.is_cutscene_active' to these Input checks.
	if is_aiming and is_instance_valid(current_cannon):
		var rotation_speed = 2.0  # Adjust rotation speed as neede
		if Input.is_action_pressed("move_left"):
			current_cannon.sprite_2d.rotation_degrees -= rotation_speed
		elif Input.is_action_pressed("move_right"):
			current_cannon.sprite_2d.rotation_degrees += rotation_speed
	
	# Sync the player's aim angle with cannon rotation
		current_cannon.sprite_2d.rotation_degrees = fmod(current_cannon.sprite_2d.rotation_degrees, 360)
	
	# Sync player aim with cannon rotation (adjusting for the 90-degree offset)
		aim_angle_deg = current_cannon.sprite_2d.rotation_degrees - 90
		update_aim_ui(aim_angle_deg)
		
	if is_in_cannon and is_aiming and Input.is_action_just_pressed("yes"):
		print("FIRE!")
		# Calculate launch direction accounting for the sprite's orientation
		if is_instance_valid(current_cannon):
			if current_cannon.has_method("get_launch_point_global_position"):
				global_position = current_cannon.get_launch_point_global_position()
			
			# If sprite faces right by default, use its rotation directly
			# If it faces up by default, subtract 90 degrees
			var cannon_rotation_rad = deg_to_rad(current_cannon.sprite_2d.rotation_degrees - 90)
			launch_direction = Vector2.RIGHT.rotated(cannon_rotation_rad)
		else:
			# Fallback to player's aim system
			launch_direction = Vector2.RIGHT.rotated(deg_to_rad(aim_angle_deg))
		
		last_bounce_direction = Vector2.ZERO
		is_aiming = false
		is_launched = true
		is_in_cannon = false
		
		# Make player visible again and clear cannon reference
		visible = true
		current_cannon = null
		
		#show_aim_ui(false)
		#animation_player.play("flying") # Play player's own flying animation
		
	if is_launched:
		# Apply the current launch velocity
		velocity = launch_direction * launch_speed

		var bounced_this_frame = false # Flag to track if a bounce occurred this physics frame

		# Decrement the bounce protection timer
		if bounced_protection_timer > 0:
			bounced_protection_timer -= delta
			if bounced_protection_timer < 0:
				bounced_protection_timer = 0 # Ensure it doesn't go negative

		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()

			if collider and collider.has_method("get_bounce_data"):

				var layer_2_bitmask = 1 << 1
				var can_collide_with_bounce = (collision_mask & layer_2_bitmask) != 0
				
				if can_collide_with_bounce and is_launched:
					if bounced_protection_timer > 0:
						continue
						
					var bounce_data = collider.get_bounce_data()
					var bounce_normal = bounce_data.normal
					var bounce_power = bounce_data.power

					if bounce_normal.length() > 0.01:
						bounce_normal = bounce_normal.normalized()
						
						# Calculate bounce
						var new_direction = velocity.bounce(bounce_normal).normalized()
						
						# Apply bounce
						launch_direction = new_direction
						velocity = launch_direction * launch_speed * bounce_power
						print("BOUNCED! New direction: ", launch_direction, " New velocity: ", velocity)
						bounced_this_frame = true
						bounced_recently()
						break
				else:
					# Player cannot collide with bounce spots or not in cannon mode
					print("Cannot bounce - collision disabled or not in cannon mode")
					continue

		# Apply gravity if launched and not on floor (for ballistic trajectory)
		if not is_on_floor():
			velocity.y += gravity * delta

		if (is_on_floor() or is_on_ceiling() or is_on_wall()) and bounced_protection_timer <= 0:
			is_launched = false
			#velocity = Vector2.ZERO # Stop movement
			canon_enabled = false # Exit cannon mode
			scale = Vector2(1,1)
			
			set_physics_process(true)
			set_process(true)
			#can_switch_form = true
			#can_attack = true
			#can_skill = true
			collision_mask = normal_collision_mask
			
			 # >>> hard reset all busy flags <<<
			telekinesis_enabled = false
			is_grappling_active = false
			is_grabbing_ledge = false
			Global.dashing = false
			Global.attacking = false
			Global.teleporting = false
			player_hit = false
			knockback_timer = 0.0
			area_goal_locked = false
			Global.is_cutscene_active = false
			# <<< end reset >>>
	
			if not is_area_goal_complete:
				reset_area_goal()
		
			visible = true
			current_cannon = null
			print("Player stopped on a non-bounce surface or came to rest.")
	else:
		# This else block handles normal gravity application when not launched, not in cannon, not telekinesis
		if not is_on_floor() and not is_in_cannon and not telekinesis_enabled and not Global.is_cutscene_active: # <-- Add cutscene check
			velocity.y += gravity * delta


	# This should be at the very end of _physics_process after all velocity calculations.
	handle_ledge_grab()
	move_and_slide()


	if not Global.is_cutscene_active and not is_busy: # <-- IMPORTANT: Add is_busy check here
		if Input.is_action_just_pressed("form_next"):
			Global.selected_form_index = (Global.selected_form_index + 1) % unlocked_states.size()
			print("Selected form: " + unlocked_states[Global.selected_form_index])

		if Input.is_action_just_pressed("form_prev"):
			Global.selected_form_index = (Global.selected_form_index - 1 + unlocked_states.size()) % unlocked_states.size()
			print("Selected form: " + unlocked_states[Global.selected_form_index])

		if Input.is_action_just_pressed("form_apply") and not dead and not Global.is_dialog_open  and can_switch_form == true:
			if not canon_enabled:
				if Global.selected_form_index != current_state_index:
					current_state_index = Global.selected_form_index
					switch_state(unlocked_states[current_state_index])
					combat_fsm.change_state(IdleState.new(self))
					can_switch_form = false
					form_cooldown_timer.start(1)

func start_cooldown():
	print("Cooldown started...")
	
	# Set the timer's wait time and start it
	player_timer.wait_time = 0.5
	player_timer.one_shot = true
	player_timer.start()
	
	# Pause the function until the timer times out
	await player_timer.timeout
	
	not_busy = true
	print("Cooldown finished!")
	
func get_current_form_id() -> String:
	if current_state_index >= 0 and current_state_index < unlocked_states.size():
		return unlocked_states[current_state_index]
	else:
		return "Normal"

func _input(event):
	if current_state:
		current_state.handle_input(event)
		
func switch_state(state_name: String) -> void:
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter()
	

	
	form_changed.emit(state_name) # Emit signal after form changes

	Dialogic.VAR.set_variable("player_current_form", state_name)
	print("Player.gd: Switched to form: ", state_name, ". Dialogic variable updated.")



func unlock_state(state_name: String) -> void:
	if unlocked_flags.has(state_name):
		unlocked_flags[state_name] = true
		unlocked_states = []
		for state in state_order:
			if unlocked_flags[state]:
				unlocked_states.append(state)
		
func lock_state(state_name: String) -> void:
	if unlocked_states.has(state_name) and state_name != "Normal":
		unlocked_states.erase(state_name)
		print("Locked state:" + state_name)
		
func enter_cannon(cannon_ref = null):
	is_in_cannon = true
	is_aiming = true
	velocity = Vector2.ZERO # Stop player movement when entering cannon
	#show_aim_ui(true)
	cannon_form_switched = false  # Reset flag when entering cannon
	print("Entered cannon and aiming.")
	current_cannon = cannon_ref
	visible = false
	collision_mask = cannon_collision_mask
	# Optionally disable animations or switch to a "cannon idle" sprite
	
func show_aim_ui(visible: bool):

	if has_node("AimUI"):
		$AimUI.visible = visible

func update_aim_ui(angle):

	if has_node("AimUI"):
		$AimUI.rotation_degrees = angle
	
func get_nearby_telekinesis_objects() -> Array[TelekinesisObject]:
	var results: Array[TelekinesisObject] = []
	var radius = 150

	var all = get_tree().get_nodes_in_group("TelekinesisObject")
	#print("Found in group:" + str(all.size()))

	for obj in all:
		#print("Checking:" + obj.name)
		var dist = obj.global_position.distance_to(global_position)
		#print("Distance to player:" + str(dist))
		if dist < radius:
			results.append(obj)

	#print("Final results:" + str(results))
	return results
	
func _on_form_cooldown_timer_timeout():
	can_switch_form = true
	#print("can form again")

func _on_attack_cooldown_timer_timeout():
	can_attack = true
	combo_timer_flag = true
	AreaAttack.monitoring = false
	#print("can atatck again")

func _on_skill_cooldown_timer_timeout():
	can_skill = true
	#print("can skill again")

func _on_animation_tree_animation_finished(anim_name):
	still_animation = false
	#print("animation end")

	
func _on_animation_player_animation_finished(anim_name):
	still_animation = false
	#print("animation end")


func check_hitbox():
	var hitbox_areas = $Hitbox.get_overlapping_areas()
	var damage: int = 0
	var hit_spike_ref: SpikeTrap = null

	if hitbox_areas:
		for area in hitbox_areas:
			# Spikes
			if area.is_in_group("boss_hitbox"):
				print("🎯 Found boss hitbox: ", area.name)
				damage = 12  # Default slam damage
				break
				
			if area.is_in_group("spikes"):
				hit_spike_ref = area as SpikeTrap
				break
			# Instant death
			elif area.is_in_group("instant_death"):
				Global.health = 0
				handle_death()
				return

	if can_take_damage:
		if damage > 0:
			print("💥 Player taking ", damage, " damage from boss hitbox")
			take_damage(damage)
		elif hit_spike_ref != null:
			respawn_nearby_spike(hit_spike_ref)
			
func take_damage(damage):
	print("Player taking damage: ", damage, " from source: ", get_stack())
	
	if damage != 0 and can_take_damage and not dead:
		# Set states immediately
		player_hit = true
		can_take_damage = false
		
		# Apply knockback and damage
		apply_knockback(Global.enemyAknockback)
		
		if Global.health > 0:
			Global.health -= damage
			print("player health: " + str(Global.health))
			
			if Global.health <= 0:
				Global.health = 0
				handle_death()
				return  # Stop here if player died
		
		# Emit health change signal
		health_changed.emit(Global.health, Global.health_max)
		


		
		# Start damage cooldown
		take_damage_cooldown(1.0)
		
		# Reset player_hit after animation completes
		await get_tree().create_timer(0.5).timeout
		player_hit = false
		
func _on_damage_cooldown_timeout():
	damage_cooldown = false
	
func handle_death():
	dead = true
	Global.playerAlive = false
	print("PLAYER DEAD")
	

	if combat_fsm:
		combat_fsm.change_state(DieState.new(self))
	
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group("boss1_cutscene"):
			if node.has_method("cancel_boss_battle_on_player_death"):
				node.cancel_boss_battle_on_player_death()

		for node in tree.get_nodes_in_group("boss2_cutscene"):
			if node.has_method("cancel_boss2_battle_on_player_death"):
				node.cancel_boss2_battle_on_player_death()
		
		for node in tree.get_nodes_in_group("replica_boss_cutscene"):
			if node.has_method("cancel_replica_boss_battle_on_player_death"):
				node.cancel_replica_boss_battle_on_player_death()
		
		for node in tree.get_nodes_in_group("gawr_boss_cutscene"):
			if node.has_method("cancel_gawr_boss_battle_on_player_death"):
				node.cancel_gawr_boss_battle_on_player_death()
	
		for node in tree.get_nodes_in_group("gigaster_boss_cutscene"):
			if node.has_method("cancel_gigaster_boss_battle_on_player_death"):
				node.cancel_gigaster_boss_battle_on_player_death()
				
		for node in tree.get_nodes_in_group("magus_king_boss_cutscene"):
			if node.has_method("cancel_magus_king_boss_battle_on_player_death"):
				node.cancel_magus_king_boss_battle_on_player_death()
	
	# Wait for death animation to play (adjust time as needed)
	await get_tree().create_timer(1.5).timeout
	
	# Reset to latest save point
	load_from_save_slot(1)


func load_from_save_slot(slot_number: int):
	print("Loading from save slot: ", slot_number)
	
	var slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + str(slot_number)
	
	# Load the game data
	var loaded_data = SaveLoadManager.load_game(slot_name)
	
	if not loaded_data.is_empty():
		var saved_scene_path = Global.current_scene_path
		
		if ResourceLoader.exists(saved_scene_path, "PackedScene"):
			print("Death respawn: Game loaded. Changing scene to: %s" % saved_scene_path)
			
			# Ensure game is unpaused before scene change
			get_tree().paused = false
			
			# Change scene to the saved one
			get_tree().change_scene_to_file.call_deferred(saved_scene_path)
			
		else:
			printerr("Death respawn: Error: Target scene path is invalid: %s" % saved_scene_path)
			# Fallback: reload current scene
			get_tree().reload_current_scene.call_deferred()
	else:
		print("Death respawn: Failed to load from slot: %s" % slot_name)
		# Fallback: reload current scene
		get_tree().reload_current_scene.call_deferred()
		
func respawn_at_save_point():
	# Reset health to max
	Global.health = Global.health_max
	
	# Reset player state
	dead = false
	Global.playerAlive = true
	player_hit = false
	can_take_damage = true
	Global.is_cutscene_active = false
	knockback_timer = 0
	is_grappling_active = false
	Global.dashing = false
	is_launched = false
	canon_enabled = false
	telekinesis_enabled = false
	is_grabbing_ledge = false
	Global.attacking =false
	Global.is_dialog_open = false
	Global.teleporting = false
	
	# Reset any other combat states
	if combat_fsm:
		combat_fsm.change_state(IdleState.new(self))
	
	# Reset visual effects
	sprite.modulate = Color(1, 1, 1)
	
	# Load from save slot 1
	SaveLoadManager.load_game("manual_save_1")
	
	# Emit health change signal
	health_changed.emit(Global.health, Global.health_max)

func respawn_nearby_spike(spike_ref: SpikeTrap = null):
	# Prevent re-entrance / chain-triggering
	if not can_take_damage or dead:
		return
	
	can_take_damage = false
	player_hit = true

	# Percentage damage from spikes
	var spike_damage = int((spike_damage_percentage / 100.0) * Global.health_max)
	Global.health = max(0, Global.health - spike_damage)

	# Death by spikes
	if Global.health <= 0:
		Global.health = 0
		health_changed.emit(Global.health, Global.health_max)
		handle_death()
		return

	# Decide where to respawn
	var safe_position: Vector2 = Vector2.ZERO

	# 1) Prefer spike's custom marker if set
	if spike_ref != null and is_instance_valid(spike_ref) and spike_ref.respawn_marker != null:
		safe_position = spike_ref.respawn_marker.global_position
	else:
		# 2) Fallback: search nearby safe tile
		safe_position = await find_nearby_safe_position()

	# Apply respawn pos with a slight upward offset so we don't clip into floor
	if safe_position != Vector2.ZERO:
		global_position = safe_position + Vector2(0, -8)
	velocity = Vector2.ZERO  # stop any fall momentum

	# Hurt feedback
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color(1, 1, 1)

	player_hit = false
	can_take_damage = true

	health_changed.emit(Global.health, Global.health_max)

	
func find_nearby_safe_position() -> Vector2:
	# Try several positions mainly above the current spot
	var check_positions = [
		Vector2(0, -48),   # Straight up
		Vector2(0, -96),   # Higher up
		Vector2(32, -48),  # Up-right
		Vector2(-32, -48), # Up-left
		Vector2(64, -48),  # Further right
		Vector2(-64, -48)  # Further left
	]

	var original_position = global_position

	for offset in check_positions:
		var test_position = original_position + offset
		
		# Temporarily move player to test position
		global_position = test_position
		await get_tree().process_frame  # Let overlap checks update

		var is_safe = true
		var areas = Hitbox.get_overlapping_areas()
		for area in areas:
			if area.is_in_group("spikes") or area.is_in_group("instant_death"):
				is_safe = false
				break
		
		if is_safe:
			print("Found safe respawn position: ", test_position)
			return test_position

	print("No safe position found, using default offset above.")
	return original_position + Vector2(0, -96)
	
func take_damage_cooldown(time):
	print("cooldown")
	can_take_damage = false
	await get_tree().create_timer(time).timeout
	can_take_damage = true

func load_game_over_scene():
	# Preload the game over scene for efficiency
	var game_over_scene_res = preload("res://scenes/ui/game_over_ui.tscn") # Adjust path if different
	
	# Create an instance of the game over scene
	var game_over_instance = game_over_scene_res.instantiate()
	
	# Add it to the current scene's root (Viewport)
	get_tree().current_scene.add_child(game_over_instance)
	

	
func apply_knockback(vector: Vector2):
	knockback_velocity = vector
	knockback_timer = knockback_duration
	
func shoot_fireball():
	if not fireball_scene:
		print("ERROR: Fireball scene not assigned in Player.gd's Inspector!")
		return

	var fireball_instance = fireball_scene.instantiate()
	get_tree().current_scene.add_child(fireball_instance)

	var fb_direction = Vector2(facing_direction, 0)

	var spawn_offset_x = fireball_spawn_point.position.x * facing_direction
	var spawn_offset_y = fireball_spawn_point.position.y

	fireball_instance.global_position = global_position + Vector2(spawn_offset_x, spawn_offset_y)
	fireball_instance.set_direction(fb_direction)

	print("Player in Magus mode shot a fireball!")

func shoot_rocket():
	if not rocket_scene:
		print("ERROR: Rocket scene not assigned in Player.gd's Inspector!")
		return

	var target_enemy = find_closest_enemy_for_rockets()

	var base_spawn_offset_x = fireball_spawn_point.position.x * facing_direction
	var base_spawn_offset_y = fireball_spawn_point.position.y
	var base_spawn_position = global_position + Vector2(base_spawn_offset_x, base_spawn_offset_y)

	var rocket1 = rocket_scene.instantiate()
	get_tree().current_scene.add_child(rocket1)
	rocket1.global_position = base_spawn_position + Vector2(-2, -12)
	rocket1.set_initial_properties(Vector2(-0.2, -0.1).normalized(), target_enemy)

	var rocket2 = rocket_scene.instantiate()
	get_tree().current_scene.add_child(rocket2)
	rocket2.global_position = base_spawn_position + Vector2(2, -12)
	rocket2.set_initial_properties(Vector2(0.2, -0.1).normalized(), target_enemy)

	print("Player in Ultimate Cyber mode shot two homing rockets!")

func find_closest_enemy_for_rockets() -> Node2D:
	var closest_enemy: Node2D = null
	var min_distance_sq = INF

	var enemies = get_tree().get_nodes_in_group("Enemies")

	for enemy in enemies:
		if is_instance_valid(enemy) and not (enemy is Player):
			var distance_sq = global_position.distance_squared_to(enemy.global_position)
			if distance_sq < min_distance_sq:
				min_distance_sq = distance_sq
				closest_enemy = enemy
	return closest_enemy

func _on_combo_timer_timeout():
	can_attack = false
	attack_cooldown_timer.start(1.0)
	print("combo,timer attack start")

#var next_ledge_position
func handle_ledge_grab():
	# Only check for ledges when in the air and not currently grabbing one
	var current_form = get_current_form_id()
	
	if LedgeLeftLower.is_colliding():
		LedgeLeftON = true
	else:
		LedgeLeftON = false
	if LedgeRightLower.is_colliding():
		LedgeRightON = true
	else:
		LedgeRightON = false
	
	if LedgeLeftUpper2.is_colliding():
		LedgeLeftON2 = true
	else:
		LedgeLeftON2 = false
	if LedgeRightUpper2.is_colliding():
		LedgeRightON2 = true
	else:
		LedgeRightON2 = false
		
	if not is_on_floor() and not is_grabbing_ledge and current_form != "Normal" and not is_grappling_active and not Global.dashing and not Global.teleporting and not is_launched:
		# Check for a ledge on the right side
		if LedgeRightLower.is_colliding() and not LedgeRightUpper.is_colliding():
			is_grabbing_ledge = true
			LedgeDirection = Vector2.RIGHT
			# Calculate the grab position relative to the lower raycast's collision point
			var collision_point = LedgeRightLower.get_collision_point()
			# Snap the player's position to hang on the ledge
			LedgePosition = Vector2(collision_point.x +6, collision_point.y - 14)
			print("Player grabbed a ledge on the right!")
			return true
			#NormalColl.disabled = true
		# Check for a ledge on the left side
		elif LedgeLeftLower.is_colliding() and not LedgeLeftUpper.is_colliding():
			is_grabbing_ledge = true
			LedgeDirection = Vector2.LEFT
			var collision_point = LedgeLeftLower.get_collision_point()
			LedgePosition = Vector2(collision_point.x -6 , collision_point.y - 14)
			print("Player grabbed a ledge on the left!")
			#NormalColl.disabled = true
			return true
		return false	
	# If the player is grabbing a ledge, handle inputs for climbing or dropping
	if is_grabbing_ledge and (current_form != "Normal"):
		#velocity.x = 0# Stop all movement
		#next_ledge_position = LedgePosition
		#camera.position_smoothing_enabled = true
		global_position = LedgePosition # Snap to the hanging position
		#velocity = Vector2.ZERO
		#NormalColl.disabled = true
		#global_position = global_position.lerp(LedgePosition, 0.5) # Adjust the interpolation speed (0.2 is a good starting point)


		
		
		# Return true to signal that no further movement logic should be processed
		return true

	return false # Return false if not grabbing a ledge
	


func add_item_to_inventory(item_id: String):
	if not inventory.has(item_id):
		inventory.append(item_id)
		print("Added '" + item_id + "' to inventory. Current inventory: " + str(inventory))
	else:
		print("Item '" + item_id + "' already in inventory.")

func has_item_in_inventory(item_id: String) -> bool:
	return inventory.has(item_id)

func remove_item_from_inventory(item_id: String):
	if inventory.has(item_id):
		inventory.erase(item_id)
		print("Removed '" + item_id + "' from inventory. Current inventory: " + str(inventory))
		return true
	print("Item '" + item_id + "' not found in inventory.")
	return false
	
#No mana, use puzzles/special enemy to overcome overpower character

func get_save_data() -> Dictionary:
	var player_data = {
		"position_x": global_position.x,
		"position_y": global_position.y,
		"health": Global.health,
		"current_state_name": get_current_form_id(),
		"unlocked_states": unlocked_states,
		"selected_form_index": Global.selected_form_index,
		"inventory": inventory # Directly save inventory
		
	}
	return player_data

#Not used currently
func apply_load_data(data: Dictionary):
	# This function is now ONLY for applying data AFTER the deferred position.
	# Position is applied directly in _physics_process on the first frame.
	print("Player.apply_load_data: Function called to apply data (non-positional).")
	
	# health, unlocked_states, current_state, inventory, money
	# These are now set in _ready or will be updated from global data

	print("Player loaded health: " + str(Global.health)) # Health should already be set in _ready()

	# Unlocked states are set in _ready(), but ensure the `unlocked_states` array is correct
	# based on the `unlocked_flags` after the initial setup.
	unlocked_states.clear()
	for state in state_order:
		if unlocked_flags[state]:
			unlocked_states.append(state)
	print("Player loaded unlocked states: " + str(unlocked_states))

	print("Player loaded form: " + get_current_form_id()) # Use get_current_form_id as state is set in _ready


	visible = true

	set_physics_process(true) # Ensure physics processing is enabled
	set_process(true) # Ensure regular processing is enabled



func try_push_objects(direction: Vector2):
	# Only push objects when not busy with other actions
	var is_busy = (dead or Global.is_cutscene_active or player_hit or knockback_timer > 0 or 
				  is_grappling_active or Global.dashing or is_launched or canon_enabled or 
				  telekinesis_enabled or is_grabbing_ledge or 
				  Global.attacking or Global.is_dialog_open or Global.teleporting)
	
	if is_busy:
		return
	
	# Check for collisions and push objects
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.has_method("push"):

			var push_direction = Vector2(facing_direction, 0)
			collider.push(push_direction, 200.0)  # Adjust force as needed
			

func bounced_recently():
	bounced_protection_timer = BOUNCE_GRACE
	last_bounce_direction = launch_direction
	
# This function will be called by the AnimationPlayer to make the player move
func move_during_cutscene(target_position: Vector2, duration: float):
	print("Player: move_during_cutscene called. Target: ", target_position, ", Duration: ", duration)
	# Use a Tween for smooth movement during a cutscene
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_position, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# This function could be called to play an animation (e.g., 'walk', 'run', 'idle')
func play_player_animation(anim_name: String):
	if $AnimationPlayer and $AnimationPlayer.has_animation(anim_name):
		$AnimationPlayer.play(anim_name)
		print("Player: Playing animation: ", anim_name)
	else:
		printerr("Player: AnimationPlayer not found or animation '", anim_name, "' does not exist!")

# This function could be called to make the player face a certain direction
func set_player_direction(direction_vector: Vector2):

	if direction_vector.x < 0:
		$Sprite2D.flip_h = true
		AreaAttackColl.position = Vector2(16,-8.75)
	elif direction_vector.x > 0:
		$Sprite2D.flip_h = false
		AreaAttackColl.position = Vector2(-16,-8.75)
	print("Player: Facing direction: ", direction_vector)


# to make the player move to a specific global position using a Tween
func move_player_to_position(target_pos: Vector2, duration: float, ease_type: Tween.EaseType = Tween.EASE_IN_OUT, trans_type: Tween.TransitionType = Tween.TRANS_SINE):
	if not is_instance_valid(self): return # Safety check
	if not Global.is_cutscene_active:
		printerr("Player: Attempted cutscene movement but Global.is_cutscene_active is false!")
		return

	print("Player: Moving to ", target_pos, " over ", duration, " seconds.")
	var tween = create_tween()

	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_ease(ease_type).set_trans(trans_type)
  


func set_player_cutscene_velocity(direction_vector: Vector2, speed_multiplier: float = 1.0):
	if not is_instance_valid(self): return
	if not Global.is_cutscene_active:
		printerr("Player: Attempted cutscene velocity but Global.is_cutscene_active is false!")
		return
	
	velocity = direction_vector.normalized() * (move_speed * speed_multiplier) # Use player's base speed
	print("Player: Setting cutscene velocity to: ", velocity)
	

	if direction_vector.x < 0:
		sprite.flip_h = true
	elif direction_vector.x > 0:
		sprite.flip_h = false


func play_player_visual_animation(anim_name: String):
	if not is_instance_valid(self): return
	
	if combat_fsm and is_instance_valid(combat_fsm):


		match anim_name:
			"idle":
				combat_fsm.change_state(IdleState.new(self))
			"run":
				combat_fsm.change_state(RunState.new(self))
			"jump":
				combat_fsm.change_state(JumpState.new(self))
			"hurt":
				combat_fsm.change_state(HurtState.new(self))
			"die":
				combat_fsm.change_state(DieState.new(self))
			"attack":
				combat_fsm.change_state(AttackState.new(self))
			"skill":
				combat_fsm.change_state(SkillState.new(self))
			# ... add other cases as needed ...
			_:
				printerr("Player: FSM has no direct state for animation '", anim_name, "'. Playing directly.")
				if animation_player and animation_player.has_animation(anim_name):
					animation_player.play(anim_name)
				else:
					printerr("Player: Cannot play visual animation '", anim_name, "'. AnimationPlayer missing or animation not found.")
	else:
		# Fallback: if no FSM or FSM is invalid, play animation directly
		if animation_player and animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
			print("Player: Playing visual animation: ", anim_name)
		else:
			printerr("Player: Cannot play visual animation '", anim_name, "'. AnimationPlayer missing or animation not found.")


func set_player_face_direction(direction: int): # 1 for right, -1 for left
	if not is_instance_valid(self): return
	facing_direction = direction
	if facing_direction == -1:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	print("Player: Facing direction set to: ", direction)


func disable_player_input_for_cutscene():
	Global.is_cutscene_active = true # Set the global flag
	print("Player: Input and direct control disabled for cutscene.")
	# Stop normal physics processing (movement, input handling)
	set_physics_process(false)
	set_process(false) 
	velocity = Vector2.ZERO # Stop any current player movement

func enable_player_input_after_cutscene():
	Global.is_cutscene_active = false # Clear the global flag
	print("Player: Input and direct control enabled after cutscene.")
	# Reset any temporary cutscene velocity
	velocity.x = 0
	
	# Re-enable physics and process
	set_physics_process(true)
	set_process(true)

	# Ensure FSM goes back to idle state
	if combat_fsm and is_instance_valid(combat_fsm):
		combat_fsm.change_state(IdleState.new(self)) # Assuming IdleState is the default after cutscene
	else:
		# Fallback if FSM is not used or not valid
		if animation_player:

			animation_player.play("idle")
	
	# visible = true # Example: if player was hidden
	

func emergency_cleanup_shaders():
	"""Emergency cleanup called right before game exit"""
	print("PLAYER: Emergency shader cleanup")
	
	# Get the sprite and reset its material immediately
	var sprite = get_node_or_null("Sprite2D")
	if sprite and is_instance_valid(sprite):
		# If sprite has any shader material, reset it to prevent exit errors
		if sprite.material is ShaderMaterial:
			print("PLAYER: Resetting shader material on sprite to prevent exit errors")
			sprite.material = null
	
	# If currently in Magus state, force its cleanup too
	if current_state is MagusState:
		current_state.force_cleanup()
	elif current_state is UltimateMagusState:
		current_state.force_cleanup()
		

func track_area_pass():
	if is_area_goal_complete or area_goal_locked or not is_launched:
		return
	
	# Check cooldown to prevent multiple counts in quick succession
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_area_pass_time < area_pass_cooldown:
		return
	
	last_area_pass_time = current_time
	area_pass_count += 1
	
	current_speed_boost *= speed_increase_multiplier
	launch_speed = base_launch_speed * current_speed_boost
	print("Area pass count: ", area_pass_count, "/", max_area_passes)
	
	show_area_pass_feedback()
	
	if area_pass_count >= max_area_passes:
		complete_area_goal()

func complete_area_goal():
	if is_area_goal_complete:
		return
	
	is_area_goal_complete = true
	area_goal_locked = true
	print("Area pass goal completed! Locking player...")
	
	# Stop the player's movement
	velocity = Vector2.ZERO
	is_launched = false
	canon_enabled = false
	
	scale = Vector2(1, 1)  # RETURN TO NORMAL SCALE
	visible = true  # MAKE SURE PLAYER IS VISIBLE
	
	collision_mask = normal_collision_mask
	
	# Big final visual effect
	sprite.modulate = Color(1, 0, 0)  # Red flash
	await get_tree().create_timer(0.3).timeout
	sprite.modulate = Color(1, 1, 1)
	
	# EMIT SIGNAL instead of starting dialog
	area_goal_completed.emit()
	
	# Lock the player for a few seconds
	await get_tree().create_timer(2.0).timeout
	area_goal_locked = false
	
	# Optionally unlock after dialog completes


func reset_area_goal():
	area_pass_count = 0
	is_area_goal_complete = false
	area_goal_locked = false
	last_area_pass_time = 0.0
	# RESET SPEED
	current_speed_boost = 1.0
	launch_speed = base_launch_speed
	
	print("Area goal and speed reset")
	
func show_area_pass_feedback():
	# More dramatic visual feedback for speed increases
	var tween = create_tween()
	
	# Flash effect with color based on speed
	var flash_color = Color(1, 1 - (current_speed_boost - 1.0) * 0.5, 1 - (current_speed_boost - 1.0) * 0.5)
	
	tween.tween_property(sprite, "modulate", flash_color, 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

	if camera:
		var shake_strength = min(10.0, (current_speed_boost - 1.0) * 50.0)
		apply_screen_shake(shake_strength)

func apply_screen_shake(strength: float):
	if camera and camera is Camera2D:
		var original_offset = camera.offset
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Shake effect
		for i in range(3):
			var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength
			tween.tween_property(camera, "offset", original_offset + random_offset, 0.05)
			tween.tween_property(camera, "offset", original_offset, 0.05)

func heal(amount: int):
	if Global.health < Global.health_max:
		Global.health += amount
		Global.health = min(Global.health, Global.health_max)
		print("Player healed! Current health: ", Global.health)
		

		if health_changed:
			health_changed.emit(Global.health, Global.health_max)

func _try_pay_health_generic(action: String) -> bool:
	# --- GLOBAL HP LIMIT: below 20% -> no attack/skill at all ---
	if Global.health_max > 0:
		var health_ratio := float(Global.health) / float(Global.health_max)
		if health_ratio <= 0.1:
			print("Action blocked: HP below 10%. HP:", Global.health, "/", Global.health_max)
			return false
	# If health_max is 0 (weird), just allow to avoid division error


	if not use_health_as_mana:
		return true

	var form_id := get_current_form_id()


	var cost_dict
	if action == "attack":
		cost_dict = ATTACK_HEALTH_COSTS
	else:
		cost_dict = SKILL_HEALTH_COSTS

	var cost: int = cost_dict.get(form_id, 0)

	if cost <= 0:
		return true  # no cost for this form / action


	var min_hp_left := 1

	if Global.health - cost < min_hp_left:
		print("Not enough health for ", action, " in form ", form_id, ". HP: ", Global.health, " cost: ", cost)
		return false

	Global.health -= cost
	print("Paid ", cost, " HP for ", action, " in form ", form_id, ". HP now: ", Global.health)

	# Notify HUD
	if health_changed:
		health_changed.emit(Global.health, Global.health_max)

	return true


func _try_pay_health_for_attack() -> bool:
	return _try_pay_health_generic("attack")


func _try_pay_health_for_skill() -> bool:
	return _try_pay_health_generic("skill")

func unlock_and_force_form(form_name: String) -> void:
	# Make sure it's unlocked
	unlock_state(form_name)

	# Find the correct index in unlocked_states
	var idx := unlocked_states.find(form_name)
	if idx == -1:
		push_warning("unlock_and_force_form: Form '%s' not in unlocked_states!" % form_name)
		return

	# Set indices
	current_state_index = idx
	Global.selected_form_index = idx

	# Switch the actual FSM/state
	switch_state(form_name)
	if combat_fsm:
		combat_fsm.change_state(IdleState.new(self))

	print("unlock_and_force_form: forced form to ", form_name, " at index ", idx)


func force_release_grapple() -> void:
	# Only do this if your current state is CyberState
	if current_state is CyberState:
		var cyber_state := current_state as CyberState
		cyber_state.release_grapple()  # this already clears flags + line + velocity handling

	# Extra safety: clear any player-side flags/visuals
	is_grappling_active = false
	still_animation = false

	if grapple_line:
		grapple_line.clear_points()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	print("🎯 Player hurtbox area entered: ", area.name)
	
	# Check if this is a boss hitbox
	if area.is_in_group("boss_hitbox"):
		var damage := 0
		
		# Determine damage based on hitbox
		if "LeftSlamHitbox" in area.name or "RightSlamHitbox" in area.name:
			damage = 12  # Gigaster slam damage
		elif "LaserHitbox" in area.name:
			damage = 16  # Gigaster laser damage
		
		if damage > 0 and can_take_damage and not dead:
			print("💥 Player hit by boss hitbox: ", area.name, " damage: ", damage)
			take_damage(damage)
