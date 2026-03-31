# code_rescue_preset.gd — 代码急救小游戏参数预设
class_name CodeRescuePreset
extends Resource

@export var preset_id: String                ## 预设标识
@export var preset_name: String              ## 显示名称（如"代码库出现严重bug"）
@export_multiline var flavor_text: String    ## 叙事包装文本

@export_group("游戏参数")
@export var initial_bug_count: int = 3       ## 初始 bug 数量
@export var spread_interval: float = 1.5     ## bug 扩散间隔（秒）
@export var use_business_energy: bool = true  ## true=用商务等级精力，false=用固定值
@export var fixed_energy: int = 10           ## use_business_energy=false 时的固定精力

@export_group("初始布局")
@export var spawn_mode: String = "random"    ## "random" / "scattered" / "edge"
## random: 完全随机位置
## scattered: 分散放置（确保相互间隔>=2格）
## edge: 从边缘涌入


## 获取实际精力值
func get_energy(business_level: int) -> int:
	if use_business_energy:
		var energy: int = Config.BUSINESS_ENERGY.get(business_level, 8) as int
		return energy
	return fixed_energy
