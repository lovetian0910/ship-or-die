# code_rescue_grid.gd — 代码急救小游戏：纯数据层（6×6网格）
class_name CodeRescueGrid
extends RefCounted

## 格子状态枚举
enum CellState { PENDING, BUG, REPAIRED, CRASHED }

const GRID_SIZE: int = 6
const CRASH_THRESHOLD: int = 3   ## bug连续N次扩散tick未修复 → 崩溃

## 网格数据：二维数组 [row][col]
var cells: Array = []             ## Array[Array[int]]  CellState值
var bug_timers: Array = []        ## Array[Array[int]]  每格bug存在的tick数

## 统计
var total_cells: int = GRID_SIZE * GRID_SIZE
var pending_count: int = total_cells
var bug_count: int = 0
var repaired_count: int = 0
var crashed_count: int = 0


## ===== 初始化网格 =====
func init_grid(bug_positions: Array) -> void:
	cells.clear()
	bug_timers.clear()
	pending_count = total_cells
	bug_count = 0
	repaired_count = 0
	crashed_count = 0

	for row: int in range(GRID_SIZE):
		var cell_row: Array = []
		var timer_row: Array = []
		for col: int in range(GRID_SIZE):
			cell_row.append(CellState.PENDING)
			timer_row.append(0)
		cells.append(cell_row)
		bug_timers.append(timer_row)

	# 放置初始bug
	for pos: Vector2i in bug_positions:
		if _in_bounds(pos.x, pos.y):
			_set_cell(pos.x, pos.y, CellState.BUG)


## ===== 生成初始bug位置 =====
static func generate_bug_positions(count: int, mode: String) -> Array:
	var positions: Array = []  ## Array[Vector2i]

	match mode:
		"scattered":
			positions = _generate_scattered(count)
		"edge":
			positions = _generate_edge(count)
		_:  # "random"
			positions = _generate_random(count)

	return positions


## ===== 修复bug =====
## 返回 true 如果成功修复
func repair_cell(row: int, col: int) -> bool:
	if not _in_bounds(row, col):
		return false
	if cells[row][col] != CellState.BUG:
		return false

	_set_cell(row, col, CellState.REPAIRED)
	bug_timers[row][col] = 0
	return true


## ===== 扩散tick =====
## 返回变化的格子列表 [{pos: Vector2i, new_state: CellState}]
func spread_tick() -> Array:
	var changes: Array = []

	# 如果场上已无bug，不做任何事（玩家已清零=胜利）
	if bug_count == 0:
		return changes

	# 第一步：收集所有bug格，增加tick计数，检查崩溃
	var current_bugs: Array = []  ## Array[Vector2i]
	for row: int in range(GRID_SIZE):
		for col: int in range(GRID_SIZE):
			if cells[row][col] == CellState.BUG:
				bug_timers[row][col] += 1
				current_bugs.append(Vector2i(row, col))

				# 检查是否达到崩溃阈值
				if bug_timers[row][col] >= CRASH_THRESHOLD:
					_set_cell(row, col, CellState.CRASHED)
					bug_timers[row][col] = 0
					changes.append({
						"pos": Vector2i(row, col),
						"new_state": CellState.CRASHED,
					})

	# 第二步：扩散 — 每个（仍为bug状态的）bug格向相邻待处理格扩散
	var new_bugs: Array = []  ## Array[Vector2i]
	for pos: Vector2i in current_bugs:
		if cells[pos.x][pos.y] != CellState.BUG:
			continue  # 已崩溃，跳过
		var neighbors: Array = _get_pending_neighbors(pos.x, pos.y)
		for n: Vector2i in neighbors:
			# 每个相邻待处理格50%概率被感染
			if randf() < 0.5:
				if cells[n.x][n.y] == CellState.PENDING:  # 再次检查避免重复
					new_bugs.append(n)

	# 应用新bug（跳过已非PENDING的格子）
	for pos: Vector2i in new_bugs:
		if cells[pos.x][pos.y] == CellState.PENDING:
			_set_cell(pos.x, pos.y, CellState.BUG)
			bug_timers[pos.x][pos.y] = 0
			changes.append({
				"pos": pos,
				"new_state": CellState.BUG,
			})

	return changes


## ===== 伤害度模型 =====
func get_damage() -> float:
	return float(bug_count) * 0.5 + float(crashed_count) * 1.0


func get_health_rate() -> float:
	return 1.0 - get_damage() / float(total_cells)


## ===== 获取格子状态 =====
func get_cell(row: int, col: int) -> int:
	if not _in_bounds(row, col):
		return CellState.CRASHED
	var state: int = cells[row][col] as int
	return state


## ===== 内部工具 =====

func _set_cell(row: int, col: int, state: int) -> void:
	var old_state: int = cells[row][col] as int
	if old_state == state:
		return

	# 更新计数
	match old_state:
		CellState.PENDING:
			pending_count -= 1
		CellState.BUG:
			bug_count -= 1
		CellState.REPAIRED:
			repaired_count -= 1
		CellState.CRASHED:
			crashed_count -= 1

	match state:
		CellState.PENDING:
			pending_count += 1
		CellState.BUG:
			bug_count += 1
		CellState.REPAIRED:
			repaired_count += 1
		CellState.CRASHED:
			crashed_count += 1

	cells[row][col] = state


func _in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < GRID_SIZE and col >= 0 and col < GRID_SIZE


func _get_pending_neighbors(row: int, col: int) -> Array:
	var result: Array = []
	var offsets: Array = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for offset: Vector2i in offsets:
		var nr: int = row + offset.x
		var nc: int = col + offset.y
		if _in_bounds(nr, nc) and cells[nr][nc] == CellState.PENDING:
			result.append(Vector2i(nr, nc))
	return result


## ===== 静态生成方法 =====

static func _generate_random(count: int) -> Array:
	var positions: Array = []
	var used: Dictionary = {}
	var safety: int = 0
	while positions.size() < count and safety < 100:
		safety += 1
		var r: int = randi_range(0, GRID_SIZE - 1)
		var c: int = randi_range(0, GRID_SIZE - 1)
		var key: String = "%d_%d" % [r, c]
		if key not in used:
			used[key] = true
			positions.append(Vector2i(r, c))
	return positions


static func _generate_scattered(count: int) -> Array:
	var positions: Array = []
	var used: Dictionary = {}
	var safety: int = 0
	while positions.size() < count and safety < 200:
		safety += 1
		var r: int = randi_range(0, GRID_SIZE - 1)
		var c: int = randi_range(0, GRID_SIZE - 1)
		var key: String = "%d_%d" % [r, c]
		if key in used:
			continue
		# 确保与已有位置间距>=2
		var too_close: bool = false
		for existing: Vector2i in positions:
			if absi(existing.x - r) + absi(existing.y - c) < 2:
				too_close = true
				break
		if not too_close:
			used[key] = true
			positions.append(Vector2i(r, c))
	# 如果散不开，补充随机位置
	if positions.size() < count:
		var extra: Array = _generate_random(count - positions.size())
		positions.append_array(extra)
	return positions


static func _generate_edge(count: int) -> Array:
	var edge_cells: Array = []
	for r: int in range(GRID_SIZE):
		for c: int in range(GRID_SIZE):
			if r == 0 or r == GRID_SIZE - 1 or c == 0 or c == GRID_SIZE - 1:
				edge_cells.append(Vector2i(r, c))
	edge_cells.shuffle()
	var positions: Array = []
	var take: int = mini(count, edge_cells.size())
	for i: int in range(take):
		positions.append(edge_cells[i])
	return positions
