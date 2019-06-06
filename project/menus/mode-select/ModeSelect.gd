extends Control

onready var _moved_left = false
onready var _moved_right = false

func _ready():
	set_process(true)
	set_process_input(false)
	
	Transition.transition_out()
	yield(Transition, "finished")
	
	set_process_input(true)
	$ArenaButton.disabled = false
	$RacingButton.disabled = false
	$ArenaButton.grab_focus()


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		transition_to("res://menus/main-menu/MainMenu.tscn")

func _process(delta):
	if not _moved_left and Input.is_action_just_pressed("ui_joy_left"):
		_moved_left = true
		var cur_focus = self.get_focus_owner()
		if cur_focus and cur_focus.focus_neighbour_left:
			cur_focus.get_node(cur_focus.focus_neighbour_left).grab_focus()
	if not _moved_right and Input.is_action_just_pressed("ui_joy_right"):
		_moved_right = true
		var cur_focus = self.get_focus_owner()
		if cur_focus and cur_focus.focus_neighbour_right:
			cur_focus.get_node(cur_focus.focus_neighbour_right).grab_focus()
	if _moved_left and Input.is_action_just_released("ui_joy_left"):
		_moved_left = false
	if _moved_right and Input.is_action_just_released("ui_joy_right"):
		_moved_right = false

func transition_to(scene_path):
	set_process_input(false)
	$ArenaButton.disabled = true
	$RacingButton.disabled = true
	
	Transition.transition_in()
	yield(Transition, "finished")
	get_tree().change_scene(scene_path)


func _on_ArenaButton_pressed():
	RoundManager.gamemode = "Arena"
	$Sounds/ConfirmSFX.play()
	transition_to("res://menus/character-select/CharacterSelect.tscn")


func _on_RacingButton_pressed():
	RoundManager.gamemode = "Race"
	$Sounds/ConfirmSFX.play()
	transition_to("res://menus/character-select/CharacterSelect.tscn")


func _on_ArenaButton_focus_entered():
	$ArenaButton.material.set_shader_param("active", true)
	$Sounds/SelectSFX.play()


func _on_ArenaButton_focus_exited():
	$ArenaButton.material.set_shader_param("active", false)


func _on_RacingButton_focus_entered():
	$RacingButton.material.set_shader_param("active", true)
	$Sounds/SelectSFX.play()


func _on_RacingButton_focus_exited():
	$RacingButton.material.set_shader_param("active", false)


func _on_Options_pressed():
	$Sounds/ConfirmSFX.play()
	transition_to("res://menus/options-menu/OptionsMenu.tscn")
