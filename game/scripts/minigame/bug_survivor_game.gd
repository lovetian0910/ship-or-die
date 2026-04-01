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

## ===== 玩家动画 =====
var _player_sprite: Sprite2D = null
var _anim_timer: float = 0.0
const ANIM_FPS: float = 8.0  # 帧动画速率
const TOP_BAR_HEIGHT: float = 44.0  # 顶栏预留高度
var _data: BugSurvivorData
var _preset: BugSurvivorPreset
var _is_running: bool = false
var _spawn_timer: float = 0.0
var _shoot_timer: float = 0.0
var _arena_size: Vector2
var _arena_offset: Vector2
var _last_shoot_dir: Vector2 = Vector2.RIGHT  ## 上次射击方向（玩家静止时朝向用）


func _ready() -> void:
	_build_ui()


## ===== 外部调用：初始化并开始 =====
func setup(preset: BugSurvivorPreset, _business_level: int) -> void:
	_preset = preset
	_arena_size = Config.BUG_SURVIVOR_ARENA_SIZE

	_data = BugSurvivorData.new()
	_data.setup(preset)

	var viewport_size: Vector2 = get_viewport_rect().size
	# 竞技场垂直居中时考虑顶栏偏移
	_arena_offset = Vector2(
		(viewport_size.x - _arena_size.x) / 2.0,
		TOP_BAR_HEIGHT + (viewport_size.y - TOP_BAR_HEIGHT - _arena_size.y) / 2.0
	)
	_arena.position = _arena_offset
	_arena_bg.size = _arena_size

	# 设置边框尺寸
	for child: Node in _arena.get_children():
		if child is ReferenceRect and child.has_meta("_is_border"):
			(child as ReferenceRect).size = _arena_size

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

	# 玩家帧动画
	if _player_sprite and _is_running:
		_anim_timer += delta
		if _anim_timer >= 1.0 / ANIM_FPS:
			_anim_timer -= 1.0 / ANIM_FPS
			_player_sprite.frame = (_player_sprite.frame + 1) % _player_sprite.hframes

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
		# 翻转精灵方向
		if _player_sprite:
			if dir.x < 0:
				_player_sprite.flip_h = true
			elif dir.x > 0:
				_player_sprite.flip_h = false
	else:
		# 没有移动输入时，朝向最近的攻击目标
		if _player_sprite and _last_shoot_dir.x != 0.0:
			_player_sprite.flip_h = _last_shoot_dir.x < 0.0

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
	_last_shoot_dir = direction

	var bullet := Area2D.new()
	bullet.position = _player.position

	var col_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Config.BUG_SURVIVOR_BULLET_RADIUS
	col_shape.shape = circle
	bullet.add_child(col_shape)

	bullet.collision_layer = 2
	bullet.collision_mask = 4

	# 代码字符作为子弹视觉
	var code_chars: Array[String] = [
		"{", "}", "(", ")", ";", "=", "++", "!=", "&&", "||",
		"if", "for", "var", "int", "0x", "//", "->", ":=", "<<", ">>",
	]
	var bullet_label := Label.new()
	bullet_label.text = code_chars[randi_range(0, code_chars.size() - 1)]
	bullet_label.add_theme_font_size_override("font_size", 14)
	bullet_label.add_theme_color_override("font_color", COLOR_BULLET)
	bullet_label.position = Vector2(-8, -10)
	bullet.add_child(bullet_label)

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

	# Bug 视觉
	var bug_tex: Texture2D = AssetRegistry.get_texture("minigame", "bug")
	if bug_tex:
		var bug_sprite := TextureRect.new()
		bug_sprite.texture = bug_tex
		var bsize: float = Config.BUG_SURVIVOR_BUG_RADIUS * 2.5
		bug_sprite.custom_minimum_size = Vector2(bsize, bsize)
		bug_sprite.size = Vector2(bsize, bsize)
		bug_sprite.position = Vector2(-bsize / 2.0, -bsize / 2.0)
		bug_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bug_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bug.add_child(bug_sprite)
	else:
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

	# 随机相位偏移，让每只虫子晃动节奏不同
	bug.set_meta("wobble_phase", randf() * TAU)
	var bsize_for_meta: float = Config.BUG_SURVIVOR_BUG_RADIUS * 2.5
	bug.set_meta("visual_base_y", -bsize_for_meta / 2.0)

	_bugs_container.add_child(bug)


func _move_bugs(delta: float) -> void:
	var bug_speed: float = _data.get_current_bug_speed()
	var player_pos: Vector2 = _player.position
	var time_sec: float = _data.elapsed

	for child: Node in _bugs_container.get_children():
		var bug: Area2D = child as Area2D
		if bug == null:
			continue
		var dir: Vector2 = (player_pos - bug.position).normalized()
		bug.position += dir * bug_speed * delta

		# 朝向：素材默认头朝右，在玩家左边时朝右飞（不翻），在右边时朝左飞（翻转）
		if dir.x < 0:
			bug.scale.x = -1.0
		elif dir.x > 0:
			bug.scale.x = 1.0

		# 上下微晃，模拟飞行（振幅3px，频率8Hz，每只虫子相位不同）
		var phase: float = bug.get_meta("wobble_phase", 0.0) as float
		var wobble_y: float = sin(time_sec * 8.0 + phase) * 3.0
		var base_offset: float = bug.get_meta("visual_base_y", 0.0) as float
		for visual_child: Node in bug.get_children():
			if visual_child is CollisionShape2D:
				continue
			if visual_child is CanvasItem:
				(visual_child as CanvasItem).position.y = base_offset + wobble_y

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
		_spawn_hit_particles(area.global_position)
		_kill_bug(area)
		bullet.queue_free()


## ===== 击杀视觉效果 =====

func _spawn_hit_particles(global_pos: Vector2) -> void:
	var local_pos: Vector2 = _arena.to_local(global_pos)
	var particle_count: int = randi_range(6, 8)
	for i: int in range(particle_count):
		var p := ColorRect.new()
		var p_size: float = randf_range(3.0, 6.0)
		p.size = Vector2(p_size, p_size)
		p.position = local_pos - Vector2(p_size / 2.0, p_size / 2.0)
		# 基于虫子红色，随机亮度偏移
		var brightness_offset: float = randf_range(-0.15, 0.15)
		p.color = Color(
			clampf(0.914 + brightness_offset, 0.0, 1.0),
			clampf(0.271 + brightness_offset, 0.0, 1.0),
			clampf(0.376 + brightness_offset, 0.0, 1.0),
		)
		_arena.add_child(p)

		# 随机方向发射
		var angle: float = randf() * TAU
		var speed: float = randf_range(80.0, 180.0)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed

		var tween: Tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", p.position + velocity * 0.3, 0.3)
		tween.tween_property(p, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(p.queue_free)


func _kill_bug(bug: Area2D) -> void:
	# 从 bugs_container 移到 arena，防止继续被碰撞检测
	var bug_pos: Vector2 = bug.position
	var bug_scale: Vector2 = bug.scale
	_bugs_container.remove_child(bug)
	_arena.add_child(bug)
	bug.position = bug_pos
	bug.scale = bug_scale

	# 禁用碰撞
	bug.collision_layer = 0
	bug.collision_mask = 0
	for child: Node in bug.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)

	# 死亡动画：闪白 → 渐隐+缩小
	var tween: Tween = bug.create_tween()
	# 闪白 0.05s
	tween.tween_property(bug, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	# 渐隐+缩小 0.2s
	tween.set_parallel(true)
	tween.tween_property(bug, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.2)
	tween.tween_property(bug, "scale", bug_scale * 0.3, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(bug.queue_free)


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

	# 竞技场边框（透明底 + 发光边框线）
	_arena_bg = ColorRect.new()
	_arena_bg.color = Color(0, 0, 0, 0)  # 完全透明
	_arena.add_child(_arena_bg)

	var border := ReferenceRect.new()
	border.editor_only = false
	border.border_color = Color(0.3, 0.8, 0.6, 0.4)
	border.border_width = 2.0
	_arena.add_child(border)
	border.set_meta("_is_border", true)  # 标记，setup 时设尺寸

	# 背景图（办公室，与代码急救统一风格）
	var bg_tex: Texture2D = AssetRegistry.get_texture("background", "office")
	if bg_tex:
		var bg_img := TextureRect.new()
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_img.modulate = Color(1, 1, 1, 0.15)
		add_child(bg_img)
		move_child(bg_img, 1)  # 放在纯色底之上、arena之下

	_player = Area2D.new()
	_player.collision_layer = 1
	_player.collision_mask = 4

	var player_col := CollisionShape2D.new()
	var player_circle := CircleShape2D.new()
	player_circle.radius = Config.BUG_SURVIVOR_PLAYER_RADIUS
	player_col.shape = player_circle
	_player.add_child(player_col)

	# 玩家视觉
	var player_tex: Texture2D = AssetRegistry.get_texture("minigame", "player_run")
	if player_tex:
		_player_sprite = Sprite2D.new()
		_player_sprite.texture = player_tex
		_player_sprite.hframes = 6  # 6帧横排 sprite sheet
		_player_sprite.frame = 0
		# 缩放到合适大小（原始每帧32×48，放大到适合游戏的尺寸）
		var target_h: float = Config.BUG_SURVIVOR_PLAYER_RADIUS * 3.0
		var scale_factor: float = target_h / 48.0
		_player_sprite.scale = Vector2(scale_factor, scale_factor)
		_player.add_child(_player_sprite)
	else:
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

	# HUD（不用 CanvasLayer，避免遮挡 PersistentUI 顶栏）
	var hud_hbox := HBoxContainer.new()
	hud_hbox.position = Vector2(20, TOP_BAR_HEIGHT + 6)
	hud_hbox.add_theme_constant_override("separation", 40)
	add_child(hud_hbox)

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
	hint_label.position = Vector2(20, TOP_BAR_HEIGHT + 38)
	add_child(hint_label)

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
