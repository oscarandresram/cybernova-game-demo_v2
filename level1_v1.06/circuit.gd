extends Node2D
# City meshes: Quaternius buildings and streetlights (CC0).

const HALF_W := 9.0
const LAPS := 3

var font: Font
var credit_font: Font
var track_title := ""
var track_artist := ""
var samples: Array[Dictionary] = []
var total_len := 1.0
var world: Node3D
var camera: Camera3D
var player: RigidBody3D
var rivals: Array[RigidBody3D] = []
var state := "lang"
var lang_index := 0
var count_left := 3.0
var race_time := 0.0
var finish_time := 0.0
var player_lap := 1
var seen_half := false
var cam_pos := Vector3.ZERO
var cam_ready := false
var map_min := Vector2.ZERO
var map_max := Vector2.ONE
var lap_of: Dictionary = {}
var seen_of: Dictionary = {}
var score_of: Dictionary = {}


func _ready() -> void:
	font = load("res://assets/PressStart2P-Regular.ttf")
	credit_font = load("res://assets/DroidSansFallbackFull.ttf")
	randomize()
	_build_track()
	_build_world()
	_spawn_cars()
	_play_random_track("res://level1_v1.06/audio/jrock")
	if Locale.chosen:
		state = "count"
	for arg in OS.get_cmdline_user_args():
		if arg == "--cruise":
			Locale.set_lang("en")
			state = "count"
			player.set("cruise", true)
		elif arg == "--reverse":
			Locale.set_lang("en")
			state = "count"
			player.set("cruise", true)
			player.set("force_reverse", true)


func _process(delta: float) -> void:
	if state == "count":
		count_left -= delta
		if count_left <= 0.0:
			state = "race"
			player.freeze = false
			player.set("active", true)
			for rival in rivals:
				rival.freeze = false
				rival.set("active", true)
	elif state == "race":
		race_time += delta
		_guide_ai()
		if bool(player.get("cruise")):
			var dist := _closest(player.global_position)
			var ahead := _frame_at(dist + 28.0)
			player.set("ai_point", ahead.pos)
		_watch_laps()
		if not player.upright() or player.global_position.y < -4.0:
			_reset_car(player, 2.0, 0.0)
		if player_lap > LAPS:
			finish_time = race_time
			state = "done"
			player.set("active", false)
			player.set("cruise", false)
	_update_camera(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif key.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif state == "lang":
		if key.keycode == KEY_UP or key.keycode == KEY_W:
			lang_index = 0
		elif key.keycode == KEY_DOWN or key.keycode == KEY_S:
			lang_index = 1
		elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
			Locale.set_lang("en" if lang_index == 0 else "es")
			state = "count"


func _build_track() -> void:
	var ctrl: Array[Vector3] = [
		Vector3(0, 0, 70),
		Vector3(0, 0, 15),
		Vector3(0, 0, -40),
		Vector3(25, 0, -95),
		Vector3(85, 0, -120),
		Vector3(145, 0, -95),
		Vector3(175, 0, -35),
		Vector3(165, 0, 25),
		Vector3(115, 0, 70),
		Vector3(55, 0, 95),
		Vector3(15, 0, 85),
	]
	var n := ctrl.size()
	var pts: Array[Vector3] = []
	for i in n:
		var p0: Vector3 = ctrl[(i - 1 + n) % n]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[(i + 1) % n]
		var p3: Vector3 = ctrl[(i + 2) % n]
		for s in 16:
			pts.append(_catmull(p0, p1, p2, p3, float(s) / 16.0))
	var acc := 0.0
	var min_x := 10000.0
	var max_x := -10000.0
	var min_z := 10000.0
	var max_z := -10000.0
	for i in pts.size():
		var p: Vector3 = pts[i]
		var nxt: Vector3 = pts[(i + 1) % pts.size()]
		var prev: Vector3 = pts[(i - 1 + pts.size()) % pts.size()]
		var tangent := nxt - prev
		if tangent.length() < 0.001:
			tangent = Vector3(0, 0, -1)
		tangent = tangent.normalized()
		var right := tangent.cross(Vector3.UP).normalized()
		samples.append({"pos": p, "tan": tangent, "right": right, "dist": acc})
		acc += p.distance_to(nxt)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	total_len = maxf(acc, 1.0)
	map_min = Vector2(min_x, min_z)
	map_max = Vector2(max_x, max_z)


func _build_world() -> void:
	world = Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.74, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.7, 0.8)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky := WorldEnvironment.new()
	sky.environment = env
	world.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 55.0
	world.add_child(camera)
	_build_road()
	_build_city()


func _build_road() -> void:
	var asphalt := _asphalt_tex()
	var road := SurfaceTool.new()
	var walk_l := SurfaceTool.new()
	var walk_r := SurfaceTool.new()
	var dashes := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	walk_l.begin(Mesh.PRIMITIVE_TRIANGLES)
	walk_r.begin(Mesh.PRIMITIVE_TRIANGLES)
	dashes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var count := samples.size()
	for i in count:
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[(i + 1) % count]
		var pa: Vector3 = a["pos"]
		var pb: Vector3 = b["pos"]
		var ra: Vector3 = a["right"]
		var rb: Vector3 = b["right"]
		var l0 := pa - ra * HALF_W
		var r0 := pa + ra * HALF_W
		var l1 := pb - rb * HALF_W
		var r1 := pb + rb * HALF_W
		var v := float(a["dist"]) / 14.0
		var v2 := float(b["dist"]) / 14.0
		_quad(road, l0, r0, r1, l1, Vector2(0, v), Vector2(1, v), Vector2(1, v2), Vector2(0, v2))
		faces.append(l0)
		faces.append(r0)
		faces.append(r1)
		faces.append(l0)
		faces.append(r1)
		faces.append(l1)
		var sl0 := l0 - ra * 3.2 + Vector3.UP * 0.12
		var sl1 := l1 - rb * 3.2 + Vector3.UP * 0.12
		var sr0 := r0 + ra * 3.2 + Vector3.UP * 0.12
		var sr1 := r1 + rb * 3.2 + Vector3.UP * 0.12
		_quad(walk_l, l0 + Vector3.UP * 0.12, sl0, sl1, l1 + Vector3.UP * 0.12, Vector2(0, v), Vector2(1, v), Vector2(1, v2), Vector2(0, v2))
		_quad(walk_r, r0 + Vector3.UP * 0.12, r1 + Vector3.UP * 0.12, sr1, sr0, Vector2(0, v), Vector2(0, v2), Vector2(1, v2), Vector2(1, v))
		if i % 2 == 0:
			var ta: Vector3 = a["tan"]
			var c0: Vector3 = pa + Vector3.UP * 0.04
			var c1: Vector3 = pa + ta * 2.4 + Vector3.UP * 0.04
			_quad(dashes, c0 - ra * 0.11, c0 + ra * 0.11, c1 + ra * 0.11, c1 - ra * 0.11, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	var road_mi := MeshInstance3D.new()
	road_mi.mesh = road.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = asphalt
	mat.roughness = 0.92
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_mi.material_override = mat
	world.add_child(road_mi)
	var dash_mi := MeshInstance3D.new()
	dash_mi.mesh = dashes.commit()
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.93, 0.86, 0.28)
	dash_mat.roughness = 0.7
	dash_mi.material_override = dash_mat
	world.add_child(dash_mi)
	var walk_mat := StandardMaterial3D.new()
	walk_mat.albedo_color = Color(0.38, 0.38, 0.39)
	walk_mat.roughness = 0.86
	var left := MeshInstance3D.new()
	left.mesh = walk_l.commit()
	left.material_override = walk_mat
	world.add_child(left)
	var right := MeshInstance3D.new()
	right.mesh = walk_r.commit()
	right.material_override = walk_mat
	world.add_child(right)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(520, 2.0, 520)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(80, -1.02, -20)
	ground.add_child(ground_shape)
	world.add_child(ground)
	var ground_mesh := MeshInstance3D.new()
	var ground_box_mesh := BoxMesh.new()
	ground_box_mesh.size = Vector3(520, 0.2, 520)
	ground_mesh.mesh = ground_box_mesh
	ground_mesh.position = Vector3(80, -0.2, -20)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.18, 0.2, 0.18)
	dirt.roughness = 1.0
	ground_mesh.material_override = dirt
	world.add_child(ground_mesh)
	_build_walls()


func _build_walls() -> void:
	var wall_body := StaticBody3D.new()
	wall_body.collision_layer = 2
	wall_body.collision_mask = 0
	world.add_child(wall_body)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.64, 0.66)
	concrete.roughness = 0.8
	for i in range(0, samples.size(), 2):
		var fr: Dictionary = samples[i]
		var pos: Vector3 = fr["pos"]
		var right: Vector3 = fr["right"]
		var tan: Vector3 = fr["tan"]
		for side_i in 2:
			var side: float = -1.0 if side_i == 0 else 1.0
			var box := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.45, 0.85, 3.2)
			box.mesh = mesh
			box.material_override = concrete
			box.position = pos + right * side * (HALF_W + 0.3) + Vector3.UP * 0.42
			wall_body.add_child(box)
			box.look_at(box.position + tan, Vector3.UP)
			var shape_node := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = mesh.size
			shape_node.shape = shape
			shape_node.transform = box.transform
			wall_body.add_child(shape_node)


func _build_city() -> void:
	var glass := _window_tex(Color(0.22, 0.28, 0.34), Color(0.55, 0.72, 0.82), Color(0.18, 0.2, 0.24))
	var brick := _window_tex(Color(0.46, 0.28, 0.22), Color(0.18, 0.16, 0.14), Color(0.38, 0.22, 0.18))
	var pale := _window_tex(Color(0.72, 0.74, 0.76), Color(0.35, 0.48, 0.58), Color(0.9, 0.82, 0.55))
	var cream := _window_tex(Color(0.78, 0.74, 0.66), Color(0.28, 0.32, 0.3), Color(0.92, 0.78, 0.4))
	var mats: Array[StandardMaterial3D] = [_tex_mat(glass, 0.18), _tex_mat(brick, 0.86), _tex_mat(pale, 0.72), _tex_mat(cream, 0.8)]
	var models: Array[PackedScene] = []
	for path in [
		"res://level1_v1.06/models/Building1_Large.glb",
		"res://level1_v1.06/models/Building2_Large.glb",
		"res://level1_v1.06/models/Building3_Big.glb",
		"res://level1_v1.06/models/Building4.glb",
		"res://level1_v1.06/models/Building1_Small.glb",
	]:
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			models.append(packed)
	var lamp_scene: PackedScene = load("res://level1_v1.06/models/Streetlight_Single.glb") as PackedScene
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(0, samples.size(), 3):
		var fr: Dictionary = samples[i]
		var pos: Vector3 = fr["pos"]
		var right: Vector3 = fr["right"]
		var tan: Vector3 = fr["tan"]
		for side_i in 2:
			var side: float = -1.0 if side_i == 0 else 1.0
			var kind: int = rng.randi_range(0, 3)
			var offset: float = HALF_W + 12.5 + rng.randf() * 9.0
			var root: Vector3 = pos + right * side * offset
			if models.size() > 0 and rng.randf() < 0.72:
				var scene: PackedScene = models[rng.randi() % models.size()]
				var node: Node3D = scene.instantiate() as Node3D
				var sc: float = rng.randf_range(1.7, 2.8)
				node.scale = Vector3(sc, sc * rng.randf_range(1.05, 1.45), sc)
				world.add_child(node)
				node.global_position = Vector3(root.x, 0.0, root.z)
				node.look_at(node.global_position + tan, Vector3.UP)
			else:
				var extra: float = 26.0 if kind == 0 else 14.0
				var wide: float = 7.0 + rng.randf() * 9.0
				var deep: float = 7.0 + rng.randf() * 11.0
				var tall: float = 10.0 + rng.randf() * extra
				_box_building(root, Vector3(wide, tall, deep), mats[kind])
				if kind == 0 and tall > 18.0:
					_box_building(root + Vector3(0.0, tall * 0.12, 0.0), Vector3(wide * 0.62, tall * 0.7, deep * 0.62), mats[0])
				if rng.randf() < 0.5:
					_box_building(root + Vector3(wide * 0.12, tall + 0.8, deep * 0.1), Vector3(1.6, 1.4, 2.2), _plain(Color(0.28, 0.3, 0.32)))
			if rng.randf() < 0.28:
				var tower_root: Vector3 = pos + right * side * (HALF_W + 22.0 + rng.randf() * 10.0)
				var th: float = 22.0 + rng.randf() * 34.0
				_box_building(tower_root, Vector3(6.0 + rng.randf() * 5.0, th, 6.0 + rng.randf() * 5.0), mats[0])
		if i % 7 == 0:
			var lamp_pos: Vector3 = pos + right * (HALF_W + 1.9)
			if lamp_scene != null:
				var lamp: Node3D = lamp_scene.instantiate() as Node3D
				lamp.scale = Vector3(2.8, 2.8, 2.8)
				world.add_child(lamp)
				lamp.global_position = lamp_pos
			else:
				_street_lamp(lamp_pos)


func _spawn_cars() -> void:
	var script := load("res://level1_v1.06/car.gd")
	player = script.new() as RigidBody3D
	player.name = "Player"
	player.set("paint_color", Color(0.74, 0.76, 0.78))
	world.add_child(player)
	_reset_car(player, 0.0, 0.0)
	player.freeze = true
	_note(player)
	_add_rival(script, "Nia", Color(0.90, 0.91, 0.93), -14.0, 3.2, 0.78)
	_add_rival(script, "Rex", Color(0.10, 0.11, 0.13), -14.0, -3.2, 0.72)
	_add_rival(script, "Sable", Color(0.72, 0.14, 0.16), -24.0, 3.2, 0.86)
	_add_rival(script, "Ivo", Color(0.16, 0.32, 0.72), -24.0, -3.2, 0.68)


func _add_rival(script: Script, car_name: String, color: Color, along: float, lateral: float, pace: float) -> void:
	var car := script.new() as RigidBody3D
	car.name = car_name
	car.set("ai", true)
	car.set("paint_color", color)
	car.set("ai_pace", pace)
	world.add_child(car)
	_reset_car(car, along, lateral)
	car.freeze = true
	rivals.append(car)
	_note(car)


func _note(car: RigidBody3D) -> void:
	var id := car.get_instance_id()
	lap_of[id] = 1
	seen_of[id] = false
	score_of[id] = 0.0


func _reset_car(car: RigidBody3D, along: float, lateral: float) -> void:
	var fr := _frame_at(along)
	var pos: Vector3 = fr.pos + fr.right * lateral + Vector3.UP * 0.58
	car.global_position = pos
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	var ahead: Vector3 = pos + fr.tan
	car.look_at(ahead, Vector3.UP)


func _guide_ai() -> void:
	for rival in rivals:
		var dist := _closest(rival.global_position)
		var speed: float = absf(float(rival.get("kmh")))
		var look: float = lerpf(18.0, 36.0, clampf(speed / 180.0, 0.0, 1.0))
		var ahead := _frame_at(dist + look)
		rival.set("ai_point", ahead.pos)


func _watch_laps() -> void:
	_advance(player)
	player_lap = int(lap_of[player.get_instance_id()])
	for rival in rivals:
		if rival.global_position.y < -3.0 or not rival.upright():
			_reset_car(rival, _closest(rival.global_position) + 8.0, 0.0)
		_advance(rival)


func _advance(car: RigidBody3D) -> void:
	var id := car.get_instance_id()
	var dist := _closest(car.global_position)
	if dist > total_len * 0.55:
		seen_of[id] = true
	if bool(seen_of[id]) and dist < total_len * 0.12:
		lap_of[id] = int(lap_of[id]) + 1
		seen_of[id] = false
	score_of[id] = float(lap_of[id]) * total_len + dist


func _place() -> int:
	var mine: float = float(score_of.get(player.get_instance_id(), 0.0))
	var place := 1
	for rival in rivals:
		if float(score_of.get(rival.get_instance_id(), 0.0)) > mine + 2.0:
			place += 1
	return place


func _update_camera(delta: float) -> void:
	var basis := player.global_transform.basis
	var fwd := -basis.z
	var up := Vector3.UP
	var want: Vector3 = player.global_position - fwd * 8.4 + up * 2.8
	var blend := 1.0 - exp(-4.5 * delta)
	if not cam_ready:
		cam_pos = want
		cam_ready = true
	else:
		cam_pos = cam_pos.lerp(want, blend)
	camera.global_position = cam_pos
	camera.look_at(player.global_position + fwd * 4.0 + up * 0.7, up)


func _frame_at(dist: float) -> Dictionary:
	dist = fposmod(dist, total_len)
	var i := 0
	for k in samples.size():
		var d0 := float(samples[k]["dist"])
		var d1 := total_len if k + 1 >= samples.size() else float(samples[k + 1]["dist"])
		if dist >= d0 and dist < d1:
			i = k
			break
	var a: Dictionary = samples[i]
	var b: Dictionary = samples[(i + 1) % samples.size()]
	var d0 := float(a["dist"])
	var d1 := total_len if i + 1 >= samples.size() else float(b["dist"])
	var t := clampf((dist - d0) / maxf(d1 - d0, 0.001), 0.0, 1.0)
	var tan: Vector3 = (a["tan"] as Vector3).lerp(b["tan"], t).normalized()
	var right: Vector3 = tan.cross(Vector3.UP).normalized()
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], t), "tan": tan, "right": right}


func _closest(p: Vector3) -> float:
	var best := 0.0
	var best_d := 100000000.0
	for sample in samples:
		var sp: Vector3 = sample["pos"]
		var d := sp.distance_squared_to(Vector3(p.x, 0.0, p.z))
		if d < best_d:
			best_d = d
			best = float(sample["dist"])
	return best


func _asphalt_tex() -> Texture2D:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for y in 256:
		for x in 256:
			var n := rng.randf_range(-0.035, 0.035)
			var col := Color(0.34 + n, 0.35 + n, 0.36 + n)
			if x < 8 or x > 247:
				col = Color(0.9, 0.9, 0.88)
			if absi(x - 128) <= 3 and (y % 64) < 26:
				col = Color(0.92, 0.92, 0.9)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _window_tex(wall: Color, pane: Color, glow: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGB8)
	for y in 96:
		for x in 64:
			var col := wall
			if y < 10:
				col = wall.darkened(0.12)
			elif x % 8 == 2 and y % 10 == 3:
				col = glow if ((x + y * 3) % 7) == 0 else pane
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _tex_mat(tex: Texture2D, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.metallic = 0.15 if rough < 0.4 else 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat


func _plain(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


func _box_building(root: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(root.x, size.y * 0.5, root.z)
	world.add_child(mi)


func _street_lamp(root: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.1
	cyl.height = 7.4
	pole.mesh = cyl
	pole.position = root + Vector3.UP * 3.7
	pole.material_override = _plain(Color(0.18, 0.19, 0.21))
	world.add_child(pole)
	var head := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.12, 0.28)
	head.mesh = box
	head.position = root + Vector3.UP * 7.35
	head.material_override = _plain(Color(0.82, 0.78, 0.62))
	world.add_child(head)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	var normal := (b - a).cross(d - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	st.set_normal(normal)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(normal)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_normal(normal)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_normal(normal)
	st.set_uv(ud)
	st.add_vertex(d)


func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _draw() -> void:
	if state == "lang":
		_draw_lang()
		_draw_track()
		return
	_draw_speedo()
	_draw_map()
	_text("LAP %d/%d" % [mini(player_lap, LAPS), LAPS], Vector2(18, 28), 12, Color(0.95, 0.95, 0.95))
	_text("P%d/%d" % [_place(), rivals.size() + 1], Vector2(18, 48), 12, Color(0.7, 0.95, 0.8))
	if state == "count":
		var n := int(ceil(count_left))
		_center("GO" if n <= 0 else str(n), 250, 40, Color(1, 1, 1))
		_center(Locale.text("race.hint3"), 500, 10, Color(1, 1, 1))
	elif state == "done":
		draw_rect(Rect2(220, 150, 520, 160), Color(0.05, 0.06, 0.08, 0.78))
		_center(Locale.text("race.finish"), 210, 16, Color(0.9, 0.95, 1))
		_center(Locale.text("race.retry"), 270, 12, Color(1, 1, 1))
	_draw_track()


func _draw_speedo() -> void:
	var kmh := 0.0
	var gear := 1
	if player != null:
		kmh = absf(float(player.get("kmh")))
		gear = int(player.get("gear"))
	var c := Vector2(820, 430)
	draw_arc(c, 78, PI * 0.72, PI * 2.28, 40, Color(1, 1, 1, 0.9), 3.0)
	var t := clampf(kmh / 240.0, 0.0, 1.0)
	var ang := lerpf(PI * 0.72, PI * 2.28, t)
	var dir := Vector2(cos(ang), sin(ang))
	draw_line(c + dir * 22.0, c + dir * 70.0, Color(0.85, 0.12, 0.1), 3.0)
	_center_at(str(int(kmh)), c + Vector2(0, 28), 16, Color(1, 1, 1))
	_center_at("KM/H", c + Vector2(0, 48), 8, Color(0.85, 0.85, 0.85))
	_center_at("R" if gear == 0 else str(gear), c + Vector2(96, 8), 22, Color(1, 1, 1))


func _draw_map() -> void:
	var origin := Vector2(78, 430)
	var span := map_max - map_min
	var scale := 90.0 / maxf(maxf(span.x, span.y), 1.0)
	for i in range(0, samples.size(), 3):
		var a: Vector3 = samples[i]["pos"]
		var b: Vector3 = samples[(i + 3) % samples.size()]["pos"]
		draw_line(_map(a, origin, scale), _map(b, origin, scale), Color(1, 1, 1, 0.75), 2.0)
	var dots: Array[Color] = [
		Color(0.93, 0.94, 0.96),
		Color(0.16, 0.16, 0.18),
		Color(0.86, 0.2, 0.22),
		Color(0.3, 0.55, 0.95),
	]
	for i in rivals.size():
		var rp := _map(rivals[i].global_position, origin, scale)
		draw_circle(rp, 4.5, Color(0.05, 0.05, 0.05))
		draw_circle(rp, 3.4, dots[i % dots.size()])
	if player != null:
		var p := player.global_position
		var pt := _map(p, origin, scale)
		draw_circle(pt, 5.2, Color(0.05, 0.05, 0.05))
		draw_circle(pt, 3.8, Color(0.25, 0.95, 0.45))


func _map(p: Vector3, origin: Vector2, scale: float) -> Vector2:
	return origin + Vector2(p.x - map_min.x, p.z - map_min.y) * scale


func _draw_lang() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.08, 0.1, 0.14, 0.72))
	_center("CYBERNOVA", 150, 26, Color(1, 1, 1))
	_center(Locale.text("race.title"), 200, 14, Color(0.95, 0.85, 0.45))
	_row(0, "ENGLISH")
	_row(1, "ESPAÑOL")


func _row(which: int, label: String) -> void:
	var rect := Rect2(250, 270 + float(which) * 54, 460, 44)
	var on := which == lang_index
	draw_rect(rect, Color(0.05, 0.07, 0.1, 0.9))
	if on:
		draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), Color(0.4, 0.85, 1))
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x if font else 0.0
	_text(label, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + 30), 16, Color(1, 1, 1))


func _text(line: String, pos: Vector2, size: int, color: Color) -> void:
	if font == null or line == "":
		return
	draw_string(font, pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.75))
	draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _center(line: String, y: float, size: int, color: Color) -> void:
	_center_at(line, Vector2(480, y), size, color)


func _center_at(line: String, pos: Vector2, size: int, color: Color) -> void:
	if font == null or line == "":
		return
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(line, Vector2(pos.x - width * 0.5, pos.y), size, color)


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
	var pos := Vector2((960.0 - width) * 0.5, 34)
	draw_rect(Rect2(pos.x - 14, 10, width + 28, 30), Color(0, 0, 0, 0.78))
	draw_string(credit_font, pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	draw_string(credit_font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.94, 0.78))
