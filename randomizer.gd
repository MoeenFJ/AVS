extends Node3D

@export var cam : GStreamerCamera
@export var rs : RoadSystem
@export var enable : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
var elapsedTime = 0
func _process(delta: float) -> void:
	elapsedTime += delta
	if elapsedTime < 2 or !enable:
		return
	elapsedTime -= 2
	#cam.fov = randi_range(45,120)
	#cam.rotation_degrees = Vector3(cam.rotation_degrees.x,cam.rotation_degrees.y,randf_range(-45,25))
	## Road width : 2-5
	## Line width : 0.1-0.8
	var lane_width = randf_range(2,5)
	var lane_count = randi_range(1,4)
	rs.road_width = lane_width*lane_count
	rs.lanes = lane_count
	rs.line_width = randf_range(0.1,0.6)
	rs.request_update()
