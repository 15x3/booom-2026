extends Node3D

signal control_interacted(control_name: String)
signal control_toggled(is_on: bool, control_name: String)

var _controls: Dictionary = {}
var _knob_scene: PackedScene
var _button_scene: PackedScene
var _switch_scene: PackedScene
var _lever_scene: PackedScene

func _ready() -> void:
	_knob_scene = load("res://scenes/controls/knob.tscn")
	_button_scene = load("res://scenes/controls/button.tscn")
	_switch_scene = load("res://scenes/controls/switch.tscn")
	_lever_scene = load("res://scenes/controls/lever.tscn")
	_build_on_scene_nodes()

func _build_on_scene_nodes() -> void:
	_build_center()
	_build_left_panel()
	_build_right_panel()

func get_control(ctrl_name: String) -> Node:
	return _controls.get(ctrl_name, null)

func get_all_controls() -> Dictionary:
	return _controls

func _register(ctrl_name: String, node: Node3D) -> void:
	_controls[ctrl_name] = node

func _find_control_name(node: Node) -> String:
	for key: String in _controls:
		if _controls[key] == node:
			return key
	return ""

func _build_center() -> void:
	var center: Node3D = get_node_or_null("CenterControls/Controls")
	if center == null:
		return

	var ignition_pos: Node3D = center.get_node_or_null("IgnitionBtn")
	if ignition_pos:
		var ignition := _instance_button("IgnitionBtn")
		ignition_pos.add_child(ignition)
		ignition.position = Vector3.ZERO
		_register("ignition", ignition)
		_add_label(center, "点火", ignition_pos.position + Vector3(0, 0.05, 0))

	var nav_pos: Node3D = center.get_node_or_null("NavKnob")
	if nav_pos:
		var nav_knob := _instance_knob("NavKnob")
		nav_knob.set_meta("stops", 3)
		nav_pos.add_child(nav_knob)
		nav_knob.position = Vector3.ZERO
		_register("nav_knob", nav_knob)
		_add_label(center, "导航", nav_pos.position + Vector3(0, 0.05, 0))

	var fuel_pos: Node3D = center.get_node_or_null("FuelValve")
	if fuel_pos:
		var fuel_valve := _instance_knob("FuelValve")
		fuel_valve.set_meta("stops", 4)
		fuel_pos.add_child(fuel_valve)
		fuel_valve.position = Vector3.ZERO
		_register("fuel_valve", fuel_valve)
		_add_label(center, "燃料", fuel_pos.position + Vector3(0, 0.05, 0))

	var thrust_pos: Node3D = center.get_node_or_null("ThrustLever")
	if thrust_pos:
		var thrust_lever := _instance_lever("ThrustLever")
		thrust_pos.add_child(thrust_lever)
		thrust_lever.position = Vector3.ZERO
		_register("thrust_lever", thrust_lever)
		_add_label(center, "推力", thrust_pos.position + Vector3(0, 0.15, 0))

	var base_pos: Node3D = center.get_node_or_null("ConsoleBase")
	if base_pos:
		var console_base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(0.85, 0.03, 0.2)
		console_base.mesh = base_mesh
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.2, 0.2, 0.22, 1)
		base_mat.roughness = 0.95
		base_mat.metallic = 0.1
		base_mat.emission_enabled = true
		base_mat.emission = Color(0.03, 0.03, 0.04)
		console_base.material_override = base_mat
		base_pos.add_child(console_base)
		console_base.position = Vector3.ZERO

func _build_left_panel() -> void:
	var panel_root: Node3D = get_node_or_null("LeftPanel")
	if panel_root == null:
		return
	_setup_side_panel(panel_root, "left", 0.4, 0.45)
	_register("left_panel", panel_root)

	var interior: Node3D = panel_root.get_node_or_null("Interior")
	if interior == null:
		return

	var scan_freq_pos: Node3D = interior.get_node_or_null("ScanFreqKnob")
	if scan_freq_pos:
		var scan_freq := _instance_knob("ScanFreqKnob")
		scan_freq_pos.add_child(scan_freq)
		scan_freq.position = Vector3.ZERO
		_register("scan_freq", scan_freq)
		_boost_interior_emission(scan_freq)
		_add_label(interior, "调频", scan_freq_pos.position + Vector3(0, 0.04, 0))

	var scan_switch_pos: Node3D = interior.get_node_or_null("ScanSwitch")
	if scan_switch_pos:
		var scan_switch := _instance_switch("ScanSwitch")
		scan_switch_pos.add_child(scan_switch)
		scan_switch.position = Vector3.ZERO
		_register("scan_switch", scan_switch)
		_boost_interior_emission(scan_switch)
		_add_label(interior, "扫描", scan_switch_pos.position + Vector3(0, 0.04, 0))

	for i in range(4):
		var breaker_pos: Node3D = interior.get_node_or_null("Breaker%d" % (i + 1))
		if breaker_pos:
			var breaker := _instance_switch("Breaker%d" % (i + 1))
			breaker_pos.add_child(breaker)
			breaker.position = Vector3.ZERO
			_register("breaker_%d" % (i + 1), breaker)
			_boost_interior_emission(breaker)

	_add_label(interior, "B1", Vector3(-0.10, -0.02, 0.02))
	_add_label(interior, "B2", Vector3(0.02, -0.02, 0.02))
	_add_label(interior, "B3", Vector3(-0.10, -0.10, 0.02))
	_add_label(interior, "B4", Vector3(0.02, -0.10, 0.02))

func _build_right_panel() -> void:
	var panel_root: Node3D = get_node_or_null("RightPanel")
	if panel_root == null:
		return
	_setup_side_panel(panel_root, "right", 0.35, 0.4)
	_register("right_panel", panel_root)

	var interior: Node3D = panel_root.get_node_or_null("Interior")
	if interior == null:
		return

	var o2_pos: Node3D = interior.get_node_or_null("O2Valve")
	if o2_pos:
		var o2_valve := _instance_switch("O2Valve")
		o2_pos.add_child(o2_valve)
		o2_valve.position = Vector3.ZERO
		_register("o2_valve", o2_valve)
		_boost_interior_emission(o2_valve)
		_add_label(interior, "O2", o2_pos.position + Vector3(0, 0.04, 0))

	var cooling_pos: Node3D = interior.get_node_or_null("CoolingKnob")
	if cooling_pos:
		var cooling := _instance_knob("CoolingKnob")
		cooling.set_meta("stops", 3)
		cooling_pos.add_child(cooling)
		cooling.position = Vector3.ZERO
		_register("cooling", cooling)
		_boost_interior_emission(cooling)
		_add_label(interior, "冷却", cooling_pos.position + Vector3(0, 0.04, 0))

func _instance_knob(ctrl_name: String) -> Node3D:
	var inst: Node3D = _knob_scene.instantiate()
	inst.name = ctrl_name
	inst.set_meta("type", "knob")
	inst.set_meta("value", 0.0)
	inst.set_meta("stops", 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.45, 1)
	mat.roughness = 0.8
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.08, 0.1, 1)
	var mesh_inst: MeshInstance3D = inst.get_node_or_null("Mesh")
	if mesh_inst:
		mesh_inst.material_override = mat
		mesh_inst.rotation.x = -PI / 2.0
		mesh_inst.position.y = 0.015
		inst.set_meta("knob_mesh", mesh_inst)
	var body: StaticBody3D = inst.get_node_or_null("Body")
	if body and mat:
		body.mouse_entered.connect(func(): _apply_hover(mat, true))
		body.mouse_exited.connect(func(): _apply_hover(mat, false))
	return inst

func _instance_button(ctrl_name: String) -> Node3D:
	var inst: Node3D = _button_scene.instantiate()
	inst.name = ctrl_name
	inst.set_meta("type", "button")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.15, 0.1, 1)
	mat.roughness = 0.7
	mat.metallic = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.05, 0.02, 1)
	var mesh_inst: MeshInstance3D = inst.get_node_or_null("Mesh")
	if mesh_inst:
		mesh_inst.material_override = mat
		mesh_inst.position.y = 0.015
	var body: StaticBody3D = inst.get_node_or_null("Body")
	if body and mat:
		body.mouse_entered.connect(func(): _apply_hover(mat, true))
		body.mouse_exited.connect(func(): _apply_hover(mat, false))
	return inst

func _instance_switch(ctrl_name: String) -> Node3D:
	var inst: Node3D = _switch_scene.instantiate()
	inst.name = ctrl_name
	inst.set_meta("type", "switch")
	inst.set_meta("is_on", false)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.5, 1)
	mat.roughness = 0.7
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.08, 0.1, 1)
	var lever: MeshInstance3D = inst.get_node_or_null("LeverMesh")
	if lever:
		lever.material_override = mat
		inst.set_meta("lever_mesh", lever)
	var base_m: MeshInstance3D = inst.get_node_or_null("BaseMesh")
	if base_m:
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.25, 0.25, 0.3, 1)
		bmat.emission_enabled = true
		bmat.emission = Color(0.03, 0.03, 0.04)
		base_m.material_override = bmat
		base_m.position.y = 0.005
	var body: StaticBody3D = inst.get_node_or_null("Body")
	if body and mat:
		body.mouse_entered.connect(func(): _apply_hover(mat, true))
		body.mouse_exited.connect(func(): _apply_hover(mat, false))
	return inst

func _instance_lever(ctrl_name: String) -> Node3D:
	var inst: Node3D = _lever_scene.instantiate()
	inst.name = ctrl_name
	inst.set_meta("type", "lever")
	inst.set_meta("value", 0.0)
	inst.set_meta("rod_height", 0.2)
	inst.set_meta("handle_radius", 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.55, 1)
	mat.roughness = 0.6
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.1, 0.12, 1)
	var rod: MeshInstance3D = inst.get_node_or_null("RodMesh")
	if rod:
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.3, 0.3, 0.35, 1)
		rmat.emission_enabled = true
		rmat.emission = Color(0.05, 0.05, 0.06)
		rod.material_override = rmat
	var handle: MeshInstance3D = inst.get_node_or_null("HandleMesh")
	if handle:
		handle.material_override = mat
		inst.set_meta("handle_mesh", handle)
	var body: StaticBody3D = inst.get_node_or_null("Body")
	if body and mat:
		body.mouse_entered.connect(func(): _apply_hover(mat, true))
		body.mouse_exited.connect(func(): _apply_hover(mat, false))
	return inst

func _setup_side_panel(panel_root: Node3D, p_side: String, pw: float, ph: float) -> void:
	panel_root.set_meta("type", "side_panel")
	panel_root.set_meta("is_open", false)
	panel_root.set_meta("side", p_side)
	panel_root.set_meta("panel_width", pw)

	var side_sign: float = -1.0 if p_side == "left" else 1.0

	var cover_node: Node3D = panel_root.get_node_or_null("Cover")
	if cover_node == null:
		return

	var cover := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(pw, ph, 0.03)
	cover.mesh = cmesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.3, 1)
	mat.roughness = 0.9
	mat.metallic = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.05, 0.07)
	cover.material_override = mat
	cover_node.add_child(cover)
	cover.position = Vector3.ZERO
	panel_root.set_meta("cover", cover)

	var edge := MeshInstance3D.new()
	var emesh := BoxMesh.new()
	emesh.size = Vector3(0.03, ph, 0.05)
	edge.mesh = emesh
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(0.5, 0.5, 0.55, 1)
	emat.emission_enabled = true
	emat.emission = Color(0.15, 0.15, 0.2)
	edge.material_override = emat
	cover.add_child(edge)
	edge.position = Vector3(side_sign * pw * 0.5, 0, 0)

	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	cover.add_child(body)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(pw + 0.05, ph + 0.05, 0.1)
	cs.shape = shape
	body.add_child(cs)

func _apply_hover(mat: StandardMaterial3D, on: bool) -> void:
	if mat == null:
		return
	var target: Color = Color(0.3, 0.8, 1.0) * 0.5 if on else Color(0.08, 0.08, 0.1)
	var tween := create_tween()
	tween.tween_property(mat, "emission", target, 0.1)

func _play_press(mesh_inst: MeshInstance3D, base_h: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(mesh_inst, "position:y", -0.01, 0.08)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_inst, "position:y", base_h * 0.5, 0.12)

func _toggle_switch(root: Node3D, lever: MeshInstance3D) -> void:
	var is_on: bool = not root.get_meta("is_on")
	root.set_meta("is_on", is_on)
	var target: float = -30.0 if is_on else 30.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(lever, "rotation_degrees:z", target, 0.15)
	var ctrl_name: String = _find_control_name(root)
	control_toggled.emit(is_on, ctrl_name)

func toggle_panel(panel_name: String) -> void:
	var panel_node: Node = _controls.get(panel_name, null)
	if panel_node == null:
		return
	var is_open: bool = panel_node.get_meta("is_open", false)
	var side: String = panel_node.get_meta("side", "left")
	var cover: MeshInstance3D = panel_node.get_meta("cover", null)
	if cover == null:
		return
	var new_open: bool = not is_open
	panel_node.set_meta("is_open", new_open)
	var side_sign: float = -1.0 if side == "left" else 1.0
	var pw: float = panel_node.get_meta("panel_width", 0.4)
	var target_x: float = side_sign * (pw + 0.05) if new_open else 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(cover, "position:x", target_x, 0.4)

func toggle_switch_by_node(switch_node: Node3D) -> void:
	var lever: MeshInstance3D = switch_node.get_meta("lever_mesh") if switch_node.has_meta("lever_mesh") else null
	if lever:
		_toggle_switch(switch_node, lever)

func press_button_by_node(btn_node: Node3D) -> void:
	var mesh_inst: MeshInstance3D = btn_node.get_node_or_null("Mesh")
	if mesh_inst:
		var base_h: float = 0.03
		if mesh_inst.mesh is BoxMesh:
			base_h = mesh_inst.mesh.size.y
		_play_press(mesh_inst, base_h)
	var ctrl_name: String = _find_control_name(btn_node)
	control_interacted.emit(ctrl_name)

func _boost_interior_emission(node: Node3D) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
			if mat and mat.emission_enabled:
				mat.emission = Color(0.25, 0.25, 0.3, 1)

func _add_label(parent: Node3D, text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 12
	label.modulate = Color(0.6, 0.85, 1.0, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.pixel_size = 0.002
	label.outline_modulate = Color(0, 0, 0, 1.0)
	label.outline_size = 4
	parent.add_child(label)
	label.position = pos
	label.rotation_degrees.x = -30
