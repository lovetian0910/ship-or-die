# fog_map.gd — 迷雾地图数据层
# 职责：8×8网格状态管理、揭开逻辑、邻接计算、稀有度延迟随机
class_name FogMap
extends RefCounted

## 格子类型
enum CellType { EMPTY, SEARCH_EVENT, FIGHT_EVENT, TREASURE, PLAYTEST, POLISH, EXIT, WALL }

## 格子状态
enum CellState { HIDDEN, FOGGY, REVEALED }

## 稀有度等级
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## 稀有度名称映射（用于查 Config 字典）
const RARITY_NAMES: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]

## 地图尺寸
const MAP_SIZE: int = 8

## 地图数据
var cells: Array = []       ## [row][col] = CellType
var states: Array = []      ## [row][col] = CellState
var rarities: Array = []    ## [row][col] = Rarity（稀有度）
var start_pos: Vector2i = Vector2i.ZERO

## 预放置格子集合（这些格子在生成时已确定类型，不走延迟随机）
var _preplaced: Dictionary = {}  ## Vector2i -> true

## 统计
var revealed_count: int = 0


func _init() -> void:
	# 初始化空网格
	cells.resize(MAP_SIZE)
	states.resize(MAP_SIZE)
	rarities.resize(MAP_SIZE)
	for row: int in range(MAP_SIZE):
		var cell_row: Array = []
		var state_row: Array = []
		var rarity_row: Array = []
		cell_row.resize(MAP_SIZE)
		state_row.resize(MAP_SIZE)
		rarity_row.resize(MAP_SIZE)
		for col: int in range(MAP_SIZE):
			cell_row[col] = CellType.EMPTY
			state_row[col] = CellState.HIDDEN
			rarity_row[col] = Rarity.COMMON
		cells[row] = cell_row
		states[row] = state_row
		rarities[row] = rarity_row


## 设置格子类型（供生成器使用）
func set_cell(row: int, col: int, cell_type: CellType) -> void:
	if _in_bounds(row, col):
		cells[row][col] = cell_type


## 标记为预放置格子（类型在生成时已确定，不走延迟随机）
func mark_preplaced(row: int, col: int) -> void:
	_preplaced[Vector2i(row, col)] = true


## 是否为预放置格子
func is_preplaced(row: int, col: int) -> bool:
	return _preplaced.has(Vector2i(row, col))


## 获取格子类型
func get_cell_type(row: int, col: int) -> CellType:
	if _in_bounds(row, col):
		return cells[row][col] as CellType
	return CellType.WALL


## 获取格子状态
func get_cell_state(row: int, col: int) -> CellState:
	if _in_bounds(row, col):
		return states[row][col] as CellState
	return CellState.HIDDEN


## 获取格子稀有度
func get_cell_rarity(row: int, col: int) -> Rarity:
	if _in_bounds(row, col):
		return rarities[row][col] as Rarity
	return Rarity.COMMON


## 设置格子稀有度
func set_cell_rarity(row: int, col: int, rarity: Rarity) -> void:
	if _in_bounds(row, col):
		rarities[row][col] = rarity


## 初始化起点：揭开起点 + 相邻格变为可点击（FOGGY）
func init_start(pos: Vector2i) -> void:
	start_pos = pos
	mark_preplaced(pos.x, pos.y)
	_reveal(pos.x, pos.y)
	_make_neighbors_foggy(pos.x, pos.y)


## 揭开格子，返回格子类型；如果不可揭开返回 null
## 对非预放置格子，揭开时按稀有度随机决定实际类型
func reveal_cell(row: int, col: int) -> Variant:
	if not _in_bounds(row, col):
		return null
	if states[row][col] != CellState.FOGGY:
		return null
	if cells[row][col] == CellType.WALL:
		return null

	# 延迟随机：非预放置格子在揭开时才决定类型
	if not is_preplaced(row, col):
		var rarity: Rarity = rarities[row][col] as Rarity
		cells[row][col] = _roll_cell_type(rarity)

	_reveal(row, col)
	_make_neighbors_foggy(row, col)
	return cells[row][col]


## 根据稀有度随机决定格子类型
static func _roll_cell_type(rarity: Rarity) -> CellType:
	var rarity_name: String = RARITY_NAMES[rarity]
	var weights: Dictionary = Config.RARITY_TYPE_WEIGHTS.get(rarity_name, {})
	var w_empty: float = weights.get("empty", 0.5) as float
	var w_search: float = weights.get("search", 0.2) as float
	var w_fight: float = weights.get("fight", 0.2) as float
	# treasure 是剩余概率

	var roll: float = randf()
	if roll < w_empty:
		return CellType.EMPTY
	elif roll < w_empty + w_search:
		return CellType.SEARCH_EVENT
	elif roll < w_empty + w_search + w_fight:
		return CellType.FIGHT_EVENT
	else:
		return CellType.TREASURE


## 获取所有当前可点击的格子（FOGGY 且非 WALL）
func get_clickable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row: int in range(MAP_SIZE):
		for col: int in range(MAP_SIZE):
			if states[row][col] == CellState.FOGGY and cells[row][col] != CellType.WALL:
				result.append(Vector2i(row, col))
	return result


## 获取指定格子的有效邻居坐标（上下左右）
func get_neighbors(row: int, col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d: Vector2i in dirs:
		var nr: int = row + d.x
		var nc: int = col + d.y
		if _in_bounds(nr, nc):
			result.append(Vector2i(nr, nc))
	return result


## 计算曼哈顿距离
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 内部：揭开单个格子
func _reveal(row: int, col: int) -> void:
	states[row][col] = CellState.REVEALED
	revealed_count += 1


## 内部：将相邻格设为 FOGGY（如果还是 HIDDEN 且非路障直接可见）
func _make_neighbors_foggy(row: int, col: int) -> void:
	for n: Vector2i in get_neighbors(row, col):
		if states[n.x][n.y] == CellState.HIDDEN:
			if cells[n.x][n.y] == CellType.WALL:
				# 路障直接可见（REVEALED 但标记为 WALL）
				states[n.x][n.y] = CellState.REVEALED
			else:
				states[n.x][n.y] = CellState.FOGGY


## 内部：边界检查
func _in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < MAP_SIZE and col >= 0 and col < MAP_SIZE
