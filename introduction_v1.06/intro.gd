extends Node2D

const VIEW_W := 960.0
const VIEW_H := 540.0

var font: Font
var credit_font: Font
var track_title := ""
var track_artist := ""
var plates: Dictionary = {}
var portraits: Dictionary = {}
var phase := "lang"
var index := 0
var t := 0.0
var beats: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = load("res://assets/PressStart2P-Regular.ttf")
	credit_font = load("res://assets/DroidSansFallbackFull.ttf")
	randomize()
	plates["ride"] = load("res://introduction_v1.06/art/kael_ride.png")
	plates["roof"] = load("res://introduction_v1.06/art/nia_roof.png")
	plates["chase"] = load("res://introduction_v1.06/art/chase.png")
	portraits["kael"] = load("res://introduction_v1.06/art/kael.png")
	portraits["nia"] = load("res://introduction_v1.06/art/nia.png")
	portraits["kael_bust"] = load("res://introduction_v1.06/art/kael_bust.png")
	portraits["nia_bust"] = load("res://introduction_v1.06/art/nia_bust.png")
	beats = [
		{"t": 0.0, "plate": "", "who": "kael", "name": "v3.kael", "keys": ["v3.kael1", "v3.kael2"]},
		{"t": 7.0, "plate": "ride", "who": "kael", "name": "v3.kael", "keys": ["v3.kael1", "v3.kael2"]},
		{"t": 15.0, "plate": "", "who": "nia", "name": "v3.nia", "keys": ["v3.nia1", "v3.nia2"]},
		{"t": 22.0, "plate": "roof", "who": "nia", "name": "v3.nia", "keys": ["v3.nia1", "v3.nia2"]},
		{"t": 30.0, "plate": "chase", "who": "both", "name": "", "keys": ["v3.chase1", "v3.chase2"]},
		{"t": 40.0, "plate": "chase", "who": "title", "name": "", "keys": []},
	]
	if Locale.chosen:
		phase = "film"
	_play_random_track("res://introduction_v1.06/audio/jpop")


func _process(delta: float) -> void:
	if phase == "film" and t < 52.0:
		t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	if phase == "lang":
		if key.keycode == KEY_UP or key.keycode == KEY_W:
			index = 0
		elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
			index = 1
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			Locale.set_lang("en" if index == 0 else "es")
			phase = "film"
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if _who() == "title":
			get_tree().change_scene_to_file("res://level1_v1.06/circuit.tscn")
		else:
			t = 40.0
	elif key.keycode == KEY_SPACE:
		_skip()


func _skip() -> void:
	var idx := _index()
	if idx + 1 < beats.size():
		t = float(beats[idx + 1]["t"])
	else:
		t = 52.0


func _index() -> int:
	var idx := 0
	for i in beats.size():
		if t >= float(beats[i]["t"]):
			idx = i
	return idx


func _who() -> String:
	if beats.is_empty():
		return ""
	return str(beats[_index()]["who"])


func _draw() -> void:
	if phase == "lang":
		_draw_lang()
		_draw_track()
		return
	var idx := _index()
	var beat: Dictionary = beats[idx]
	var plate := str(beat["plate"])
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.015, 0.02, 0.05))
	if plate != "" and plates.get(plate) != null:
		var drift := sin(t * 0.35) * 12.0
		draw_texture_rect(plates[plate], Rect2(-16 + drift, -8, VIEW_W + 32, VIEW_H + 16), false)
	elif str(beat["who"]) == "kael" and portraits.get("kael") != null:
		draw_texture_rect(portraits["kael"], Rect2(300, 40, 360, 360), false)
	elif str(beat["who"]) == "nia" and portraits.get("nia") != null:
		draw_texture_rect(portraits["nia"], Rect2(300, 30, 360, 360), false)
	if _who() == "title":
		_draw_title()
	else:
		_draw_caption(beat)
	draw_rect(Rect2(0, 0, VIEW_W, 22), Color(0, 0, 0))
	if t < 5.0:
		_text(Locale.text("v3.skip"), Vector2(16, 18), 10, Color(0.75, 0.82, 0.88))
	_draw_track()


func _draw_lang() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.02, 0.03, 0.07))
	if portraits.get("kael") != null:
		draw_texture_rect(portraits["kael"], Rect2(28, 120, 240, 240), false)
	if portraits.get("nia") != null:
		draw_texture_rect(portraits["nia"], Rect2(692, 120, 240, 240), false)
	_center("CYBERNOVA", 150, 28, Color(0.86, 0.97, 1))
	_center(Locale.text("boot.prompt"), 214, 14, Color(0.55, 0.86, 0.95))
	_option(0, "ENGLISH")
	_option(1, "ESPAÑOL")


func _option(which: int, label: String) -> void:
	var rect := Rect2(250, 280 + float(which) * 56, 460, 46)
	var on := which == index
	draw_rect(rect, Color(0.02, 0.08, 0.12, 0.92 if on else 0.55))
	if on:
		draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), Color(0.45, 0.95, 1))
	var color := Color(0.55, 0.95, 1) if on else Color(0.78, 0.82, 0.86)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(label, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + 30), 16, color)


func _draw_caption(beat: Dictionary) -> void:
	draw_rect(Rect2(0, 430, VIEW_W, 110), Color(0, 0, 0, 0.88))
	var who := str(beat["who"])
	if who == "kael" or who == "nia":
		var bust: Texture2D = portraits["kael_bust"] if who == "kael" else portraits["nia_bust"]
		if bust:
			draw_texture_rect(bust, Rect2(VIEW_W - 118, 348, 96, 96), false)
	var name := str(beat["name"])
	if name != "":
		_center(Locale.text(name), 462, 12, Color(0.45, 0.95, 1))
	var keys: Array = beat["keys"]
	var local := t - float(beat["t"])
	for i in keys.size():
		_center(_typed(Locale.text(str(keys[i])), local, 0.2 + float(i) * 0.9), 492 + float(i) * 22, 12, Color(0.95, 0.95, 0.92))


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0, 0.01, 0.04, 0.45))
	if portraits.get("kael") != null:
		draw_texture_rect(portraits["kael"], Rect2(48, 150, 200, 200), false)
	if portraits.get("nia") != null:
		draw_texture_rect(portraits["nia"], Rect2(712, 150, 200, 200), false)
	_center("CYBERNOVA", 230, 28, Color(0.86, 0.97, 1))
	_center(Locale.text("v3.chase2"), 280, 12, Color(0.55, 0.86, 0.95))
	_center(Locale.text("v3.play"), 360, 12, Color(0.95, 0.95, 0.92))


func _typed(line: String, local_t: float, delay: float) -> String:
	var count := int((local_t - delay) * 48.0)
	if count <= 0:
		return ""
	if count >= line.length():
		return line
	return line.substr(0, count)


func _text(line: String, pos: Vector2, size: int, color: Color) -> void:
	if font == null or line == "":
		return
	draw_string(font, pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, color.a))
	draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _center(line: String, y: float, size: int, color: Color) -> void:
	if font == null or line == "":
		return
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(line, Vector2((VIEW_W - width) * 0.5, y), size, color)


func _play_random_track(folder: String) -> void:
	var catalog_text := FileAccess.get_file_as_string(folder + "/catalog.json")
	var parsed: Variant = JSON.parse_string(catalog_text)
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).is_empty():
		return
	var songs: Array = parsed
	var pick: Dictionary = songs[randi() % songs.size()]
	track_title = str(pick.get("title", ""))
	track_artist = str(pick.get("artist", ""))
	var loaded := load("%s/%s" % [folder, str(pick.get("file", ""))])
	if loaded == null or not (loaded is AudioStream):
		return
	var stream := loaded.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var music := AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = -4.0
	add_child(music)
	music.play()


func _draw_track() -> void:
	if track_title == "" or credit_font == null:
		return
	var line := "%s  —  %s" % [track_artist, track_title]
	var size := 16
	var width := credit_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2((VIEW_W - width) * 0.5, 34)
	draw_rect(Rect2(pos.x - 14, 10, width + 28, 30), Color(0, 0, 0, 0.78))
	draw_string(credit_font, pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	draw_string(credit_font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.94, 0.78))
