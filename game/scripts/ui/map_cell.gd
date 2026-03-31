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

## 类型图标
const TYPE_ICONS: Dictionary = {
	FogMap.CellType.EMPTY: "·",
	FogMap.CellType.SEARCH_EVENT: "🔍",
	FogMap.CellType.FIGHT_EVENT: "⚠️",
	FogMap.CellType.TREASURE: "💎",
	FogMap.CellType.PLAYTEST: "🔬",
	FogMap.CellType.POLISH: "✨",
	FogMap.CellType.EXIT: "🚀",
	FogMap.CellType.WALL: "█",
}

## 稀有度标记符号（迷雾状态显示在 ? 旁边）
const RARITY_MARKS: Dictionary = {
	FogMap.Rarity.COMMON: "",
	FogMap.Rarity.UNCOMMON: "+",
	FogMap.Rarity.RARE: "★",
	FogMap.Rarity.EPIC: "♦",
	FogMap.Rarity.LEGENDARY: "♛",
}

## 是否为起点
var is_start: bool = false

## 进度环参数
const RING_RADIUS: float = 20.0          ## 圆环半径
const RING_WIDTH: float = 3.0            ## 圆环线宽
const RING_BG_ALPHA: float = 0.25        ## 底环透明度
const RING_SEGMENTS: int = 64            ## 圆弧段数


func _ready() -> void:
	pressed.connect(_on_pressed)
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
	bg_rect.color = COLOR_HIDDEN
	icon_label.text = ""
	glow_rect.color = Color(0, 0, 0, 0)
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _show_foggy() -> void:
	bg_rect.color = COLOR_FOGGY
	# 显示 ? + 稀有度标记
	var mark: String = RARITY_MARKS.get(rarity, "") as String
	if mark != "":
		icon_label.text = "?%s" % mark
	else:
		icon_label.text = "?"
	# 光晕颜色改为稀有度颜色（而非类型颜色）
	var rarity_color: Color = _get_rarity_glow_color()
	glow_rect.color = rarity_color
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _show_revealed() -> void:
	if is_start:
		bg_rect.color = COLOR_START
		icon_label.text = "★"
	else:
		bg_rect.color = _get_type_color()
		icon_label.text = TYPE_ICONS.get(cell_type, "") as String
	glow_rect.color = Color(0, 0, 0, 0)
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW


## ===== Loading 动画 =====

## 开始 loading 动画
func start_loading() -> void:
	var rarity_name: String = FogMap.RARITY_NAMES[rarity]
	_loading_duration = Config.RARITY_LOADING_DURATION.get(rarity_name, 0.5) as float
	var level_data: Dictionary = Config.RARITY_LEVELS.get(rarity_name, {})
	_loading_color = level_data.get("color", Color(0.7, 0.7, 0.7)) as Color
	_loading_progress = 0.0
	_loading_month_cost = Config.RARITY_MONTH_COST.get(rarity_name, 1) as int
	_loading_months_consumed = 0
	_is_loading = true

	# 隐藏 ? 图标，显示空
	icon_label.text = ""

	# 禁用自身
	disabled = true

	# 用 Tween 驱动进度
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
	if _draw_layer:
		_draw_layer.queue_redraw()
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

## 获取稀有度对应的光晕颜色
func _get_rarity_glow_color() -> Color:
	var rarity_name: String = FogMap.RARITY_NAMES[rarity]
	var level_data: Dictionary = Config.RARITY_LEVELS.get(rarity_name, {})
	var base_color: Color = level_data.get("color", Color(0.5, 0.5, 0.5)) as Color
	# 稀有度越高光晕越亮
	var alpha: float = 0.08
	match rarity:
		FogMap.Rarity.COMMON:
			alpha = 0.08
		FogMap.Rarity.UNCOMMON:
			alpha = 0.15
		FogMap.Rarity.RARE:
			alpha = 0.22
		FogMap.Rarity.EPIC:
			alpha = 0.30
		FogMap.Rarity.LEGENDARY:
			alpha = 0.40
	return Color(base_color.r, base_color.g, base_color.b, alpha)


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
