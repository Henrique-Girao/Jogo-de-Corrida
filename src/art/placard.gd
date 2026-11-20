extends RefCounted
## Signage lives on the front face of a panel (+Z in panel space).

const Ui = preload("res://src/ui/ui_kit.gd")
const FONT_SIZE := 64
const FACE_OFFSET := 0.012


static func panel(parent: Node3D, face: Transform3D, size: Vector2, title: String, detail: String,
		title_ink: Color, detail_ink: Color, width_fraction := 0.84) -> void:
	var width := size.x * width_fraction
	if detail.is_empty():
		line(parent, face, title, Vector2(width, size.y * 0.75), title_ink)
		return
	var head := face.translated_local(Vector3(0.0, size.y * 0.17, 0.0))
	var foot := face.translated_local(Vector3(0.0, -size.y * 0.27, 0.0))
	line(parent, head, title, Vector2(width, size.y * 0.49), title_ink)
	line(parent, foot, detail, Vector2(width, size.y * 0.27), detail_ink, true)


static func line(parent: Node3D, face: Transform3D, words: String, size: Vector2, ink: Color,
		detail := false) -> Label3D:
	var font: Font = Ui.MONO if detail else Ui.DISPLAY
	# The allowance accounts for italic overhang and the texture's transparent edge.
	var metrics := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE) + Vector2(8, 4)
	var label := Label3D.new()
	label.text = words
	label.font = font
	label.font_size = FONT_SIZE
	label.pixel_size = minf(size.x / metrics.x, size.y / metrics.y)
	label.modulate = ink
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.transform = face.translated_local(Vector3(0, 0, FACE_OFFSET))
	label.set_meta("letter_area", size)
	parent.add_child(label)
	return label
