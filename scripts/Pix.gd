extends RefCounted
## Procedural pixel-art generator. Every sprite, tile and icon is drawn here in code.

static var _cache := {}
const OUT := Color("140c1c")

static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)

static func _px(im: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, c)

static func _rect(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(im, xx, yy, c)

static func _ell(im: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx = (xx + 0.5 - cx) / rx
			var dy = (yy + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(im, xx, yy, c)

static func _line(im: Image, x0: int, y0: int, x1: int, y1: int, c: Color, th := 1) -> void:
	var n = maxi(absi(x1 - x0), absi(y1 - y0))
	for i in n + 1:
		var t = float(i) / maxf(1.0, n)
		var x = int(round(lerpf(x0, x1, t)))
		var y = int(round(lerpf(y0, y1, t)))
		_rect(im, x, y, th, th, c)

static func _tri(im: Image, ax: int, ay: int, bx: int, by: int, cx: int, cy: int, c: Color) -> void:
	var minx = mini(ax, mini(bx, cx)); var maxx := maxi(ax, maxi(bx, cx))
	var miny = mini(ay, mini(by, cy)); var maxy := maxi(ay, maxi(by, cy))
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			var w0 = (bx - ax) * (y - ay) - (by - ay) * (x - ax)
			var w1 = (cx - bx) * (y - by) - (cy - by) * (x - bx)
			var w2 = (ax - cx) * (y - cy) - (ay - cy) * (x - cx)
			if (w0 >= 0 and w1 >= 0 and w2 >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0):
				_px(im, x, y, c)

static func _finish(im: Image, shade := true) -> ImageTexture:
	var w = im.get_width(); var h := im.get_height()
	if shade:
		var src = im.duplicate()
		for y in h:
			for x in w:
				var c: Color = src.get_pixel(x, y)
				if c.a < 0.5 or c == OUT:
					continue
				var up: Color = src.get_pixel(x, y - 1) if y > 0 else Color(0, 0, 0, 0)
				var dn: Color = src.get_pixel(x, y + 1) if y < h - 1 else Color(0, 0, 0, 0)
				if up.a < 0.5:
					im.set_pixel(x, y, c.lightened(0.22))
				elif dn.a < 0.5:
					im.set_pixel(x, y, c.darkened(0.25))
	var src2 = im.duplicate()
	for y in h:
		for x in w:
			if src2.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x; var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src2.get_pixel(nx, ny).a > 0.5 and src2.get_pixel(nx, ny) != OUT:
					im.set_pixel(x, y, OUT)
					break
	return ImageTexture.create_from_image(im)

# ------------------------------------------------------------------ heroes
const HERO_PAL := {
	"runeknight": {"a": "b04a3a", "b": "6a2a26", "c": "ffd36b", "h": "c8ccd8", "s": "f0c09a", "w": "e8eef8"},
	"stormcaller": {"a": "3a5ac8", "b": "1e2a6a", "c": "ffe45c", "h": "2a3a8a", "s": "e8b890", "w": "8a6a4a"},
	"thornwarden": {"a": "4a8a3a", "b": "24461e", "c": "c8a050", "h": "3a6a2a", "s": "d8a07a", "w": "8a5a2a"},
	"shadeblade": {"a": "3a3048", "b": "1a1424", "c": "b07cff", "h": "241c30", "s": "d8b090", "w": "c8ccd8"},
	"cleric": {"a": "f0ead8", "b": "a89a7a", "c": "ffd36b", "h": "e8c86a", "s": "f0c8a0", "w": "ffd36b"},
	"gearsmith": {"a": "c87a3a", "b": "6a3a1a", "c": "7fd8ff", "h": "5a3a2a", "s": "e0a880", "w": "9aa8b8"},
}

static func hero(cls: String) -> ImageTexture:
	var key = "h_" + cls
	if _cache.has(key):
		return _cache[key]
	var p: Dictionary = HERO_PAL[cls]
	var A = Color(p.a); var B := Color(p.b); var C := Color(p.c); var H := Color(p.h); var S := Color(p.s); var W := Color(p.w)
	var im = _img(20, 20)
	var robe = cls in ["stormcaller", "cleric"]
	# legs
	if robe:
		_rect(im, 6, 12, 7, 5, A); _rect(im, 6, 16, 7, 1, B); _rect(im, 9, 12, 1, 5, B)
	else:
		_rect(im, 7, 14, 2, 3, B); _rect(im, 10, 14, 2, 3, B)
		_rect(im, 7, 17, 2, 1, OUT.lightened(0.15)); _rect(im, 10, 17, 2, 1, OUT.lightened(0.15))
	# torso
	_rect(im, 6, 9, 7, 5, A)
	_rect(im, 6, 12, 7, 1, C if cls != "shadeblade" else B)
	_rect(im, 9, 9, 1, 3, B)
	# arms
	_rect(im, 5, 9, 1, 4, B); _rect(im, 13, 9, 1, 4, B)
	_px(im, 5, 13, S); _px(im, 13, 13, S)
	# head
	_rect(im, 7, 4, 5, 5, S)
	_px(im, 8, 6, OUT); _px(im, 10, 6, OUT)
	match cls:
		"runeknight":
			_rect(im, 6, 3, 7, 3, H); _rect(im, 6, 4, 1, 4, H); _rect(im, 12, 4, 1, 4, H)
			_rect(im, 7, 6, 5, 1, H.darkened(0.3)); _px(im, 8, 6, C); _px(im, 10, 6, C)
			_px(im, 9, 2, C); _px(im, 9, 1, A)
			_rect(im, 5, 9, 2, 2, H); _rect(im, 12, 9, 2, 2, H)
			_line(im, 15, 4, 15, 13, W); _rect(im, 14, 12, 3, 1, C); _px(im, 15, 14, B)
		"stormcaller":
			_tri(im, 9, -1, 5, 5, 13, 5, H); _rect(im, 5, 4, 9, 1, H.darkened(0.2)); _px(im, 9, 1, C)
			_line(im, 15, 3, 15, 17, W); _ell(im, 15.5, 2.5, 1.6, 1.6, C)
		"thornwarden":
			_rect(im, 6, 3, 7, 2, H); _rect(im, 6, 5, 1, 4, H); _rect(im, 12, 5, 1, 3, H)
			_px(im, 13, 3, Color("7be06a")); _px(im, 5, 3, Color("7be06a"))
			_line(im, 15, 3, 16, 6, W); _line(im, 16, 7, 16, 11, W); _line(im, 16, 12, 15, 15, W)
			_line(im, 15, 4, 15, 14, Color("e8e0c8"))
		"shadeblade":
			_rect(im, 6, 3, 7, 3, H); _rect(im, 6, 4, 1, 5, H); _rect(im, 12, 4, 1, 5, H)
			_rect(im, 7, 7, 5, 2, H); _px(im, 8, 6, C); _px(im, 10, 6, C)
			_line(im, 14, 10, 16, 8, W); _line(im, 3, 10, 4, 12, W)
			_rect(im, 4, 9, 2, 6, B)
		"cleric":
			_rect(im, 7, 3, 5, 2, H); _rect(im, 6, 4, 1, 4, H); _rect(im, 12, 4, 1, 4, H)
			_rect(im, 7, 1, 5, 1, C)
			_line(im, 15, 7, 15, 15, Color("a89a7a")); _ell(im, 15.5, 6.5, 1.8, 1.8, W); _px(im, 15, 6, Color("ffffff"))
		"gearsmith":
			_rect(im, 6, 3, 7, 2, H); _rect(im, 7, 5, 5, 1, Color("3a3a48")); _px(im, 8, 5, C); _px(im, 10, 5, C)
			_rect(im, 7, 9, 5, 3, Color("5a3a2a"))
			_line(im, 15, 6, 15, 15, Color("6a4a2a")); _rect(im, 13, 4, 5, 3, W); _px(im, 15, 5, C)
	var t = _finish(im)
	_cache[key] = t
	return t

# ------------------------------------------------------------------ enemies
static func enemy(id: String) -> ImageTexture:
	var key = "e_" + id
	if _cache.has(key):
		return _cache[key]
	var d: Dictionary = Data.ENEMIES[id]
	var M = Color(d.pal[0]); var D := Color(d.pal[1]); var G := Color(d.pal[2])
	var im = _img(32, 32)
	match d.shape:
		"blob":
			_ell(im, 16, 22, 11, 8, M); _ell(im, 16, 18, 8, 6, M); _rect(im, 6, 26, 20, 3, D)
			_ell(im, 11, 15, 2, 2, Color(1, 1, 1, 0.9)); _px(im, 13, 20, OUT); _px(im, 19, 20, OUT)
			_px(im, 13, 19, G); _px(im, 19, 19, G); _rect(im, 15, 23, 3, 1, D)
		"beast":
			_ell(im, 14, 20, 9, 5, M); _ell(im, 23, 15, 5, 4, M); _tri(im, 21, 12, 23, 7, 24, 12, D); _tri(im, 24, 12, 27, 8, 27, 13, D)
			for lx in [7, 11, 16, 20]:
				_rect(im, lx, 23, 2, 5, D)
			_line(im, 5, 18, 1, 13, D, 2); _px(im, 25, 14, G); _rect(im, 25, 17, 3, 1, Color("ffffff"))
			_rect(im, 9, 17, 9, 1, D)
		"imp":
			_ell(im, 16, 21, 5, 6, M); _ell(im, 16, 12, 6, 5, M)
			_tri(im, 11, 9, 9, 3, 13, 8, G); _tri(im, 21, 9, 23, 3, 19, 8, G)
			_tri(im, 11, 18, 3, 13, 9, 24, D); _tri(im, 21, 18, 29, 13, 23, 24, D)
			_px(im, 14, 12, G); _px(im, 18, 12, G); _rect(im, 14, 15, 5, 1, D)
			_rect(im, 13, 26, 2, 4, D); _rect(im, 18, 26, 2, 4, D)
		"wisp":
			_ell(im, 16, 15, 8, 8, M); _tri(im, 8, 15, 24, 15, 16, 31, M); _tri(im, 10, 10, 16, 0, 22, 10, M)
			_ell(im, 16, 16, 4, 4, G.lerp(M, 0.4)); _rect(im, 12, 14, 2, 3, OUT); _rect(im, 19, 14, 2, 3, OUT)
			_tri(im, 12, 22, 16, 30, 18, 22, D)
		"golem":
			_rect(im, 7, 9, 18, 14, M); _rect(im, 11, 3, 10, 7, M); _rect(im, 2, 10, 5, 13, D); _rect(im, 25, 10, 5, 13, D)
			_rect(im, 9, 23, 5, 7, D); _rect(im, 18, 23, 5, 7, D)
			_rect(im, 13, 5, 2, 2, G); _rect(im, 17, 5, 2, 2, G)
			_line(im, 12, 12, 16, 17, G); _line(im, 16, 17, 20, 13, G); _rect(im, 14, 14, 4, 3, G.lerp(M, 0.3))
		"eye":
			_ell(im, 16, 14, 11, 11, M); _ell(im, 16, 14, 6, 6, G); _ell(im, 16, 14, 3, 4, OUT); _px(im, 14, 12, Color.WHITE)
			for tx in [8, 13, 19, 24]:
				_line(im, tx, 22, tx + (2 if tx < 16 else -2), 30, D, 2)
			_ell(im, 12, 8, 2, 1.5, M.lightened(0.4))
		"bat":
			_ell(im, 16, 16, 5, 6, M); _tri(im, 12, 13, 0, 8, 4, 22, D); _tri(im, 20, 13, 31, 8, 27, 22, D)
			_tri(im, 12, 11, 12, 6, 15, 10, M); _tri(im, 20, 11, 20, 6, 17, 10, M)
			_px(im, 14, 15, G); _px(im, 18, 15, G); _px(im, 15, 19, Color.WHITE); _px(im, 17, 19, Color.WHITE)
		"crab":
			_ell(im, 16, 19, 11, 7, M); _ell(im, 4, 12, 4, 4, M); _ell(im, 28, 12, 4, 4, M)
			_rect(im, 3, 9, 2, 2, Color(0, 0, 0, 0)); _rect(im, 27, 9, 2, 2, Color(0, 0, 0, 0))
			for lx in [6, 10, 22, 26]:
				_line(im, lx, 24, lx + (-2 if lx < 16 else 2), 29, D, 1)
			_rect(im, 12, 11, 2, 3, D); _rect(im, 19, 11, 2, 3, D); _px(im, 12, 11, G); _px(im, 19, 11, G)
			_line(im, 9, 17, 23, 17, G)
		"knight":
			_rect(im, 10, 11, 12, 11, M); _rect(im, 11, 3, 10, 8, M); _rect(im, 12, 6, 8, 2, OUT); _px(im, 14, 6, G); _px(im, 17, 6, G)
			_tri(im, 11, 4, 7, 0, 12, 7, D); _tri(im, 21, 4, 25, 0, 20, 7, D)
			_rect(im, 3, 11, 7, 11, D); _rect(im, 5, 14, 3, 4, G)
			_line(im, 25, 2, 25, 24, Color("d8e0f0"), 2); _rect(im, 22, 20, 7, 2, G)
			_rect(im, 11, 22, 4, 8, D); _rect(im, 17, 22, 4, 8, D)
		"drake":
			_ell(im, 15, 20, 9, 6, M); _line(im, 21, 16, 25, 8, M, 3); _ell(im, 26, 7, 4, 3, M); _px(im, 27, 6, G)
			_tri(im, 8, 15, 2, 2, 18, 13, D); _tri(im, 14, 14, 16, 1, 22, 14, D)
			_line(im, 6, 22, 1, 28, M, 2); _rect(im, 9, 24, 3, 5, D); _rect(im, 18, 24, 3, 5, D)
			_line(im, 11, 22, 20, 22, G); _rect(im, 28, 8, 3, 1, G)
		"engine":
			_rect(im, 6, 8, 20, 18, M); _rect(im, 4, 26, 24, 4, D)
			_ell(im, 6, 8, 5, 5, D); _ell(im, 6, 8, 2, 2, G)
			_ell(im, 26, 10, 4, 4, D); _ell(im, 26, 10, 1.5, 1.5, G)
			_ell(im, 16, 17, 5, 5, G); _ell(im, 16, 17, 2.5, 2.5, Color.WHITE)
			_rect(im, 13, 2, 3, 6, D); _rect(im, 18, 4, 2, 4, D)
			_rect(im, 8, 11, 3, 1, OUT); _rect(im, 21, 11, 3, 1, OUT)
		"harpy":
			_ell(im, 16, 17, 4, 6, M); _ell(im, 16, 9, 4, 4, Color("e8c0a0")); _rect(im, 12, 5, 8, 2, D)
			_tri(im, 12, 14, 0, 6, 6, 24, M); _tri(im, 20, 14, 31, 6, 26, 24, M)
			_line(im, 2, 9, 6, 20, D); _line(im, 29, 9, 25, 20, D)
			_px(im, 14, 9, OUT); _px(im, 18, 9, OUT); _line(im, 14, 23, 13, 29, G); _line(im, 18, 23, 19, 29, G)
		"eel":
			var pts = [[4, 24], [8, 26], [12, 24], [15, 20], [17, 16], [20, 12], [24, 10], [27, 11]]
			for i in pts.size():
				_ell(im, pts[i][0], pts[i][1], 3.5 if i > 0 else 2.5, 3.5 if i > 0 else 2.5, M)
			_ell(im, 27, 10, 4, 3.5, M); _px(im, 28, 9, G); _rect(im, 28, 12, 3, 1, D)
			for i in range(1, pts.size(), 2):
				_px(im, pts[i][0], pts[i][1], G)
			_tri(im, 18, 13, 16, 8, 21, 11, D)
		"tree":
			_ell(im, 16, 9, 12, 8, D); _ell(im, 11, 8, 6, 5, M.lerp(G, 0.25)); _ell(im, 21, 7, 6, 5, M.lerp(G, 0.25))
			_rect(im, 11, 13, 10, 13, M); _line(im, 11, 25, 4, 30, M, 2); _line(im, 20, 25, 27, 30, M, 2); _line(im, 15, 26, 15, 30, M, 2)
			_rect(im, 13, 16, 2, 2, G); _rect(im, 18, 16, 2, 2, G); _rect(im, 14, 21, 5, 1, OUT)
			_line(im, 10, 15, 3, 11, M, 2); _line(im, 21, 15, 29, 12, M, 2)
		"king":
			_tri(im, 16, 8, 3, 30, 29, 30, D); _tri(im, 16, 10, 8, 30, 24, 30, M)
			_ell(im, 16, 8, 4.5, 4.5, Color("2a2038")); _px(im, 14, 8, G); _px(im, 18, 8, G)
			_rect(im, 11, 2, 11, 2, G); _px(im, 11, 1, G); _px(im, 16, 0, G); _px(im, 21, 1, G); _px(im, 16, 2, Color("ff3a5a"))
			_line(im, 27, 4, 27, 30, Color("8a7a9a"), 1); _ell(im, 27, 4, 2.5, 2.5, Color("c47bff"))
			_rect(im, 13, 17, 7, 1, G)
	var t = _finish(im)
	_cache[key] = t
	return t

# ------------------------------------------------------------------ tiles
static func tile(kind: String, floor_i: int, variant := 0) -> ImageTexture:
	var key = "t_%s_%d_%d" % [kind, floor_i, variant]
	if _cache.has(key):
		return _cache[key]
	var pal: Dictionary = Data.FLOORS[floor_i].pal
	var F = Color(pal.floor); var F2 := Color(pal.floor2); var Wc := Color(pal.wall); var W2 := Color(pal.wall2); var Ac := Color(pal.accent)
	var im = _img(16, 16)
	var r = RandomNumberGenerator.new()
	r.seed = hash(key)
	var shade = false
	match kind:
		"floor":
			_rect(im, 0, 0, 16, 16, F)
			for i in 6:
				_px(im, r.randi() % 16, r.randi() % 16, F2)
			if variant == 1:
				_rect(im, 0, 0, 16, 1, F2); _rect(im, 0, 0, 1, 16, F2)
			if variant == 2:
				_px(im, r.randi() % 14 + 1, r.randi() % 14 + 1, Ac.darkened(0.4)); _px(im, r.randi() % 14 + 1, r.randi() % 14 + 1, Ac.darkened(0.5))
		"wall":
			_rect(im, 0, 0, 16, 16, W2)
			for row in 4:
				var off = 0 if row % 2 == 0 else 4
				for bx in range(-off, 16, 8):
					_rect(im, bx + 1, row * 4 + 1, 7, 3, Wc.darkened(r.randf() * 0.2))
			_rect(im, 0, 0, 16, 1, Wc.lightened(0.25))
		"walltop":
			_rect(im, 0, 0, 16, 16, Color("0b0812"))
			for i in 3:
				_px(im, r.randi() % 16, r.randi() % 16, W2.darkened(0.3))
		"chest", "chest_open":
			_rect(im, 2, 6, 12, 8, Color("8a5a2a")); _rect(im, 2, 6, 12, 2, Color("b07a3a"))
			_rect(im, 2, 9, 12, 1, Color("ffd36b")); _rect(im, 7, 8, 2, 3, Color("ffd36b"))
			if kind == "chest_open":
				_rect(im, 3, 3, 10, 3, Color("6a3a1a")); _rect(im, 4, 6, 8, 2, Color("1a0e08"))
			shade = true
		"stairs":
			_rect(im, 0, 0, 16, 16, F)
			for i in 4:
				_rect(im, 2 + i, 3 + i * 3, 12 - i * 2, 3, Wc.darkened(i * 0.18))
			_rect(im, 6, 12, 4, 2, OUT)
		"portal":
			_rect(im, 0, 0, 16, 16, F)
			_ell(im, 8, 8, 6, 6, Color("6d4fd6")); _ell(im, 8, 8, 4, 4, Color("b07cff")); _ell(im, 8, 8, 2, 2, Color("ffffff"))
		"trap":
			_rect(im, 0, 0, 16, 16, F)
			for i in 3:
				for j in 3:
					_tri(im, 2 + i * 5, 6 + j * 4, 4 + i * 5, 3 + j * 4, 5 + i * 5, 6 + j * 4, Color("c8ccd8"))
		"trap_hint":
			_rect(im, 0, 0, 16, 16, F)
			_rect(im, 4, 4, 8, 8, Color(1, 0.3, 0.3, 0.35)); _px(im, 8, 6, Color("ff6a6a")); _rect(im, 8, 7, 1, 3, Color("ff6a6a"))
		"fountain", "fountain_dry":
			_rect(im, 0, 0, 16, 16, F)
			_ell(im, 8, 10, 7, 4, Wc); _ell(im, 8, 10, 5, 2.5, Color("4ab0ff") if kind == "fountain" else W2)
			_rect(im, 7, 2, 2, 8, Wc.lightened(0.2))
			if kind == "fountain":
				_px(im, 8, 1, Color("bfe6ff")); _px(im, 6, 3, Color("bfe6ff")); _px(im, 10, 3, Color("bfe6ff"))
	var t = _finish(im, shade) if shade else ImageTexture.create_from_image(im)
	_cache[key] = t
	return t

# ------------------------------------------------------------------ icons
static func weapon_icon(type: String, rarity: int, tier := 0) -> ImageTexture:
	var key = "w_%s_%d_%d" % [type, rarity, tier]
	if _cache.has(key):
		return _cache[key]
	var metal: Color = [Color("c08a50"), Color("b8c0cc"), Color("8ab0ff"), Color("fff0b0"), Color("c47bff")][clampi(tier, 0, 4)]
	var glow: Color = Data.RARITY_COLOR[rarity]
	var wood = Color("7a4a2a")
	var im = _img(16, 16)
	match type:
		"sword":
			_line(im, 4, 11, 12, 3, metal, 2); _line(im, 3, 9, 6, 12, glow, 1); _line(im, 2, 13, 4, 11, wood, 2)
		"staff":
			_line(im, 3, 14, 11, 6, wood, 1); _ell(im, 12, 4, 2.5, 2.5, glow); _px(im, 12, 4, Color.WHITE)
		"bow":
			_line(im, 4, 2, 9, 4, wood); _line(im, 9, 4, 12, 9, wood); _line(im, 12, 9, 13, 14, wood); _line(im, 4, 2, 13, 14, Color("e8e0c8"))
			_px(im, 8, 8, glow)
		"dagger":
			_line(im, 6, 10, 11, 5, metal, 2); _rect(im, 4, 9, 4, 1, glow); _line(im, 3, 13, 5, 11, wood, 1)
		"mace":
			_line(im, 3, 13, 9, 7, wood, 1); _ell(im, 10.5, 5.5, 3, 3, metal); _px(im, 10, 1, glow); _px(im, 14, 5, glow); _px(im, 10, 9, glow); _px(im, 6, 5, glow)
		"hammer":
			_line(im, 3, 13, 9, 7, wood, 1); _rect(im, 8, 2, 6, 5, metal); _rect(im, 10, 4, 2, 1, glow)
	var t = _finish(im, false)
	_cache[key] = t
	return t

static func gem(col: Color, kind := "rune") -> ImageTexture:
	var key = "g_%s_%s" % [col.to_html(), kind]
	if _cache.has(key):
		return _cache[key]
	var im = _img(12, 12)
	match kind:
		"rune":
			_tri(im, 6, 1, 1, 6, 11, 6, col); _tri(im, 1, 6, 11, 6, 6, 11, col.darkened(0.25)); _px(im, 6, 4, Color.WHITE); _px(im, 5, 6, Color.WHITE); _px(im, 7, 7, Color.WHITE)
		"ore":
			_ell(im, 6, 7, 5, 4, col.darkened(0.3)); _ell(im, 5, 6, 2.5, 2, col); _px(im, 4, 5, Color.WHITE)
		"potion":
			_rect(im, 5, 1, 2, 3, Color("d8d2c4")); _ell(im, 6, 7.5, 4, 3.8, col); _px(im, 4, 6, Color.WHITE)
	var t = _finish(im, false)
	_cache[key] = t
	return t

static func item_icon(id: String) -> ImageTexture:
	var cols = {"tonic": Color("ff5a6a"), "hi_tonic": Color("ff3a9a"), "ether": Color("5a9aff"), "ember_feather": Color("ff9a3a"), "clearwater": Color("7fffd8"), "smoke_bomb": Color("9a9aaa")}
	return gem(cols.get(id, Color.WHITE), "potion")
