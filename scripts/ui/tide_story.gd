class_name TideStory
extends RefCounted
## Сюжетные материалы: портреты героини и реплики пролога.
##
## Портреты — большие вырезки 1536×2752, поэтому грузятся по требованию и не
## кэшируются: в памяти живёт только тот, что сейчас на экране.

const DIR := "res://assets/story/"
const HEROINE := "ДОЧЬ"
const MOTHER := "МАМА · СО ВТОРОГО ЭТАЖА"

## Пролог перед первым выходом: мама отправляет за материалами, героиня не
## в восторге, а её ещё и укачивает. who: 0 — героиня, 1 — мама (за кадром).
const PROLOGUE := [
	{"who": 0, "face": "yawn", "line": "…Ещё пять минут. Суббота же."},
	{"who": 1, "face": "hears_1", "line": "Ты встала? Маяк опять без пигмента. Сгоняй на лодке за материалами!"},
	{"who": 1, "face": "hears_2", "line": "И не делай вид, что не слышишь!"},
	{"who": 0, "face": "side_1", "line": "Слышу, слышу…"},
	{"who": 0, "face": "reply_annoyed", "line": "Мам, меня на этой лодке укачивает! Каждый раз!"},
	{"who": 1, "face": "side_2", "line": "Смотри на горизонт и дыши носом. Пигмент сам себя не соберёт."},
	{"who": 0, "face": "thoughtful", "line": "Хотя… если обернусь до обеда, остаток дня — мой."},
	{"who": 0, "face": "sly", "line": "И часть добычи тоже моя. За вредность."},
	{"who": 0, "face": "nausea_1", "line": "Ох. Ещё даже не отчалила, а уже мутит."},
]

## Реплики в рейсе: чем ниже осадка корпуса, тем сильнее укачивает.
const NAUSEA := [
	"Что-то меня мутит…",
	"Ой-ой. Не качай так!",
	"Всё. Сейчас стошнит.",
]


## Материал белой подложки-силуэта: прячет недовырезанные белые точки в
## волосах. spread — ширина каймы в пикселях исходного спрайта.
static func backing(spread: float = 14.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sprite_backing.gdshader")
	material.set_shader_parameter("spread", spread)
	return material


static func portrait(face: String) -> Texture2D:
	var path := "%sheroine_%s.webp" % [DIR, face]
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
