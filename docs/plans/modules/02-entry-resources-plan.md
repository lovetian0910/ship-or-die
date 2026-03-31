# 模块02：入场资源与经济系统 — 实施方案

> 对应规格：`docs/specs/modules/02-entry-resources.md`
> 日期：2026-03-30
> 技术栈：**Godot 4.6.1 + GDScript**
> 预估总工时：**5小时**
> 依赖模块：模块01（核心框架 / GameState / 场景管理）

---

## 一、技术选型

| 决策项 | 选择 | 理由 |
|-------|------|------|
| 数据定义 | **自定义 Resource 子类 + .tres 文件** | Godot Resource 天然支持数据驱动，编辑器内可直接调参，无需硬编码 |
| 经济管理 | **Autoload 单例（EconomyManager）** | 跨场景持久化，全局唯一，符合 Godot 的 Autoload 模式 |
| UI 布局 | **HBoxContainer + VBoxContainer + 自定义 ResourceCard 场景** | Godot 内建容器节点自动布局，3列结构用 HBox 嵌套 VBox |
| 模块通信 | **Godot 信号（signal）** | 原生机制，类型安全，编辑器可视化连接 |
| 数据持久化 | **内存（Autoload 变量）** | Demo 无需存档，Autoload 单例在场景切换间保持 |

---

## 二、文件清单与职责

```
game/
├── scripts/
│   ├── autoload/
│   │   └── economy_manager.gd        # ★ Autoload单例：金钱管理、保底、局间传递
│   │
│   ├── resources/
│   │   └── entry_resource_data.gd    # ★ Resource子类：单条资源数据定义
│   │
│   └── ui/
│       ├── entry_shop.gd             # ★ 选购界面主控脚本
│       └── resource_card.gd          # ★ 单张资源卡片交互脚本
│
├── resources/
│   └── entry_resources/
│       ├── creator_low.tres           # ★ 独立游戏愤青
│       ├── creator_mid.tres           # ★ 鹅皇互娱主创
│       ├── creator_high.tres          # ★ 天命堂制作人
│       ├── outsource_low.tres         # ★ 大学生兼职组
│       ├── outsource_mid.tres         # ★ 外包铁军
│       ├── outsource_high.tres        # ★ 越南闪电队
│       ├── business_low.tres          # ★ 实习商务
│       ├── business_mid.tres          # ★ 万能商务
│       └── business_high.tres         # ★ 前渠道教父
│
└── scenes/
    ├── entry_shop.tscn                # ★ 选购界面场景
    └── ui/
        └── resource_card.tscn         # ★ 资源卡片可复用场景
```

**★ = 本模块新建文件（14个：2个脚本类 + 2个UI脚本 + 9个.tres + 2个.tscn - 1个已含脚本引用 = 实际需创建14个文件）**

---

## 三、核心代码结构

### 3.1 Resource 子类：`entry_resource_data.gd`

用 Godot 的 Resource 系统定义数据，每条资源导出为 `.tres` 文件，编辑器内可直接修改数值。

```gdscript
# scripts/resources/entry_resource_data.gd
class_name EntryResourceData
extends Resource

## 资源类别
enum Category { CREATOR, OUTSOURCE, BUSINESS }

## 资源等级
enum Tier { LOW, MID, HIGH }

@export var category: Category
@export var tier: Tier

@export var display_name: String          ## 显示名称（如"鹅皇互娱主创"）
@export_multiline var description: String ## 简介
@export var price: int                    ## 购买价格
@export var icon: Texture2D              ## 头像/图标（可选，无则用占位）

## ---- 效果参数（按类别只填对应字段） ----
@export_group("品质上限 (主创)")
@export var quality_cap: int = 0          ## 品质上限分数

@export_group("时间效率 (外包)")
@export var dev_speed: float = 1.0        ## 研发速度倍率

@export_group("事件应对 (商务)")
@export var energy: int = 0               ## 代码急救精力值
@export var option_unlock: String = ""    ## 选项解锁级别: "partial" / "full" / "all_risky"


## 获取效果字典（供其他模块读取）
func get_effects() -> Dictionary:
	match category:
		Category.CREATOR:
			return { "quality_cap": quality_cap }
		Category.OUTSOURCE:
			return { "dev_speed": dev_speed }
		Category.BUSINESS:
			return { "energy": energy, "option_unlock": option_unlock }
	return {}
```

**每条 .tres 文件示例（`creator_mid.tres`）：**

```ini
[gd_resource type="Resource" script_class="EntryResourceData" load_steps=2 format=3]

[ext_resource type="Script" path="res://game/scripts/resources/entry_resource_data.gd" id="1"]

[resource]
script = ExtResource("1")
category = 0
tier = 1
display_name = "鹅皇互娱主创"
description = "大厂历练过，能做出像样的东西"
price = 300
quality_cap = 70
```

> **优势：** 策划可在 Godot 编辑器的 Inspector 面板中直接修改数值，无需改代码。

---

### 3.2 EconomyManager：Autoload 单例

```gdscript
# scripts/autoload/economy_manager.gd
extends Node

## ---- 配置常量 ----
const INITIAL_MONEY: int = 600    ## 首局初始金钱
const FLOOR_MONEY: int = 300      ## 保底金钱
const MIN_LOADOUT_COST: int = 300 ## 最低配置总价（3×低级）

## ---- 信号 ----
signal money_changed(new_amount: int)
signal loadout_confirmed(loadout: Dictionary)

## ---- 状态 ----
var money: int = INITIAL_MONEY
var is_first_run: bool = true

## ---- 当前局装备 ----
var current_loadout: Dictionary = {}  # { "creator": EntryResourceData, "outsource": ..., "business": ... }


func _ready() -> void:
	money = INITIAL_MONEY


## 获取当前金钱
func get_money() -> int:
	return money


## 局结算：成功 —— 加收益
func add_earnings(amount: int) -> void:
	money += amount
	money_changed.emit(money)


## 局结算：失败 —— 触底保底
func apply_failure(loadout_cost: int) -> void:
	money = maxi(money - loadout_cost, FLOOR_MONEY)
	money_changed.emit(money)


## 购买入场资源（扣钱），返回是否成功
func purchase_loadout(total_cost: int) -> bool:
	if total_cost > money:
		return false
	money -= total_cost
	money_changed.emit(money)
	return true


## 检查是否买得起
func can_afford(cost: int) -> bool:
	return money >= cost


## 存储本局选购结果
func set_loadout(creator: EntryResourceData, outsource: EntryResourceData, business: EntryResourceData) -> void:
	current_loadout = {
		"creator": creator,
		"outsource": outsource,
		"business": business,
	}


## 获取本局合并效果（供研发/事件模块读取）
func get_loadout_effects() -> Dictionary:
	if current_loadout.is_empty():
		return {}
	var effects: Dictionary = {}
	for res: EntryResourceData in current_loadout.values():
		effects.merge(res.get_effects())
	return effects


## 获取本局入场总投入
func get_loadout_cost() -> int:
	var total: int = 0
	for res: EntryResourceData in current_loadout.values():
		total += res.price
	return total


## 重置（新游戏）
func reset() -> void:
	money = INITIAL_MONEY
	is_first_run = true
	current_loadout = {}
	money_changed.emit(money)
```

**注册 Autoload：** 在 `project.godot` 的 `[autoload]` 区段添加：
```
EconomyManager="*res://game/scripts/autoload/economy_manager.gd"
```

---

### 3.3 资源卡片场景：`resource_card.tscn` + `resource_card.gd`

**场景树结构：**

```
ResourceCard (PanelContainer)                # resource_card.gd
├── MarginContainer
│   └── VBoxContainer
│       ├── IconTexture (TextureRect)        # 头像/占位图
│       ├── NameLabel (Label)                # "鹅皇互娱主创"
│       ├── DescLabel (Label)                # "大厂历练过..."
│       ├── HSeparator
│       ├── EffectLabel (Label)              # "品质上限: 70分"
│       └── PriceLabel (Label)               # "💰 300"
└── SelectHighlight (ColorRect)              # 选中高亮层（默认隐藏）
```

```gdscript
# scripts/ui/resource_card.gd
class_name ResourceCard
extends PanelContainer

## 信号：被点击选中
signal card_selected(card: ResourceCard)

## 绑定的资源数据
var resource_data: EntryResourceData

## UI引用
@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var effect_label: Label = %EffectLabel
@onready var price_label: Label = %PriceLabel
@onready var select_highlight: ColorRect = %SelectHighlight

var is_selected: bool = false
var is_affordable: bool = true


func setup(data: EntryResourceData) -> void:
	resource_data = data
	name_label.text = data.display_name
	desc_label.text = data.description
	price_label.text = "💰 %d" % data.price

	# 根据类别显示效果文本
	match data.category:
		EntryResourceData.Category.CREATOR:
			effect_label.text = "品质上限: %d分" % data.quality_cap
		EntryResourceData.Category.OUTSOURCE:
			effect_label.text = "研发速度: %.1f×" % data.dev_speed
		EntryResourceData.Category.BUSINESS:
			effect_label.text = "急救精力: %d点" % data.energy

	# 图标
	if data.icon:
		icon_texture.texture = data.icon
	# 无图标时保留占位

	select_highlight.visible = false


func set_selected(selected: bool) -> void:
	is_selected = selected
	select_highlight.visible = selected


func set_affordable(affordable: bool) -> void:
	is_affordable = affordable
	modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.4)
	# 灰显不可选


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_affordable:
			card_selected.emit(self)
```

---

### 3.4 选购界面场景：`entry_shop.tscn` + `entry_shop.gd`

**场景树结构：**

```
EntryShop (Control)                          # entry_shop.gd — 根节点 full_rect
├── Background (ColorRect)                   # 深色背景
├── VBoxContainer (主布局)
│   ├── MoneyLabel (Label)                   # "持有金钱: 600"
│   ├── HSeparator
│   ├── HBoxContainer (3列资源)
│   │   ├── CreatorColumn (VBoxContainer)
│   │   │   ├── ColumnTitle (Label)          # "🎮 主创"
│   │   │   └── CardContainer (VBoxContainer) # 动态填充3张卡片
│   │   ├── VSeparator
│   │   ├── OutsourceColumn (VBoxContainer)
│   │   │   ├── ColumnTitle (Label)          # "⚙️ 外包"
│   │   │   └── CardContainer (VBoxContainer)
│   │   ├── VSeparator
│   │   └── BusinessColumn (VBoxContainer)
│   │       ├── ColumnTitle (Label)          # "🤝 商务"
│   │       └── CardContainer (VBoxContainer)
│   ├── HSeparator
│   └── HBoxContainer (底栏)
│       ├── TotalLabel (Label)               # "已选总价: 300 / 600"
│       └── ConfirmButton (Button)           # "开工！"
```

```gdscript
# scripts/ui/entry_shop.gd
extends Control

## 信号：选购完成，通知核心框架切换到选题阶段
signal shop_completed

## 资源数据预加载（编辑器拖入 .tres 文件）
@export var creator_resources: Array[EntryResourceData] = []   # 低/中/高 共3个
@export var outsource_resources: Array[EntryResourceData] = []
@export var business_resources: Array[EntryResourceData] = []

## UI 引用
@onready var money_label: Label = %MoneyLabel
@onready var total_label: Label = %TotalLabel
@onready var confirm_button: Button = %ConfirmButton

@onready var creator_container: VBoxContainer = %CreatorCardContainer
@onready var outsource_container: VBoxContainer = %OutsourceCardContainer
@onready var business_container: VBoxContainer = %BusinessCardContainer

## 卡片场景预加载
var card_scene: PackedScene = preload("res://game/scenes/ui/resource_card.tscn")

## 当前选中状态（每列一个）
var selected: Dictionary = {
	"creator": null,     # ResourceCard
	"outsource": null,
	"business": null,
}

## 所有卡片引用（用于刷新状态）
var all_cards: Array[ResourceCard] = []


func _ready() -> void:
	_build_column(creator_container, creator_resources, "creator")
	_build_column(outsource_container, outsource_resources, "outsource")
	_build_column(business_container, business_resources, "business")

	confirm_button.pressed.connect(_on_confirm)
	EconomyManager.money_changed.connect(_on_money_changed)

	_refresh_ui()


## 构建一列卡片
func _build_column(container: VBoxContainer, resources: Array[EntryResourceData], category_key: String) -> void:
	for res_data: EntryResourceData in resources:
		var card: ResourceCard = card_scene.instantiate()
		container.add_child(card)
		card.setup(res_data)
		card.card_selected.connect(_on_card_selected.bind(category_key))
		all_cards.append(card)

	# 默认选中最低级（数组第0个）
	if container.get_child_count() > 0:
		var first_card: ResourceCard = container.get_child(0) as ResourceCard
		first_card.set_selected(true)
		selected[category_key] = first_card


## 卡片被选中的回调
func _on_card_selected(card: ResourceCard, category_key: String) -> void:
	# 取消同列旧选中
	var old_card: ResourceCard = selected[category_key]
	if old_card and old_card != card:
		old_card.set_selected(false)

	card.set_selected(true)
	selected[category_key] = card
	_refresh_ui()


## 计算当前已选总价
func _get_total_cost() -> int:
	var total: int = 0
	for card: ResourceCard in selected.values():
		if card:
			total += card.resource_data.price
	return total


## 刷新所有 UI 状态
func _refresh_ui() -> void:
	var current_money: int = EconomyManager.get_money()
	var total_cost: int = _get_total_cost()

	# 更新金钱和总价显示
	money_label.text = "持有金钱: %d" % current_money
	total_label.text = "已选总价: %d / %d" % [total_cost, current_money]

	# 计算每张卡片的可选状态：
	# 如果选中该卡片替换同列当前选中，总价是否 <= 金钱
	for card: ResourceCard in all_cards:
		var simulated_cost: int = total_cost
		# 减去同列当前选中的价格
		var cat_key: String = _category_to_key(card.resource_data.category)
		var current_card: ResourceCard = selected[cat_key]
		if current_card:
			simulated_cost -= current_card.resource_data.price
		# 加上该卡片的价格
		simulated_cost += card.resource_data.price
		card.set_affordable(simulated_cost <= current_money)

	# 确认按钮状态
	confirm_button.disabled = total_cost > current_money


## 确认选购
func _on_confirm() -> void:
	var total_cost: int = _get_total_cost()
	if not EconomyManager.purchase_loadout(total_cost):
		return  # 不应走到这里（按钮已禁用），防御性检查

	# 存储装备数据
	EconomyManager.set_loadout(
		selected["creator"].resource_data,
		selected["outsource"].resource_data,
		selected["business"].resource_data
	)

	# 通知外部
	shop_completed.emit()


## 金钱变化回调（局间重入时更新）
func _on_money_changed(_new_amount: int) -> void:
	_refresh_ui()


## 辅助：Category枚举 → 字典key
func _category_to_key(category: EntryResourceData.Category) -> String:
	match category:
		EntryResourceData.Category.CREATOR:
			return "creator"
		EntryResourceData.Category.OUTSOURCE:
			return "outsource"
		EntryResourceData.Category.BUSINESS:
			return "business"
	return ""


## 重入时重置选中状态（每局开始调用）
func reset_selection() -> void:
	for category_key: String in selected.keys():
		if selected[category_key]:
			selected[category_key].set_selected(false)
		selected[category_key] = null

	# 重新默认选中每列最低级
	_default_select(creator_container, "creator")
	_default_select(outsource_container, "outsource")
	_default_select(business_container, "business")
	_refresh_ui()


func _default_select(container: VBoxContainer, category_key: String) -> void:
	if container.get_child_count() > 0:
		var first_card: ResourceCard = container.get_child(0) as ResourceCard
		first_card.set_selected(true)
		selected[category_key] = first_card
```

---

### 3.5 场景间接口（与模块01对接）

```gdscript
## ---- 模块01的场景管理器中，监听选购完成信号 ----
# 假设在 GameManager Autoload 或主场景脚本中：

func _on_entry_shop_completed() -> void:
	# EntryShop 的 shop_completed 信号连接到此
	game_state.transition("TOPIC_SELECT")  # 进入选题阶段


## ---- 模块06结算完成后，重入选购 ----
func _on_settlement_finished(success: bool, earnings: int) -> void:
	if success:
		EconomyManager.add_earnings(earnings)
	else:
		EconomyManager.apply_failure(EconomyManager.get_loadout_cost())
	# 切换回选购场景
	game_state.transition("ENTRY_SHOP")
	entry_shop_scene.reset_selection()
```

**下游模块读取装备效果的方式：**

```gdscript
# 模块04（研发流程）中：
var effects: Dictionary = EconomyManager.get_loadout_effects()
var quality_cap: int = effects.get("quality_cap", 40)
var dev_speed: float = effects.get("dev_speed", 1.0)

# 模块05（随机事件）中：
var effects: Dictionary = EconomyManager.get_loadout_effects()
var energy: int = effects.get("energy", 8)
var option_unlock: String = effects.get("option_unlock", "partial")
```

---

## 四、实施步骤与工时

### 步骤1：Resource 子类 + 9个 .tres 数据文件（0.75h）

**产出文件：**
- `game/scripts/resources/entry_resource_data.gd`
- `game/resources/entry_resources/*.tres`（9个文件）

**内容：**
- 定义 `EntryResourceData` Resource 子类，包含 Category/Tier 枚举、所有 @export 属性
- 创建 9 个 `.tres` 文件，填入规格文档中的数值
- 在 Godot 编辑器的 Inspector 中验证所有字段正确可编辑

**依赖：** 无

**验收：** 编辑器中双击任意 `.tres` 文件，Inspector 显示所有字段且数值正确。

---

### 步骤2：EconomyManager Autoload 单例（1h）

**产出文件：**
- `game/scripts/autoload/economy_manager.gd`
- 修改 `project.godot` 注册 Autoload

**内容：**
- 实现金钱管理（增减、保底、购买校验）
- 实现装备存储（set_loadout / get_loadout_effects）
- 定义信号 `money_changed` / `loadout_confirmed`
- 控制台验证：通过编辑器 Remote 面板检查变量，或写一个临时测试场景

**依赖：** 步骤1（需要 EntryResourceData 类）

**验收：** 在编辑器 Remote 面板或 GDScript `_ready()` 中调用 `EconomyManager.purchase_loadout(300)` → 金钱从600变300 → `money_changed` 信号触发。

---

### 步骤3：资源卡片可复用场景（1h）

**产出文件：**
- `game/scenes/ui/resource_card.tscn`
- `game/scripts/ui/resource_card.gd`

**内容：**
- 搭建 PanelContainer 场景树（图标 + 名称 + 简介 + 效果 + 价格）
- 实现 `setup()` / `set_selected()` / `set_affordable()` 接口
- 实现点击输入处理 + `card_selected` 信号
- 像素风样式：通过 Theme Override 设置字体/颜色/边距

**依赖：** 步骤1（setup 方法需要 EntryResourceData 类型）

**验收：** 单独运行 `resource_card.tscn`，调用 `setup()` 传入测试数据，卡片正确显示内容。

---

### 步骤4：选购界面主场景 + 交互逻辑（1.25h）

**产出文件：**
- `game/scenes/entry_shop.tscn`
- `game/scripts/ui/entry_shop.gd`

**内容：**
- 搭建 3 列布局（HBoxContainer 包含 3 个 VBoxContainer）
- 顶部金钱显示 + 底部总价/确认按钮
- 动态实例化 ResourceCard 并连接信号
- 实现同列单选互斥逻辑
- 实时总价计算 + 可选性灰显
- 确认时扣钱 → 存装备 → 发射 `shop_completed` 信号
- @export 数组绑定 .tres 文件（编辑器内拖入）

**依赖：** 步骤1（数据）+ 步骤2（EconomyManager）+ 步骤3（卡片场景）

**验收：**
- 独立运行 `entry_shop.tscn`
- 3列×3行卡片全部展示，默认选中每列最低级
- 点击切换选中态，总价实时更新
- 选了高级后另一列高级灰显（金钱不足）
- 点确认，打印信号被触发

---

### 步骤5：局间衔接与集成测试（1h）

**修改文件：** `economy_manager.gd` + `entry_shop.gd` + 模块01场景管理

**内容：**
- 将 `entry_shop.tscn` 接入模块01的场景管理流程
- `shop_completed` 信号连接到状态机的 `ENTRY_SHOP → TOPIC_SELECT` 转移
- 局结束后重入选购界面，验证金钱正确：
  - 首局：600，默认3个低级
  - 失败后：保底300，只能全选低级
  - 成功后：金钱 > 600，可选更高配置
- `reset_selection()` 在重入时正确重置
- 调试快捷方式：通过编辑器 Remote 修改 `EconomyManager.money` 验证各种边界情况

**依赖：** 步骤1-4 全部完成 + 模块01场景管理器

**验收：** 完整流程跑通（菜单 → 选购 → 确认 → 场景切换成功）。

---

## 五、依赖关系图

```
模块01（核心框架）
  ├── GameState（状态机）──────────┐
  └── 场景管理器 ─────────────────┤
                                   │
步骤1: entry_resource_data.gd     │
       + 9个 .tres（无依赖）       │
  │                                │
  ├──→ 步骤2: economy_manager.gd  │
  │    （依赖步骤1的类定义）        │
  │                                │
  ├──→ 步骤3: resource_card.tscn  │
  │    （依赖步骤1的类定义）        │
  │                                │
  └──→ 步骤4: entry_shop.tscn ←───┤
       （依赖步骤1+2+3）           │
         │                         │
         ▼                         │
       步骤5: 集成测试 ←───────────┘
       （依赖步骤1-4 + 模块01）

下游消费方：
  → 模块04（研发）：EconomyManager.get_loadout_effects() → quality_cap / dev_speed
  → 模块05（事件）：EconomyManager.get_loadout_effects() → energy / option_unlock
  → 模块06（结算）：EconomyManager.add_earnings() / apply_failure()
```

**可并行：** 步骤2 和步骤3 互相独立，可同时开发（都只依赖步骤1）。
**必须串行：** 步骤1 → 步骤4 → 步骤5。

---

## 六、工时汇总

| 步骤 | 内容 | 工时 | 可并行 |
|------|------|------|--------|
| 1 | Resource子类 + 9个.tres数据 | 0.75h | — |
| 2 | EconomyManager Autoload | 1.0h | 与步骤3并行 |
| 3 | 资源卡片可复用场景 | 1.0h | 与步骤2并行 |
| 4 | 选购界面主场景+交互 | 1.25h | — |
| 5 | 局间衔接与集成测试 | 1.0h | — |
| **总计** | | **5.0h** | 串行关键路径: 4.0h |

---

## 七、风险与降级方案

| 风险 | 降级方案 |
|------|---------|
| 卡片样式调试超时 | 砍掉 PanelContainer 样式，用纯 Label + ColorRect 最简布局 |
| 角色头像素材未就绪 | icon 字段留空，用 emoji + 色块占位（Theme 颜色区分等级） |
| 灰显可选性逻辑复杂 | 简化：只在点击确认时校验总价，不实时灰显单卡 |
| 模块01未完成阻塞集成 | 步骤1-4可独立开发运行，`entry_shop.tscn` 独立测试，用 `print()` 模拟场景切换 |
| .tres 文件编辑器创建繁琐 | 写一个简单的工具脚本 `@tool` 批量生成9个.tres文件 |

---

## 八、验收标准

- [ ] 首局进入选购界面，显示金钱600，3列×3级共9张卡片全部展示
- [ ] 每列单选互斥，选中高亮，总价实时更新
- [ ] 买不起的选项灰显不可点（选了高级主创后，高级外包灰显）
- [ ] 点"开工"正确扣钱，`EconomyManager.current_loadout` 写入正确数据
- [ ] `get_loadout_effects()` 返回合并后的效果字典，字段完整
- [ ] 全损后重入（模拟），金钱保底300，只能全选低级
- [ ] 成功结算后重入（模拟），金钱增加，可选范围扩大
- [ ] 编辑器内修改任意 .tres 文件的 price/quality_cap 等字段，运行后立即生效

---

## 九、Godot 项目配置备忘

```ini
# project.godot 需要添加的配置

[autoload]
EconomyManager="*res://game/scripts/autoload/economy_manager.gd"
```

确保 `game/scripts/resources/entry_resource_data.gd` 中的 `class_name EntryResourceData` 声明在文件顶部，Godot 会自动将其注册为全局可用类型，无需额外配置。
