@tool
class_name RoadNode
extends Node3D

@export var handle_out: Vector3 = Vector3(8, 0, 0):
	set(value):
		handle_out = value
		# Auto-mirror in-handle to guarantee smooth C1 continuity
		_handle_in = -value
		_notify_system()

@export var handle_in: Vector3:
	get:
		return _handle_in
	set(value):
		_handle_in = value
		_notify_system()

var _handle_in: Vector3 = Vector3(-8, 0, 0)

@export var node_radius: float = 0.3:
	set(value):
		node_radius = value
		_update_mesh_size()

var _visual_mesh: MeshInstance3D

func _ready() -> void:
	set_notify_transform(true)
	_setup_visual_indicator()
	_notify_system()

func _setup_visual_indicator() -> void:
	_visual_mesh = get_node_or_null("NodeGizmoMesh") as MeshInstance3D
	if not _visual_mesh:
		_visual_mesh = MeshInstance3D.new()
		_visual_mesh.name = "NodeGizmoMesh"
		
		var sphere = SphereMesh.new()
		sphere.radius = node_radius
		sphere.height = node_radius * 2.0
		_visual_mesh.mesh = sphere

		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.3, 0.1)
		_visual_mesh.material_override = mat

		add_child(_visual_mesh)
	_visual_mesh.visible = Engine.is_editor_hint()

func _update_mesh_size() -> void:
	if _visual_mesh and _visual_mesh.mesh is SphereMesh:
		var sphere = _visual_mesh.mesh as SphereMesh
		sphere.radius = node_radius
		sphere.height = node_radius * 2.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_notify_system()

func _notify_system() -> void:
	var parent = get_parent()
	if parent and parent.has_method("request_update"):
		parent.request_update()
