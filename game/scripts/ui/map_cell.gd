# map_cell.gd — 单个地图格子UI脚本
# 职责：显示格子状态（隐藏/迷雾/揭开），处理点击，显示稀有度，开格子loading动画
extends Button

## 信号：格子被点击，传递行列坐标
signal cell_clicked(row: int, col: int)
## 信号：loading 完成，传递行列坐标
signal cell_loading_finished(row: int, col: int)
## 信号：loading 过程中每消耗一个月触发一次
signal cell_month_tick(row: int, col: int)

## 格子坐标
var row: int = 0
var col: int = 0

## 格子数据
var cell_type: FogMap.CellType = FogMap.CellType.EMPTY
var cell_state: FogMap.CellState = FogMap.CellState.HIDDEN
var rarity: FogMap.Rarity = FogMap.Rarity.COMMON

## Loading 状态
var _is_loading: bool = false
var _loading_progress: float = 0.0        ## 0.0 ~ 1.0
var _loading_duration: float = 0.5        ## loading 总时长（秒）
var _loading_color: Color = Color.WHITE   ## 进度环颜色
var _loading_month_cost: int = 1          ## 总消耗月数
var _loading_months_consumed: int = 0     ## 已触发的月数 tick

## 绘制层节点（在所有子节点之上绘制进度环）
var _draw_layer: Control = null

## 图标图片节点（揭开后显示）
var _icon_rect: TextureRect = null

## 迷雾问号晃动动画 Tween
var _wobble_tween: Tween = null

## 呼吸脉冲动画 Tween
var _breath_tween: Tween = null

## 呼吸脉冲原始背景色
var _breath_base_color: Color = COLOR_FOGGY

## 图标纹理缓存（static 级别，所有格子共用）
static var _icon_tex_cache: Dictionary = {}

## 子节点
@onready var bg_rect: ColorRect = $BG
@onready var icon_label: Label = $IconLabel
@onready var glow_rect: ColorRect = $Glow

## 颜色配置
const COLOR_HIDDEN: Color = Color(0.15, 0.15, 0.18, 1.0)       ## 未知-深灰
const COLOR_FOGGY: Color = Color(0.25, 0.25, 0.30, 1.0)        ## 迷雾-稍亮
const COLOR_EMPTY: Color = Color(0.35, 0.35, 0.38, 1.0)        ## 空地-灰
const COLOR_SEARCH: Color = Color(0.2, 0.55, 0.2, 1.0)         ## 搜类-绿
const COLOR_FIGHT: Color = Color(0.65, 0.15, 0.15, 1.0)        ## 打类-红
const COLOR_TREASURE: Color = Color(0.75, 0.6, 0.1, 1.0)       ## 宝箱-金
const COLOR_PLAYTEST: Color = Color(0.1, 0.6, 0.6, 1.0)        ## 内测-青
const COLOR_POLISH: Color = Color(0.5, 0.2, 0.6, 1.0)          ## 打磨-紫
const COLOR_EXIT: Color = Color(0.8, 0.45, 0.1, 1.0)           ## 出口-橙
const COLOR_WALL: Color = Color(0.08, 0.08, 0.08, 1.0)         ## 路障-黑
const COLOR_START: Color = Color(0.3, 0.5, 0.7, 1.0)           ## 起点-蓝

## 类型图标 emoji（用于通过 AssetRegistry 查找图标图片）
const TYPE_ICON_EMOJI: Dictionary = {
	FogMap.CellType.EMPTY: "",
	FogMap.CellType.SEARCH_EVENT: "🔍",
	FogMap.CellType.FIGHT_EVENT: "⚠️",
	FogMap.CellType.TREASURE: "💎",
	FogMap.CellType.PLAYTEST: "🔬",
	FogMap.CellType.POLISH: "✨",
	FogMap.CellType.EXIT: "🚀",
	FogMap.CellType.WALL: "",
}

## 文字 fallback（无图时显示）
const TYPE_ICONS_FALLBACK: Dictionary = {
	FogMap.CellType.EMPTY: "·",
	FogMap.CellType.SEARCH_EVENT: "?!",
	FogMap.CellType.FIGHT_EVENT: "!!",
	FogMap.CellType.TREASURE: "<>",
	FogMap.CellType.PLAYTEST: ">>",
	FogMap.CellType.POLISH: "**",
	FogMap.CellType.EXIT: "=>",
	FogMap.CellType.WALL: "█",
}

## 起点图标
const START_EMOJI: String = "🏆"


## 是否为起点
var is_start: bool = false
var _legendary_pulse_played: bool = false

## 进度环参数
const RING_RADIUS: float = 20.0          ## 圆环半径
const RING_WIDTH: float = 3.0            ## 圆环线宽
const RING_BG_ALPHA: float = 0.25        ## 底环透明度
const RING_SEGMENTS: int = 64            ## 圆弧段数


func _ready() -> void:
	pressed.connect(_on_pressed)

	# 创建图标 TextureRect（居中，揭开后显示图片图标）
	_icon_rect = TextureRect.new()
	_icon_rect.name = "IconRect"
	_icon_rect.set_anchors_and_offsets_preset(PRESET_CENTER)
	_icon_rect.custom_minimum_size = Vector2(24, 24)
	_icon_rect.size = Vector2(24, 24)
	# 居中：手动偏移到格子中心
	_icon_rect.position = Vector2(-12, -12)  # 会在 update_visual 中重算
	_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.visible = false
	add_child(_icon_rect)

	# 创建绘制层——在所有子节点之上，用于绘制进度环
	_draw_layer = Control.new()
	_draw_layer.name = "DrawLayer"
	_draw_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.draw.connect(_on_draw_layer_draw)
	add_child(_draw_layer)
	update_visual()


## 初始化格子
func setup(p_row: int, p_col: int, p_type: FogMap.CellType, p_state: FogMap.CellState, p_rarity: FogMap.Rarity = FogMap.Rarity.COMMON) -> void:
	row = p_row
	col = p_col
	cell_type = p_type
	cell_state = p_state
	rarity = p_rarity
	if is_node_ready():
		update_visual()


## 更新显示状态
func update_state(new_state: FogMap.CellState, new_type: FogMap.CellType, new_rarity: FogMap.Rarity = FogMap.Rarity.COMMON) -> void:
	cell_state = new_state
	cell_type = new_type
	rarity = new_rarity
	if not _is_loading:
		update_visual()


## 更新视觉
func update_visual() -> void:
	if not is_node_ready():
		return

	match cell_state:
		FogMap.CellState.HIDDEN:
			_show_hidden()
		FogMap.CellState.FOGGY:
			_show_foggy()
		FogMap.CellState.REVEALED:
			_show_revealed()


func _show_hidden() -> void:
	_stop_wobble()
	bg_rect.color = COLOR_HIDDEN
	icon_label.text = ""
	icon_label.visible = true
	_icon_rect.visible = false
	glow_rect.color = Color(0, 0, 0, 0)
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _show_foggy() -> void:
	bg_rect.color = COLOR_FOGGY
	# 尝试用图标图片显示问号
	var tex: Texture2D = _get_icon_texture("❓")
	if tex != null and DisplayServer.get_name() != "headless":
		_icon_rect.texture = tex
		var cell_size: Vector2 = size
		_icon_rect.position = (cell_size - Vector2(24, 24)) / 2.0
		_icon_rect.visible = true
		icon_label.visible = false
	else:
		_icon_rect.visible = false
		icon_label.visible = true
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.text = "?"
	# 光晕颜色改为稀有度颜色（而非类型颜色）
	var rarity_color: Color = _get_rarity_glow_color()
	glow_rect.color = rarity_color
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 启动问号晃动动画
	_start_wobble()

	# 撤离点特殊显示：穿透迷雾，显示橙色边框和图标
	if cell_type == FogMap.CellType.EXIT:
		_show_icon_texture("🚀", "=>")
		glow_rect.color = Color(Config.MAP_EXIT_BORDER_COLOR.r, Config.MAP_EXIT_BORDER_COLOR.g, Config.MAP_EXIT_BORDER_COLOR.b, 0.5)
		# 撤离点不可直接点击（需要连通路径）
		disabled = true
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _show_revealed() -> void:
	_stop_wobble()
	if is_start:
		bg_rect.color = COLOR_START
		_show_icon_texture(START_EMOJI, "★")
	else:
		# 背景色用稀有度颜色（揭示时的"开箱"闪变）
		bg_rect.color = _get_rarity_reveal_color()
		var emoji: String = TYPE_ICON_EMOJI.get(cell_type, "") as String
		var fallback: String = TYPE_ICONS_FALLBACK.get(cell_type, "") as String
		_show_icon_texture(emoji, fallback)
	glow_rect.color = Color(0, 0, 0, 0)
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	# 传说级揭示脉冲动画（只播一次）
	if rarity == FogMap.Rarity.LEGENDARY and not is_start and not _legendary_pulse_played:
		_legendary_pulse_played = true
		_play_legendary_reveal()


## 尝试显示图标图片，失败则显示文字 fallback
func _show_icon_texture(emoji: String, fallback_text: String) -> void:
	if emoji == "" or DisplayServer.get_name() == "headless":
		icon_label.text = fallback_text
		icon_label.visible = true
		_icon_rect.visible = false
		return

	var tex: Texture2D = _get_icon_texture(emoji)
	if tex != null:
		_icon_rect.texture = tex
		# 居中定位
		var cell_size: Vector2 = size
		_icon_rect.position = (cell_size - Vector2(24, 24)) / 2.0
		_icon_rect.visible = true
		icon_label.visible = false
	else:
		icon_label.text = fallback_text
		icon_label.visible = true
		_icon_rect.visible = false


## 从缓存获取图标纹理
func _get_icon_texture(emoji: String) -> Texture2D:
	if _icon_tex_cache.has(emoji):
		return _icon_tex_cache[emoji] as Texture2D

	var icon_name: String = AssetRegistry.EMOJI_ICON_MAP.get(emoji, "") as String
	if icon_name.is_empty():
		return null
	var path: String = AssetRegistry.ICON_DIR + icon_name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_icon_tex_cache[emoji] = tex
	return tex


## ===== Loading 动画 =====

## 开始 loading 动画
func start_loading() -> void:
	_stop_wobble()
	var rarity_name: String = FogMap.RARITY_NAMES[rarity]
	_loading_duration = Config.RARITY_LOADING_DURATION.get(rarity_name, 0.5) as float
	var level_data: Dictionary = Config.RARITY_LEVELS.get(rarity_name, {})
	_loading_color = Color.WHITE
	_loading_progress = 0.0
	_loading_month_cost = Config.RARITY_MONTH_COST.get(rarity_name, 1) as int
	_loading_months_consumed = 0
	_is_loading = true

	# 禁用自身
	disabled = true

	# 问号消散动画（C）：放大 + 旋转 + 淡出，0.3s
	var dissolve_duration: float = 0.3
	var dissolve_target: Control = _icon_rect if _icon_rect.visible else icon_label as Control

	# 设置旋转锚点为中心
	if dissolve_target == _icon_rect:
		_icon_rect.pivot_offset = Vector2(12, 12)
	else:
		icon_label.pivot_offset = icon_label.size / 2.0

	var dissolve_tween: Tween = create_tween().set_parallel(true)
	dissolve_tween.tween_property(dissolve_target, "scale", Vector2(2.0, 2.0), dissolve_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	dissolve_tween.tween_property(dissolve_target, "rotation_degrees", 45.0, dissolve_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	dissolve_tween.tween_property(dissolve_target, "modulate:a", 0.0, dissolve_duration) \
		.set_ease(Tween.EASE_IN)

	# 消散完成后：隐藏图标，重置属性，启动进度环 + 呼吸脉冲
	dissolve_tween.chain().tween_callback(_on_dissolve_finished.bind(dissolve_target))


## 消散动画完成，启动进度环和呼吸脉冲
func _on_dissolve_finished(target: Control) -> void:
	# 重置消散目标的变换属性
	target.scale = Vector2.ONE
	target.rotation_degrees = 0.0
	target.modulate.a = 1.0

	# 隐藏问号
	icon_label.text = ""
	icon_label.visible = false
	_icon_rect.visible = false

	# 启动呼吸脉冲（A）
	_start_breath_pulse()

	# 启动进度环
	var tween: Tween = create_tween()
	tween.tween_method(_set_loading_progress, 0.0, 1.0, _loading_duration)
	tween.tween_callback(_on_loading_complete)


## 是否正在 loading
func is_loading() -> bool:
	return _is_loading


## 获取该格子消耗的月数
func get_month_cost() -> int:
	var rarity_name: String = FogMap.RARITY_NAMES[rarity]
	return Config.RARITY_MONTH_COST.get(rarity_name, 1) as int


func _set_loading_progress(value: float) -> void:
	_loading_progress = value
	# 检查是否该触发新的月数 tick
	# 把进度 0~1 等分为 _loading_month_cost 段，每跨过一个节点消耗 1 个月
	if _loading_month_cost > 0:
		var expected_months: int = mini(int(value * _loading_month_cost) + 1, _loading_month_cost)
		# value == 0.0 时也算跨入第 1 段
		if value <= 0.0:
			expected_months = 0
		while _loading_months_consumed < expected_months:
			_loading_months_consumed += 1
			cell_month_tick.emit(row, col)
	if _draw_layer:
		_draw_layer.queue_redraw()


func _on_loading_complete() -> void:
	_is_loading = false
	_loading_progress = 0.0
	_stop_breath_pulse()
	if _draw_layer:
		_draw_layer.queue_redraw()
	# 揭示动画：颜色闪变（在 cell_loading_finished 之前，让 dev_running 处理后再更新视觉）
	cell_loading_finished.emit(row, col)


## 绘制进度环（在 DrawLayer 上，确保在所有子节点之上）
func _on_draw_layer_draw() -> void:
	if not _is_loading:
		return

	var center: Vector2 = _draw_layer.size / 2.0
	var start_angle: float = -PI / 2.0  # 从12点方向开始

	# 底环（半透明完整圆）
	var bg_color: Color = Color(_loading_color.r, _loading_color.g, _loading_color.b, RING_BG_ALPHA)
	_draw_arc_on(_draw_layer, center, RING_RADIUS, start_angle, start_angle + TAU, bg_color)

	# 进度环
	if _loading_progress > 0.0:
		var end_angle: float = start_angle + TAU * _loading_progress
		_draw_arc_on(_draw_layer, center, RING_RADIUS, start_angle, end_angle, _loading_color)


## 在指定 Control 上绘制圆弧
func _draw_arc_on(target: Control, center: Vector2, radius: float, angle_from: float, angle_to: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = maxi(int(RING_SEGMENTS * absf(angle_to - angle_from) / TAU), 4)
	for i: int in range(seg_count + 1):
		var angle: float = angle_from + (angle_to - angle_from) * float(i) / float(seg_count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 2:
		target.draw_polyline(points, color, RING_WIDTH, true)


## ===== 稀有度颜色 =====

## 获取稀有度对应的光晕颜色（2档制：暗/亮）
func _get_rarity_glow_color() -> Color:
	# 稀有度 >= RARE 显示统一暖白微光，否则无光晕
	if rarity >= Config.MAP_GLOW_RARITY_THRESHOLD:
		return Color(Config.MAP_GLOW_COLOR.r, Config.MAP_GLOW_COLOR.g, Config.MAP_GLOW_COLOR.b, Config.MAP_GLOW_ALPHA)
	else:
		return Color(0, 0, 0, 0)


## 揭示时的背景色：稀有度颜色（预放置特殊格子用类型颜色）
func _get_rarity_reveal_color() -> Color:
	# 预放置特殊格子保持类型颜色
	match cell_type:
		FogMap.CellType.WALL:
			return COLOR_WALL
		FogMap.CellType.PLAYTEST:
			return COLOR_PLAYTEST
		FogMap.CellType.POLISH:
			return COLOR_POLISH
		FogMap.CellType.EXIT:
			return COLOR_EXIT
	# 普通格子用稀有度颜色
	var rarity_name: String = FogMap.RARITY_NAMES[rarity]
	var level_data: Dictionary = Config.RARITY_LEVELS.get(rarity_name, {})
	var base_color: Color = level_data.get("color", Color(0.5, 0.5, 0.5)) as Color
	# 稍微压暗作为背景（不刺眼）
	return base_color.darkened(0.3)


func _get_type_color() -> Color:
	match cell_type:
		FogMap.CellType.EMPTY:
			return COLOR_EMPTY
		FogMap.CellType.SEARCH_EVENT:
			return COLOR_SEARCH
		FogMap.CellType.FIGHT_EVENT:
			return COLOR_FIGHT
		FogMap.CellType.TREASURE:
			return COLOR_TREASURE
		FogMap.CellType.PLAYTEST:
			return COLOR_PLAYTEST
		FogMap.CellType.POLISH:
			return COLOR_POLISH
		FogMap.CellType.EXIT:
			return COLOR_EXIT
		FogMap.CellType.WALL:
			return COLOR_WALL
		_:
			return COLOR_EMPTY


func _on_pressed() -> void:
	cell_clicked.emit(row, col)


## ===== 迷雾问号晃动动画 =====
const WOBBLE_ANGLE: float = 12.0     ## 最大旋转角度（度）
const WOBBLE_DURATION: float = 0.6   ## 单次摆动时长（秒）
const WOBBLE_PAUSE: float = 1.2      ## 两次摆动之间的停顿（秒）

func _start_wobble() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_stop_wobble()
	if not is_instance_valid(_icon_rect) or not _icon_rect.visible:
		return
	# 设置旋转锚点为图标中心
	_icon_rect.pivot_offset = Vector2(12, 12)
	_wobble_tween = create_tween().set_loops()
	# 左摆
	_wobble_tween.tween_property(_icon_rect, "rotation_degrees", -WOBBLE_ANGLE, WOBBLE_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).from(0.0)
	# 右摆
	_wobble_tween.tween_property(_icon_rect, "rotation_degrees", WOBBLE_ANGLE, WOBBLE_DURATION) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# 回正
	_wobble_tween.tween_property(_icon_rect, "rotation_degrees", 0.0, WOBBLE_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# 停顿
	_wobble_tween.tween_interval(WOBBLE_PAUSE)


func _stop_wobble() -> void:
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()
		_wobble_tween = null
	if is_instance_valid(_icon_rect):
		_icon_rect.rotation_degrees = 0.0


## ===== 呼吸脉冲动画（loading 中背景明暗闪烁）=====
const BREATH_BRIGHT: float = 0.35     ## 亮峰：背景色增亮幅度
const BREATH_CYCLE: float = 0.5       ## 单次呼吸周期（秒）

func _start_breath_pulse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_stop_breath_pulse()
	_breath_base_color = bg_rect.color
	var bright_color: Color = _breath_base_color.lightened(BREATH_BRIGHT)
	# 呼吸脉冲使用纯白色提亮，不泄露稀有度
	bright_color = bright_color.lerp(Color.WHITE, 0.15)

	_breath_tween = create_tween().set_loops()
	# 亮起
	_breath_tween.tween_property(bg_rect, "color", bright_color, BREATH_CYCLE * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# 暗回
	_breath_tween.tween_property(bg_rect, "color", _breath_base_color, BREATH_CYCLE * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_breath_pulse() -> void:
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
		_breath_tween = null


## 传说级揭示脉冲动画（放大再回弹）
func _play_legendary_reveal() -> void:
	if DisplayServer.get_name() == "headless":
		return
	pivot_offset = size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(Config.LEGENDARY_REVEAL_SCALE, Config.LEGENDARY_REVEAL_SCALE), Config.LEGENDARY_REVEAL_DURATION * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, Config.LEGENDARY_REVEAL_DURATION * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
