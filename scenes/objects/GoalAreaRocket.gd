# res://scripts/minigames/RocketGoal.gd
extends Area2D

@export var speed: float = 200.0
@export var loop: bool = true

# Parent that holds RocketMarker* (default: go 2 levels up to Room_ExactlyionTown)
@export var waypoint_root_path: NodePath = NodePath("../..")
@onready var anim: AnimationPlayer = $AnimationPlayer

var _waypoints: Array[Node2D] = []
var _current_index: int = 0
var _active: bool = false


func _ready() -> void:
	var root := get_node_or_null(waypoint_root_path)
	if root == null:
		root = get_parent()
		push_warning("RocketGoal: waypoint_root_path invalid, using parent instead: %s" % str(root))

	_waypoints.clear()

	# Collect all Marker2D nodes named "RocketMarker*"
	for child in root.get_children():
		if child is Marker2D and child.name.begins_with("RocketMarker"):
			_waypoints.append(child)

	# Sort by the numeric suffix in the name: RocketMarker1,2,3,4,...
	_waypoints.sort_custom(Callable(self, "_sort_markers_by_number"))

	# Debug: print the order we detected
	print("RocketGoal: collected %d waypoints in order:" % _waypoints.size())
	for i in _waypoints.size():
		print("  %d → %s at %s" % [i, _waypoints[i].name, str(_waypoints[i].global_position)])

	# Start at first marker if available
	if _waypoints.size() > 0:
		global_position = _waypoints[0].global_position
		rotation = 0.0

	# Start hidden & inactive — controller will call activate()
	visible = false
	set_physics_process(false)

	if anim:
		anim.stop()


func _sort_markers_by_number(a: Node, b: Node) -> bool:
	# Extract the first number in each name and compare numerically.
	var re := RegEx.new()
	re.compile("\\d+")

	var ma := re.search(a.name)
	var mb := re.search(b.name)

	if ma and mb:
		var ia := int(ma.get_string())
		var ib := int(mb.get_string())
		if ia != ib:
			return ia < ib

	# Fallback to normal string comparison if no numbers found
	return a.name < b.name



func activate() -> void:
	if _waypoints.size() < 2:
		push_warning("RocketGoal: Not enough waypoints to move (need at least 2).")
		return

	_active = true
	visible = true
	set_physics_process(true)

	if anim and anim.has_animation("run"):
		anim.play("run")

	print("RocketGoal: ACTIVATED, starting at %s → next %s"
		% [ _waypoints[0].name, _waypoints[1].name ])


func _physics_process(delta: float) -> void:
	if not _active or _waypoints.is_empty():
		return

	var target := _waypoints[_current_index].global_position
	var to_target := target - global_position
	var dist := to_target.length()

	# Reached current waypoint
	if dist <= 4.0:
		_current_index += 1

		if _current_index >= _waypoints.size():
			if loop:
				_current_index = 0
			else:
				# Stop at last waypoint
				_active = false
				set_physics_process(false)
				if anim:
					anim.stop()
				print("RocketGoal: finished path at %s" % _waypoints[_waypoints.size() - 1].name)
				return

		# Update target for new waypoint
		target = _waypoints[_current_index].global_position
		to_target = target - global_position

	# Move towards current waypoint
	var dir := to_target.normalized()
	global_position += dir * speed * delta
	rotation = dir.angle()
