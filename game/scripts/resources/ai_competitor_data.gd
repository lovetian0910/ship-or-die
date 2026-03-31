# ai_competitor_data.gd — AI竞品运行时数据（局初动态生成）
class_name AICompetitorData
extends Resource

enum Personality { AGGRESSIVE, CONSERVATIVE, FOLLOWER }

@export var competitor_name: String = ""
@export var personality: Personality = Personality.AGGRESSIVE
@export var quality: float = 0.0                ## 品质分（隐藏）
@export var planned_launch_month: int = 0       ## 预设上线月份（离散月份制）
@export var heat_threshold: float = -1.0        ## 跟风派热度阈值，-1表示不看热度
@export var launched: bool = false
@export var topic_id: StringName = &""
