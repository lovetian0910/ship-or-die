# fog_map_generator.gd — 迷雾地图生成器
# 职责：随机生成地图，确保连通性，分布各类型格子
class_name FogMapGenerator
extends RefCounted


## 生成一张完整地图，返回 FogMap 实例
static func generate(seed_val: int = -1) -> FogMap:
	if seed_val >= 0:
		seed(seed_val)
	else:
		randomize()

	var fog_map: FogMap = FogMap.new()

	# 1. 选择起点（避免四角，在内部区域 2~5）
	var start_row: int = randi_range(2, 5)
	var start_col: int = randi_range(2, 5)
	var start: Vector2i = Vector2i(start_row, start_col)

	# 2. 放置路障（确保连通性）
	var walls: Array[Vector2i] = _place_walls(fog_map, start)

	# 3. 放置特殊固定格子（预放置，类型在生成时确定）
	var occupied: Array[Vector2i] = [start]
	occupied.append_array(walls)

	# 标记路障为预放置
	for w: Vector2i in walls:
		fog_map.mark_preplaced(w.x, w.y)

	# 内测节点：中部区域（2~5, 2~5）
	var playtest_pos: Vector2i = _find_free_cell(fog_map, occupied, 2, 5, 2, 5, start, 2)
	fog_map.set_cell(playtest_pos.x, playtest_pos.y, FogMap.CellType.PLAYTEST)
	fog_map.mark_preplaced(playtest_pos.x, playtest_pos.y)
	occupied.append(playtest_pos)

	# 打磨节点：边缘区域（0~1 or 6~7 行或列）
	var polish_pos: Vector2i = _find_edge_cell(fog_map, occupied, start, 3)
	fog_map.set_cell(polish_pos.x, polish_pos.y, FogMap.CellType.POLISH)
	fog_map.mark_preplaced(polish_pos.x, polish_pos.y)
	occupied.append(polish_pos)

	# 上线出口：距起点较远（≥ MAP_EXIT_MIN_DISTANCE）
	var exit_count: int = 3
	for _i: int in range(exit_count):
		var exit_pos: Vector2i = _find_distant_cell(fog_map, occupied, start, Config.MAP_EXIT_MIN_DISTANCE)
		if exit_pos != Vector2i(-1, -1):
			fog_map.set_cell(exit_pos.x, exit_pos.y, FogMap.CellType.EXIT)
			fog_map.mark_preplaced(exit_pos.x, exit_pos.y)
			occupied.append(exit_pos)

	# 4. 为剩余格子分配稀有度（类型延迟到揭开时决定）
	_assign_rarities(fog_map, occupied)

	# 5. 初始化起点
	fog_map.init_start(start)

	return fog_map


## 放置路障，确保不堵死通路
static func _place_walls(fog_map: FogMap, start: Vector2i) -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	var max_walls: int = Config.MAP_WALL_MAX
	var attempts: int = 0
	var max_attempts: int = 200

	while walls.size() < max_walls and attempts < max_attempts:
		attempts += 1
		var row: int = randi_range(0, FogMap.MAP_SIZE - 1)
		var col: int = randi_range(0, FogMap.MAP_SIZE - 1)
		var pos: Vector2i = Vector2i(row, col)

		# 不能放在起点及其直接邻居
		if FogMap.manhattan_distance(pos, start) <= 1:
			continue
		# 不能放在已有路障位置
		if pos in walls:
			continue

		# 临时放置，验证连通性
		fog_map.set_cell(row, col, FogMap.CellType.WALL)
		if _check_connectivity(fog_map, start, walls.size() + 1):
			walls.append(pos)
		else:
			fog_map.set_cell(row, col, FogMap.CellType.EMPTY)

	return walls


## 连通性检查：从起点 flood fill，确保非路障格子都可达
static func _check_connectivity(fog_map: FogMap, start: Vector2i, wall_count: int) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		for n: Vector2i in fog_map.get_neighbors(current.x, current.y):
			if n not in visited and fog_map.get_cell_type(n.x, n.y) != FogMap.CellType.WALL:
				visited[n] = true
				queue.append(n)

	# 可达格数 = 总格数 - 路障数
	var expected: int = FogMap.MAP_SIZE * FogMap.MAP_SIZE - wall_count
	return visited.size() >= expected


## 在指定区域找一个空闲格子
static func _find_free_cell(fog_map: FogMap, occupied: Array[Vector2i],
		row_min: int, row_max: int, col_min: int, col_max: int,
		_start: Vector2i, min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row: int in range(row_min, row_max + 1):
		for col: int in range(col_min, col_max + 1):
			var pos: Vector2i = Vector2i(row, col)
			if pos not in occupied and fog_map.get_cell_type(row, col) != FogMap.CellType.WALL:
				if FogMap.manhattan_distance(pos, _start) >= min_dist:
					candidates.append(pos)

	if candidates.size() > 0:
		return candidates[randi_range(0, candidates.size() - 1)]

	# fallback: 任何空闲格
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			var pos: Vector2i = Vector2i(row, col)
			if pos not in occupied and fog_map.get_cell_type(row, col) != FogMap.CellType.WALL:
				return pos

	return Vector2i(0, 0)  # 理论上不应到达


## 在边缘区域找一个空闲格子
static func _find_edge_cell(fog_map: FogMap, occupied: Array[Vector2i],
		start: Vector2i, min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			# 边缘：行或列在 0,1,6,7
			if not (row <= 1 or row >= 6 or col <= 1 or col >= 6):
				continue
			var pos: Vector2i = Vector2i(row, col)
			if pos not in occupied and fog_map.get_cell_type(row, col) != FogMap.CellType.WALL:
				if FogMap.manhattan_distance(pos, start) >= min_dist:
					candidates.append(pos)

	if candidates.size() > 0:
		return candidates[randi_range(0, candidates.size() - 1)]

	# fallback
	return _find_free_cell(fog_map, occupied, 0, 7, 0, 7, start, 0)


## 找距起点较远的格子
static func _find_distant_cell(fog_map: FogMap, occupied: Array[Vector2i],
		start: Vector2i, min_dist: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			var pos: Vector2i = Vector2i(row, col)
			if pos not in occupied and fog_map.get_cell_type(row, col) != FogMap.CellType.WALL:
				if FogMap.manhattan_distance(pos, start) >= min_dist:
					candidates.append(pos)

	if candidates.size() > 0:
		return candidates[randi_range(0, candidates.size() - 1)]

	return Vector2i(-1, -1)


## 为剩余空闲格子分配稀有度（类型在揭开时按稀有度随机决定）
static func _assign_rarities(fog_map: FogMap, occupied: Array[Vector2i]) -> void:
	# 构建稀有度权重数组
	var rarity_entries: Array = []  # [{rarity: Rarity, weight: float}]
	for i: int in range(FogMap.RARITY_NAMES.size()):
		var rarity_name: String = FogMap.RARITY_NAMES[i]
		var level_data: Dictionary = Config.RARITY_LEVELS.get(rarity_name, {})
		var w: float = level_data.get("weight", 0.0) as float
		rarity_entries.append({"rarity": i as FogMap.Rarity, "weight": w})

	# 为每个非占用格分配稀有度
	for row: int in range(FogMap.MAP_SIZE):
		for col: int in range(FogMap.MAP_SIZE):
			var pos: Vector2i = Vector2i(row, col)
			if pos in occupied:
				continue
			if fog_map.get_cell_type(row, col) != FogMap.CellType.EMPTY:
				continue
			# 按权重随机选稀有度
			var rarity: FogMap.Rarity = _roll_rarity(rarity_entries)
			fog_map.set_cell_rarity(row, col, rarity)


## 按权重随机选择稀有度
static func _roll_rarity(entries: Array) -> FogMap.Rarity:
	var total_weight: float = 0.0
	for e: Dictionary in entries:
		total_weight += e.get("weight", 0.0) as float

	var roll: float = randf() * total_weight
	var accum: float = 0.0
	for e: Dictionary in entries:
		accum += e.get("weight", 0.0) as float
		if roll <= accum:
			return e.get("rarity", 0) as FogMap.Rarity
	return FogMap.Rarity.COMMON
