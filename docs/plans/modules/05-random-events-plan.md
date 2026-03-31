# 模块05：随机事件与代码急救小游戏 — 实施方案（Godot 4.6.1）

> 对应规格：`docs/specs/modules/05-random-events.md`
> 技术栈：**Godot 4.6.1 + GDScript**
> 预估总工时：**14-16小时**
> 优先级：**P0**（代码急救是 Demo gameplay 核心亮点）

---

## 一、技术选型

| 层面 | 选型 | 理由 |
|------|------|------|
| 代码急救网格 | **GridContainer + ColorRect** | 6×6 网格天然匹配 GridContainer 布局，每个格子用 ColorRect 节点，三种状态用颜色区分，实现最快 |
| 事件弹窗 | **PopupPanel / PanelContainer** | Godot 内置弹窗，搜类事件用 VBoxContainer + Label + Button 组合 |
| 事件数据 | **Resource 子类（.tres）** | GDScript 原生 Resource 序列化，编辑器可直接编辑，支持导出和复用 |
| 事件调度器 | **Node 挂在研发场景下** | 跟随 DEV_RUNNING 场景生命周期，用 Timer 节点驱动冷却和随机探索点时间窗口 |
| 扩散驱动 | **Timer 节点（1.5秒 tick）** | 每 tick 全局扫描一次，逻辑简洁清晰 |
| 动画反馈 | **Tween + StyleBox 动态修改** | 不依赖外部资源，纯代码实现修复闪白、扩散脉冲等手感反馈 |

### 关键约束
- 代码急救小游戏启动时 **暂停主时间流**（`TimeSystem.pause()`），小游戏有独立 15 秒 Timer
- 搜类事件弹窗出现时暂停主时间流，时间代价在选择"接受"后一次性扣除
- 所有事件数据用 Resource 定义，实例化小游戏时传入不同 Resource 参数实现复用

---

## 二、文件结构与职责

```
project/
├── resources/
│   └── events/
│       ├── event_data.gd                  # EventData Resource 基类脚本
│       ├── search_event_data.gd           # 搜类事件 Resource 子类
│       ├── fight_event_data.gd            # 打类事件 Resource 子类
│       ├── code_rescue_preset.gd          # 代码急救参数预设 Resource
│       ├── presets/
│       │   ├── tech_accident.tres         # 技术事故预设
│       │   ├── team_conflict.tres         # 团队内讧预设
│       │   └── external_shock.tres        # 外部冲击预设
│       └── pool/
│           ├── search_talent_01.tres      # 搜类-人才发现#1
│           ├── search_talent_02.tres      # 搜类-人才发现#2
│           ├── search_tech_01.tres        # 搜类-技术方案#1
│           ├── search_tech_02.tres        # 搜类-技术方案#2
│           ├── search_differentiation.tres # 搜类-差异化方向
│           ├── search_resource.tres       # 搜类-资源机会
│           ├── fight_tech_01.tres         # 打类-技术事故#1
│           ├── fight_tech_02.tres         # 打类-技术事故#2
│           ├── fight_team.tres            # 打类-团队内讧
│           └── fight_external.tres        # 打类-外部冲击
│
├── scenes/
│   └── events/
│       ├── event_scheduler.tscn           # 事件调度器场景（挂在研发场景下）
│       ├── search_event_popup.tscn        # 搜类事件弹窗场景
│       ├── fight_event_intro.tscn         # 打类事件叙事入口场景
│       ├── code_rescue_game.tscn          # 代码急救小游戏场景（核心）
│       ├── code_rescue_cell.tscn          # 单个格子预制场景
│       ├── code_rescue_result.tscn        # 小游戏结算面板
│       └── random_explore_icon.tscn       # 随机探索点闪烁图标
│
├── scripts/
│   └── events/
│       ├── event_scheduler.gd             # 事件调度器脚本
│       ├── event_pool.gd                  # 事件数据池（加载所有 .tres）
│       ├── event_effects.gd               # 事件结算效果（修改 GameState）
│       ├── search_event_popup.gd          # 搜类弹窗控制脚本
│       ├── fight_event_intro.gd           # 打类叙事入口脚本
│       ├── code_rescue_game.gd            # 代码急救主控脚本
│       ├── code_rescue_grid.gd            # 6×6网格数据模型
│       ├── code_rescue_cell.gd            # 单格节点控制脚本
│       ├── code_rescue_result_panel.gd    # 结算面板脚本
│       └── random_explore_icon.gd         # 随机探索点图标脚本
```

### 文件职责详述

| 文件 | 核心职责 | 对外接口 |
|------|---------|---------|
| `event_data.gd` | Resource 基类，定义事件通用属性 | `id`, `category`, `trigger_type`, `phases`, `title`, `description`, `flavor` |
| `search_event_data.gd` | 搜类事件 Resource，包含代价和收益 | 继承 EventData + `time_cost`, `reward_type`, `reward_value` |
| `fight_event_data.gd` | 打类事件 Resource，包含代码急救预设引用 | 继承 EventData + `preset: CodeRescuePreset`, `result_effects: Dictionary` |
| `code_rescue_preset.gd` | 代码急救参数 Resource（复用核心） | `initial_bug_count`, `bug_placement_mode`, `spread_interval`, `energy_source`, `energy_fixed`, `energy_map`, `narrative` |
| `event_scheduler.gd` | 监听时间 tick，按阶段调度事件 | `signal event_triggered(event_data)`, `start()`, `stop()` |
| `event_pool.gd` | 加载所有事件 .tres，按阶段/类型筛选 | `get_events_for_phase(phase)`, `get_random_event(category, phase)` |
| `event_effects.gd` | 将事件选择结果写入 GameState | `apply_effect(effect: Dictionary)` |
| `code_rescue_game.gd` | 小游戏生命周期：初始化→运行→结算 | `signal game_finished(result_tier)`, `start_game(preset, energy)` |
| `code_rescue_grid.gd` | 纯数据层：网格状态、扩散、修复 | `tick()`, `repair(row, col)`, `get_stats()` |
| `code_rescue_cell.gd` | 单格 UI 控制：颜色切换、动画 | `set_cell_state(state)`, `play_repair_anim()`, `play_spread_anim()` |

---

## 三、核心代码结构

### 3.1 事件数据 Resource 定义

```gdscript
# resources/events/event_data.gd
class_name EventData
extends Resource

enum Category { SEARCH, FIGHT }
enum TriggerType { PASSIVE_CRISIS, FIXED_EXPLORE, RANDOM_EXPLORE }
enum Phase { EARLY, MID, LATE }

@export var id: StringName = &""
@export var category: Category = Category.SEARCH
@export var trigger_type: TriggerType = TriggerType.PASSIVE_CRISIS
@export var phases: Array[Phase] = []
@export var title: String = ""
@export_multiline var description: String = ""
@export_multiline var flavor: String = ""
```

```gdscript
# resources/events/search_event_data.gd
class_name SearchEventData
extends EventData

enum RewardType { QUALITY, EFFICIENCY, RESPONSE }

@export var time_cost: float = 20.0          # 时间代价（秒）
@export var reward_type: RewardType = RewardType.QUALITY
@export var reward_value: float = 5.0        # 收益数值
@export var reward_description: String = ""  # "品质上限+5" 之类的显示文本
```

```gdscript
# resources/events/fight_event_data.gd
class_name FightEventData
extends EventData

@export var preset: CodeRescuePreset         # 代码急救参数预设
## 三档结算对应的效果 { "type": "quality", "value": -10 }
@export var conservative_effect: Dictionary = {}   # 保守：承受惩罚
@export var steady_effect: Dictionary = {}         # 稳妥：消除惩罚
@export var risky_effect: Dictionary = {}          # 冒险：危机变机会
```

```gdscript
# resources/events/code_rescue_preset.gd
class_name CodeRescuePreset
extends Resource

enum BugPlacement { CLUSTER, SCATTERED, EDGE }

@export var preset_name: String = ""
@export var initial_bug_count: int = 3
@export var bug_placement: BugPlacement = BugPlacement.CLUSTER
@export var spread_interval: float = 1.5     # 扩散间隔（秒）
@export var energy_source: String = "business"  # "business" 按商务等级 / "fixed" 固定值
@export var energy_fixed: int = 10           # energy_source == "fixed" 时使用
@export var energy_map: Dictionary = { "low": 8, "mid": 12, "high": 16 }
@export_multiline var narrative: String = "" # 叙事文本
```

### 3.2 事件调度器

```gdscript
# scripts/events/event_scheduler.gd
class_name EventScheduler
extends Node

signal event_triggered(event_data: EventData)
signal random_explore_spawned()
signal random_explore_expired()

@export var cooldown_duration: float = 17.0   # 冷却（15-20取中值）
@export var random_explore_window: float = 18.0  # 随机探索点时间窗口

var _event_pool: EventPool
var _cooldown_timer: float = 0.0
var _phase_fired: Dictionary = {
    "early":  { "passive": 0, "fixed": 0, "random": 0 },
    "mid":    { "passive": 0, "fixed": 0, "random": 0 },
    "late":   { "passive": 0, "fixed": 0, "random": 0 },
}

## 各阶段事件预算
const PHASE_QUOTAS := {
    "early":  { "passive_max": 1, "fixed": 1, "random_max": 0 },
    "mid":    { "passive_max": 2, "fixed": 1, "random_max": 1 },
    "late":   { "passive_max": 1, "fixed": 0, "random_max": 1 },
}

## 被动危机触发概率检查间隔（秒）
const PASSIVE_CHECK_INTERVAL := 15.0
var _passive_check_timer: float = 0.0

## 随机探索点
var _random_explore_check_timer: float = 0.0
const RANDOM_EXPLORE_CHECK_INTERVAL_MIN := 30.0
const RANDOM_EXPLORE_CHECK_INTERVAL_MAX := 50.0
var _next_random_check_at: float = 0.0
var _active_random_explore: EventData = null
var _random_explore_remaining: float = 0.0

## 固定探索点触发标记（按进度比例触发）
const FIXED_EXPLORE_TRIGGERS := {
    "early": 0.15,   # 前期 15% 进度时触发
    "mid":   0.50,   # 中期 50% 进度时触发
}
var _fixed_triggered: Dictionary = {}

var _is_active: bool = false
var _current_phase: String = "early"
var _last_phase: String = ""

@onready var _cooldown_node: Timer = $CooldownTimer


func _ready() -> void:
    _event_pool = EventPool.new()
    _next_random_check_at = randf_range(
        RANDOM_EXPLORE_CHECK_INTERVAL_MIN,
        RANDOM_EXPLORE_CHECK_INTERVAL_MAX
    )


func start() -> void:
    _is_active = true
    _cooldown_timer = 0.0
    _passive_check_timer = 0.0
    _random_explore_check_timer = 0.0
    _phase_fired = {
        "early":  { "passive": 0, "fixed": 0, "random": 0 },
        "mid":    { "passive": 0, "fixed": 0, "random": 0 },
        "late":   { "passive": 0, "fixed": 0, "random": 0 },
    }
    _fixed_triggered.clear()


func stop() -> void:
    _is_active = false


## 由研发场景每帧调用
func tick(delta: float, elapsed: float, total: float) -> void:
    if not _is_active:
        return

    var progress := elapsed / total
    _current_phase = _get_phase(progress)

    # 阶段切换时重置被动检查计时
    if _current_phase != _last_phase:
        _passive_check_timer = 0.0
        _last_phase = _current_phase

    # 冷却中不触发新事件
    if _cooldown_timer > 0.0:
        _cooldown_timer -= delta
        _update_random_explore(delta)
        return

    # 1. 固定探索点（按进度里程碑）
    if _check_fixed_explore(progress):
        return

    # 2. 被动危机（概率触发）
    _passive_check_timer += delta
    if _passive_check_timer >= PASSIVE_CHECK_INTERVAL:
        _passive_check_timer = 0.0
        if _check_passive_crisis():
            return

    # 3. 随机探索点生成 + 倒计时
    _update_random_explore(delta)


func _get_phase(progress: float) -> String:
    if progress < 0.3:
        return "early"
    elif progress < 0.7:
        return "mid"
    else:
        return "late"


func _check_fixed_explore(progress: float) -> bool:
    if not FIXED_EXPLORE_TRIGGERS.has(_current_phase):
        return false
    var trigger_at: float = FIXED_EXPLORE_TRIGGERS[_current_phase]
    var key := _current_phase + "_fixed"
    if _fixed_triggered.has(key):
        return false
    var quota: int = PHASE_QUOTAS[_current_phase]["fixed"]
    if _phase_fired[_current_phase]["fixed"] >= quota:
        return false
    if progress >= trigger_at:
        _fixed_triggered[key] = true
        _phase_fired[_current_phase]["fixed"] += 1
        var evt := _event_pool.get_random_event("fixed", _current_phase)
        if evt:
            _fire_event(evt)
            return true
    return false


func _check_passive_crisis() -> bool:
    var quota_max: int = PHASE_QUOTAS[_current_phase]["passive_max"]
    if _phase_fired[_current_phase]["passive"] >= quota_max:
        return false
    # 每次检查 40% 概率触发
    if randf() < 0.4:
        _phase_fired[_current_phase]["passive"] += 1
        var evt := _event_pool.get_random_event("passive", _current_phase)
        if evt:
            _fire_event(evt)
            return true
    return false


func _update_random_explore(delta: float) -> void:
    # 已有活跃随机探索点 → 倒计时
    if _active_random_explore:
        _random_explore_remaining -= delta
        if _random_explore_remaining <= 0.0:
            _active_random_explore = null
            random_explore_expired.emit()
        return

    # 检查是否该生成新的随机探索点
    var quota_max: int = PHASE_QUOTAS[_current_phase]["random_max"]
    if _phase_fired[_current_phase]["random"] >= quota_max:
        return

    _random_explore_check_timer += delta
    if _random_explore_check_timer >= _next_random_check_at:
        _random_explore_check_timer = 0.0
        _next_random_check_at = randf_range(
            RANDOM_EXPLORE_CHECK_INTERVAL_MIN,
            RANDOM_EXPLORE_CHECK_INTERVAL_MAX
        )
        if randf() < 0.4:
            var evt := _event_pool.get_random_event("random", _current_phase)
            if evt:
                _active_random_explore = evt
                _random_explore_remaining = random_explore_window
                _phase_fired[_current_phase]["random"] += 1
                random_explore_spawned.emit()


## 玩家点击随机探索点图标时调用
func accept_random_explore() -> void:
    if _active_random_explore:
        var evt := _active_random_explore
        _active_random_explore = null
        _fire_event(evt)


func _fire_event(evt: EventData) -> void:
    _cooldown_timer = cooldown_duration
    event_triggered.emit(evt)
```

### 3.3 搜类事件弹窗

**场景树：`search_event_popup.tscn`**

```
SearchEventPopup (PanelContainer)
├── MarginContainer
│   └── VBoxContainer
│       ├── TitleLabel (Label)            # 事件标题
│       ├── FlavorLabel (Label)           # 风味文本（斜体、小字）
│       ├── HSeparator
│       ├── DescriptionLabel (RichTextLabel) # 事件描述
│       ├── HSeparator
│       ├── CostRewardPanel (HBoxContainer)
│       │   ├── CostLabel (Label)         # "消耗：25秒"
│       │   └── RewardLabel (Label)       # "收益：品质上限+5"
│       └── ButtonContainer (HBoxContainer)
│           ├── AcceptButton (Button)     # "接受"
│           └── DeclineButton (Button)    # "放弃"
```

```gdscript
# scripts/events/search_event_popup.gd
class_name SearchEventPopup
extends PanelContainer

signal choice_made(accepted: bool, event_data: SearchEventData)

@onready var _title: Label = %TitleLabel
@onready var _flavor: Label = %FlavorLabel
@onready var _description: RichTextLabel = %DescriptionLabel
@onready var _cost_label: Label = %CostLabel
@onready var _reward_label: Label = %RewardLabel
@onready var _accept_btn: Button = %AcceptButton
@onready var _decline_btn: Button = %DeclineButton

var _current_event: SearchEventData


func _ready() -> void:
    _accept_btn.pressed.connect(_on_accept)
    _decline_btn.pressed.connect(_on_decline)
    hide()


func show_event(event_data: SearchEventData) -> void:
    _current_event = event_data
    _title.text = event_data.title
    _flavor.text = event_data.flavor
    _description.text = event_data.description
    _cost_label.text = "消耗：%d 秒" % int(event_data.time_cost)
    _reward_label.text = "收益：%s" % event_data.reward_description
    _accept_btn.text = "接受（-%d秒）" % int(event_data.time_cost)
    show()


func _on_accept() -> void:
    hide()
    choice_made.emit(true, _current_event)


func _on_decline() -> void:
    hide()
    choice_made.emit(false, _current_event)
```

### 3.4 代码急救小游戏（核心重点）

#### 3.4.1 网格数据模型 `code_rescue_grid.gd`

```gdscript
# scripts/events/code_rescue_grid.gd
class_name CodeRescueGrid
extends RefCounted

enum CellState { NORMAL, BUG, CRASHED }

const ROWS := 6
const COLS := 6
const CRASH_THRESHOLD := 3   # 连续3次tick未修复 → 崩溃

## 每个格子的数据结构
var grid: Array[Array] = []   # grid[row][col] = { "state": CellState, "bug_ticks": int }

var energy: int = 0
var max_energy: int = 0
var spread_interval: float = 1.5
var _spread_timer: float = 0.0

signal cell_changed(row: int, col: int, new_state: CellState, old_state: CellState)
signal cell_repaired(row: int, col: int)
signal cell_spread(row: int, col: int, from_row: int, from_col: int)
signal cell_crashed(row: int, col: int)
signal energy_changed(current: int, maximum: int)


func init(preset: CodeRescuePreset, business_level: String) -> void:
    # 确定精力值
    if preset.energy_source == "fixed":
        energy = preset.energy_fixed
    else:
        energy = preset.energy_map.get(business_level, 10)
    max_energy = energy

    # 初始化全 NORMAL 的网格
    grid.clear()
    for r in ROWS:
        var row_data: Array = []
        for c in COLS:
            row_data.append({ "state": CellState.NORMAL, "bug_ticks": 0 })
        grid.append(row_data)

    # 放置初始 Bug
    var bug_positions := _generate_bug_positions(
        preset.bug_placement, preset.initial_bug_count
    )
    for pos in bug_positions:
        grid[pos.x][pos.y]["state"] = CellState.BUG
        grid[pos.x][pos.y]["bug_ticks"] = 0

    spread_interval = preset.spread_interval
    _spread_timer = 0.0


func tick(delta: float) -> void:
    _spread_timer += delta
    if _spread_timer >= spread_interval:
        _spread_timer -= spread_interval
        _do_spread()


func repair(row: int, col: int) -> bool:
    if energy <= 0:
        return false
    if row < 0 or row >= ROWS or col < 0 or col >= COLS:
        return false
    if grid[row][col]["state"] != CellState.BUG:
        return false
    energy -= 1
    grid[row][col]["state"] = CellState.NORMAL
    grid[row][col]["bug_ticks"] = 0
    cell_repaired.emit(row, col)
    energy_changed.emit(energy, max_energy)
    return true


func get_stats() -> Dictionary:
    var normal := 0
    var bug := 0
    var crashed := 0
    for r in ROWS:
        for c in COLS:
            match grid[r][c]["state"]:
                CellState.NORMAL:
                    normal += 1
                CellState.BUG:
                    bug += 1
                CellState.CRASHED:
                    crashed += 1
    var total := ROWS * COLS
    return {
        "total": total,
        "normal": normal,
        "bug": bug,
        "crashed": crashed,
        "normal_ratio": float(normal) / float(total),
    }


func _do_spread() -> void:
    # Phase 1: 递增 bug_ticks，检查崩溃
    var bugs_to_crash: Array[Vector2i] = []
    var bugs_to_spread: Array[Vector2i] = []

    for r in ROWS:
        for c in COLS:
            if grid[r][c]["state"] == CellState.BUG:
                grid[r][c]["bug_ticks"] += 1
                if grid[r][c]["bug_ticks"] >= CRASH_THRESHOLD:
                    bugs_to_crash.append(Vector2i(r, c))
                else:
                    bugs_to_spread.append(Vector2i(r, c))

    # Phase 2: 崩溃
    for pos in bugs_to_crash:
        grid[pos.x][pos.y]["state"] = CellState.CRASHED
        cell_crashed.emit(pos.x, pos.y)

    # Phase 3: 扩散（每个 BUG 格向4邻 NORMAL 格 70% 概率扩散）
    for pos in bugs_to_spread:
        for dir in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
            var nr := pos.x + dir.x
            var nc := pos.y + dir.y
            if nr < 0 or nr >= ROWS or nc < 0 or nc >= COLS:
                continue
            if grid[nr][nc]["state"] == CellState.NORMAL:
                if randf() < 0.7:
                    grid[nr][nc]["state"] = CellState.BUG
                    grid[nr][nc]["bug_ticks"] = 0
                    cell_spread.emit(nr, nc, pos.x, pos.y)


func _generate_bug_positions(mode: CodeRescuePreset.BugPlacement, count: int) -> Array[Vector2i]:
    var positions: Array[Vector2i] = []
    match mode:
        CodeRescuePreset.BugPlacement.CLUSTER:
            # 集中在一个随机区域
            var center := Vector2i(randi_range(1, 4), randi_range(1, 4))
            var candidates: Array[Vector2i] = [center]
            for dir in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1),
                        Vector2i(-1,-1), Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1)]:
                var p := center + dir
                if p.x >= 0 and p.x < ROWS and p.y >= 0 and p.y < COLS:
                    candidates.append(p)
            candidates.shuffle()
            for i in mini(count, candidates.size()):
                positions.append(candidates[i])

        CodeRescuePreset.BugPlacement.SCATTERED:
            # 随机散布
            var all_cells: Array[Vector2i] = []
            for r in ROWS:
                for c in COLS:
                    all_cells.append(Vector2i(r, c))
            all_cells.shuffle()
            for i in mini(count, all_cells.size()):
                positions.append(all_cells[i])

        CodeRescuePreset.BugPlacement.EDGE:
            # 从边缘涌入
            var edge_cells: Array[Vector2i] = []
            for r in ROWS:
                edge_cells.append(Vector2i(r, 0))
                edge_cells.append(Vector2i(r, COLS - 1))
            for c in range(1, COLS - 1):
                edge_cells.append(Vector2i(0, c))
                edge_cells.append(Vector2i(ROWS - 1, c))
            edge_cells.shuffle()
            for i in mini(count, edge_cells.size()):
                positions.append(edge_cells[i])

    return positions
```

#### 3.4.2 单格节点 `code_rescue_cell.gd`

**场景树：`code_rescue_cell.tscn`**

```
CodeRescueCell (Button)        # 用 Button 天然支持 pressed 信号 + hover
├── ColorBackground (ColorRect) # 状态底色
└── BugTickIndicator (Label)    # 显示 bug_ticks（可选，调试用）
```

```gdscript
# scripts/events/code_rescue_cell.gd
class_name CodeRescueCell
extends Button

signal cell_clicked(row: int, col: int)

const COLOR_NORMAL := Color("#4ec9b0")   # 青绿
const COLOR_BUG := Color("#f44747")      # 亮红
const COLOR_CRASHED := Color("#3c3c3c")  # 深灰
const COLOR_FLASH := Color("#ffffff")    # 修复闪白
const COLOR_BUG_WARN := Color("#ff8c00") # 扩散预警橙

@onready var _bg: ColorRect = $ColorBackground

var row: int = 0
var col: int = 0
var _current_state: CodeRescueGrid.CellState = CodeRescueGrid.CellState.NORMAL


func setup(r: int, c: int) -> void:
    row = r
    col = c
    set_cell_state(CodeRescueGrid.CellState.NORMAL)
    pressed.connect(func(): cell_clicked.emit(row, col))


func set_cell_state(state: CodeRescueGrid.CellState) -> void:
    _current_state = state
    match state:
        CodeRescueGrid.CellState.NORMAL:
            _bg.color = COLOR_NORMAL
        CodeRescueGrid.CellState.BUG:
            _bg.color = COLOR_BUG
        CodeRescueGrid.CellState.CRASHED:
            _bg.color = COLOR_CRASHED
            disabled = true   # 崩溃格不可点击


func play_repair_anim() -> void:
    # 闪白 → 缩放弹性 → 恢复绿色
    var tween := create_tween()
    _bg.color = COLOR_FLASH
    tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.05)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(_bg, "color", COLOR_NORMAL, 0.15)


func play_spread_anim() -> void:
    # 绿 → 橙 → 红 渐变
    var tween := create_tween()
    _bg.color = COLOR_BUG_WARN
    tween.tween_property(_bg, "color", COLOR_BUG, 0.3)


func play_crash_anim() -> void:
    # 抖动 + 红→白闪→黑
    var tween := create_tween()
    var original_pos := position
    tween.tween_property(self, "position", original_pos + Vector2(2, -2), 0.025)
    tween.tween_property(self, "position", original_pos + Vector2(-2, 2), 0.025)
    tween.tween_property(self, "position", original_pos, 0.025)
    tween.parallel().tween_property(_bg, "color", COLOR_FLASH, 0.05)
    tween.tween_property(_bg, "color", COLOR_CRASHED, 0.15)


## Bug 快要崩溃时的脉冲闪烁（bug_ticks >= 2 时调用）
func play_pulse_anim() -> void:
    var tween := create_tween().set_loops(3)
    tween.tween_property(_bg, "color", Color("#ff6b6b"), 0.15)
    tween.tween_property(_bg, "color", COLOR_BUG, 0.15)
```

#### 3.4.3 代码急救主控 `code_rescue_game.gd`

**场景树：`code_rescue_game.tscn`**

```
CodeRescueGame (PanelContainer)                   # 深色面板 #1e1e1e
├── VBoxContainer
│   ├── TopBar (HBoxContainer)
│   │   ├── NarrativeLabel (Label)                # 叙事文本
│   │   ├── Spacer (Control, h_expand)
│   │   ├── TimerLabel (Label)                    # "15.0"
│   │   └── EnergyLabel (Label)                   # "精力：12/12"
│   ├── SurvivalBar (ProgressBar)                 # 存活率实时条
│   ├── GridContainer (GridContainer, columns=6)  # 6×6 网格容器
│   │   └── (运行时动态添加 36 个 CodeRescueCell)
│   └── HintLabel (Label)                         # "点击红色格子修复Bug！"
├── SpreadTimer (Timer, wait_time=动态, autostart=false)
└── CountdownTimer (Timer, wait_time=1.0, autostart=false, one_shot=false)
```

```gdscript
# scripts/events/code_rescue_game.gd
class_name CodeRescueGame
extends PanelContainer

signal game_finished(result_tier: String)  # "risky" / "steady" / "conservative"

@onready var _grid_container: GridContainer = %GridContainer
@onready var _timer_label: Label = %TimerLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _survival_bar: ProgressBar = %SurvivalBar
@onready var _narrative_label: Label = %NarrativeLabel
@onready var _hint_label: Label = %HintLabel
@onready var _spread_timer: Timer = $SpreadTimer
@onready var _countdown_timer: Timer = $CountdownTimer

const CELL_SCENE := preload("res://scenes/events/code_rescue_cell.tscn")
const GAME_DURATION := 15.0

var _grid_model: CodeRescueGrid
var _cells: Array[Array] = []    # _cells[row][col] = CodeRescueCell 节点
var _time_remaining: float = GAME_DURATION
var _is_running: bool = false


func start_game(preset: CodeRescuePreset, business_level: String) -> void:
    # 1. 初始化数据模型
    _grid_model = CodeRescueGrid.new()
    _grid_model.init(preset, business_level)

    # 连接模型信号
    _grid_model.cell_repaired.connect(_on_cell_repaired)
    _grid_model.cell_spread.connect(_on_cell_spread)
    _grid_model.cell_crashed.connect(_on_cell_crashed)
    _grid_model.energy_changed.connect(_on_energy_changed)

    # 2. 创建 UI 网格
    _clear_grid()
    _grid_container.columns = CodeRescueGrid.COLS
    _cells.clear()
    for r in CodeRescueGrid.ROWS:
        var row_cells: Array = []
        for c in CodeRescueGrid.COLS:
            var cell: CodeRescueCell = CELL_SCENE.instantiate()
            cell.custom_minimum_size = Vector2(56, 56)
            cell.setup(r, c)
            cell.cell_clicked.connect(_on_cell_clicked)
            _grid_container.add_child(cell)
            row_cells.append(cell)
        _cells.append(row_cells)

    # 3. 同步初始状态到 UI
    _sync_all_cells()

    # 4. 设置 UI
    _narrative_label.text = preset.narrative
    _update_energy_label()
    _update_timer_label()
    _survival_bar.value = 100.0

    # 5. 启动定时器
    _time_remaining = GAME_DURATION
    _spread_timer.wait_time = preset.spread_interval
    _spread_timer.start()
    _is_running = true
    show()


func _process(delta: float) -> void:
    if not _is_running:
        return

    _time_remaining -= delta
    _update_timer_label()

    # 驱动数据模型 tick
    _grid_model.tick(delta)

    # 更新存活率
    var stats := _grid_model.get_stats()
    _survival_bar.value = stats["normal_ratio"] * 100.0

    # 同步有 bug tick 变化的格子视觉（脉冲警告）
    _sync_bug_pulse()

    # 倒计时最后5秒紧迫感
    if _time_remaining <= 5.0:
        _timer_label.add_theme_color_override("font_color", Color("#ff3333"))

    if _time_remaining <= 0.0:
        _end_game()


func _on_cell_clicked(row: int, col: int) -> void:
    if not _is_running:
        return
    var success := _grid_model.repair(row, col)
    if success:
        _cells[row][col].play_repair_anim()
        _cells[row][col].set_cell_state(CodeRescueGrid.CellState.NORMAL)
    elif _grid_model.energy <= 0:
        # 精力耗尽反馈：格子弹一下但不修复
        var tween := _cells[row][col].create_tween()
        tween.tween_property(_cells[row][col], "scale", Vector2(1.05, 1.05), 0.03)
        tween.tween_property(_cells[row][col], "scale", Vector2(1.0, 1.0), 0.05)
        # 精力条闪红
        _energy_label.add_theme_color_override("font_color", Color("#ff3333"))
        get_tree().create_timer(0.3).timeout.connect(func():
            _energy_label.add_theme_color_override("font_color", Color("#cccccc"))
        )


func _on_cell_repaired(row: int, col: int) -> void:
    _update_energy_label()


func _on_cell_spread(row: int, col: int, _from_row: int, _from_col: int) -> void:
    _cells[row][col].play_spread_anim()
    _cells[row][col].set_cell_state(CodeRescueGrid.CellState.BUG)


func _on_cell_crashed(row: int, col: int) -> void:
    _cells[row][col].play_crash_anim()
    _cells[row][col].set_cell_state(CodeRescueGrid.CellState.CRASHED)


func _on_energy_changed(current: int, _maximum: int) -> void:
    _update_energy_label()


func _sync_all_cells() -> void:
    for r in CodeRescueGrid.ROWS:
        for c in CodeRescueGrid.COLS:
            var state: CodeRescueGrid.CellState = _grid_model.grid[r][c]["state"]
            _cells[r][c].set_cell_state(state)


func _sync_bug_pulse() -> void:
    for r in CodeRescueGrid.ROWS:
        for c in CodeRescueGrid.COLS:
            var cell_data: Dictionary = _grid_model.grid[r][c]
            if cell_data["state"] == CodeRescueGrid.CellState.BUG and cell_data["bug_ticks"] >= 2:
                _cells[r][c].play_pulse_anim()


func _update_timer_label() -> void:
    _timer_label.text = "%.1f" % maxf(_time_remaining, 0.0)


func _update_energy_label() -> void:
    _energy_label.text = "精力：%d/%d" % [_grid_model.energy, _grid_model.max_energy]


func _end_game() -> void:
    _is_running = false
    _spread_timer.stop()

    # 冻结画面 0.5秒
    await get_tree().create_timer(0.5).timeout

    # 存活格子依次闪绿（快速 sweep）
    for r in CodeRescueGrid.ROWS:
        for c in CodeRescueGrid.COLS:
            if _grid_model.grid[r][c]["state"] == CodeRescueGrid.CellState.NORMAL:
                var tween := _cells[r][c].create_tween()
                tween.tween_property(
                    _cells[r][c]._bg, "color", Color("#00ff88"), 0.05
                )
                tween.tween_property(
                    _cells[r][c]._bg, "color", CodeRescueCell.COLOR_NORMAL, 0.1
                )
            await get_tree().create_timer(0.02).timeout

    # 结算
    var stats := _grid_model.get_stats()
    var tier := _calculate_result(stats["normal_ratio"])
    game_finished.emit(tier)


func _calculate_result(normal_ratio: float) -> String:
    if normal_ratio >= 0.9:
        return "risky"          # 完美急救！危机变机会
    elif normal_ratio >= 0.6:
        return "steady"         # 稳住了，损失可控
    else:
        return "conservative"   # 代码库严重受损...


func _clear_grid() -> void:
    for child in _grid_container.get_children():
        child.queue_free()
```

### 3.5 打类事件入口 + 结算流程

```gdscript
# scripts/events/fight_event_intro.gd
class_name FightEventIntro
extends PanelContainer

signal fight_resolved(effect: Dictionary)

@onready var _title_label: Label = %TitleLabel
@onready var _flavor_label: Label = %FlavorLabel
@onready var _description_label: RichTextLabel = %DescriptionLabel
@onready var _start_btn: Button = %StartRescueButton

const CODE_RESCUE_SCENE := preload("res://scenes/events/code_rescue_game.tscn")

var _current_event: FightEventData
var _code_rescue_instance: CodeRescueGame


func show_event(event_data: FightEventData, business_level: String) -> void:
    _current_event = event_data
    _title_label.text = event_data.title
    _flavor_label.text = event_data.flavor
    _description_label.text = event_data.description
    _start_btn.visible = false
    show()

    # 1秒阅读时间后显示"开始急救"按钮
    await get_tree().create_timer(1.0).timeout
    _start_btn.visible = true
    _start_btn.pressed.connect(func():
        _start_btn.pressed.disconnect(func(): pass)  # 防重复
        _start_code_rescue(business_level)
    , CONNECT_ONE_SHOT)


func _start_code_rescue(business_level: String) -> void:
    hide()

    _code_rescue_instance = CODE_RESCUE_SCENE.instantiate()
    get_tree().root.add_child(_code_rescue_instance)
    _code_rescue_instance.game_finished.connect(_on_rescue_finished)
    _code_rescue_instance.start_game(_current_event.preset, business_level)


func _on_rescue_finished(tier: String) -> void:
    _code_rescue_instance.queue_free()
    _code_rescue_instance = null

    # 根据 tier 选取对应效果
    var effect: Dictionary
    match tier:
        "risky":
            effect = _current_event.risky_effect
        "steady":
            effect = _current_event.steady_effect
        "conservative":
            effect = _current_event.conservative_effect

    # 显示结算面板（简化：复用自身显示结果）
    _show_result(tier, effect)


func _show_result(tier: String, effect: Dictionary) -> void:
    var tier_labels := {
        "risky": "🔥 完美急救！危机变机会！",
        "steady": "✅ 稳住了，损失可控",
        "conservative": "💀 代码库严重受损...",
    }
    _title_label.text = tier_labels.get(tier, "结算")
    _flavor_label.text = ""
    _description_label.text = _format_effect(effect)
    _start_btn.text = "确认"
    _start_btn.visible = true
    _start_btn.pressed.connect(func():
        hide()
        fight_resolved.emit(effect)
    , CONNECT_ONE_SHOT)
    show()


func _format_effect(effect: Dictionary) -> String:
    var parts: PackedStringArray = []
    for key in effect:
        var val = effect[key]
        if val > 0:
            parts.append("%s +%s" % [key, str(val)])
        else:
            parts.append("%s %s" % [key, str(val)])
    return "\n".join(parts)
```

### 3.6 事件效果结算

```gdscript
# scripts/events/event_effects.gd
class_name EventEffects
extends RefCounted

## effect 格式示例：
## { "quality": 5, "time": -20, "efficiency": 0.1 }
## 正值=增益，负值=惩罚
static func apply_effect(game_state: Node, effect: Dictionary) -> void:
    for key in effect:
        var value = effect[key]
        match key:
            "quality":
                game_state.run.quality_cap += value
            "efficiency":
                game_state.run.time_efficiency += value
            "response":
                game_state.run.response_ability += value
            "time":
                # 负值 = 扣时间
                if value < 0:
                    game_state.time_system.consume(absf(value))
                else:
                    game_state.time_system.add_time(value)
```

### 3.7 事件数据池

```gdscript
# scripts/events/event_pool.gd
class_name EventPool
extends RefCounted

var _all_events: Array[EventData] = []

const EVENT_DIR := "res://resources/events/pool/"


func _init() -> void:
    _load_all_events()


func _load_all_events() -> void:
    var dir := DirAccess.open(EVENT_DIR)
    if not dir:
        push_warning("EventPool: Cannot open " + EVENT_DIR)
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if file_name.ends_with(".tres"):
            var res := load(EVENT_DIR + file_name)
            if res is EventData:
                _all_events.append(res)
        file_name = dir.get_next()


func get_events_for_phase(phase: String) -> Array[EventData]:
    var phase_enum: EventData.Phase
    match phase:
        "early": phase_enum = EventData.Phase.EARLY
        "mid":   phase_enum = EventData.Phase.MID
        "late":  phase_enum = EventData.Phase.LATE
    return _all_events.filter(
        func(e: EventData) -> bool: return phase_enum in e.phases
    )


func get_random_event(trigger: String, phase: String) -> EventData:
    var trigger_enum: EventData.TriggerType
    match trigger:
        "passive": trigger_enum = EventData.TriggerType.PASSIVE_CRISIS
        "fixed":   trigger_enum = EventData.TriggerType.FIXED_EXPLORE
        "random":  trigger_enum = EventData.TriggerType.RANDOM_EXPLORE

    var candidates := get_events_for_phase(phase).filter(
        func(e: EventData) -> bool: return e.trigger_type == trigger_enum
    )
    if candidates.is_empty():
        return null
    return candidates[randi() % candidates.size()]
```

### 3.8 随机探索点闪烁图标

```gdscript
# scripts/events/random_explore_icon.gd
class_name RandomExploreIcon
extends Button

signal icon_clicked()

@onready var _countdown_bar: ProgressBar = $CountdownBar
@onready var _blink_timer: Timer = $BlinkTimer

var _total_time: float = 18.0
var _remaining: float = 18.0


func start_countdown(duration: float) -> void:
    _total_time = duration
    _remaining = duration
    _countdown_bar.max_value = duration
    _countdown_bar.value = duration
    _blink_timer.start()
    show()


func _process(delta: float) -> void:
    if not visible:
        return
    _remaining -= delta
    _countdown_bar.value = _remaining
    if _remaining <= 0.0:
        hide()


func _on_blink_timer_timeout() -> void:
    modulate.a = 0.3 if modulate.a > 0.5 else 1.0


func _ready() -> void:
    pressed.connect(func(): icon_clicked.emit())
    hide()
```

---

## 四、实施步骤与工时

### Step 1：事件 Resource 定义（1h）

**产出：** `event_data.gd`, `search_event_data.gd`, `fight_event_data.gd`, `code_rescue_preset.gd`

**内容：** 定义所有 Resource 子类的 `@export` 属性，确保编辑器中可直接创建 `.tres` 文件。

**依赖：** 无
**预估：** 1h

---

### Step 2：代码急救 — 网格数据模型（2h）⭐ 核心

**产出：** `code_rescue_grid.gd`

**内容：**
- 6×6 二维数组，每格维护 state + bug_ticks
- 三种 BugPlacement 模式的初始位置生成
- `tick()` 驱动扩散：bug_ticks 递增 → 崩溃判定 → 70% 概率向4邻扩散
- `repair()` 修复逻辑 + 精力扣减
- `get_stats()` 统计存活率
- 信号通知 UI：`cell_repaired`, `cell_spread`, `cell_crashed`, `energy_changed`

**依赖：** Step 1（CodeRescuePreset Resource）
**预估：** 2h

---

### Step 3：代码急救 — 单格节点 + 网格 UI（2h）⭐ 手感关键

**产出：** `code_rescue_cell.tscn`, `code_rescue_cell.gd`

**内容：**
- Button 基类，内含 ColorRect 作状态底色
- `set_cell_state()` 切换颜色
- 三套 Tween 动画：修复闪白弹性、扩散渐变、崩溃抖动
- 脉冲警告动画（bug_ticks ≥ 2 时）
- 深色 IDE 风格 StyleBox（#1e1e1e 背景，1px 间隔）

**依赖：** Step 2（CellState 枚举）
**预估：** 2h（含动画调优）

---

### Step 4：代码急救 — 主控场景（2h）⭐ 核心

**产出：** `code_rescue_game.tscn`, `code_rescue_game.gd`

**内容：**
- GridContainer（columns=6）动态实例化 36 个 CodeRescueCell
- `_process(delta)` 驱动：倒计时递减 → grid_model.tick() → UI 同步
- 点击处理：cell_clicked → grid_model.repair() → 播放动画
- 精力耗尽反馈：点击无效 + 格子弹性 + 精力条闪红
- 倒计时最后 5 秒：数字变红
- 结算流程：冻结 0.5s → 存活格子 sweep 闪绿 → emit game_finished
- 精力条 + 倒计时 + 存活率 ProgressBar 实时更新

**依赖：** Step 2, Step 3
**预估：** 2h

---

### Step 5：事件调度器（2.5h）

**产出：** `event_scheduler.tscn`, `event_scheduler.gd`, `event_pool.gd`

**内容：**
- 阶段划分（early 0-30% / mid 30-70% / late 70-100%）
- 各阶段独立预算：被动危机 / 固定探索 / 随机探索
- 被动危机：每 15 秒检查一次，40% 概率触发，触发后 17 秒冷却
- 固定探索点：按进度里程碑触发（15%, 50%）
- 随机探索点：30-50 秒间隔检查，40% 概率生成，18 秒时间窗口
- EventPool：扫描 `res://resources/events/pool/` 加载全部 .tres，按类型/阶段筛选

**依赖：** Step 1（EventData Resource）
**预估：** 2.5h

---

### Step 6：搜类事件弹窗 UI（1.5h）

**产出：** `search_event_popup.tscn`, `search_event_popup.gd`

**内容：**
- PanelContainer + VBoxContainer 布局
- 标题 / 风味文本 / 描述 / 代价-收益 / 接受-放弃按钮
- 弹窗出现时暂停主时间，选择后恢复
- 深色卡片风格（#2d2d2d），像素风等宽字体

**依赖：** Step 1
**预估：** 1.5h

---

### Step 7：打类事件入口 + 结算面板（1.5h）

**产出：** `fight_event_intro.tscn`, `fight_event_intro.gd`, `code_rescue_result.tscn`, `code_rescue_result_panel.gd`

**流程：**
1. 弹出叙事面板 → 1 秒阅读 → 显示"开始急救"按钮
2. 启动 CodeRescueGame（传入 preset + business_level）
3. 小游戏结束 → 根据 tier 映射效果 → 显示结算面板
4. 确认后调用 `EventEffects.apply_effect()` 写入 GameState

**依赖：** Step 4（CodeRescueGame）, Step 1
**预估：** 1.5h

---

### Step 8：事件效果结算 + 随机探索点图标（1h）

**产出：** `event_effects.gd`, `random_explore_icon.tscn`, `random_explore_icon.gd`

**内容：**
- EventEffects：静态方法，按 key 修改 GameState 对应属性
- 随机探索点图标：闪烁 Button + ProgressBar 倒计时，点击后触发事件

**依赖：** Step 1
**预估：** 1h

---

### Step 9：事件内容填充（1.5h）

**产出：** `resources/events/pool/` 下 10 个 .tres 文件 + 3 个预设 .tres

**数量规划：**

| 类型 | 数量 | 说明 |
|------|------|------|
| 搜类-人才发现 | 2 | 品质上限提升 |
| 搜类-技术方案 | 2 | 时间效率提升 |
| 搜类-差异化方向 | 1 | 品质 + 竞争优势 |
| 搜类-资源机会 | 1 | 事件应对资源 |
| 打类-技术事故 | 2 | cluster 预设，不同叙事 |
| 打类-团队内讧 | 1 | scattered 预设 |
| 打类-外部冲击 | 1 | edge 预设 |
| **总计** | **10** | 足以支撑 4-8 次/局 |

每个事件：标题 + 风味文本 + 描述 + 数值。遵守世界观约束（虚构名称、影射现实、行业黑色幽默）。

预设 .tres 创建：
- `tech_accident.tres`: cluster/3 bug/1.5s 扩散/按商务等级精力
- `team_conflict.tres`: scattered/5 bug/2.0s 扩散/固定 10 精力
- `external_shock.tres`: edge/2 bug/1.0s 扩散/按商务等级精力

**依赖：** Step 1
**预估：** 1.5h

---

### Step 10：集成联调（1h）

**内容：**
- EventScheduler 挂到 DevRunningScene 下，接收 `time:tick` 信号驱动
- 事件触发 → 暂停 TimeSystem → 弹窗/小游戏 → 结算 → 恢复 TimeSystem
- 搜类/打类正确分流
- 随机探索点倒计时 + 消失
- 全流程冒烟测试：一局内触发 4-8 个事件无崩溃
- 边界测试：事件处理中时间耗尽、精力归零后连续点击、快速连续事件

**依赖：** 全部前序步骤 + 模块01（GameState/TimeSystem/EventBus）+ 模块04（DevPipelineManager）
**预估：** 1h

---

## 五、依赖关系图

```
Step 1 (Resource 定义)
  ├──→ Step 2 (网格数据模型)
  │       └──→ Step 3 (单格节点 UI)
  │               └──→ Step 4 (小游戏主控) ──→ Step 7 (打类入口+结算)
  ├──→ Step 5 (事件调度器 + 数据池)
  ├──→ Step 6 (搜类弹窗 UI)
  ├──→ Step 8 (效果结算 + 探索图标)
  └──→ Step 9 (事件内容填充)

Step 10 (集成联调) ←── 全部

外部依赖：
  ← 模块01：GameState、TimeSystem（pause/resume/consume）、EventBus
  ← 模块02：商务等级（读取精力值）、入场资源数据
  ← 模块04：DevPipelineManager（阶段信号、暂停/恢复协调）
```

**可并行的工作：**
- Step 1 完成后：Step 2 与 Step 5/6/8/9 全部可并行启动
- Step 3 与 Step 5 可并行（UI 与调度器无依赖）
- Step 7 与 Step 9 可并行

---

## 六、总工时预估

| 步骤 | 内容 | 工时 |
|------|------|------|
| Step 1 | Resource 定义 | 1h |
| Step 2 | 代码急救-网格数据模型 | 2h |
| Step 3 | 代码急救-单格节点 UI | 2h |
| Step 4 | 代码急救-主控场景 | 2h |
| Step 5 | 事件调度器 + 数据池 | 2.5h |
| Step 6 | 搜类事件弹窗 UI | 1.5h |
| Step 7 | 打类事件入口 + 结算 | 1.5h |
| Step 8 | 效果结算 + 探索图标 | 1h |
| Step 9 | 事件内容填充 | 1.5h |
| Step 10 | 集成联调 | 1h |
| **总计** | | **16h** |

### 建议实施顺序

```
第1轮（3h）：Step 1 → Step 2（串行，Resource 定义 → 网格模型）
第2轮（4h）：Step 3 + Step 5（并行，格子UI / 调度器）
第3轮（3.5h）：Step 4 + Step 6（并行，小游戏主控 / 搜类弹窗）
第4轮（2.5h）：Step 7 + Step 8（并行，打类入口 / 效果结算）
第5轮（2.5h）：Step 9 + Step 10（内容填充 → 集成联调）
```

**单人串行最长路径：~14h**（Step 1 → 2 → 3 → 4 → 7 → 10）

---

## 七、风险与降级方案

| 风险 | 影响 | 降级方案 |
|------|------|---------|
| Tween 动画调优超时 | 手感不够好 | 砍脉冲警告和 sweep 闪绿，保留修复闪白 + 颜色切换两个核心反馈 |
| 扩散逻辑边界 case | bug 行为异常 | 先用 100% 确定性扩散调通，再加 70% 概率 |
| GridContainer 布局问题 | 格子间距/尺寸不对 | 改用手动 `_draw()` + 鼠标坐标换算，回退到类 Canvas 方案 |
| 事件调度与时间系统冲突 | 暂停/恢复时序错乱 | 调度器改为纯信号驱动，不主动调用 pause/resume，由上层协调 |
| 事件文案写不完 | 事件种类不够 | 先写 6 个（搜4打2），其余复用文案换数值 |
| Resource 编辑器创建 .tres 慢 | 阻塞内容填充 | 改用 GDScript 代码 `ResourceSaver.save()` 批量生成 |

---

## 八、代码急救手感优化 Checklist

> 这是 Demo 的 gameplay 亮点，以下是必须做到的手感标准：

- [ ] **点击响应即时**：`cell_clicked` 信号 → 同帧修改 grid state + 触发 Tween 动画
- [ ] **修复反馈三件套**：缩放弹性（1.08x → 1.0x）+ 颜色闪白（150ms）+ 恢复绿色
- [ ] **扩散可预判**：bug 格 `bug_ticks >= 2` 时脉冲闪烁加速，暗示即将崩溃
- [ ] **崩溃有重量感**：崩溃瞬间格子抖动（position ±2px，75ms）+ 红→白闪→黑
- [ ] **精力归零有绝望感**：点击 bug 格子弹一下但不修复，精力 Label 闪红 0.3s
- [ ] **倒计时最后5秒紧迫感**：数字变红（`font_color` override）
- [ ] **结算有仪式感**：0.5s 冻结 → 存活格子依次闪绿 sweep（每格间隔 20ms）→ 显示结果文字

---

## 九、场景集成示意

```
DevRunningScene (研发主场景)
├── TimeBar
├── QualityDisplay
├── LaunchButton
├── EventScheduler (Node)                    ← 本模块核心
│   └── CooldownTimer (Timer)
├── SearchEventPopup (PanelContainer)        ← 搜类弹窗，默认隐藏
├── FightEventIntro (PanelContainer)         ← 打类入口，默认隐藏
├── RandomExploreIcon (Button)               ← 随机探索点图标，默认隐藏
└── CodeRescueGame (PanelContainer)          ← 小游戏，按需实例化或默认隐藏
```

**事件流转：**

```
EventScheduler.event_triggered(evt)
  ├── evt is SearchEventData
  │     → TimeSystem.pause()
  │     → SearchEventPopup.show_event(evt)
  │     → 玩家选择
  │     → EventEffects.apply_effect() / 无操作
  │     → TimeSystem.resume()
  │
  └── evt is FightEventData
        → TimeSystem.pause()
        → FightEventIntro.show_event(evt, business_level)
        → "开始急救" 按钮
        → CodeRescueGame.start_game(preset, business_level)
        → 15秒小游戏
        → 结算 tier → 映射 effect
        → EventEffects.apply_effect()
        → TimeSystem.resume()
```
