# memory_match_game.gd — 素材归档小游戏：场景脚本
# 4×3 翻牌配对，3D翻转动画，15秒限时
extends Control

signal game_finished(result: String, survival_rate: float)

var _data: MemoryMatchData = null
var _preset: MemoryMatchPreset = null
var _card_nodes: Array = []        ## [row][col] = Button
var _card_icons: Array = []        ## [row][col] = Control（正面内容节点）
var _card_backs: Array = []        ## [row][col] = Control（背面内容节点）
var _asset_keys: Array = []        ## 素材key列表，索引对应 data.grid 中的ID
var _time_label: Label = null
var _pairs_label: Label = null
var _grid_container: GridContainer = null
var _animating: bool = false       ## 动画锁
var _peek_pair: Array = []         ## 配对失败时暂存的两个位置

## 素材池：[category, key] 组合
const ICON_POOL: Array = [
	["icon", "icon_money"],
	["icon", "icon_warning"],
	["icon", "icon_success"],
	["icon", "icon_search"],
	["icon", "icon_treasure"],
	["icon", "icon_launch"],
	["icon", "icon_polish"],
	["icon", "icon_time"],
	["icon", "icon_gamepad"],
	["icon", "icon_team"],
	["icon", "icon_mystery"],
]

const PORTRAIT_POOL: Array = [
	["portrait", "creator_low"],
	["portrait", "creator_mid"],
	["portrait", "creator_high"],
	["portrait", "outsource_low"],
	["portrait", "outsource_mid"],
	["portrait", "outsource_high"],
	["portrait", "business_low"],
	["portrait", "business_mid"],
	["portrait", "business_high"],
]


func setup(preset: MemoryMatchPreset, _business_level: int) -> void:
	_preset = preset
	_data = MemoryMatchData.new()
	_data.setup(preset)

	# 从混合池随机选6个素材
	var full_pool: Array = ICON_POOL.duplicate()
	full_pool.append_array(PORTRAIT_POOL)
	full_pool.shuffle()
	_asset_keys.clear()
	for i: int in range(_data.total_pairs):
		_asset_keys.append(full_pool[i])

	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# 顶部 HUD
	var hud := HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	hud.offset_top = 20
	hud.offset_left = 40
	hud.offset_right = -40
	hud.offset_bottom = 60
	hud.add_theme_constant_override("separation", 40)
	add_child(hud)

	_time_label = Label.new()
	_time_label.text = "剩余：15.0s"
	_time_label.add_theme_font_size_override("font_size", 22)
	_time_label.add_theme_color_override("font_color", Color.WHITE)
	hud.add_child(_time_label)

	_pairs_label = Label.new()
	_pairs_label.text = "配对：0/6"
	_pairs_label.add_theme_font_size_override("font_size", 22)
	_pairs_label.add_theme_color_override("font_color", Color("#4ecca3"))
	hud.add_child(_pairs_label)

	var title := Label.new()
	title.text = "素材归档"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f0a030"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(title)

	# 卡牌网格居中
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.offset_top = 70
	add_child(center)

	_grid_container = GridContainer.new()
	_grid_container.columns = _preset.grid_cols
	_grid_container.add_theme_constant_override("h_separation", 8)
	_grid_container.add_theme_constant_override("v_separation", 8)
	center.add_child(_grid_container)

	# 创建卡牌
	var rows: int = _preset.grid_rows
	var cols: int = _preset.grid_cols
	_card_nodes.resize(rows)
	_card_icons.resize(rows)
	_card_backs.resize(rows)

	for row: int in range(rows):
		var node_row: Array = []
		var icon_row: Array = []
		var back_row: Array = []
		node_row.resize(cols)
		icon_row.resize(cols)
		back_row.resize(cols)

		for col: int in range(cols):
			var card := Button.new()
			card.custom_minimum_size = Vector2(90, 110)
			card.clip_contents = true
			card.pressed.connect(_on_card_pressed.bind(row, col))

			# 卡牌样式
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.25, 0.30)
			style.set_corner_radius_all(8)
			style.set_content_margin_all(4)
			card.add_theme_stylebox_override("normal", style)

			var hover := StyleBoxFlat.new()
			hover.bg_color = Color(0.30, 0.30, 0.38)
			hover.set_corner_radius_all(8)
			hover.set_content_margin_all(4)
			card.add_theme_stylebox_override("hover", hover)

			var pressed_style := StyleBoxFlat.new()
			pressed_style.bg_color = Color(0.35, 0.35, 0.42)
			pressed_style.set_corner_radius_all(8)
			pressed_style.set_content_margin_all(4)
			card.add_theme_stylebox_override("pressed", pressed_style)

			var disabled_style := StyleBoxFlat.new()
			disabled_style.bg_color = Color(0.2, 0.6, 0.2, 0.3)
			disabled_style.set_corner_radius_all(8)
			disabled_style.set_content_margin_all(4)
			card.add_theme_stylebox_override("disabled", disabled_style)

			# 背面内容（?）
			var back_label := Label.new()
			back_label.text = "?"
			back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			back_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			back_label.add_theme_font_size_override("font_size", 32)
			back_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			card.add_child(back_label)

			# 正面内容（素材图标）
			var card_id: int = _data.grid[row][col]
			var asset_info: Array = _asset_keys[card_id]
			var category: String = asset_info[0] as String
			var key: String = asset_info[1] as String
			var icon_node: Control = _create_card_face(category, key)
			icon_node.visible = false
			card.add_child(icon_node)

			_grid_container.add_child(card)
			node_row[col] = card
			icon_row[col] = icon_node
			back_row[col] = back_label

		_card_nodes[row] = node_row
		_card_icons[row] = icon_row
		_card_backs[row] = back_row


## 创建卡牌正面显示内容
func _create_card_face(category: String, key: String) -> Control:
	var container := CenterContainer.new()
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# 尝试加载图片
	var tex: Texture2D = null
	if category == "icon":
		var path: String = AssetRegistry.ICON_DIR + key + ".png"
		if ResourceLoader.exists(path) and DisplayServer.get_name() != "headless":
			tex = load(path) as Texture2D
	elif category == "portrait":
		tex = AssetRegistry.get_texture("portrait", key)

	if tex != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(tex_rect)
	else:
		# 占位：文字
		var fallback := Label.new()
		fallback.text = key.substr(0, 3).to_upper()
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 16)
		fallback.add_theme_color_override("font_color", Color.WHITE)
		container.add_child(fallback)

	return container


func _process(delta: float) -> void:
	if _data == null or _data.is_finished:
		return
	_data.advance_time(delta)
	_update_hud()
	if _data.is_finished:
		_finish_game()


func _update_hud() -> void:
	var remaining: float = maxf(_data.time_limit - _data.elapsed, 0.0)
	_time_label.text = "剩余：%.1fs" % remaining
	if remaining <= 5.0:
		_time_label.add_theme_color_override("font_color", Color.RED)
	_pairs_label.text = "配对：%d/%d" % [_data.matched_pairs, _data.total_pairs]


func _on_card_pressed(row: int, col: int) -> void:
	if _animating or _data == null or _data.is_finished:
		return

	var result: MemoryMatchData.PickResult = _data.pick_card(row, col)

	match result:
		MemoryMatchData.PickResult.FIRST_REVEALED:
			_animating = true
			_flip_to_front(row, col, func() -> void:
				_animating = false
			)
		MemoryMatchData.PickResult.MATCH_SUCCESS:
			_animating = true
			# 找到另一张配对牌（first_pick已经被data清了，遍历找已matched但未disabled的）
			var first: Vector2i = Vector2i(-1, -1)
			for r: int in range(_preset.grid_rows):
				for c: int in range(_preset.grid_cols):
					if _data.matched[r][c] and Vector2i(r, c) != Vector2i(row, col):
						if not (_card_nodes[r][c] as Button).disabled:
							first = Vector2i(r, c)
			_flip_to_front(row, col, func() -> void:
				_match_success_anim(first, Vector2i(row, col))
			)
		MemoryMatchData.PickResult.MATCH_FAIL:
			_animating = true
			# 找第一张翻开的牌（data已翻回，但UI上icon仍然visible）
			_peek_pair = []
			for r: int in range(_preset.grid_rows):
				for c: int in range(_preset.grid_cols):
					if not _data.matched[r][c] and (_card_icons[r][c] as Control).visible:
						_peek_pair.append(Vector2i(r, c))
			_peek_pair.append(Vector2i(row, col))
			_flip_to_front(row, col, func() -> void:
				# 停留让玩家记住
				if not is_inside_tree():
					_animating = false
					return
				var timer: SceneTreeTimer = get_tree().create_timer(_preset.peek_duration)
				timer.timeout.connect(_flip_back_pair)
			)
		MemoryMatchData.PickResult.INVALID:
			pass


## 翻到正面动画（scale.x 压缩→换内容→展开）
func _flip_to_front(row: int, col: int, on_complete: Callable) -> void:
	var card: Button = _card_nodes[row][col]
	var icon: Control = _card_icons[row][col]
	var back: Control = _card_backs[row][col]
	var duration: float = _preset.flip_duration * 0.5

	if DisplayServer.get_name() == "headless":
		back.visible = false
		icon.visible = true
		on_complete.call()
		return

	card.pivot_offset = card.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		back.visible = false
		icon.visible = true
	)
	tween.tween_property(card, "scale:x", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(on_complete)


## 翻回背面动画
func _flip_to_back(row: int, col: int, on_complete: Callable) -> void:
	var card: Button = _card_nodes[row][col]
	var icon: Control = _card_icons[row][col]
	var back: Control = _card_backs[row][col]
	var duration: float = _preset.flip_duration * 0.5

	if DisplayServer.get_name() == "headless":
		icon.visible = false
		back.visible = true
		on_complete.call()
		return

	card.pivot_offset = card.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		icon.visible = false
		back.visible = true
	)
	tween.tween_property(card, "scale:x", 1.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(on_complete)


## 配对失败：翻回两张牌
func _flip_back_pair() -> void:
	if _peek_pair.size() < 2:
		_animating = false
		return
	var pos_a: Vector2i = _peek_pair[0] as Vector2i
	var pos_b: Vector2i = _peek_pair[1] as Vector2i
	_peek_pair.clear()

	# 闪红
	_flash_card(pos_a, Color.RED, 0.15)
	_flash_card(pos_b, Color.RED, 0.15)

	# 翻回（用 Array 包装计数器，确保 lambda 共享引用而非值拷贝）
	var counter: Array[int] = [0]
	var check_done: Callable = func() -> void:
		counter[0] += 1
		if counter[0] >= 2:
			_animating = false
	_flip_to_back(pos_a.x, pos_a.y, check_done)
	_flip_to_back(pos_b.x, pos_b.y, check_done)


## 配对成功动画：闪绿 + 缩小消失
func _match_success_anim(pos_a: Vector2i, pos_b: Vector2i) -> void:
	_flash_card(pos_a, Color.GREEN, 0.2)
	_flash_card(pos_b, Color.GREEN, 0.2)

	if DisplayServer.get_name() == "headless":
		(_card_nodes[pos_a.x][pos_a.y] as Button).disabled = true
		(_card_nodes[pos_b.x][pos_b.y] as Button).disabled = true
		_animating = false
		if _data.is_finished:
			_finish_game()
		return

	# 用 Array 包装计数器，确保 lambda 共享引用而非值拷贝
	var counter: Array[int] = [0]
	var check_done: Callable = func() -> void:
		counter[0] += 1
		if counter[0] >= 2:
			_animating = false
			if _data.is_finished:
				_finish_game()

	for pos: Vector2i in [pos_a, pos_b]:
		var card: Button = _card_nodes[pos.x][pos.y]
		card.pivot_offset = card.size / 2.0
		var tween: Tween = create_tween()
		tween.tween_interval(0.2)
		tween.tween_property(card, "scale", Vector2.ZERO, 0.3) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(func() -> void:
			card.disabled = true
			card.modulate.a = 0.0
			check_done.call()
		)


## 闪色效果
func _flash_card(pos: Vector2i, color: Color, duration: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var card: Button = _card_nodes[pos.x][pos.y]
	var original: Color = card.modulate
	var tween: Tween = create_tween()
	tween.tween_property(card, "modulate", color, duration * 0.5)
	tween.tween_property(card, "modulate", original, duration * 0.5)


## 游戏结束
func _finish_game() -> void:
	var result: String = _data.get_result_tier()
	var rate: float = _data.get_completion_rate()
	game_finished.emit(result, rate)
