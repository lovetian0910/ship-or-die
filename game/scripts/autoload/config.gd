# config.gd — 数值配置常量集中管理
extends Node

## ===== 时间系统（混合制：离散月份 + 实时小游戏）=====
const TIME_TOTAL_MONTHS: int = 36               ## 总研发预算（月）
const TIME_WARNING_THRESHOLD: float = 0.2       ## 剩余20%触发警告（≤7个月）

## ===== 研发阶段划分（按已消耗月份的比例）=====
const PHASE_EARLY_END: float = 0.3              ## 0~30% = 前期（0-10月）
const PHASE_MID_END: float = 0.7                ## 30~70% = 中期（11-25月）, 70%+ = 后期

## ===== 代码急救小游戏：实时部分 =====
const MINIGAME_REAL_SECONDS: float = 15.0       ## 小游戏实际时长（真实秒）
const MINIGAME_DISPLAY_HOURS: int = 480          ## 小游戏UI显示工时（480工时=约2个月）
const MINIGAME_MONTH_COST: int = 2               ## 小游戏结束后消耗的月数

## ===== 经济 =====
const INITIAL_MONEY: int = 600                  ## 初始金钱
const MIN_MONEY: int = 300                      ## 保底金钱（至少能买3个低级）

## ===== 入场资源价格 =====
const RESOURCE_PRICES: Dictionary = {
	"creator":   { 1: 100, 2: 300, 3: 600 },
	"outsource": { 1: 100, 2: 300, 3: 600 },
	"business":  { 1: 100, 2: 300, 3: 600 },
}

## ===== 品质上限（按主创等级）=====
const QUALITY_CAP: Dictionary = {
	0: 20.0,   # 未选（不应出现）
	1: 40.0,   # 独立游戏愤青
	2: 70.0,   # 鹅皇互娱主创
	3: 100.0,  # 天命堂制作人
}

## ===== 品质积累（每消耗1个月，品质增加多少）=====
const QUALITY_PER_MONTH: float = 1.5            ## 基础品质增长/月

## ===== 外包效率倍率（影响品质积累速度，同样时间积累更多品质）=====
const OUTSOURCE_SPEED: Dictionary = {
	0: 1.0,    # 未选
	1: 1.0,    # 大学生兼职组
	2: 1.5,    # 外包铁军
	3: 2.0,    # 越南闪电队
}

## ===== 商务精力（代码急救小游戏）=====
const BUSINESS_ENERGY: Dictionary = {
	0: 6,      # 未选
	1: 8,      # 实习商务
	2: 12,     # 万能商务
	3: 16,     # 前渠道教父
}

## ===== 可选节点（消耗月数）=====
const PLAYTEST_MONTH_COST: int = 3              ## 内测验证消耗3个月
const PLAYTEST_TRIGGER_PROGRESS: float = 0.5    ## 内测在50%进度时出现
const POLISH_MONTH_COST: int = 3                ## 打磨消耗3个月
const POLISH_TRIGGER_PROGRESS: float = 0.85     ## 打磨在85%进度时出现
const POLISH_SUCCESS_CHANCE: float = 0.7        ## 打磨成功概率
const POLISH_QUALITY_BOOST: float = 8.0         ## 打磨成功品质提升
const POLISH_BUG_FIX_MONTHS: int = 2            ## 修bug消耗月数
const POLISH_FAIL_PENALTY: float = 25.0         ## 放弃修复品质惩罚

## ===== 事件时间消耗（月）=====
const EVENT_SEARCH_COST_SMALL: int = 1          ## 搜类-小收益
const EVENT_SEARCH_COST_LARGE: int = 3          ## 搜类-大收益
const EVENT_CRISIS_CONSERVATIVE_COST: int = 0   ## 保守选项-不消耗时间但受惩罚
const EVENT_CRISIS_STEADY_COST: int = 1         ## 稳妥选项
const EVENT_CRISIS_RISKY_COST: int = 3          ## 冒险选项

## ===== 市场热度 =====
const HEAT_UPDATE_PER_MONTH: bool = true        ## 每过1个月更新一次热度
const HEAT_PERCEPTION_NOISE: float = 5.0        ## 感知误差 ±5

## ===== 基础研发消耗（每个"研发推进"节点自动消耗的月数）=====
const DEV_AUTO_ADVANCE_MONTHS: int = 3          ## 节点间自动推进消耗

## ===== 迷雾地图探索系统 =====
const MAP_SIZE: int = 8                         ## 地图尺寸 8×8
const MAP_GUARANTEED_FIGHT_CELL: int = 5        ## 第N格必定触发小游戏（保底机制）

## 稀有度对应的研发月数消耗（稀有度越高开格子越贵）
const RARITY_MONTH_COST: Dictionary = {
	"COMMON": 1,
	"UNCOMMON": 2,
	"RARE": 3,
	"EPIC": 4,
	"LEGENDARY": 5,
}

## 稀有度对应的 loading 动画时长（秒）
const RARITY_LOADING_DURATION: Dictionary = {
	"COMMON": 0.5,
	"UNCOMMON": 1.0,
	"RARE": 1.5,
	"EPIC": 2.0,
	"LEGENDARY": 2.5,
}

## 探索多少格后弹出上线提示（选择不上线则重置地图继续探索）
const MAP_LAUNCH_PROMPT_INTERVAL: int = 10

## 格子类型分布比例
const MAP_CELL_RATIOS: Dictionary = {
	"empty": 0.30,          ## 空地 ~19格
	"search_event": 0.18,   ## 搜类事件 ~11格
	"fight_event": 0.22,    ## 打类事件(危机) ~14格
	"treasure": 0.10,       ## 宝箱 ~6格
	"exit": 0.05,           ## 上线出口 ~3格
	"wall": 0.10,           ## 路障 ~6格
}

## 特殊格子（固定数量，不参与比例分配）
const MAP_PLAYTEST_COUNT: int = 1               ## 内测节点（中部区域）
const MAP_POLISH_COUNT: int = 1                 ## 打磨节点（边缘区域）
const MAP_EXIT_MIN_DISTANCE: int = 5            ## 上线出口距起点最小曼哈顿距离
const MAP_WALL_MAX: int = 8                     ## 路障最大数量

## 空地品质范围
const MAP_EMPTY_QUALITY_MIN: float = 0.5        ## 空地最低品质
const MAP_EMPTY_QUALITY_MAX: float = 1.5        ## 空地最高品质

## 宝箱收益
const MAP_TREASURE_QUALITY: float = 3.0         ## 宝箱品质收益
const MAP_TREASURE_SPEED_BONUS: float = 0.1     ## 宝箱效率收益
const MAP_TREASURE_ENERGY_BONUS: int = 2        ## 宝箱精力收益

## ===== 稀有度系统 =====
## 稀有度定义（概率权重 + 颜色 + 显示名）
const RARITY_LEVELS: Dictionary = {
	"COMMON":    { "weight": 0.40, "color": Color(0.7, 0.7, 0.7), "label": "普通" },
	"UNCOMMON":  { "weight": 0.30, "color": Color(0.3, 0.8, 0.3), "label": "优良" },
	"RARE":      { "weight": 0.18, "color": Color(0.3, 0.5, 0.9), "label": "稀有" },
	"EPIC":      { "weight": 0.08, "color": Color(0.6, 0.2, 0.8), "label": "史诗" },
	"LEGENDARY": { "weight": 0.04, "color": Color(0.9, 0.7, 0.1), "label": "传说" },
}

## 各稀有度对应的格子类型概率分布
const RARITY_TYPE_WEIGHTS: Dictionary = {
	"COMMON":    { "empty": 0.65, "search": 0.20, "fight": 0.15, "treasure": 0.00 },
	"UNCOMMON":  { "empty": 0.40, "search": 0.30, "fight": 0.20, "treasure": 0.10 },
	"RARE":      { "empty": 0.20, "search": 0.30, "fight": 0.25, "treasure": 0.25 },
	"EPIC":      { "empty": 0.10, "search": 0.25, "fight": 0.30, "treasure": 0.35 },
	"LEGENDARY": { "empty": 0.00, "search": 0.20, "fight": 0.30, "treasure": 0.50 },
}

## ===== Bug Survivor 小游戏 =====
const BUG_SURVIVOR_GAME_DURATION: float = 60.0      ## 总时长（秒）
const BUG_SURVIVOR_ARENA_SIZE: Vector2 = Vector2(800, 600)  ## 竞技场尺寸
const BUG_SURVIVOR_PLAYER_SPEED: float = 200.0      ## 玩家移速（像素/秒）
const BUG_SURVIVOR_PLAYER_RADIUS: float = 32.0      ## 玩家碰撞半径（2×）
const BUG_SURVIVOR_BULLET_SPEED: float = 400.0      ## 子弹速度（像素/秒）
const BUG_SURVIVOR_BULLET_INTERVAL: float = 0.35    ## 射击间隔（秒，略慢，火力密度降低）
const BUG_SURVIVOR_BULLET_RADIUS: float = 8.0       ## 子弹碰撞半径
const BUG_SURVIVOR_BUG_RADIUS: float = 24.0         ## 虫子碰撞半径（2×）

## 难度曲线：站着不动30秒内必死
const BUG_SURVIVOR_SPAWN_CURVE: Array = [
	{"time_start": 0.0, "spawn_interval": 0.75, "speed_multiplier": 1.3},
	{"time_start": 9.0, "spawn_interval": 0.42, "speed_multiplier": 1.8},
	{"time_start": 20.0, "spawn_interval": 0.26, "speed_multiplier": 2.2},
	{"time_start": 35.0, "spawn_interval": 0.18, "speed_multiplier": 2.6},
]
