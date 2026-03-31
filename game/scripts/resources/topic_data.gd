# topic_data.gd — 题材静态配置
class_name TopicData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""           ## 一句话描述
@export var icon: Texture2D                     ## 题材图标（可空，用占位色块）

## 热度曲线参数
@export_group("Heat Config")
@export var initial_heat: float = 50.0          ## 初始热度 [30-70]
@export var phase_offset: float = 0.0           ## 正弦波相位偏移（弧度），各题材错峰
@export var amplitude: float = 25.0             ## 正弦波振幅
@export var noise_seed: int = 0                 ## 噪声种子
