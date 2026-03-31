# event_bus.gd — 全局信号总线，所有跨模块通信的中枢
extends Node

## ===== 状态机信号 =====
signal state_changed(from_state: StringName, to_state: StringName)

## ===== 时间系统信号 =====
signal time_tick(remaining: float, elapsed: float, total: float)
signal time_warning(remaining: float)        ## 剩余 < 20%
signal time_expired()                        ## 时间耗尽
signal time_paused()
signal time_resumed()

## ===== 研发阶段信号 =====
signal dev_phase_changed(new_phase: StringName)  ## "early" / "mid" / "late"

## ===== 局生命周期信号 =====
signal run_started()                         ## 新局开始
signal run_ended(success: bool, earnings: int)  ## 局结束

## ===== 入场资源信号 =====
signal shop_completed(loadout: Dictionary)   ## 资源选购完成
signal money_changed(new_amount: int)        ## 金钱变动

## ===== 选题信号 =====
signal topic_selected(topic_id: String, game_name: String)

## ===== 事件系统信号 =====
signal event_triggered(event_data: Dictionary)
signal event_resolved(event_id: String, result: Dictionary)
signal exploration_appeared(explore_data: Dictionary)
signal exploration_expired(explore_id: String)

## ===== 品质信号 =====
signal quality_changed(new_quality: float, display_level: String)
signal quality_revealed(true_quality: float, true_level: String)

## ===== 市场信号 =====
signal market_updated(topic_id: String, signal_text: String)
signal competitor_launched(competitor_name: String, topic_id: String)

## ===== 上线与结算信号 =====
signal launch_requested()
signal launch_confirmed()
signal launch_cancelled()
signal settlement_complete(action: String)   ## "next_run" 或 "main_menu"
