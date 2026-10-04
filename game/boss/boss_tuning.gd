class_name BossTuning
extends Resource
## Native encounter parameters; the scene owns positions and collision shapes.

@export_category("Health and shield")
@export_range(1, 2000, 1) var max_hp := 220.0
@export_range(0.05, 0.95, 0.05) var phase_two_ratio := 0.5
@export_range(0, 1000, 1) var shield_capacity := 100.0
@export_range(0, 1, 0.05) var shield_damage_multiplier := 0.25
@export_range(0, 10, 0.1) var shield_break_stun := 2.2

@export_category("Movement and crushing")
@export_range(0, 10, 0.05) var phase_one_speed_cells := 1.1
@export_range(0, 10, 0.05) var phase_two_speed_cells := 1.45
@export_range(1, 20, 1) var target_seconds_min := 3
@export_range(1, 20, 1) var target_seconds_max := 5
@export_range(0.1, 5, 0.1) var body_crush_cooldown := 0.8

@export_category("Two-shot alternating volleys")
@export_range(0.1, 30, 0.1) var first_wave_delay := 3.0
@export_range(0.1, 30, 0.1) var phase_one_wave_interval := 8.0
@export_range(0.1, 30, 0.1) var phase_two_wave_interval := 6.5
@export_range(1, 8, 1) var shots_per_burst := 2
@export_range(0.05, 3, 0.05) var burst_gap := 0.5
@export_range(1, 36, 1) var phase_one_ring_count := 9
@export_range(1, 36, 1) var phase_two_ring_count := 12
@export_range(1, 20, 1) var phase_one_aim_count := 4
@export_range(1, 20, 1) var phase_two_aim_count := 5
@export_range(0, 1, 0.01) var aim_spread := 0.16
@export_range(0, 2, 0.01) var ring_rotation_step := 0.37
@export_range(0.1, 20, 0.1) var phase_one_seed_speed_cells := 2.1
@export_range(0.1, 20, 0.1) var phase_two_seed_speed_cells := 2.4
@export_range(0, 10, 0.1) var aimed_speed_bonus_cells := 0.5
@export_range(0.1, 30, 0.1) var seed_lifetime := 12.0
@export_range(0, 100, 1) var reflected_seed_damage := 6.0

@export_category("Phase-one summons")
@export_range(0.1, 60, 0.1) var first_summon_delay := 9.0
@export_range(0.1, 60, 0.1) var summon_interval := 12.0
@export_range(0, 20, 1) var summon_limit := 3
@export_range(1, 20, 1) var summon_radius_min_cells := 5
@export_range(1, 20, 1) var summon_radius_max_cells := 8
