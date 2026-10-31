class_name SupplyCatalog
extends RefCounted
## Баланс M5 в одном месте; M6 может менять числа без правки систем.
const SETTINGS := {
	"start_magazine": 5,
	"start_regular_reserve": 7,
	"start_ap_reserve": 0,
	"magazine_capacity": 5,
	"muzzle_speed": 620.0,
	"bolt_seconds": 0.38,
	"reload_seconds": 1.8,
	"ap_pierce_limit": 2,
	"target_reward": 100,
	"robot_rewards": {"scout": 100, "walker": 250, "carrier": 400},
	"lift_ascent_mean": 45.0,
	"lift_ascent_variance": 15.0,
	"lift_descent_seconds": 12.0,
	"lift_called_seconds": 0.6,
	"lift_open_seconds": 1.0,
	"lift_unloaded_seconds": 0.6,
	"crate_reach": 5.0,
}
const ITEMS := {
	"ammo": {"id": "ammo", "name": "Патроны", "cost": 150, "type": "Consumable", "description_one_liner": "Пять обычных патронов в запас", "effect_payload": {"regular_ammo": 5}},
	"ap": {"id": "ap", "name": "Бронебойные", "cost": 300, "type": "Consumable", "description_one_liner": "Три патрона против брони", "effect_payload": {"ap_ammo": 3}},
	"antenna": {"id": "antenna", "name": "Антенна", "cost": 400, "type": "Upgrade", "description_one_liner": "Усиливает приём живого эфира", "effect_payload": {"live_signal_multiplier": 1.6}},
	"stability": {"id": "stability", "name": "Стабилизация", "cost": 500, "type": "Upgrade", "description_one_liner": "Уменьшает раскачку на 50%", "effect_payload": {"sway_multiplier": 0.5}},
	"scope": {"id": "scope", "name": "Оптика", "cost": 600, "type": "Upgrade", "description_one_liner": "Увеличивает кратность прицела", "effect_payload": {"zoom_multiplier": 1.5}},
}
const ORDER := ["ammo", "ap", "antenna", "stability", "scope"]


static func item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})
