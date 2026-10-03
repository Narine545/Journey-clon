class_name ProcTextures
extends RefCounted
## Генерация маленьких текстур кодом — никаких бинарных ассетов.


## Мягкий белый круг (альфа падает от центра к краю).
static func radial(size: int = 48, falloff: float = 1.6) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := pow(clampf(1.0 - d, 0.0, 1.0), falloff)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## Чёрная точка — безопасное значение по умолчанию для sampler2D.
static func black_pixel() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 1.0))
	return ImageTexture.create_from_image(img)


## Материал частицы: аддитивный, неосвещённый, мягкий спрайт.
static func particle_material(tex: ImageTexture, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = tex
	m.albedo_color = tint
	m.disable_receive_shadows = true
	return m
