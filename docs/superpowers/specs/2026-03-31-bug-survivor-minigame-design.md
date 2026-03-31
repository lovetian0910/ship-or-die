# Bug Survivor 小游戏设计规格

## 概述

新增一个幸存者 Like 小游戏，与现有代码急救小游戏并存，作为部分打类事件的载体。玩家控制一个程序员角色，在固定竞技场内躲避并射击不断生成的虫子（bug），坚持 60 秒通关。

## 核心玩法

- **操控**：WASD / 方向键控制 8 方向移动，射击全自动（锁定最近虫子）
- **胜利条件**：坚持 60 秒
- **失败条件**：虫子碰到玩家
- **结算**：`survival_rate = 存活时间 / 60`，复用现有三档结算（大成功 / 保守成功 / 失败）

## 架构

### 技术方案

方案 A：纯 Area2D 碰撞。玩家、子弹、虫子全部用 Area2D + CollisionShape2D，通过 `area_entered` 信号检测碰撞。不使用 CharacterBody2D 或 RigidBody2D。

选择理由：1 分钟嵌入式小游戏，Area2D 完全够用，开发速度最快，与现有架构风格一致。

### 场景结构

```
BugSurvivorGame (Node2D)
├── Arena (Node2D)
│   ├── ArenaBorder — 边界（位置 clamp 或 StaticBody2D）
│   ├── Player (Area2D)
│   │   ├── CollisionShape2D（圆形，半径 ~16px）
│   │   └── ColorRect + Label（占位图："👨‍💻"）
│   ├── Bullets (Node2D) — 子弹容器
│   └── Bugs (Node2D) — 虫子容器
├── HUD (CanvasLayer)
│   ├── TimeLabel — 倒计时 / 已坚持时间
│   └── KillCount — 击杀数（纯展示）
└── GameOverPanel (Control) — 结束面板
```

### 代码分层

| 层 | 文件 | 职责 |
|---|---|---|
| 数据层 | `bug_survivor_data.gd` (RefCounted) | 纯逻辑：生成间隔计算、难度曲线、存活率计算。零 UI 依赖，完全可测试 |
| 游戏层 | `bug_survivor_game.gd` (Node2D) | 主控：玩家移动、子弹发射、虫子生成、碰撞处理、计时、结算 |
| 预设层 | `bug_survivor_preset.gd` (Resource) | 参数化：竞技场大小、虫子速度、生成频率等 |

分层对齐现有代码急救的 `code_rescue_grid.gd` / `code_rescue_game.gd` / `code_rescue_preset.gd` 三层结构。

### 信号接口

```gdscript
signal game_finished(survival_rate: float)
```

与代码急救完全一致，FightEventPopup 下游结算代码零改动。

## 游戏实体

### 玩家

- 移动：WASD / 方向键，8 方向，固定速度，位置 clamp 在竞技场内
- 碰撞体：圆形 Area2D，半径 ~16px
- 被虫子碰到 → 游戏立即结束（一击死，无血量系统）
- 占位图：ColorRect + "👨‍💻" Label（后期替换精灵帧动画）

### 子弹

- 发射：自动锁定最近虫子，固定间隔（如 0.3 秒 / 颗）
- 飞行：直线飞向发射瞬间目标位置（不追踪），固定速度
- 碰撞：Area2D，碰到虫子 → 虫子死亡 + 子弹消失（一击一杀）
- 离开竞技场边界自动销毁
- 占位图：小矩形 + 字母符号

### 虫子

- 生成位置：竞技场四周边缘随机点
- 移动：始终朝玩家当前位置匀速移动（每帧更新方向）
- 碰撞：Area2D，碰到玩家 → 触发 game_finished
- 被子弹击中 → 立即消失
- 占位图：ColorRect + "🐛" Label

## 难度曲线

随时间推进，虫子生成越来越密：

| 时间段 | 生成间隔 | 虫子速度倍率 | 体感 |
|--------|---------|------------|------|
| 0~15 秒 | 1.0 秒 / 只 | 1.0x | 热身，熟悉操作 |
| 15~30 秒 | 0.6 秒 / 只 | 1.2x | 开始有压力 |
| 30~45 秒 | 0.35 秒 / 只 | 1.5x | 需要持续走位 |
| 45~60 秒 | 0.2 秒 / 只 | 1.8x | 弹幕地狱，考验极限 |

速度倍率基于预设中的 `bug_base_speed` 计算：`实际速度 = bug_base_speed * 倍率`。

具体数值全部放 Config.gd，可调。

## 竞技场

- 固定矩形区域（800x600），玩家不能走出边界
- 边界实现：位置 clamp
- 背景：深色底 + 网格线（代码编辑器风格，呼应世界观）

## 集成方案

### 主流程集成

现有流程：
```
随机事件触发 → FightEventPopup → 实例化 CodeRescueGame → game_finished(survival_rate) → 三档结算
```

改造后：
```
随机事件触发 → FightEventPopup → 根据事件的 minigame_type 字段选择场景 → game_finished(survival_rate) → 三档结算
```

FightEventPopup 改动最小化：只需根据事件数据中的 `minigame_type` 字段决定加载哪个场景。

### 预设

新增 2 个幸存者 Like 预设：

| 预设 | 对应事件 | 难度特点 |
|------|---------|---------|
| `bug_swarm.tres` | 虫群爆发 | 标准难度，生成间隔正常，虫子速度正常 |
| `bug_invasion.tres` | 虫族入侵 | 高难度，生成更密、虫子更快 |

### 预设参数

```gdscript
# BugSurvivorPreset (Resource)
@export var arena_size: Vector2        # 竞技场尺寸
@export var game_duration: float       # 总时长（秒）
@export var player_speed: float        # 玩家移速
@export var bullet_speed: float        # 子弹速度
@export var bullet_interval: float     # 射击间隔
@export var bug_base_speed: float      # 虫子基础速度
@export var spawn_curve: Array[Dictionary]  # 各阶段的生成间隔和速度倍率
```

## 文件清单

### 新增

| 文件 | 说明 |
|------|------|
| `game/scripts/minigame/bug_survivor_data.gd` | 数据层（RefCounted） |
| `game/scripts/minigame/bug_survivor_game.gd` | 游戏层（Node2D 主控脚本） |
| `game/scripts/resources/bug_survivor_preset.gd` | 预设 Resource 定义 |
| `game/scenes/minigame/bug_survivor_game.tscn` | 小游戏场景 |
| `game/resources/minigame_presets/bug_swarm.tres` | 预设：虫群爆发（标准） |
| `game/resources/minigame_presets/bug_invasion.tres` | 预设：虫族入侵（困难） |
| `game/resources/events/bug_swarm_event.tres` | 事件数据：虫群爆发 |
| `game/resources/events/bug_invasion_event.tres` | 事件数据：虫族入侵 |

### 修改

| 文件 | 改动 |
|------|------|
| `game/scripts/popups/fight_event_popup.gd` | 增加 minigame_type 分发逻辑 |
| `game/scripts/autoload/config.gd` | 增加幸存者小游戏数值配置区 |
| `game/tests/test_runner.gd` | 增加新小游戏测试用例 |

## 美术规划

### 当前阶段（占位图）

所有实体使用 ColorRect + Label/emoji 占位：
- 玩家："👨‍💻"
- 子弹：字母符号小矩形
- 虫子："🐛"
- 竞技场：深色底 + 网格线

### 后续升级

使用 AI 生成序列帧精灵图：
- 玩家：程序员角色，idle / walk 动画
- 子弹：飞行键盘按键，旋转动画
- 虫子：爬行虫子，移动动画 + 死亡动画

替换方式：将 PNG 序列帧放到 `game/assets/sprites/bug_survivor/`，修改 AssetRegistry 中的路径。
