extends Node2D

onready var countdown = $Countdown
onready var pause_screen = $PauseScreen

const HOOK = preload("res://player/hook/Hook.tscn")
const MEGAHOOK = preload("res://objects/Powerups/MegaHook.tscn")
const HOOK_CLINK = preload("res://player/hook/HookClink.tscn")
const ROPE = preload("res://player/rope/Rope.tscn")
const WALL_PARTICLES = preload("res://fx/WallParticles.tscn")
const SHOW_ROUND_DELAY = 1.5
const TRANSITION_OFFSET = 1000
const TRANSITION_TIME = 1.0

export (int)var total_stages = 10

var hook_clink_positions = []
var Cameras = []
var players
var calling_check_winner = false
var current_stage = 0


func _ready():
	var stage = get_first_stage().instance()
	players = stage.setup_players()
	stage.set_name("Stage")
	add_child(stage)
	
	Cameras = get_cameras() 
	for camera in Cameras:
		if camera.has_method("reset_focus_point"):
			camera.reset_focus_point()
	
	connect_players()
	
	if Transition.is_black_screen:
		Transition.transition_out()
		yield(Transition, "finished")
	
	Sound.menu_bgm.stop()
	if not Sound.game_bgm.playing:
		Sound.game_bgm.play()
		Sound.play_ambience()
	
	for player in players:
		player.spawn_animation()
		
	countdown.start_countdown()
	
	yield(countdown, "go_shown")
	
	activate_players()


func get_cameras():
	# Override on Arena.gd and Race.gd
	assert(false)


func connect_players():
	# Override on Arena.gd and Race.gd
	assert(false)


func activate_players():
	# Override on Arena.gd and Race.gd
	assert(false)


func create_rope(player, hook):
	var rope = ROPE.instance()
	var angle = Vector2(cos(player.sprite.rotation), sin(player.sprite.rotation))
	var rider_pos = player.position + player.rider_offset * angle
	rope.add_point(rider_pos)
	rope.add_point(rider_pos)
	rope.player = player
	rope.hook = hook
	get_node("Stage/Ropes").add_child(rope)
	return rope


func transition_stage():
	var rs = $RoundScreen
	rs.show_round()
	
	yield(rs, "shown")
	free_current_stage()
	add_new_stage()
	connect_players()
	
	yield(rs, "hidden")
	
	for player in players:
		player.spawn_animation()
	
	countdown.start_countdown()
	
	yield(countdown, "go_shown")
	
	activate_players()


func clean_all():
	for child in $"Old Stage/Trails".get_children():
		child.queue_free()
	for child in $"Old Stage/Hooks".get_children():
		child.free_hook()
	players.clear()


func free_current_stage():
	var stage = get_node("Stage")
	stage.set_name("Old Stage") # Necessary to keep new stage from getting a name like Stage1
	for camera in Cameras:
		camera.current = false
	clean_all()
	stage.queue_free()


func add_new_stage():
	var stage = get_random_stage().instance()
	players = stage.setup_players()
	stage.set_name("Stage")
	add_child(stage)
	Cameras = get_cameras()
	for camera in Cameras:
		camera.current = true


func remove_player(player):
	players.erase(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	
	if not calling_check_winner:
		call_deferred("check_winner")
		calling_check_winner = true


func check_winner():
	calling_check_winner = false
	
	
	if players.size() == 1:
		var winner = players[0]
		winner.disable()
		RoundManager.scores[winner.id] += 1
		RoundManager.round_winner = winner.id
		for camera in Cameras:
			if camera.has_method("focus_on_point"):
				camera.focus_on_point(winner.get_global_position())
	elif players.size() == 0:
		RoundManager.round_winner = -1
	else:
		return
	
	yield(get_tree().create_timer(SHOW_ROUND_DELAY), "timeout")
	transition_stage()


func _on_player_hook_shot(player, direction):
	var new_hook = HOOK.instance()
	new_hook.init(player, direction.normalized())
	new_hook.rope = create_rope(player, new_hook)
	get_node("Stage/Hooks").add_child(new_hook)
	for camera in Cameras:
		new_hook.connect("shook_screen", camera, "add_shake")
	new_hook.connect("hook_clinked", self, "_on_hook_clinked")
	new_hook.connect("wall_hit", self, "_on_wall_hit")

	player.get_node("SFX/HarpoonSFX").play()
	player.hook = new_hook


func _on_player_megahook_shot(player, direction):
	var explosion = load("res://fx/explosion/DeathExplosion.tscn").instance()
	var new_megahook = MEGAHOOK.instance()
	var angle = Vector2(cos(player.sprite.rotation), sin(player.sprite.rotation))
	
	explosion.position = player.position + player.rider_offset * angle
	new_megahook.activate(player, direction.normalized())
	get_node("Stage/Hooks").add_child(new_megahook)
	get_node("Stage/Trails").add_child(explosion)
	
	yield(explosion.get_node("AnimationPlayer"), "animation_finished")
	explosion.queue_free()


func _on_hook_clinked(clink_position):
	if clink_position in hook_clink_positions:
		return
	
	$ScreenBlink.blink()
	
	var hook_clink = HOOK_CLINK.instance()
	hook_clink.emitting = true
	hook_clink.position = clink_position
	add_child(hook_clink)

	hook_clink_positions.append(clink_position)

	var delay = hook_clink.lifetime / hook_clink.speed_scale
	yield(get_tree().create_timer(delay), "timeout")

	hook_clink.queue_free()
	hook_clink_positions.erase(clink_position)


func _on_wall_hit(position, rotation):
	var wall_particles = WALL_PARTICLES.instance()
	wall_particles.emitting = true
	wall_particles.position = position
	wall_particles.rotation = rotation
	add_child(wall_particles)

	var delay = wall_particles.lifetime / wall_particles.speed_scale
	yield(get_tree().create_timer(delay), "timeout")

	wall_particles.queue_free()


func _on_player_created_trail(trail):
	$Stage/Trails.add_child(trail)


func _on_player_paused(player):
	pause_screen.pause(player)


func get_stage(stage_number):
	current_stage = stage_number
	var base_path = str("stages/", self.get_name().to_lower(), "-stages/Stage")
	return load(str(base_path, stage_number, ".tscn"))


func get_random_stage():
	var available_stages = range(1, total_stages + 1)
	available_stages.erase(current_stage)
	return get_stage(available_stages[randi() % available_stages.size()])


func get_first_stage():
	return get_stage(1)
