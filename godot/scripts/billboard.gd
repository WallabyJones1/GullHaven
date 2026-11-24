extends RefCounted
## Sprite-sheet helpers for 4-direction pixel characters that stay right as the camera
## turns: the row shown depends on which way the character faces in the world *and*
## where the camera is looking from.
## Sheets are laid out with rows down, up, left, right.

const DOWN := 0
const UP := 1
const LEFT := 2
const RIGHT := 3


static func row_for(dir: Vector3, cam: Camera3D) -> int:
	dir.y = 0.0
	if dir.length() < 0.001:
		return DOWN
	var right := Vector3.RIGHT
	var fwd := Vector3.FORWARD
	if cam:
		right = cam.global_transform.basis.x
		fwd = -cam.global_transform.basis.z
		right.y = 0.0
		fwd.y = 0.0
		right = right.normalized()
		fwd = fwd.normalized()
	var a := dir.dot(right)
	var b := dir.dot(fwd)
	if absf(a) > absf(b):
		return RIGHT if a > 0.0 else LEFT
	return UP if b > 0.0 else DOWN


## A pixel-art billboard standing on the ground at `at` (feet at `foot_px` from the top of
## each frame).
static func sprite(tex: Texture2D, pixel: float, hframes := 1, vframes := 1, foot_px := -1.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = hframes
	s.vframes = vframes
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if tex:
		var fh := tex.get_height() / float(vframes)
		var foot := foot_px if foot_px >= 0.0 else fh - 2.0
		s.offset = Vector2(0.0, fh * 0.5 - (fh - foot))
	return s
