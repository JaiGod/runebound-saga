extends RefCounted
## Theme + widget helpers shared by every screen.

const GOLD := Color("ffd36b")
const INK := Color("f2ead8")
const DIM := Color("a89cc0")
const BG := Color("120c1e")
const PANEL := Color("1e1630")
const EDGE := Color("5a4890")
const GOOD := Color("7be06a")
const BAD := Color("ff6a6a")

static var _theme: Theme

static func sb(bg: Color, edge: Color, bw := 2, radius := 3, pad := 6) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t = Theme.new()
	t.default_font_size = 12
	t.set_stylebox("normal", "Button", sb(Color("2a1f44"), EDGE))
	t.set_stylebox("hover", "Button", sb(Color("3a2c5e"), GOLD))
	t.set_stylebox("pressed", "Button", sb(Color("4a3a78"), GOLD))
	t.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), GOLD, 2))
	t.set_stylebox("disabled", "Button", sb(Color("1a1428"), Color("3a3050")))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("6a6080"))
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, EDGE, 2, 4, 8))
	t.set_stylebox("panel", "Panel", sb(PANEL, EDGE, 2, 4, 8))
	t.set_color("font_color", "Label", INK)
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("h_separation", "GridContainer", 4)
	t.set_constant("v_separation", "GridContainer", 4)
	var sbg = StyleBoxFlat.new(); sbg.bg_color = Color("2a1f44"); sbg.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", sbg)
	var gr = StyleBoxFlat.new(); gr.bg_color = EDGE; gr.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	_theme = t
	return t

static func btn(text: String, cb: Callable, min_w := 0, h := 26) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

static func lbl(text: String, size := 12, col := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l

static func wrap(text: String, size := 11, col := DIM) -> Label:
	var l = lbl(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 60
	return l

static func vbox(sep := 4) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 4) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func panel(pad := 8) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(0.118, 0.086, 0.188, 0.96), EDGE, 2, 4, pad))
	return p

static func icon(tex: Texture2D, size := 24) -> TextureRect:
	var t = TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t

static func scroll(child: Control) -> ScrollContainer:
	var s = ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func bar(rect: Rect2, frac: float, col: Color, ci: CanvasItem, back := Color("0c0814")) -> void:
	ci.draw_rect(rect, back)
	var r = rect.grow(-1)
	r.size.x *= clampf(frac, 0.0, 1.0)
	ci.draw_rect(r, col)

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

static func focus_first(n: Node) -> void:
	for c in n.find_children("*", "Button", true, false):
		var b: Button = c
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return
