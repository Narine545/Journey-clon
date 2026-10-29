class_name Ballistics
extends RefCounted
## Ветер — ускорение, а не мгновенное смещение. Масштаб ускорения
## намеренно игровой: 6 м/с бокового ветра дают ~2 м/с² сноса.
const GRAVITY := 9.81
const WIND_SPEED_SCALE := 6.0
const WIND_COUPLING := 0.32
const GUST_ACCEL := 0.30


static func wind_velocity(game: GameState) -> Vector3:
	return game.wind_dir_3d() * game.wind_strength * WIND_SPEED_SCALE


static func acceleration(game: GameState, age: float, gust_phase: float) -> Vector3:
	var gust := GUST_ACCEL * sin(age * 2.7 + gust_phase)
	return Vector3.DOWN * GRAVITY + game.wind_dir_3d() * (game.wind_strength * WIND_SPEED_SCALE * WIND_COUPLING + gust)


## Непрерывный отрезок снаряда/дальномера против высотного поля Coast.
## Между пробами уточняем переход через поверхность бисекцией; это не
## мгновенный хитскан выстрела, а проверка пройденного за шаг пути.
static func terrain_hit(coast: Coast, start: Vector3, end: Vector3, step: float = 3.0) -> Dictionary:
	var distance := start.distance_to(end)
	var samples := maxi(1, ceili(distance / maxf(step, 0.1)))
	var previous := start
	for i in range(1, samples + 1):
		var point := start.lerp(end, float(i) / float(samples))
		if point.y <= coast.ground_height(point.x, point.z):
			var a := previous
			var b := point
			for j in range(8):
				var mid := (a + b) * 0.5
				if mid.y > coast.ground_height(mid.x, mid.z):
					a = mid
				else:
					b = mid
			return {"position": b}
		previous = point
	return {}
