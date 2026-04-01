# main_menu.gd — 主菜单
extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	#_add_test_button()  # 测试入口，发布时隐藏
	_setup_background()


func _on_start_pressed() -> void:
	GameManager.start_new_run()
	GameManager.transition_to(GameManager.GameState.ENTRY_SHOP)


## ===== 测试入口：直接启动 Bug Survivor 小游戏 =====
func _add_test_button() -> void:
	var vbox: VBoxContainer = $CenterContainer/VBoxContainer

	var test_btn := Button.new()
	test_btn.text = "[BUG] 测试 Bug Survivor"
	test_btn.custom_minimum_size = Vector2(200, 50)
	test_btn.pressed.connect(_on_test_survivor)
	vbox.add_child(test_btn)

	var memory_btn := Button.new()
	memory_btn.text = "[MEM] 测试素材归档"
	memory_btn.custom_minimum_size = Vector2(200, 50)
	memory_btn.pressed.connect(_on_test_memory_match)
	vbox.add_child(memory_btn)


func _on_test_survivor() -> void:
	# 加载预设
	var preset: BugSurvivorPreset = load("res://resources/minigame_presets/bug_swarm.tres") as BugSurvivorPreset
	if preset == null:
		push_error("无法加载 bug_swarm 预设")
		return

	# 加载小游戏场景
	var scene: PackedScene = load("res://scenes/minigame/bug_survivor_game.tscn")
	if scene == null:
		push_error("无法加载 Bug Survivor 场景")
		return

	var game_instance: Control = scene.instantiate()
	get_tree().root.add_child(game_instance)
	game_instance.setup(preset, 1)
	game_instance.game_finished.connect(_on_test_finished.bind(game_instance))

	# 隐藏菜单
	visible = false


func _on_test_finished(_result: String, _survival_rate: float, game_instance: Control) -> void:
	game_instance.queue_free()
	visible = true


func _on_test_memory_match() -> void:
	var preset: MemoryMatchPreset = load("res://resources/minigame_presets/memory_standard.tres") as MemoryMatchPreset
	if preset == null:
		push_error("无法加载 memory_standard 预设")
		return

	var scene: PackedScene = load("res://scenes/minigame/memory_match_game.tscn")
	if scene == null:
		push_error("无法加载素材归档场景")
		return

	var game_instance: Control = scene.instantiate()
	get_tree().root.add_child(game_instance)
	game_instance.setup(preset, 1)
	game_instance.game_finished.connect(_on_test_finished.bind(game_instance))

	visible = false


## ===== 设置背景图 =====
func _setup_background() -> void:
	var tex: Texture2D = AssetRegistry.get_texture("background", "menu")
	if tex == null:
		return
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1, 1, 1, 0.3)  # 半透明避免遮挡UI
	add_child(bg)
	move_child(bg, 0)  # 放到最底层
