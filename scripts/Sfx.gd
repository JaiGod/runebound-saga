extends Node
## Procedural audio: every sound effect and music loop is synthesised at runtime.

const RATE := 22050
const MRATE := 11025
var _cache := {}
var _music_cache := {}
var _players: Array = []
var _music: AudioStreamPlayer
var _music_id := ""
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -11.0
	add_child(_music)

func play(id: String, pitch := 1.0) -> void:
	if not Game.settings.sound:
		return
	if not _cache.has(id):
		var s = _make(id)
		if s == null:
			return
		_cache[id] = s
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[id]
	p.pitch_scale = pitch
	p.play()

func music(id: String) -> void:
	if id == _music_id and _music.playing:
		return
	_music_id = id
	if not Game.settings.music or id == "":
		_music.stop()
		return
	if not _music_cache.has(id):
		_music_cache[id] = _make_music(id)
	_music.stream = _music_cache[id]
	_music.play()

func refresh_music() -> void:
	var id = _music_id
	_music_id = ""
	if Game.settings.music:
		music(id)
	else:
		_music.stop()
		_music_id = id

# ------------------------------------------------------------------ synthesis
func _osc(wave: int, ph: float) -> float:
	match wave:
		0: return sin(ph * TAU)
		1: return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		2: return 2.0 * absf(2.0 * fmod(ph, 1.0) - 1.0) - 1.0
		3: return 2.0 * fmod(ph, 1.0) - 1.0
	return randf() * 2.0 - 1.0

func _tone(buf: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, wave: int, vol: float, attack := 0.004) -> void:
	var i0 = int(start * rate)
	var n = int(dur * rate)
	var ph = 0.0
	for i in n:
		var idx = i0 + i
		if idx >= buf.size():
			break
		var t = float(i) / n
		var f = lerpf(f0, f1, t)
		ph += f / rate
		var env = minf(1.0, float(i) / (attack * rate + 1.0)) * pow(1.0 - t, 1.6)
		buf[idx] += _osc(wave, ph) * vol * env

func _to_wav(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

func _buf(sec: float, rate := RATE) -> PackedFloat32Array:
	var b = PackedFloat32Array()
	b.resize(int(sec * rate))
	return b

func _make(id: String) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match id:
		"click":
			b = _buf(0.06); _tone(b, RATE, 0, 0.05, 880, 990, 1, 0.18)
		"move":
			b = _buf(0.05); _tone(b, RATE, 0, 0.04, 620, 660, 2, 0.2)
		"step":
			b = _buf(0.05); _tone(b, RATE, 0, 0.04, 140, 90, 4, 0.10)
		"hit":
			b = _buf(0.16); _tone(b, RATE, 0, 0.12, 220, 70, 4, 0.45); _tone(b, RATE, 0, 0.1, 160, 60, 3, 0.25)
		"crit":
			b = _buf(0.26); _tone(b, RATE, 0, 0.18, 320, 60, 4, 0.5); _tone(b, RATE, 0.02, 0.22, 900, 300, 3, 0.25)
		"ehit":
			b = _buf(0.18); _tone(b, RATE, 0, 0.15, 130, 50, 4, 0.5); _tone(b, RATE, 0, 0.14, 100, 45, 1, 0.2)
		"magic":
			b = _buf(0.35)
			for i in 4:
				_tone(b, RATE, i * 0.05, 0.2, 500 + i * 180, 800 + i * 200, 2, 0.18)
		"storm":
			b = _buf(0.4); _tone(b, RATE, 0, 0.35, 2000, 200, 4, 0.35); _tone(b, RATE, 0, 0.3, 90, 40, 1, 0.2)
		"heal":
			b = _buf(0.5)
			for i in 5:
				_tone(b, RATE, i * 0.07, 0.25, [523, 659, 784, 1046, 1318][i], [523, 659, 784, 1046, 1318][i], 0, 0.2)
		"buff":
			b = _buf(0.35); _tone(b, RATE, 0, 0.3, 300, 900, 2, 0.25)
		"debuff":
			b = _buf(0.35); _tone(b, RATE, 0, 0.3, 500, 150, 3, 0.18)
		"miss":
			b = _buf(0.15); _tone(b, RATE, 0, 0.12, 700, 1200, 0, 0.15)
		"break":
			b = _buf(0.6); _tone(b, RATE, 0, 0.5, 900, 80, 4, 0.5); _tone(b, RATE, 0, 0.4, 440, 110, 1, 0.25); _tone(b, RATE, 0.1, 0.4, 1760, 1760, 0, 0.12)
		"burst":
			b = _buf(0.9); _tone(b, RATE, 0, 0.8, 80, 30, 4, 0.5)
			for i in 6:
				_tone(b, RATE, i * 0.06, 0.4, 300 + i * 150, 1200, 3, 0.12)
		"chest":
			b = _buf(0.5)
			for i in 4:
				_tone(b, RATE, i * 0.08, 0.2, [784, 988, 1175, 1568][i], [784, 988, 1175, 1568][i], 1, 0.13)
		"coin":
			b = _buf(0.18); _tone(b, RATE, 0, 0.06, 988, 988, 1, 0.14); _tone(b, RATE, 0.06, 0.12, 1318, 1318, 1, 0.14)
		"forge":
			b = _buf(0.5); _tone(b, RATE, 0, 0.1, 1800, 1400, 2, 0.35); _tone(b, RATE, 0, 0.3, 200, 60, 4, 0.35); _tone(b, RATE, 0.12, 0.35, 2400, 2300, 0, 0.12)
		"trap":
			b = _buf(0.35); _tone(b, RATE, 0, 0.3, 300, 80, 3, 0.35); _tone(b, RATE, 0, 0.2, 2000, 400, 4, 0.2)
		"deny":
			b = _buf(0.2); _tone(b, RATE, 0, 0.08, 220, 200, 1, 0.16); _tone(b, RATE, 0.09, 0.1, 180, 160, 1, 0.16)
		"levelup":
			b = _buf(0.9)
			for i in 6:
				_tone(b, RATE, i * 0.09, 0.3, [523, 659, 784, 659, 784, 1046][i], [523, 659, 784, 659, 784, 1046][i], 1, 0.12)
		"victory":
			b = _buf(1.4)
			var mel = [523, 523, 523, 659, 587, 659, 784]
			var tm = [0, 0.12, 0.24, 0.36, 0.6, 0.72, 0.84]
			for i in mel.size():
				_tone(b, RATE, tm[i], 0.5 if i == 6 else 0.14, mel[i], mel[i], 1, 0.13)
				_tone(b, RATE, tm[i], 0.5 if i == 6 else 0.14, mel[i] / 2.0, mel[i] / 2.0, 2, 0.12)
		"defeat":
			b = _buf(1.4)
			var mel = [392, 370, 349, 262]
			for i in mel.size():
				_tone(b, RATE, i * 0.3, 0.5, mel[i], mel[i] * 0.98, 2, 0.2)
		"encounter":
			b = _buf(0.5)
			for i in 6:
				_tone(b, RATE, i * 0.05, 0.12, 300 + i * 120, 330 + i * 120, 3, 0.12)
		"stairs":
			b = _buf(0.6)
			for i in 5:
				_tone(b, RATE, i * 0.08, 0.2, 800 - i * 100, 780 - i * 100, 2, 0.18)
		_:
			return null
	return _to_wav(b, RATE)

func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)

func _make_music(id: String) -> AudioStreamWAV:
	# chord roots per bar, scale arps; 4 bars of 4 beats
	var bpm = 96.0
	var prog = [57, 53, 48, 55]          # Am F C G
	var minor = true
	var lead_wave = 2
	var drums = false
	match id:
		"title": bpm = 80.0; prog = [57, 53, 55, 52]
		"town": bpm = 100.0; prog = [48, 57, 53, 55]; minor = false; lead_wave = 1
		"dungeon": bpm = 84.0; prog = [50, 46, 48, 45]; lead_wave = 2
		"battle": bpm = 138.0; prog = [52, 48, 50, 47]; lead_wave = 1; drums = true
		"boss": bpm = 150.0; prog = [45, 46, 45, 44]; lead_wave = 3; drums = true
	var beat = 60.0 / bpm
	var total = beat * 16.0
	var b = _buf(total, MRATE)
	for bar in 4:
		var root: int = prog[bar]
		var third = 3 if minor and bar % 2 == 0 else 4
		if not minor: third = 4 if bar != 1 else 3
		var chord = [root, root + third, root + 7, root + 12]
		var t0 = bar * 4 * beat
		# bass
		for q in 4:
			_tone(b, MRATE, t0 + q * beat, beat * 0.9, _midi(root - 12), _midi(root - 12), 2, 0.22)
		# arpeggio
		for e in 8:
			var n: int = chord[[0, 1, 2, 3, 2, 1, 2, 3][e]] + 12
			_tone(b, MRATE, t0 + e * beat * 0.5, beat * 0.45, _midi(n), _midi(n), lead_wave, 0.07)
		# pad
		_tone(b, MRATE, t0, beat * 4.0, _midi(chord[1]), _midi(chord[1]), 0, 0.05, 0.4)
		if drums:
			for q in 8:
				if q % 2 == 0:
					_tone(b, MRATE, t0 + q * beat * 0.5, 0.12, 120, 40, 0, 0.35)
				else:
					_tone(b, MRATE, t0 + q * beat * 0.5, 0.05, 3000, 3000, 4, 0.06)
	return _to_wav(b, MRATE, true)
