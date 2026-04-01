# memory_match_data.gd — 素材归档小游戏：纯数据层
# 负责：网格生成、翻牌判定、配对逻辑、结算
# 零UI依赖，完全可测试
class_name MemoryMatchData
extends RefCounted

## 翻牌操作结果
enum PickResult { FIRST_REVEALED, MATCH_SUCCESS, MATCH_FAIL, INVALID }

var preset: MemoryMatchPreset
var grid: Array = []             ## [row][col] = int（素材ID，0 ~ total_pairs-1）
var revealed: Array = []         ## [row][col] = bool（是否翻开）
var matched: Array = []          ## [row][col] = bool（是否已配对消除）
var first_pick: Vector2i = Vector2i(-1, -1)  ## 第一张翻开的位置
var matched_pairs: int = 0
var total_pairs: int = 0
var elapsed: float = 0.0
var time_limit: float = 15.0
var is_finished: bool = false


func setup(p_preset: MemoryMatchPreset) -> void:
	preset = p_preset
	var rows: int = p_preset.grid_rows
	var cols: int = p_preset.grid_cols
	total_pairs = (rows * cols) / 2
	time_limit = p_preset.get_time_limit()
	matched_pairs = 0
	elapsed = 0.0
	is_finished = false
	first_pick = Vector2i(-1, -1)

	# 生成配对数组并洗牌
	var cards: Array[int] = []
	for i: int in range(total_pairs):
		cards.append(i)
		cards.append(i)
	cards.shuffle()

	# 填入网格
	grid.resize(rows)
	revealed.resize(rows)
	matched.resize(rows)
	var idx: int = 0
	for row: int in range(rows):
		var grid_row: Array[int] = []
		var revealed_row: Array[bool] = []
		var matched_row: Array[bool] = []
		grid_row.resize(cols)
		revealed_row.resize(cols)
		matched_row.resize(cols)
		for col: int in range(cols):
			grid_row[col] = cards[idx]
			revealed_row[col] = false
			matched_row[col] = false
			idx += 1
		grid[row] = grid_row
		revealed[row] = revealed_row
		matched[row] = matched_row


## 翻牌操作
func pick_card(row: int, col: int) -> PickResult:
	if is_finished:
		return PickResult.INVALID
	# 不能点已消除或已翻开的牌
	if matched[row][col] or revealed[row][col]:
		return PickResult.INVALID

	if first_pick == Vector2i(-1, -1):
		# 翻第一张
		first_pick = Vector2i(row, col)
		revealed[row][col] = true
		return PickResult.FIRST_REVEALED
	else:
		# 翻第二张
		revealed[row][col] = true
		var first_id: int = grid[first_pick.x][first_pick.y]
		var second_id: int = grid[row][col]

		if first_id == second_id:
			# 配对成功
			matched[first_pick.x][first_pick.y] = true
			matched[row][col] = true
			matched_pairs += 1
			first_pick = Vector2i(-1, -1)
			# 检查是否全部配对
			if matched_pairs >= total_pairs:
				is_finished = true
			return PickResult.MATCH_SUCCESS
		else:
			# 配对失败：翻回去
			revealed[first_pick.x][first_pick.y] = false
			revealed[row][col] = false
			first_pick = Vector2i(-1, -1)
			return PickResult.MATCH_FAIL


## 推进时间
func advance_time(delta: float) -> void:
	if is_finished:
		return
	elapsed += delta
	if elapsed >= time_limit:
		elapsed = time_limit
		is_finished = true


## 完成率
func get_completion_rate() -> float:
	if total_pairs <= 0:
		return 0.0
	return float(matched_pairs) / float(total_pairs)


## 结果等级
func get_result_tier() -> String:
	var rate: float = get_completion_rate()
	if rate >= 0.9:
		return "risky"
	elif rate >= 0.6:
		return "steady"
	else:
		return "conservative"
