extends RigidBody3D
# Visual: Sports Car by Quaternius (CC0).

const WHEEL_RADIUS := 0.33
const SUSP_REST := 0.34
const SUSP_TRAVEL := 0.20
const STIFF := 26000.0
const DAMP := 4200.0
const WHEEL_X := 0.78
const FRONT_Z := -1.22
const REAR_Z := 1.18

var active := false
var ai := false
var ai_point := Vector3.ZERO
var cruise := false
var force_reverse := false
var ai_pace := 0.9
var paint_color := Color(0.74, 0.76, 0.78)
var steer_angle := 0.0
var throttle_input := 0.0
var brake_input := 0.0
var reverse_input := 0.0
var handbrake := false
var kmh := 0.0
var gear := 1
var wheel_spin := 0.0
var throttle_smooth := 0.0
var reverse_smooth := 0.0
var wheels: Array[Dictionary] = []
var meshes: Array[Node3D] = []
var wheel_rest: Array[Transform3D] = []
var wheel_centers: Array[Vector3] = []
var visual: Node3D


func _ready() -> void:
	mass = 1260.0
	gravity_scale = 1.0
	can_sleep = false
	continuous_cd = true
	linear_damp = 0.012
	angular_damp = 1.65
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.14, 0.10)
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.70, 0.52, 4.05)
	shape.shape = box
	shape.position = Vector3(0, 0.58, -0.04)
	add_child(shape)
	_build_body()
	wheels = [
		{"pos": Vector3(-WHEEL_X, 0.20, FRONT_Z), "steer": true, "drive": true},
		{"pos": Vector3(WHEEL_X, 0.20, FRONT_Z), "steer": true, "drive": true},
		{"pos": Vector3(-WHEEL_X, 0.20, REAR_Z), "steer": false, "drive": true},
		{"pos": Vector3(WHEEL_X, 0.20, REAR_Z), "steer": false, "drive": true},
	]


func _build_body() -> void:
	var packed: PackedScene = load("res://level1_v1.06/models/sports_car.glb") as PackedScene
	if packed != null:
		visual = packed.instantiate() as Node3D
		visual.name = "Body"
		add_child(visual)
		_paint_tree(visual)
		_collect_wheels(visual)
		if meshes.size() > 0:
			return
	_build_fallback_body()


func _paint_tree(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src == null:
					continue
				var mat := src.duplicate() as Material
				var std := mat as StandardMaterial3D
				if std != null:
					var nm := src.resource_name.to_lower()
					if nm.find("white") >= 0 or std.albedo_color.g > 0.82:
						std.albedo_color = paint_color
						std.metallic = 0.88
						std.roughness = 0.24
					elif nm.find("window") >= 0:
						std.albedo_color = Color(0.12, 0.18, 0.24, 0.42)
						std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						std.roughness = 0.06
					elif nm.find("head") >= 0:
						std.emission_enabled = true
						std.emission = Color(0.95, 0.96, 0.88)
						std.emission_energy_multiplier = 2.4
					elif nm.find("tail") >= 0:
						std.emission_enabled = true
						std.emission = Color(0.85, 0.08, 0.06)
						std.emission_energy_multiplier = 2.0
				mi.set_surface_override_material(i, mat)
	for child in n.get_children():
		_paint_tree(child)


func _collect_wheels(n: Node) -> void:
	var nm := String(n.name).to_lower()
	if nm.find("wheel") >= 0 and n is MeshInstance3D:
		var mi := n as MeshInstance3D
		meshes.append(mi)
		wheel_rest.append(mi.transform)
		var center := Vector3.ZERO
		if mi.mesh != null:
			center = mi.mesh.get_aabb().get_center()
		wheel_centers.append(center)
		return
	for child in n.get_children():
		_collect_wheels(child)


func _build_fallback_body() -> void:
	var paint := _metal(paint_color)
	var dark := _metal(Color(0.06, 0.065, 0.07))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.12, 0.18, 0.24, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.2
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	body.mesh = _loft_mesh()
	body.material_override = paint
	add_child(body)
	_glass_panel(Vector3(0, 0.94, -0.38), Vector3(1.05, 0.02, 0.95), Vector3(18, 0, 0), glass)
	_glass_panel(Vector3(0, 0.96, 0.42), Vector3(1.0, 0.02, 0.7), Vector3(-22, 0, 0), glass)
	_box(Vector3(1.55, 0.04, 0.28), Vector3(0, 0.78, 1.95), paint)
	_box(Vector3(0.26, 0.09, 0.06), Vector3(-0.58, 0.46, -2.08), _emit(Color(0.95, 0.96, 0.9)))
	_box(Vector3(0.26, 0.09, 0.06), Vector3(0.58, 0.46, -2.08), _emit(Color(0.95, 0.96, 0.9)))
	_box(Vector3(0.32, 0.08, 0.05), Vector3(-0.55, 0.48, 2.16), _emit(Color(0.85, 0.08, 0.06)))
	_box(Vector3(0.32, 0.08, 0.05), Vector3(0.55, 0.48, 2.16), _emit(Color(0.85, 0.08, 0.06)))
	for spec in [
		Vector3(-WHEEL_X, 0.33, FRONT_Z),
		Vector3(WHEEL_X, 0.33, FRONT_Z),
		Vector3(-WHEEL_X, 0.33, REAR_Z),
		Vector3(WHEEL_X, 0.33, REAR_Z),
	]:
		var pivot := Node3D.new()
		pivot.position = spec
		add_child(pivot)
		var hub := Node3D.new()
		pivot.add_child(hub)
		var wheel := MeshInstance3D.new()
		var tyre := CylinderMesh.new()
		tyre.top_radius = WHEEL_RADIUS
		tyre.bottom_radius = WHEEL_RADIUS
		tyre.height = 0.26
		wheel.mesh = tyre
		wheel.rotation.z = PI * 0.5
		wheel.material_override = dark
		hub.add_child(wheel)
		meshes.append(pivot)
		wheel_rest.append(pivot.transform)
		wheel_centers.append(Vector3.ZERO)


func _loft_mesh() -> ArrayMesh:
	var stations: Array = [
		[-2.18, 0.40, 0.16, 0.38, 0.40, 0.26],
		[-1.78, 0.88, 0.14, 0.52, 0.56, 0.64],
		[-1.05, 0.92, 0.20, 0.62, 0.72, 0.62],
		[-0.18, 0.90, 0.20, 0.72, 1.16, 0.48],
		[0.72, 0.90, 0.20, 0.70, 1.06, 0.50],
		[1.52, 0.91, 0.18, 0.60, 0.70, 0.76],
		[2.22, 0.62, 0.16, 0.46, 0.52, 0.48],
		[2.34, 0.32, 0.20, 0.40, 0.44, 0.24],
	]
	var rings: Array = []
	for st in stations:
		var z: float = float(st[0])
		var hw: float = float(st[1])
		var yb: float = float(st[2])
		var ybelt: float = float(st[3])
		var yr: float = float(st[4])
		var rh: float = float(st[5])
		rings.append([
			Vector3(-hw * 0.55, yb, z),
			Vector3(hw * 0.55, yb, z),
			Vector3(hw, yb + 0.08, z),
			Vector3(hw, ybelt, z),
			Vector3(rh, yr, z),
			Vector3(-rh, yr, z),
			Vector3(-hw, ybelt, z),
			Vector3(-hw, yb + 0.08, z),
		])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in 8:
			var k2: int = (k + 1) % 8
			_tri(tool, a[k] as Vector3, b[k] as Vector3, b[k2] as Vector3)
			_tri(tool, a[k] as Vector3, b[k2] as Vector3, a[k2] as Vector3)
	tool.generate_normals()
	return tool.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _glass_panel(pos: Vector3, size: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)


func _metal(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.92
	mat.roughness = 0.22
	return mat


func _emit(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _physics_process(delta: float) -> void:
	if freeze:
		return
	_read_input(delta)
	_simulate_wheels(delta)
	var fwd := -global_transform.basis.z
	var speed := linear_velocity.dot(fwd)
	kmh = speed * 3.6
	gear = _gear_for(absf(kmh))
	if reverse_smooth > 0.35 and speed < -0.35:
		gear = 0
	wheel_spin = fposmod(wheel_spin + speed / WHEEL_RADIUS * delta, TAU)
	_update_wheel_meshes()
	apply_torque(-global_transform.basis.y * angular_velocity.y * 6800.0)
	if global_transform.basis.y.dot(Vector3.UP) > 0.7:
		var flatten: float = global_transform.basis.x.dot(Vector3.UP)
		apply_torque(-global_transform.basis.z * flatten * 8000.0)


func _read_input(delta: float) -> void:
	var want_throttle := 0.0
	var want_brake := 0.0
	var want_reverse := 0.0
	handbrake = false
	var steer_target := 0.0
	var fwd := -global_transform.basis.z
	var speed := linear_velocity.dot(fwd)
	if ai:
		var to := ai_point - global_position
		var local := global_transform.basis.inverse() * to
		steer_target = clampf(-local.x / 11.0, -1.0, 1.0)
		var bend: float = absf(local.x)
		if bend > 7.0:
			want_brake = clampf((bend - 7.0) / 8.0, 0.0, 0.75)
			want_throttle = ai_pace * 0.42
		elif -local.z > 1.5:
			want_throttle = ai_pace
		else:
			want_brake = 0.35
	elif active or cruise:
		if cruise:
			var to := ai_point - global_position
			var local := global_transform.basis.inverse() * to
			steer_target = clampf(-local.x / 10.0, -1.0, 1.0)
			want_throttle = 0.62
			if force_reverse:
				want_throttle = 0.0
				want_reverse = 1.0
				steer_target = 0.0
		else:
			var accel := _key(KEY_UP) or _key(KEY_W)
			var back := _key(KEY_DOWN) or _key(KEY_S)
			if accel:
				want_throttle = 1.0
			if back:
				if speed > 1.2:
					want_brake = 1.0
				else:
					want_reverse = 1.0
			if _key(KEY_LEFT) or _key(KEY_A):
				steer_target += 1.0
			if _key(KEY_RIGHT) or _key(KEY_D):
				steer_target -= 1.0
			handbrake = _key(KEY_SPACE)
	throttle_smooth = move_toward(throttle_smooth, want_throttle, 3.2 * delta)
	reverse_smooth = move_toward(reverse_smooth, want_reverse, 4.8 * delta)
	brake_input = move_toward(brake_input, want_brake, 5.5 * delta)
	throttle_input = throttle_smooth
	reverse_input = reverse_smooth
	var speed_factor: float = clampf(absf(speed) / 34.0, 0.0, 1.0)
	var max_steer: float = lerpf(0.44, 0.13, speed_factor)
	var steer_rate: float = lerpf(2.8, 1.55, speed_factor)
	steer_angle = move_toward(steer_angle, steer_target * max_steer, steer_rate * delta)


func _simulate_wheels(_delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var basis := global_transform.basis
	var fwd := -basis.z
	var hits := 0
	var comp_l := 0.0
	var comp_r := 0.0
	for i in wheels.size():
		var spec: Dictionary = wheels[i]
		var local_pos: Vector3 = spec["pos"]
		var origin: Vector3 = global_transform * local_pos + Vector3.UP * 0.25
		var length: float = SUSP_REST + SUSP_TRAVEL + WHEEL_RADIUS + 0.9
		var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * length, 1)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		hits += 1
		var hit_pos: Vector3 = hit["position"]
		var dist: float = origin.distance_to(hit_pos)
		var compression: float = clampf(SUSP_REST + WHEEL_RADIUS - dist, 0.0, SUSP_REST + SUSP_TRAVEL)
		var point_vel: Vector3 = linear_velocity + angular_velocity.cross(hit_pos - global_position)
		var comp_vel: float = point_vel.dot(Vector3.UP)
		var spring: float = maxf(compression * STIFF - comp_vel * DAMP, 0.0)
		if local_pos.x < 0.0:
			comp_l += compression
		else:
			comp_r += compression
		apply_force(Vector3.UP * spring, hit_pos - global_position)
		var wheel_fwd: Vector3 = Vector3(fwd.x, 0.0, fwd.z)
		if wheel_fwd.length_squared() < 0.0001:
			wheel_fwd = Vector3(0, 0, -1)
		wheel_fwd = wheel_fwd.normalized()
		if bool(spec["steer"]):
			wheel_fwd = wheel_fwd.rotated(Vector3.UP, steer_angle)
		var wheel_right: Vector3 = wheel_fwd.cross(Vector3.UP).normalized()
		var v_long: float = point_vel.dot(wheel_fwd)
		var v_lat: float = point_vel.dot(wheel_right)
		var drive := 0.0
		if bool(spec["drive"]):
			if throttle_input > 0.0 and not handbrake:
				drive += throttle_input * _engine_force()
			if reverse_input > 0.0:
				drive -= reverse_input * _reverse_force()
		var brake_force := 0.0
		if brake_input > 0.0:
			brake_force = brake_input * 9000.0 * signf(v_long)
		var grip: float = 5600.0
		if handbrake and not bool(spec["steer"]):
			grip = 2100.0
		var lat: float = clampf(-v_lat * 2100.0, -grip, grip)
		var lon: float = clampf(drive - brake_force - v_long * 4.0, -28000.0, 28000.0)
		apply_force(wheel_right * lat, hit_pos - global_position)
		apply_central_force(wheel_fwd * lon * 0.28)
	if reverse_input > 0.12:
		var rev: float = reverse_input * 7000.0 * clampf(1.0 - absf(minf(kmh, 0.0)) / 46.0, 0.2, 1.0)
		apply_central_force(-fwd * rev)
	if hits > 0:
		apply_torque(basis.z * (comp_l - comp_r) * 9000.0)
	var horiz := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var speed: float = horiz.length()
	apply_central_force(-horiz * speed * 0.42)
	apply_central_force(Vector3.DOWN * speed * speed * 0.15)


func _engine_force() -> float:
	return 30000.0 * clampf(1.0 - absf(kmh) / 305.0, 0.0, 1.0)


func _reverse_force() -> float:
	return 22000.0 * clampf(1.0 - absf(minf(kmh, 0.0)) / 48.0, 0.18, 1.0)


func _gear_for(speed_kmh: float) -> int:
	if speed_kmh < 40.0:
		return 1
	if speed_kmh < 80.0:
		return 2
	if speed_kmh < 120.0:
		return 3
	if speed_kmh < 160.0:
		return 4
	return 5


func _update_wheel_meshes() -> void:
	for i in meshes.size():
		var node: Node3D = meshes[i]
		var rest: Transform3D = wheel_rest[i]
		var steer: float = steer_angle if String(node.name).to_lower().find("front") >= 0 else 0.0
		var roll := Basis(Vector3.RIGHT, -wheel_spin)
		var yaw := Basis(Vector3.UP, steer)
		var spin_basis := yaw * roll
		if node is MeshInstance3D:
			var center: Vector3 = wheel_centers[i]
			var around := Transform3D(Basis.IDENTITY, center) * Transform3D(spin_basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -center)
			node.transform = rest * around
		else:
			node.rotation = Vector3(0.0, steer, 0.0)
			if node.get_child_count() > 0:
				var hub := node.get_child(0) as Node3D
				hub.rotation.x = -wheel_spin


func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)


func upright() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > 0.25
