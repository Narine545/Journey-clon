class_name GameGraphicsSettings
extends RefCounted
## Локальные настройки рендера; не содержат игрового прогресса.
signal changed

const PATH := "user://graphics.cfg"
const SCALES := [50, 60, 70, 80, 90, 100]
const MSAA_VALUES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
var scale_percent := 100
var msaa: int = Viewport.MSAA_4X
var save_error := OK
var path := PATH


func load_from_disk(file_path: String = PATH) -> void:
	path = file_path
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var scale_value: Variant = config.get_value("graphics", "scale_percent", scale_percent)
	var msaa_value: Variant = config.get_value("graphics", "msaa", msaa)
	if typeof(scale_value) == TYPE_INT and scale_value in SCALES:
		scale_percent = int(scale_value)
	if typeof(msaa_value) == TYPE_INT and msaa_value in MSAA_VALUES:
		msaa = int(msaa_value)


func set_scale(value: int) -> void:
	if value not in SCALES or scale_percent == value:
		return
	scale_percent = value
	_save_and_notify()


func set_msaa(value: int) -> void:
	if value not in MSAA_VALUES or msaa == value:
		return
	msaa = value
	_save_and_notify()


func _save_and_notify() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "scale_percent", scale_percent)
	config.set_value("graphics", "msaa", msaa)
	save_error = config.save(path)
	changed.emit()


func apply(viewport: Viewport) -> void:
	viewport.scaling_3d_scale = float(scale_percent) / 100.0
	viewport.msaa_3d = msaa as Viewport.MSAA
