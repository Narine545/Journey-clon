class_name TideStory
extends RefCounted
## Сюжетные материалы: портреты Мимо и тёти Форнэль, реплики пролога и рейда.
##
## Портреты — большие вырезки (около 1536×2752, размер у файлов слегка разный), поэтому грузятся по требованию и не
## кэшируются: в памяти живёт только тот, что сейчас на экране.

const DIR := "res://assets/story/"
## Мимо — по канону автора ей 18 лет.
const HEROINE := "МИМО"
const AUNT := "ТЁТЯ ФОРНЭЛЬ"

## Пролог перед первым выходом: тётя Форнэль отправляет Мимо за материалами,
## та не в восторге, а её ещё и укачивает. who: 0 — Мимо, 1 — тётя.
## face — файл портрета: «aunt_*» — тётя, остальное — «heroine_*». Тётю сначала
## только слышно (в кадре реакция Мимо), потом она входит сама.
const PROLOGUE := [
	{"who": 0, "face": "yawn", "line": "…Ещё пять минут. Суббота же."},
	{"who": 1, "face": "hears_1", "line": "Мимо! Ты встала? Маяк опять без пигмента."},
	{"who": 1, "face": "aunt_talk", "line": "Сгоняй на лодке за материалами. И не делай вид, что не слышишь!"},
	{"who": 0, "face": "side_1", "line": "Слышу, слышу…"},
	{"who": 0, "face": "reply_annoyed", "line": "Тёть, меня на этой лодке укачивает! Каждый раз!"},
	{"who": 1, "face": "aunt_idle", "line": "Смотри на горизонт и дыши носом. Пигмент сам себя не соберёт."},
	{"who": 0, "face": "thoughtful", "line": "Хотя… если обернусь до обеда, остаток дня — мой."},
	{"who": 0, "face": "sly", "line": "И часть добычи тоже моя. За вредность."},
	{"who": 1, "face": "aunt_talk", "line": "Я всё слышу, Мимо."},
	{"who": 0, "face": "nausea_1", "line": "Ох. Ещё даже не отчалила, а уже мутит."},
]

## Реплики в рейде по мере потери корпуса: сперва укачивает, потом страшно.
## below — порог доли корпуса, ниже которого реплика срабатывает.
const HULL_BARKS := [
	{"below": 0.70, "face": "nausea_1", "line": "Что-то меня мутит…"},
	{"below": 0.50, "face": "nausea_2", "line": "Ой-ой. Не качай так!"},
	{"below": 0.35, "face": "fear_hull_1", "line": "Корпус трещит! Тётя меня убьёт…"},
	{"below": 0.20, "face": "fear_hull_2", "line": "Мы сейчас утонем!"},
]
## Заставка перед репликами: два кадра и подписи к ним.
const INTRO := [
	{"file": "intro_sleep", "line": "05:40. Тихая бухта ещё спит."},
	{"file": "intro_awake", "line": "Мимо тоже хотела бы. Но у тёти Форнэль другие планы."},
]
const BOSS_BARK := {"face": "fear_big", "line": "Это ЧТО ещё такое?!"}

## Доля кадра портрета, где находится лицо (общая для всех вырезок Мимо).
const FACE_REGION := Rect2(0.26, 0.17, 0.55, 0.25)


## Материал белой подложки-силуэта: прячет недовырезанные белые точки в
## волосах. spread — ширина каймы в пикселях исходного спрайта.
static func backing(spread: float = 14.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sprite_backing.gdshader")
	material.set_shader_parameter("spread", spread)
	return material


static func portrait(face: String) -> Texture2D:
	return picture(("" if face.begins_with("aunt_") else "heroine_") + face)


## Кадр заставки пролога: верхняя часть картинки (подушка, лицо, будильник)
## широкой кинополосой.
static func intro_frame(file: String) -> Texture2D:
	var source := picture(file)
	if source == null:
		return null
	var extent := Vector2(source.get_size())
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	# Вся ширина кадра: общий план комнаты, лицо и руки не крупным планом.
	atlas.region = Rect2(0.0, 0.0, extent.x, extent.y * 0.42)
	return atlas


static func picture(file: String) -> Texture2D:
	var path := "%s%s.webp" % [DIR, file]
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	# Проект ещё не импортирован (первый запуск, CI): читаем файл напрямую.
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	var image := Image.load_from_file(absolute)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
