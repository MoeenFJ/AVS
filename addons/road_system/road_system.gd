@tool
class_name RoadSystem
extends Node3D

@export var line_color: Color = Color.GREEN
@export var handle_color: Color = Color.CYAN
@export var tessellation_stages: int = 5
@export var tolerance_degrees: float = 2.0

@export var road_width: float = 6.0
@export var uv_scale: Vector2 = Vector2(1.0, 0.2)
@export var road_material: Material


@export_group("Lanes & Markings")
@export var lanes: int = 2:
	set(value):
		lanes = max(1, value)
		request_update()
@export var lane_line_material : Material
@export var line_width: float = 0.15 # Width of the solid white lines in meters


var road_mesh_instance: MeshInstance3D
var lines_mask_mesh_instance: MeshInstance3D
var lines_mesh_instance: MeshInstance3D

var curve: Curve3D = Curve3D.new()
var mesh_instance: MeshInstance3D
var immediate_mesh: ImmediateMesh
var line_material: StandardMaterial3D
var handle_material: StandardMaterial3D

func _ready() -> void:
	set_notify_transform(true)
	_setup_mesh()
	call_deferred("request_update")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		request_update()

func _setup_mesh() -> void:
	# 1. Debug 1D Lines (Editor Gizmo - Hidden in Game)
	mesh_instance = get_node_or_null("LineRenderer") as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "LineRenderer"
		add_child(mesh_instance)

	mesh_instance.visible = Engine.is_editor_hint()

	immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh

	line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = line_color

	handle_material = StandardMaterial3D.new()
	handle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	handle_material.albedo_color = handle_color

	# 2. Main Road Surface (Renders on Layer 1)
	road_mesh_instance = get_node_or_null("RoadMesh") as MeshInstance3D
	if not road_mesh_instance:
		road_mesh_instance = MeshInstance3D.new()
		road_mesh_instance.name = "RoadMesh"
		add_child(road_mesh_instance)

	road_mesh_instance.layers = 1 # Assigned to Layer 1 (Standard World)

		
	lines_mask_mesh_instance = get_node_or_null("RoadLinesMaskMesh") as MeshInstance3D
	if not lines_mask_mesh_instance:
		lines_mask_mesh_instance = MeshInstance3D.new()
		lines_mask_mesh_instance.name = "RoadLinesMaskMesh"
		add_child(lines_mask_mesh_instance)

	lines_mask_mesh_instance.layers = 4

	# 3. Separate Road Lines Surface (Renders on Layers 1 and 2)
	lines_mesh_instance = get_node_or_null("RoadLinesMesh") as MeshInstance3D
	if not lines_mesh_instance:
		lines_mesh_instance = MeshInstance3D.new()
		lines_mesh_instance.name = "RoadLinesMesh"
		add_child(lines_mesh_instance)

	# Layer value '3' enables both Layer 1 and Layer 2 (1 + 2 = 3)
	# This lets your Main Camera and your Line Camera both see the lines!
	lines_mesh_instance.layers = 1
	


func request_update() -> void:
	rebuild_curve()
	draw_lines()
	generate_road_mesh()

func rebuild_curve() -> void:
	curve.clear_points()
	
	var nodes: Array[RoadNode] = []
	for child in get_children():
		if child is RoadNode:
			nodes.append(child)

	if nodes.size() < 2:
		return

	# Transform handles by node rotation into system-local space
	var system_inv_basis = global_transform.basis.inverse()

	for node in nodes:
		var local_pos = to_local(node.global_position)
		
		# Rotate node handle vectors according to node rotation
		var node_basis = node.global_transform.basis
		var rot_handle_in = system_inv_basis * (node_basis * node.handle_in)
		var rot_handle_out = system_inv_basis * (node_basis * node.handle_out)
		
		curve.add_point(local_pos, rot_handle_in, rot_handle_out)

func draw_lines() -> void:
	if not immediate_mesh:
		return
		
	immediate_mesh.clear_surfaces()

	var nodes: Array[RoadNode] = []
	for child in get_children():
		if child is RoadNode:
			nodes.append(child)

	# 1. Draw Continuous Curve Line
	if curve.get_point_count() >= 2:
		var points: PackedVector3Array = curve.tessellate(tessellation_stages, tolerance_degrees)
		if points.size() >= 2:
			line_material.albedo_color = line_color
			immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
			for i in range(points.size() - 1):
				immediate_mesh.surface_add_vertex(points[i])
				immediate_mesh.surface_add_vertex(points[i + 1])
			immediate_mesh.surface_end()

	# 2. Draw Handle Vector Lines in Editor
	if Engine.is_editor_hint() and nodes.size() > 0:
		handle_material.albedo_color = handle_color
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, handle_material)
		
		for node in nodes:
			var node_local = to_local(node.global_position)
			var node_basis = node.global_transform.basis
			var system_inv_basis = global_transform.basis.inverse()
			
			var h_in = node_local + system_inv_basis * (node_basis * node.handle_in)
			var h_out = node_local + system_inv_basis * (node_basis * node.handle_out)
			
			immediate_mesh.surface_add_vertex(node_local)
			immediate_mesh.surface_add_vertex(h_in)
			
			immediate_mesh.surface_add_vertex(node_local)
			immediate_mesh.surface_add_vertex(h_out)
			
		immediate_mesh.surface_end()
		
func generate_road_mesh() -> void:
	if not road_mesh_instance or not lines_mesh_instance or not lines_mask_mesh_instance:
		return

	if curve.get_point_count() < 2:
		road_mesh_instance.mesh = null
		lines_mesh_instance.mesh = null
		lines_mask_mesh_instance.mesh = null
		return

	var points: PackedVector3Array = curve.tessellate(tessellation_stages, tolerance_degrees)
	if points.size() < 2:
		road_mesh_instance.mesh = null
		lines_mesh_instance.mesh = null
		lines_mask_mesh_instance.mesh = null
		return

	var half_width = road_width * 0.5
	var distance_traveled: float = 0.0

	# -------------------------------------------------------------------------
	# STEP A: BUILD MAIN ASPHALT GEOMETRY
	# -------------------------------------------------------------------------
	var st_asphalt = SurfaceTool.new()
	st_asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size()):
		var current_pos = points[i]
		var forward: Vector3 = _get_forward_dir(points, i)

		if i > 0:
			distance_traveled += points[i].distance_to(points[i - 1])

		var right = forward.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.001:
			right = forward.cross(Vector3.RIGHT).normalized()

		var left_vertex = current_pos - (right * half_width)
		var right_vertex = current_pos + (right * half_width)
		var v_coord = distance_traveled * uv_scale.y
		var u_max = road_width * uv_scale.x

		st_asphalt.set_normal(Vector3.UP)
		st_asphalt.set_uv(Vector2(0.0, v_coord))
		st_asphalt.add_vertex(left_vertex)

		st_asphalt.set_normal(Vector3.UP)
		st_asphalt.set_uv(Vector2(u_max, v_coord))
		st_asphalt.add_vertex(right_vertex)

	for i in range(points.size() - 1):
		var idx = i * 2
		st_asphalt.add_index(idx)
		st_asphalt.add_index(idx + 2)
		st_asphalt.add_index(idx + 1)

		st_asphalt.add_index(idx + 1)
		st_asphalt.add_index(idx + 2)
		st_asphalt.add_index(idx + 3)

	st_asphalt.generate_tangents()
	road_mesh_instance.mesh = st_asphalt.commit()

	if road_material:
		road_mesh_instance.material_override = road_material
	else:
		var default_mat = StandardMaterial3D.new()
		default_mat.albedo_color = Color(0.15, 0.15, 0.15)
		road_mesh_instance.material_override = default_mat

	# -------------------------------------------------------------------------
	# STEP B: BUILD UNSHADED LINE GEOMETRY
	# -------------------------------------------------------------------------
	var st_lines = SurfaceTool.new()
	st_lines.begin(Mesh.PRIMITIVE_TRIANGLES)

	var line_offsets: Array[float] = []
	for l in range(lanes + 1):
		var t = float(l) / float(lanes)
		line_offsets.append(lerp(-half_width, half_width, t))

	var line_count = line_offsets.size()
	var half_line = line_width * 0.5
	var line_v_dist: float = 0.0

	for i in range(points.size()):
		var current_pos = points[i]
		var forward: Vector3 = _get_forward_dir(points, i)

		if i > 0:
			line_v_dist += points[i].distance_to(points[i - 1])

		var right = forward.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.001:
			right = forward.cross(Vector3.RIGHT).normalized()

		# Raised slightly (+0.002m) to prevent z-fighting with asphalt
		var elevated_pos = current_pos + (Vector3.UP * 0.002)

		for offset in line_offsets:
			var line_center = elevated_pos + (right * offset)
			var l_vert = line_center - (right * half_line)
			var r_vert = line_center + (right * half_line)

			st_lines.set_normal(Vector3.UP)
			#st_lines.set_color(line_color_surface)
			st_lines.set_uv(Vector2(0.0, line_v_dist))
			st_lines.add_vertex(l_vert)

			st_lines.set_normal(Vector3.UP)
			#st_lines.set_color(line_color_surface)
			st_lines.set_uv(Vector2(1.0, line_v_dist))
			st_lines.add_vertex(r_vert)

	for i in range(points.size() - 1):
		var row_stride = line_count * 2
		var curr_row_idx = i * row_stride
		var next_row_idx = (i + 1) * row_stride

		for l in range(line_count):
			var idx = curr_row_idx + (l * 2)
			var next_idx = next_row_idx + (l * 2)

			st_lines.add_index(idx)
			st_lines.add_index(next_idx)
			st_lines.add_index(idx + 1)

			st_lines.add_index(idx + 1)
			st_lines.add_index(next_idx)
			st_lines.add_index(next_idx + 1)

	st_lines.generate_tangents()
	lines_mask_mesh_instance.mesh = st_lines.commit()
	lines_mesh_instance.mesh = st_lines.commit()


	lines_mesh_instance.material_override = lane_line_material
	
	
	
	var line_mask_mat = StandardMaterial3D.new()
	line_mask_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mask_mat.vertex_color_use_as_albedo = true
	line_mask_mat.albedo_color = Color.WHITE
	lines_mask_mesh_instance.material_override = line_mask_mat
# Helper function for tangent calculation
func _get_forward_dir(points: PackedVector3Array, index: int) -> Vector3:
	if index < points.size() - 1:
		return (points[index + 1] - points[index]).normalized()
	else:
		return (points[index] - points[index - 1]).normalized()
