# bug_survivor_game.gd — Bug Survivor 小游戏：游戏层
# 职责：玩家移动、子弹发射、虫子生成、碰撞处理、HUD、结算
extends Control

## ===== 信号（与代码急救完全一致）=====
signal game_finished(result: String, survival_rate: float)

## ===== 颜色 =====
const COLOR_BG: Color = Color("#0a0a1a")
const COLOR_GRID: Color = Color(0.15, 0.15, 0.25)
const COLOR_PLAYER: Color = Color("#4ecca3")
const COLOR_BULLET: Color = Color("#f0e68c")
const COLOR_BUG: Color = Color("#e94560")
const COLOR_HUD: Color = Color(0.85, 0.85, 0.85)

## ===== 节点引用 =====
var _arena: Node2D
var _player: Area2D
var _bullets_container: Node2D
var _bugs_container: Node2D
var _timer_label: Label
var _kill_label: Label
var _result_panel: PanelContainer
var _result_label: Label
var _result_btn: Button
var _arena_bg: ColorRect

## ===== 游戏数据 =====
var _data: BugSurvivorData
var _preset: BugSurvivorPreset
var _is_running: bool = false
var _spawn_timer: float = 0.0
var _shoot_timer: float = 0.0
var _arena_size: Vector2
var _arena_offset: Vector2


func _ready() -> void:
	_build_ui()


## ===== 外部调用：初始化并开始 =====
func setup(preset: BugSurvivorPreset, _business_level: int) -> void:
	_preset = preset
	_arena_size = Config.BUG_SURVIVOR_ARENA_SIZE

	_data = BugSurvivorData.new()
	_data.setup(preset)

	var viewport_size: Vector2 = get_viewport_rect().size
	_arena_offset = (viewport_size - _arena_size) / 2.0
	_arena.position = _arena_offset
	_arena_bg.size = _arena_size

	_player.position = _arena_size / 2.0

	_spawn_timer = 0.0
	_shoot_timer = 0.0
	_is_running = true
	_result_panel.visible = false

	TimeManager.start_minigame()
	_update_hud()


func _process(delta: float) -> void:
	if not _is_running:
		return

	var still_going: bool = _data.advance(delta)
	if not still_going:
		_end_game()
		return

	_move_player(delta)

	_shoot_timer += delta
	var interval: float = _preset.get_bullet_interval()
	if _shoot_timer >= interval:
		_shoot_timer -= interval
		_shoot_nearest_bug()

	_spawn_timer += delta
	var spawn_iv: float = _data.get_current_spawn_interval()
	if _spawn_timer >= spawn_iv:
		_spawn_timer -= spawn_iv
		_spawn_bug()

	_move_bugs(delta)
	_move_bullets(delta)
	_update_hud()


func _move_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir.y += 1.0

	if dir.length_squared() > 0:
		dir = dir.normalized()

	var speed: float = _preset.get_player_speed()
	_player.position += dir * speed * delta

	var r: float = Config.BUG_SURVIVOR_PLAYER_RADIUS
	_player.position.x = clampf(_player.position.x, r, _arena_size.x - r)
	_player.position.y = clampf(_player.position.y, r, _arena_size.y - r)


func _shoot_nearest_bug() -> void:
	if _bugs_container.get_child_count() == 0:
		return

	var nearest: Area2D = null
	var nearest_dist: float = INF
	for child: Node in _bugs_container.get_children():
		var bug: Area2D = child as Area2D
		if bug == null:
			continue
		var dist: float = _player.position.distance_to(bug.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = bug

	if nearest == null:
		return

	var direction: Vector2 = (_player.position.direction_to(nearest.position)).normalized()

	var bullet := Area2D.new()
	bullet.position = _player.position

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.BUG_SURVIVOR_BULLET_RADIUS
	col_shape.shape = circle
	bullet.add_child(col_shape)

	bullet.collision_layer = 2
	bullet.collision_mask = 4

	var visual := ColorRect.new()
	var bsize: float = Config.BUG_SURVIVOR_BULLET_RADIUS * 2.0
	visual.size = Vector2(bsize, bsize)
	visual.position = Vector2(-bsize / 2.0, -bsize / 2.0)
	visual.color = COLOR_BULLET
	bullet.add_child(visual)

	bullet.set_meta("direction", direction)
	bullet.set_meta("speed", Config.BUG_SURVIVOR_BULLET_SPEED)

	bullet.area_entered.connect(_on_bullet_hit.bind(bullet))

	_bullets_container.add_child(bullet)


func _spawn_bug() -> void:
	var bug := Area2D.new()
	bug.position = BugSurvivorData.random_edge_position(_arena_size)

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.BUG_SURVIVOR_BUG_RADIUS
	col_shape.shape = circle
	bug.add_child(col_shape)

	bug.collision_layer = 4
	bug.collision_mask = 3

	var visual := ColorRect.new()
	var bsize: float = Config.BUG_SURVIVOR_BUG_RADIUS * 2.5
	visual.size = Vector2(bsize, bsize)
	visual.position = Vector2(-bsize / 2.0, -bsize / 2.0)
	visual.color = COLOR_BUG
	bug.add_child(visual)

	var label := Label.new()
	label.text = "BUG"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-12, -8)
	bug.add_child(label)

	_bugs_container.add_child(bug)


func _move_bugs(delta: float) -> void:
	var bug_speed: float = _data.get_current_bug_speed()
	var player_pos: Vector2 = _player.position

	for child: Node in _bugs_container.get_children():
		var bug: Area2D = child as Area2D
		if bug == null:
			continue
		var dir: Vector2 = (player_pos - bug.position).normalized()
		bug.position += dir * bug_speed * delta

		var dist: float = bug.position.distance_to(player_pos)
		if dist < Config.BUG_SURVIVOR_PLAYER_RADIUS + Config.BUG_SURVIVOR_BUG_RADIUS:
			_on_player_hit()
			return


func _move_bullets(delta: float) -> void:
	for child: Node in _bullets_container.get_children():
		var bullet: Area2D = child as Area2D
		if bullet == null:
			continue
		var dir: Vector2 = bullet.get_meta("direction", Vector2.RIGHT) as Vector2
		var spd: float = bullet.get_meta("speed", 400.0) as float
		bullet.position += dir * spd * delta

		var margin: float = 50.0
		if bullet.position.x < -margin or bullet.position.x > _arena_size.x + margin \
			or bullet.position.y < -margin or bullet.position.y > _arena_size.y + margin:
			bullet.queue_free()


func _on_bullet_hit(area: Area2D, bullet: Area2D) -> void:
	if area.get_parent() == _bugs_container:
		_data.record_kill()
		area.queue_free()
		bullet.queue_free()


func _on_player_hit() -> void:
	if not _is_running:
		return
	_data.player_died()
	_end_game()


func _update_hud() -> void:
	var remaining: float = _data.game_duration - _data.elapsed
	_timer_label.text = "剩余：%.1f 秒" % maxf(remaining, 0.0)
	_kill_label.text = "击杀：%d" % _data.kill_count

	if remaining > 30.0:
		_timer_label.add_theme_color_override("font_color", COLOR_PLAYER)
	elif remaining > 15.0:
		_timer_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_timer_label.add_theme_color_override("font_color", COLOR_BUG)


func _end_game() -> void:
	_is_running = false
	TimeManager.stop_minigame()

	var survival_rate: float = _data.get_survival_rate()
	var result: String = _data.get_result()

	var result_text: String
	if survival_rate >= 0.9:
		result_text = "【大成功】坚持了 %.1f 秒！\n击杀 %d 只虫子！" % [_data.elapsed, _data.kill_count]
	elif survival_rate >= 0.6:
		result_text = "【一般】坚持了 %.1f 秒\n还可以更好。" % _data.elapsed
	else:
		result_text = "【失败】仅坚持了 %.1f 秒\n虫子入侵了代码库……" % _data.elapsed

	_result_label.text = result_text
	_result_panel.visible = true
	_result_panel.set_meta("result", result)
	_result_panel.set_meta("survival_rate", survival_rate)


func _on_result_confirm() -> void:
	var result: String = _result_panel.get_meta("result", "conservative") as String
	var survival_rate: float = _result_panel.get_meta("survival_rate", 0.0) as float
	game_finished.emit(result, survival_rate)
	queue_free()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	_arena = Node2D.new()
	add_child(_arena)

	_arena_bg = ColorRect.new()
	_arena_bg.color = Color(0.06, 0.06, 0.12)
	_arena.add_child(_arena_bg)

	_player = Area2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 4

	var player_col := CollisionShape2D.new()
	var player_circle := CircleShape2D.new()
	player_circle.radius = Config.BUG_SURVIVOR_PLAYER_RADIUS
	player_col.shape = player_circle
	_player.add_child(player_col)

	var player_visual := ColorRect.new()
	var psize: float = Config.BUG_SURVIVOR_PLAYER_RADIUS * 2.5
	player_visual.size = Vector2(psize, psize)
	player_visual.position = Vector2(-psize / 2.0, -psize / 2.0)
	player_visual.color = COLOR_PLAYER
	_player.add_child(player_visual)

	var player_label := Label.new()
	player_label.text = "P"
	player_label.add_theme_font_size_override("font_size", 18)
	player_label.add_theme_color_override("font_color", Color.WHITE)
	player_label.position = Vector2(-6, -12)
	_player.add_child(player_label)

	_player.area_entered.connect(_on_player_area_entered)

	_arena.add_child(_player)

	_bullets_container = Node2D.new()
	_arena.add_child(_bullets_container)

	_bugs_container = Node2D.new()
	_arena.add_child(_bugs_container)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	var hud_hbox := HBoxContainer.new()
	hud_hbox.position = Vector2(20, 10)
	hud_hbox.add_theme_constant_override("separation", 40)
	hud_layer.add_child(hud_hbox)

	_timer_label = Label.new()
	_timer_label.text = "剩余：60.0 秒"
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", COLOR_PLAYER)
	hud_hbox.add_child(_timer_label)

	_kill_label = Label.new()
	_kill_label.text = "击杀：0"
	_kill_label.add_theme_font_size_override("font_size", 22)
	_kill_label.add_theme_color_override("font_color", COLOR_HUD)
	hud_hbox.add_child(_kill_label)

	var hint_label := Label.new()
	hint_label.text = "方向键/WASD 移动 | 自动射击"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint_label.position = Vector2(20, 42)
	hud_layer.add_child(hint_label)

	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(420, 200)

	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	result_style.border_color = COLOR_PLAYER
	result_style.set_border_width_all(2)
	result_style.set_corner_radius_all(8)
	result_style.set_content_margin_all(20)
	_result_panel.add_theme_stylebox_override("panel", result_style)

	var result_vbox := VBoxContainer.new()
	result_vbox.add_theme_constant_override("separation", 16)
	_result_panel.add_child(result_vbox)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 20)
	_result_label.add_theme_color_override("font_color", Color.WHITE)
	result_vbox.add_child(_result_label)

	_result_btn = Button.new()
	_result_btn.text = "确认"
	_result_btn.custom_minimum_size = Vector2(120, 40)
	_result_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_btn.pressed.connect(_on_result_confirm)
	result_vbox.add_child(_result_btn)

	add_child(_result_panel)


func _on_player_area_entered(area: Area2D) -> void:
	if area.get_parent() == _bugs_container:
		_on_player_hit()
