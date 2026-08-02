extends Node3D

@export var rc: RoadContainer
@export var sample_spacing: float = 0.5
@export var print_interval: float = 0.5
@export var curve_color: Color = Color(0.0, 1.0, 0.0, 1.0)
@export var point_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var line_color: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var y_offset: float = 0.05

var segs = []

var closest_segment = null
var closest_point: Vector3 = Vector3.ZERO
var closest_distance_sq: float = INF

var debug_timer: float = 0.0

var curve_mesh_instance: MeshInstance3D
var marker_mesh_instance: MeshInstance3D
var line_mesh_instance: MeshInstance3D

func _ready() -> void:
	if rc != null:
		segs = rc.get_segments()

	setup_debug_meshes()

func _process(delta: float) -> void:
	if rc == null:
		return

	if segs.is_empty():
		segs = rc.get_segments()
		if segs.is_empty():
			return

	find_closest_segment()

	debug_timer += delta
	if debug_timer >= print_interval:
		debug_timer = 0.0
		if closest_segment != null:
			print("Closest segment: ", closest_segment)
			print("Closest point: ", closest_point)
			print("Distance to curve: ", sqrt(closest_distance_sq))

	update_debug_draw()

func find_closest_segment() -> void:
	closest_segment = null
	closest_point = Vector3.ZERO
	closest_distance_sq = INF

	for seg in segs:
		if seg == null:
			continue
		if not seg.has_method("get"):
			continue
		if seg.curve == null:
			continue

		var p: Vector3 = seg.curve.get_closest_point(global_position)
		var d_sq: float = global_position.distance_squared_to(p)

		if d_sq < closest_distance_sq:
			closest_distance_sq = d_sq
			closest_point = p
			closest_segment = seg

func setup_debug_meshes() -> void:
	# Curve mesh
	curve_mesh_instance = MeshInstance3D.new()
	add_child(curve_mesh_instance)

	# Marker mesh
	marker_mesh_instance = MeshInstance3D.new()
	add_child(marker_mesh_instance)

	# Line-to-point mesh
	line_mesh_instance = MeshInstance3D.new()
	add_child(line_mesh_instance)

	# Small sphere marker
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	marker_mesh_instance.mesh = sphere

	var point_mat := StandardMaterial3D.new()
	point_mat.albedo_color = point_color
	point_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mesh_instance.material_override = point_mat

func update_debug_draw() -> void:
	if closest_segment == null or closest_segment.curve == null:
		return

	draw_curve(closest_segment.curve)
	draw_marker(closest_point)
	draw_line_to_point(global_position, closest_point)

func draw_curve(curve: Curve3D) -> void:
	var imm := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true

	var length := curve.get_baked_length()
	if length <= 0.001:
		curve_mesh_instance.mesh = null
		return

	imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)

	var d := 0.0
	while d <= length:
		var p: Vector3 = curve.sample_baked(d)
		p.y += y_offset
		imm.surface_set_color(curve_color)
		imm.surface_add_vertex(to_local(p))
		d += sample_spacing

	var p_end := curve.sample_baked(length)
	p_end.y += y_offset
	imm.surface_set_color(curve_color)
	imm.surface_add_vertex(to_local(p_end))

	imm.surface_end()
	curve_mesh_instance.mesh = imm

func draw_marker(pos: Vector3) -> void:
	marker_mesh_instance.global_position = pos + Vector3(0, y_offset, 0)

func draw_line_to_point(from_pos: Vector3, to_pos: Vector3) -> void:
	var imm := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true

	imm.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	imm.surface_set_color(line_color)
	imm.surface_add_vertex(to_local(from_pos + Vector3(0, y_offset, 0)))

	imm.surface_set_color(line_color)
	imm.surface_add_vertex(to_local(to_pos + Vector3(0, y_offset, 0)))

	imm.surface_end()
	line_mesh_instance.mesh = imm
