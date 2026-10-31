extends SceneTree
## Standalone GLB import test; run in an isolated test project, not the game.

func _initialize() -> void:
	call_deferred("run_test")

func find_type(node: Node, kind: String) -> Node:
	if node.is_class(kind):
		return node
	for child: Node in node.get_children():
		var found: Node = find_type(child, kind)
		if found != null:
			return found
	return null

func fail(message: String) -> void:
	printerr("[SPRINGFIELD] FAIL: " + message)
	quit(1)

func run_test() -> void:
	var resource: PackedScene = load("res://springfield_animated.glb") as PackedScene
	if resource == null:
		fail("GLB scene did not load")
		return
	var model: Node = resource.instantiate()
	root.add_child(model)
	var player: AnimationPlayer = find_type(model, "AnimationPlayer") as AnimationPlayer
	var skeleton: Skeleton3D = find_type(model, "Skeleton3D") as Skeleton3D
	if player == null or skeleton == null or skeleton.get_bone_count() < 30:
		fail("Missing AnimationPlayer or skeletal rig")
		return
	var names: PackedStringArray = player.get_animation_list()
	print("[SPRINGFIELD] imported animations: ", names, "; bones: ", skeleton.get_bone_count())
	for animation_name: String in ["Kar98k", "Kar98k.001", "Oldk98k"]:
		if not player.has_animation(animation_name):
			fail("Missing animation: " + animation_name)
			return
		var animation: Animation = player.get_animation(animation_name)
		player.play(animation_name)
		player.seek(0.1, true)
		var initial: Array[Transform3D] = []
		for bone_index in skeleton.get_bone_count():
			initial.append(skeleton.get_bone_pose(bone_index))
		player.seek(animation.length * 0.5, true)
		var changed := false
		for bone_index in skeleton.get_bone_count():
			if not initial[bone_index].is_equal_approx(skeleton.get_bone_pose(bone_index)):
				changed = true
				break
		if not changed:
			fail("No skeleton movement in " + animation_name)
			return
		print("[SPRINGFIELD] skeletal movement verified: ", animation_name, " length ", animation.length)
	model.queue_free()
	print("[SPRINGFIELD] PASS: GLB loads and all three actions animate bones")
	quit(0)
