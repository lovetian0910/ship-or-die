# 模块03：选题与市场热度系统 — 实施方案

> 对应规格：`docs/specs/modules/03-topic-market.md`
> 技术栈：Godot 4.6.1 + GDScript
> 预估总工时：**6 小时**

---

## 一、架构概览

| 层面 | 选型 | 理由 |
|------|------|------|
| 数据定义 | `Resource` 子类 (`.tres`) | Godot 原生序列化，Inspector 可编辑，零解析成本 |
| 热度更新 | `Timer` 节点（2秒间隔） | 不需要每帧算，Timer tick 足够且暂停友好 |
| 模块通信 | Godot 信号 (`signal`) | 与引擎事件系统一致，松耦合 |
| UI | `Control` 节点树（`HBoxContainer` + `PanelContainer`） | 原生 UI 系统，布局自动化 |

---

## 二、文件清单与职责

```
project/
├── data/
│   ├── topic_data.gd              # Resource 子类：单个题材的配置数据
│   ├── ai_competitor_data.gd      # Resource 子类：单个AI竞品的运行时数据
│   ├── topics/
│   │   ├── topic_phantom_realm.tres    # 题材1：幻境探索（影射开放世界）
│   │   ├── topic_mecha_clash.tres      # 题材2：铁甲争锋（影射竞技对战）
│   │   ├── topic_idle_empire.tres      # 题材3：挂机帝国（影射放置游戏）
│   │   └── topic_star_ranch.tres       # 题材4：星际牧场（影射模拟经营）
│   └── config.gd                  # 全局数值配置（已有，本模块追加常量）
├── systems/
│   ├── market_heat_system.gd      # 市场热度动态算法（Autoload 单例）
│   ├── ai_competitor_manager.gd   # AI竞品生成+行为+上线判定
│   └── fuzzy_signal.gd            # 热度值 → 模糊文字映射
├── scenes/
│   └── topic_select/
│       ├── topic_select_screen.tscn   # 选题界面场景
│       ├── topic_select_screen.gd     # 选题界面主控脚本
│       ├── topic_card.tscn            # 单个题材卡片（可复用子场景）
│       └── topic_card.gd             # 卡片交互脚本
└── ui/
    └── competitor_notification.gd     # 竞品上线通知弹窗（挂在研发主界面上）
```

| 文件 | 职责 | 对外接口 |
|------|------|---------|
| `topic_data.gd` | 定义题材静态配置（名称、图标、热度参数） | `TopicData` Resource |
| `ai_competitor_data.gd` | 定义单个AI竞品运行时数据 | `AICompetitorData` Resource |
| `market_heat_system.gd` | 维护各题材实时热度(0-100)，Timer 驱动更新 | `get_heat()`, `apply_competitor_drain()`, `apply_market_event()`, 信号 `heat_updated` |
| `fuzzy_signal.gd` | 将精确热度映射为模糊文字+颜色，带刷新冷却 | `get_label()`, `get_color()` |
| `ai_competitor_manager.gd` | 局初生成竞品，Timer tick 判定上线 | `init_competitors()`, `get_competitors()`, 信号 `competitor_launched` |
| `topic_select_screen.tscn/.gd` | 渲染选题界面、处理选择与命名 | 信号 `topic_confirmed(topic_data, game_name)` |
| `topic_card.tscn/.gd` | 单张题材卡片UI+点击交互 | 信号 `card_selected(topic_data)` |

---

## 三、核心代码结构

### 3.1 题材数据定义 — `data/topic_data.gd`

```gdscript
class_name TopicData
extends Resource

## 题材静态配置，每个 .tres 文件对应一个题材

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""           # 一句话描述
@export var icon: Texture2D                     # 题材图标

## 热度曲线参数
@export_group("Heat Config")
@export var initial_heat: float = 50.0          # 初始热度 [30-70]
@export var phase_offset: float = 0.0           # 正弦波相位偏移（弧度），各题材错峰
@export var amplitude: float = 25.0             # 正弦波振幅，默认25
@export var noise_seed: int = 0                 # 噪声种子
```

**设计要点：**
- 纯数据容器，无逻辑，Inspector 里直接编辑 `.tres`
- `phase_offset` 让各题材热度曲线错峰：0, π/2, π, 3π/2

---

### 3.2 AI竞品数据 — `data/ai_competitor_data.gd`

```gdscript
class_name AICompetitorData
extends Resource

## AI竞品运行时数据（局初动态生成，不存 .tres）

enum Personality { AGGRESSIVE, CONSERVATIVE, FOLLOWER }

@export var competitor_name: String = ""
@export var personality: Personality = Personality.AGGRESSIVE
@export var quality: float = 0.0                # 品质分（隐藏）
@export var planned_launch_time: float = 0.0    # 预设上线时间（秒）
@export var heat_threshold: float = -1.0        # 跟风派热度阈值，-1表示不看热度
@export var launched: bool = false
@export var topic_id: StringName = &""
```

---

### 3.3 市场热度算法 — `systems/market_heat_system.gd`

```gdscript
class_name MarketHeatSystem
extends Node

## 市场热度动态系统
## 注册为 Autoload 单例: MarketHeat

signal heat_updated                             # 每次 tick 后触发，UI 监听刷新

const TICK_INTERVAL: float = 2.0                # 每2秒更新一次热度
const PERIOD: float = 120.0                     # 正弦波周期（游戏秒）
const NOISE_SCALE: float = 0.05                 # 噪声采样频率
const NOISE_AMPLITUDE: float = 10.0             # 噪声振幅

var _topics: Array[TopicData] = []
var _heat_values: Dictionary = {}               # { topic_id: float }  当前热度
var _drain_accum: Dictionary = {}               # { topic_id: float }  竞品累计消耗
var _elapsed: float = 0.0                       # 游戏内已过时间
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

## 局初调用：传入题材配置列表，初始化热度
func init_market(topics: Array[TopicData]) -> void:
	_topics = topics
	_heat_values.clear()
	_drain_accum.clear()
	_elapsed = 0.0
	for t in topics:
		_heat_values[t.id] = t.initial_heat
		_drain_accum[t.id] = 0.0

## 开始/停止热度更新
func start() -> void:
	_timer.start()

func stop() -> void:
	_timer.stop()

## 暂停友好：Timer 跟随 SceneTree.paused 自动暂停
## 只需设置 process_mode = PROCESS_MODE_PAUSABLE（默认）

## 获取某题材当前热度
func get_heat(topic_id: StringName) -> float:
	return _heat_values.get(topic_id, 0.0)

## AI竞品上线：永久性消耗热度
func apply_competitor_drain(topic_id: StringName, amount: float) -> void:
	_drain_accum[topic_id] = _drain_accum.get(topic_id, 0.0) + amount

## 偶发市场事件：持久修正（正值=加热，负值=降温）
func apply_market_event(topic_id: StringName, delta: float) -> void:
	# 通过减少 drain 实现加热，增加 drain 实现降温
	_drain_accum[topic_id] = _drain_accum.get(topic_id, 0.0) - delta

## ---- 内部逻辑 ----

func _on_tick() -> void:
	# 从核心框架时间系统获取已过时间（如果有 Autoload）
	# 简化方案：直接用 Timer 累计
	_elapsed += TICK_INTERVAL

	for t in _topics:
		var base_heat := _calc_base_heat(t)
		var noise := _simple_noise(t.noise_seed + _elapsed * NOISE_SCALE) * NOISE_AMPLITUDE
		var drain := _drain_accum.get(t.id, 0.0)
		_heat_values[t.id] = clampf(base_heat + noise - drain, 0.0, 100.0)

	heat_updated.emit()

## 正弦波基底：中心50，振幅由题材配置决定
func _calc_base_heat(topic: TopicData) -> float:
	var sin_value := sin((topic.phase_offset + _elapsed) * TAU / PERIOD)
	return 50.0 + sin_value * topic.amplitude

## 简易确定性噪声（无需外部库）
func _simple_noise(t: float) -> float:
	var i := floori(t)
	var f := t - float(i)
	var a := _hash(i)
	var b := _hash(i + 1)
	# smoothstep 插值
	var u := f * f * (3.0 - 2.0 * f)
	return a + (b - a) * u  # 输出约 [-1, 1]

func _hash(n: int) -> float:
	var x := sin(float(n) * 127.1 + 311.7) * 43758.5453
	return (x - floor(x)) * 2.0 - 1.0
```

**设计要点：**
- `Timer` 每2秒 tick 一次，不占每帧开销
- `heat_updated` 信号通知 UI 刷新，松耦合
- 暂停时 Timer 自动暂停（Godot `process_mode` 默认行为）
- `_drain_accum` 单向累积，竞品消耗不可恢复——"市场被瓜分"

---

### 3.4 模糊信号映射 — `systems/fuzzy_signal.gd`

```gdscript
class_name FuzzySignal
extends RefCounted

## 热度值 → 模糊文字，带刷新冷却（不实时跟踪）

const REFRESH_INTERVAL: float = 30.0            # 游戏内30秒刷新一次
const PERCEPTION_JITTER: float = 5.0            # ±5 感知误差

## 热度档位定义
const HEAT_TIERS: Array[Dictionary] = [
	{ "max": 20.0,  "text": "无人问津",   "color": Color(0.5, 0.5, 0.6) },
	{ "max": 40.0,  "text": "逐渐升温",   "color": Color(0.3, 0.7, 0.4) },
	{ "max": 60.0,  "text": "热度攀升中", "color": Color(0.9, 0.8, 0.2) },
	{ "max": 80.0,  "text": "市场火爆",   "color": Color(0.9, 0.4, 0.1) },
	{ "max": 100.0, "text": "全民狂热",   "color": Color(0.9, 0.1, 0.1) },
]

var _cache: Dictionary = {}   # { topic_id: { text, color, last_refresh } }
var _market_heat: MarketHeatSystem

func _init(market_heat: MarketHeatSystem) -> void:
	_market_heat = market_heat

## 获取模糊文字（带冷却缓存）
func get_label(topic_id: StringName, elapsed: float) -> String:
	_maybe_refresh(topic_id, elapsed)
	var entry = _cache.get(topic_id, {})
	return entry.get("text", "未知")

## 获取对应颜色
func get_color(topic_id: StringName, elapsed: float) -> Color:
	_maybe_refresh(topic_id, elapsed)
	var entry = _cache.get(topic_id, {})
	return entry.get("color", Color.GRAY)

## 强制立即刷新所有（选题界面首次显示时调用）
func refresh_all(elapsed: float) -> void:
	for topic_id in _cache.keys():
		_do_refresh(topic_id, elapsed)

func register_topic(topic_id: StringName, elapsed: float) -> void:
	_do_refresh(topic_id, elapsed)

## ---- 内部 ----

func _maybe_refresh(topic_id: StringName, elapsed: float) -> void:
	if not _cache.has(topic_id):
		_do_refresh(topic_id, elapsed)
		return
	if elapsed - _cache[topic_id]["last_refresh"] >= REFRESH_INTERVAL:
		_do_refresh(topic_id, elapsed)

func _do_refresh(topic_id: StringName, elapsed: float) -> void:
	var heat := _market_heat.get_heat(topic_id)
	# 感知误差：±5 随机偏移
	var perceived := heat + randf_range(-PERCEPTION_JITTER, PERCEPTION_JITTER)
	var tier := HEAT_TIERS.back()
	for t in HEAT_TIERS:
		if perceived <= t["max"]:
			tier = t
			break
	_cache[topic_id] = {
		"text": tier["text"],
		"color": tier["color"],
		"last_refresh": elapsed,
	}
```

**设计要点：**
- `RefCounted` 轻量对象，不需要挂节点树
- 30秒冷却 + ±5感知误差 = 双重模糊，玩家无法反推精确值
- 颜色直接绑定档位，UI 直接使用

---

### 3.5 AI竞品管理 — `systems/ai_competitor_manager.gd`

```gdscript
class_name AICompetitorManager
extends Node

## AI竞品行为管理
## 注册为 Autoload 单例: AICompetitors

signal competitor_launched(competitor: AICompetitorData)

const TICK_INTERVAL: float = 2.0

## 性格模板
const PERSONALITIES: Dictionary = {
	AICompetitorData.Personality.AGGRESSIVE: {
		"label": "激进派",
		"quality_min": 20.0, "quality_max": 45.0,
		"launch_ratio_min": 0.2, "launch_ratio_max": 0.4,
		"heat_threshold": -1.0,      # 不看热度
	},
	AICompetitorData.Personality.CONSERVATIVE: {
		"label": "保守派",
		"quality_min": 55.0, "quality_max": 80.0,
		"launch_ratio_min": 0.7, "launch_ratio_max": 0.9,
		"heat_threshold": -1.0,
	},
	AICompetitorData.Personality.FOLLOWER: {
		"label": "跟风派",
		"quality_min": 35.0, "quality_max": 60.0,
		"launch_ratio_min": 0.4, "launch_ratio_max": 0.7,
		"heat_threshold": 60.0,      # 热度>=60触发上线
	},
}

## 虚构名前后缀
const NAME_PREFIXES: Array[String] = ["星际", "幻境", "暗影", "铁甲", "灵魂", "深渊", "天际", "零点"]
const NAME_SUFFIXES: Array[String] = ["纪元", "传说", "狂潮", "猎手", "边界", "觉醒", "风暴", "幻想"]

var _competitors: Array[AICompetitorData] = []
var _market_heat: MarketHeatSystem
var _total_time: float = 300.0
var _elapsed: float = 0.0
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK_INTERVAL
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

## 局初生成竞品（选题确认后调用）
func init_competitors(topic_id: StringName, market_heat: MarketHeatSystem, total_time: float) -> void:
	_market_heat = market_heat
	_total_time = total_time
	_elapsed = 0.0
	_competitors.clear()

	# 随机2-3个竞品，从三种性格中不重复抽取
	var personalities := [
		AICompetitorData.Personality.AGGRESSIVE,
		AICompetitorData.Personality.CONSERVATIVE,
		AICompetitorData.Personality.FOLLOWER,
	]
	personalities.shuffle()
	var count := randi_range(2, 3)

	for i in range(count):
		var p_key: AICompetitorData.Personality = personalities[i]
		var p: Dictionary = PERSONALITIES[p_key]
		var comp := AICompetitorData.new()
		comp.competitor_name = "《%s%s》" % [NAME_PREFIXES.pick_random(), NAME_SUFFIXES.pick_random()]
		comp.personality = p_key
		comp.quality = randf_range(p["quality_min"], p["quality_max"])
		comp.planned_launch_time = randf_range(
			p["launch_ratio_min"] * _total_time,
			p["launch_ratio_max"] * _total_time
		)
		comp.heat_threshold = p["heat_threshold"]
		comp.launched = false
		comp.topic_id = topic_id
		_competitors.append(comp)

func start() -> void:
	_timer.start()

func stop() -> void:
	_timer.stop()

func get_competitors() -> Array[AICompetitorData]:
	return _competitors

## ---- 内部 ----

func _on_tick() -> void:
	_elapsed += TICK_INTERVAL

	for comp in _competitors:
		if comp.launched:
			continue

		var should_launch := false

		# 跟风派：热度达标 且 已过最早上线时间
		if comp.heat_threshold >= 0.0:
			var heat := _market_heat.get_heat(comp.topic_id)
			var p: Dictionary = PERSONALITIES[comp.personality]
			var earliest := p["launch_ratio_min"] * _total_time
			if heat >= comp.heat_threshold and _elapsed >= earliest:
				should_launch = true

		# 所有性格：到达预设时间必定上线
		if _elapsed >= comp.planned_launch_time:
			should_launch = true

		if should_launch:
			comp.launched = true
			# 消耗热度：品质越高消耗越大（范围约5-15）
			var drain := 5.0 + (comp.quality / 100.0) * 10.0
			_market_heat.apply_competitor_drain(comp.topic_id, drain)
			competitor_launched.emit(comp)
```

**设计要点：**
- 三种性格用"预设时间 + 条件触发"实现，不需要行为树
- 竞品名字随机拼接，符合世界观约束
- `competitor_launched` 信号被研发主界面监听，弹通知

---

### 3.6 选题界面场景 — `scenes/topic_select/`

#### 场景树结构 — `topic_select_screen.tscn`

```
TopicSelectScreen (Control)                     # 根节点，全屏
├── Background (ColorRect)                      # 背景
├── VBoxContainer                               # 主布局
│   ├── TitleLabel (Label)                      # "选择题材"
│   ├── HintLabel (Label)                       # "观察市场热度，选择你的方向"
│   ├── CardsContainer (HBoxContainer)          # 题材卡片容器
│   │   ├── TopicCard1 (topic_card.tscn)
│   │   ├── TopicCard2 (topic_card.tscn)
│   │   ├── TopicCard3 (topic_card.tscn)
│   │   └── TopicCard4 (topic_card.tscn)
│   └── ConfirmSection (VBoxContainer)          # 确认区域（选中后显示）
│       ├── SelectedLabel (Label)               # "已选择：XXX"
│       ├── GameNameInput (LineEdit)            # 游戏名输入框
│       └── ConfirmButton (Button)              # "确认，开始研发"
└── HeatRefreshTimer (Timer)                    # 热度文字刷新定时器
```

#### 主控脚本 — `topic_select_screen.gd`

```gdscript
extends Control

## 选题界面主控

signal topic_confirmed(topic: TopicData, game_name: String)

@export var topic_list: Array[TopicData] = []       # Inspector 中拖入4个 .tres

@onready var cards_container: HBoxContainer = $VBoxContainer/CardsContainer
@onready var confirm_section: VBoxContainer = $VBoxContainer/ConfirmSection
@onready var selected_label: Label = $VBoxContainer/ConfirmSection/SelectedLabel
@onready var game_name_input: LineEdit = $VBoxContainer/ConfirmSection/GameNameInput
@onready var confirm_button: Button = $VBoxContainer/ConfirmSection/ConfirmButton

var _selected_topic: TopicData = null
var _fuzzy_signal: FuzzySignal
var _cards: Array[Node] = []

func _ready() -> void:
	confirm_section.visible = false
	confirm_button.pressed.connect(_on_confirm)
	game_name_input.text_changed.connect(_on_name_changed)

	# 初始化模糊信号
	_fuzzy_signal = FuzzySignal.new(MarketHeat)  # MarketHeat 是 Autoload

	# 动态填充卡片数据
	var card_nodes := cards_container.get_children()
	for i in range(mini(topic_list.size(), card_nodes.size())):
		var card: Node = card_nodes[i]
		card.setup(topic_list[i], _fuzzy_signal)
		card.card_selected.connect(_on_card_selected)
		_cards.append(card)
		_fuzzy_signal.register_topic(topic_list[i].id, 0.0)

	# 监听热度更新，刷新卡片显示
	MarketHeat.heat_updated.connect(_on_heat_updated)

func _on_card_selected(topic: TopicData) -> void:
	_selected_topic = topic
	# 取消其他卡片选中态
	for card in _cards:
		card.set_selected(card.topic_data == topic)
	# 显示确认区域
	confirm_section.visible = true
	selected_label.text = "已选择：%s" % topic.display_name
	game_name_input.text = ""
	game_name_input.placeholder_text = "为你的游戏起个名字..."
	confirm_button.disabled = true

func _on_name_changed(new_text: String) -> void:
	confirm_button.disabled = new_text.strip_edges().is_empty()

func _on_confirm() -> void:
	if _selected_topic == null:
		return
	var game_name := game_name_input.text.strip_edges()
	if game_name.is_empty():
		game_name = "未命名项目"
	topic_confirmed.emit(_selected_topic, game_name)

func _on_heat_updated() -> void:
	# 热度系统 tick 了，让卡片刷新模糊文字
	for card in _cards:
		card.refresh_heat_label()
```

#### 单张卡片 — `topic_card.tscn` / `topic_card.gd`

```
TopicCard (PanelContainer)
├── VBoxContainer
│   ├── IconRect (TextureRect)          # 题材图标
│   ├── NameLabel (Label)               # 题材名称
│   ├── DescLabel (Label)               # 一句话描述
│   └── HeatLabel (Label)              # 模糊热度文字（带颜色）
└── ClickArea (Button)                  # 透明按钮覆盖整个卡片
```

```gdscript
extends PanelContainer

## 单张题材卡片

signal card_selected(topic: TopicData)

@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel
@onready var heat_label: Label = $VBoxContainer/HeatLabel
@onready var click_area: Button = $ClickArea

var topic_data: TopicData
var _fuzzy_signal: FuzzySignal
var _elapsed: float = 0.0

func setup(topic: TopicData, fuzzy_signal: FuzzySignal) -> void:
	topic_data = topic
	_fuzzy_signal = fuzzy_signal
	icon_rect.texture = topic.icon
	name_label.text = topic.display_name
	desc_label.text = topic.description
	refresh_heat_label()
	click_area.pressed.connect(func(): card_selected.emit(topic_data))

func refresh_heat_label() -> void:
	# _elapsed 可从 Autoload 时间系统获取，此处简化用累计
	_elapsed += 2.0  # 与热度 tick 同步
	heat_label.text = _fuzzy_signal.get_label(topic_data.id, _elapsed)
	heat_label.modulate = _fuzzy_signal.get_color(topic_data.id, _elapsed)

func set_selected(selected: bool) -> void:
	# 选中高亮：修改 PanelContainer 的 StyleBox
	if selected:
		add_theme_stylebox_override("panel", _get_selected_style())
	else:
		remove_theme_stylebox_override("panel")

func _get_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.5, 0.8)
	style.border_color = Color(0.4, 0.7, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
```

---

### 3.7 竞品上线通知 — `ui/competitor_notification.gd`

```gdscript
extends Control

## 竞品上线弹窗通知（挂在研发主界面上）
## AICompetitors.competitor_launched 信号触发

@onready var panel: PanelContainer = $Panel
@onready var message_label: Label = $Panel/Label
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	panel.visible = false
	# 监听 Autoload
	AICompetitors.competitor_launched.connect(_on_competitor_launched)

func _on_competitor_launched(comp: AICompetitorData) -> void:
	var personality_label: String = AICompetitorManager.PERSONALITIES[comp.personality]["label"]
	message_label.text = "%s 已经上线了！\n[%s]" % [comp.competitor_name, personality_label]
	panel.visible = true
	# 3秒后自动隐藏
	if anim_player.has_animation("show_hide"):
		anim_player.play("show_hide")
	else:
		await get_tree().create_timer(3.0).timeout
		panel.visible = false
```

---

## 四、Autoload 注册

在 `project.godot` 中注册两个单例：

| Autoload 名 | 脚本路径 | 说明 |
|-------------|---------|------|
| `MarketHeat` | `res://systems/market_heat_system.gd` | 市场热度系统 |
| `AICompetitors` | `res://systems/ai_competitor_manager.gd` | AI竞品管理 |

---

## 五、实施步骤与工时

| # | 步骤 | 产出文件 | 预估工时 | 依赖 |
|---|------|---------|---------|------|
| S1 | 定义 `TopicData` Resource + 创建 4个 `.tres` | `data/topic_data.gd`, `data/topics/*.tres` | 0.5h | 无 |
| S2 | 定义 `AICompetitorData` Resource | `data/ai_competitor_data.gd` | 0.25h | 无 |
| S3 | 实现 `MarketHeatSystem`（热度算法 + Timer tick） | `systems/market_heat_system.gd` | 1.5h | S1 |
| S4 | 实现 `FuzzySignal`（模糊映射 + 冷却缓存） | `systems/fuzzy_signal.gd` | 0.5h | S3 |
| S5 | 实现 `AICompetitorManager`（生成 + 行为 + 上线） | `systems/ai_competitor_manager.gd` | 1.0h | S2, S3 |
| S6 | 搭建 `topic_card.tscn/.gd`（单卡片子场景） | `scenes/topic_select/topic_card.*` | 0.5h | S1, S4 |
| S7 | 搭建 `topic_select_screen.tscn/.gd`（选题主界面 + 命名输入） | `scenes/topic_select/topic_select_screen.*` | 1.0h | S4, S6 |
| S8 | 实现 `competitor_notification.gd`（通知弹窗） | `ui/competitor_notification.gd` | 0.25h | S5 |
| S9 | 集成联调：Autoload 注册 + 与核心框架状态机对接 + 竞品通知接入研发UI | — | 0.5h | S1-S8, 模块01 |

### 依赖关系图

```
S1 ──┬──→ S3 ──┬──→ S4 ──→ S6 ──→ S7
     │         │                    ↓
S2 ──┘         └──→ S5 ──→ S8 ──→ S9（集成）
```

**可并行：** S1/S2 可同时开始；S4 和 S5 互相独立可并行；S6/S7（UI）与 S5（AI逻辑）可并行。

---

## 六、依赖关系

### 上游依赖（需先完成）

| 依赖 | 内容 | 阻塞点 |
|------|------|--------|
| 模块01 核心框架 | 游戏状态机（`TOPIC_SELECT` 状态）、时间系统（`TimeSystem` 提供 `elapsed` / `total_time`） | S9 集成时需要 |

> S1-S8 纯数据+逻辑+UI 可先行开发，mock 时间 tick。

### 下游被依赖（本模块输出给其他模块）

| 消费模块 | 需要的接口 | 说明 |
|---------|-----------|------|
| 模块04 研发流程 | `AICompetitors.competitor_launched` 信号 | 研发界面弹出竞品上线通知 |
| 模块04 研发流程 | `MarketHeat.start()` / `.stop()` | 研发阶段热度持续变化 |
| 模块06 上线结算 | `MarketHeat.get_heat(topic_id)` | 结算时获取热度乘数 |
| 模块06 上线结算 | `AICompetitors.get_competitors()` | 结算时获取竞品品质，计算市场份额 |

---

## 七、总工时预估

| 类别 | 工时 |
|------|------|
| 数据定义（S1-S2） | 0.75h |
| 核心逻辑（S3-S5） | 3.0h |
| UI 场景（S6-S8） | 1.75h |
| 集成联调（S9） | 0.5h |
| **合计** | **6.0h** |

占 4 天总工时比例：约 6 / 32（按每天 8 小时）= 19%，合理。

---

## 八、风险与降级预案

| 风险 | 降级方案 |
|------|---------|
| 热度算法调参耗时超预期 | 砍掉噪声，只保留正弦波 + 竞品消耗。正弦波已能支撑"涨落可感知"的核心体验 |
| AI竞品上线通知感知弱 | 加大弹窗尺寸、加 `AudioStreamPlayer` 播放提示音（1行代码），逻辑不变 |
| 选题UI交互打磨耗时 | 砍掉卡片动画和选中高亮过渡，纯 `visible` 切换 + 文字标记"已选" |
| 模糊信号体验不明显 | 缩短刷新冷却到 15 秒，让玩家能感受到"文字在变" |
| 题材图标素材未备齐 | 用 `PlaceholderTexture2D` 或纯色 `ColorRect` + 文字替代，不阻塞逻辑开发 |
