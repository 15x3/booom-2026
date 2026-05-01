extends Node3D

signal control_interacted(control_name: String)
signal control_toggled(is_on: bool, control_name: String)

var _controls: Dictionary = {}
var _external_root: Node3D = null

func _ready() -> void:
	_build_on_scene_nodes()

func set_external_root(root: Node3D) -> void:
	_external_root = root

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

func _find_node(name: String) -> Node3D:
	var search_root: Node = _external_root if _external_root else get_parent()
	if search_root:
		var n: Node3D = search_root.get_node_or_null("Controls/" + name)
		if n and n.get_child_count() > 0:
			return n
	return null

func _build_center() -> void:
	var center: Node3D = get_node_or_null("CenterControls/Controls")

	var ignition: Node3D = _find_node("IgnitionBtn")
	if ignition:
		_setup_button(ignition)
		_register("ignition", ignition)
		if center:
			_add_label(center, "点火", ignition.position + Vector3(0, 0.05, 0))

	var nav: Node3D = _find_node("NavKnob")
	if nav:
		_setup_steering_wheel(nav)
		nav.set_meta("stops", 3)
		_register("nav_knob", nav)
		if center:
			_add_label(center, "导航", nav.position + Vector3(0, 0.06, 0))

	var fuel: Node3D = _find_node("FuelValve")
	if fuel:
		_setup_knob(fuel)
		fuel.set_meta("stops", 4)
		_register("fuel_valve", fuel)
		if center:
			_add_label(center, "燃料", fuel.position + Vector3(0, 0.05, 0))

	var thrust: Node3D = _find_node("ThrustLever")
	if thrust:
		_setup_lever(thrust)
		_register("thrust_lever", thrust)
		if center:
			_add_label(center, "推力", thrust.position + Vector3(0, 0.15, 0))

	if center:
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

	var scan_freq: Node3D = _find_node("ScanFreqKnob")
	if scan_freq:
		_setup_knob(scan_freq)
		_register("scan_freq", scan_freq)
		var interior: Node3D = panel_root.get_node_or_null("Interior")
		if interior:
			_add_label(interior, "调频", scan_freq.position + Vector3(0, 0.04, 0))

	var scan_sw: Node3D = _find_node("ScanSwitch")
	if scan_sw:
		_setup_switch(scan_sw)
		_register("scan_switch", scan_sw)
		var interior2: Node3D = panel_root.get_node_or_null("Interior")
		if interior2:
			_add_label(interior2, "扫描", scan_sw.position + Vector3(0, 0.04, 0))

	for i in range(4):
		var breaker_name: String = "Breaker%d" % (i + 1)
		var breaker: Node3D = _find_node(breaker_name)
		if breaker:
			_setup_switch(breaker)
			_register("breaker_%d" % (i + 1), breaker)

	var interior_lbl: Node3D = panel_root.get_node_or_null("Interior")
	if interior_lbl:
		_add_label(interior_lbl, "B1", Vector3(-0.10, -0.02, 0.02))
		_add_label(interior_lbl, "B2", Vector3(0.02, -0.02, 0.02))
		_add_label(interior_lbl, "B3", Vector3(-0.10, -0.10, 0.02))
		_add_label(interior_lbl, "B4", Vector3(0.02, -0.10, 0.02))

func _build_right_panel() -> void:
	var panel_root: Node3D = get_node_or_null("RightPanel")
	if panel_root == null:
		return
	_setup_side_panel(panel_root, "right", 0.35, 0.4)
	_register("right_panel", panel_root)

	var o2: Node3D = _find_node("O2Valve")
	if o2:
		_setup_switch(o2)
		_register("o2_valve", o2)
		var interior: Node3D = panel_root.get_node_or_null("Interior")
		if interior:
			_add_label(interior, "O2", o2.position + Vector3(0, 0.04, 0))

	var cooling: Node3D = _find_node("CoolingKnob")
	if cooling:
		_setup_knob(cooling)
		cooling.set_meta("stops", 3)
		_register("cooling", cooling)
		var interior2: Node3D = panel_root.get_node_or_null("Interior")
		if interior2:
			_add_label(interior2, "冷却", cooling.position + Vector3(0, 0.04, 0))

func _apply_mat_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child: Node in node.get_children():
		_apply_mat_recursive(child, mat)

func _init_drag_anim(inst: Node3D, initial_value: float = 0.5) -> void:
	inst.set_meta("drag_value", initial_value)
	var anim: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
	if anim and anim.has_animation("drag"):
		anim.play("drag")
		anim.pause()
		anim.seek(initial_value * anim.get_animation("drag").length, true)
		inst.set_meta("anim_player", anim)

func _setup_knob(inst: Node3D) -> void:
	inst.set_meta("type", "knob")
	inst.set_meta("value", 0.0)
	inst.set_meta("stops", 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.45, 1)
	mat.roughness = 0.8
	mat.metallic = 0.3
	var mesh_inst: MeshInstance3D = inst.get_node_or_null("Mesh")
	if mesh_inst:
		_apply_mat_recursive(mesh_inst, mat)
		inst.set_meta("knob_mesh", mesh_inst)
	var sketchfab: Node = inst.get_node_or_null("Sketchfab_Scene")
	if sketchfab:
		_apply_mat_recursive(sketchfab, mat)
	_init_drag_anim(inst, 0.5)

func _setup_steering_wheel(inst: Node3D) -> void:
	inst.set_meta("type", "knob")
	inst.set_meta("value", 0.0)
	inst.set_meta("stops", 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.18, 1)
	mat.roughness = 0.4
	mat.metallic = 0.6
	var mesh_inst: MeshInstance3D = inst.get_node_or_null("Mesh")
	if mesh_inst:
		_apply_mat_recursive(mesh_inst, mat)
		inst.set_meta("knob_mesh", mesh_inst)
	var sketchfab: Node = inst.get_node_or_null("Sketchfab_Scene")
	if sketchfab:
		_apply_mat_recursive(sketchfab, mat)
	_init_drag_anim(inst, 0.5)

func _setup_button(inst: Node3D) -> void:
	inst.set_meta("type", "button")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.15, 0.1, 1)
	mat.roughness = 0.7
	mat.metallic = 0.3
	var mesh_inst: MeshInstance3D = inst.get_node_or_null("MeshInstance3D")
	if mesh_inst:
		_apply_mat_recursive(mesh_inst, mat)
		inst.set_meta("button_mesh", mesh_inst)
	var sketchfab: Node = inst.get_node_or_null("Sketchfab_Scene")
	if sketchfab:
		_apply_mat_recursive(sketchfab, mat)
	var anim: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
	if anim:
		anim.autoplay = ""
		anim.stop()

func _setup_switch(inst: Node3D) -> void:
	inst.set_meta("type", "switch")
	inst.set_meta("is_on", false)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.5, 1)
	mat.roughness = 0.7
	mat.metallic = 0.4
	var lever: MeshInstance3D = inst.get_node_or_null("LeverMesh")
	if lever:
		lever.material_override = mat
		inst.set_meta("lever_mesh", lever)
	var base_m: MeshInstance3D = inst.get_node_or_null("BaseMesh")
	if base_m:
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.25, 0.25, 0.3, 1)
		base_m.material_override = bmat

func _setup_lever(inst: Node3D) -> void:
	inst.set_meta("type", "lever")
	inst.set_meta("value", 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.55, 1)
	mat.roughness = 0.6
	mat.metallic = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.08, 0.1)
	mat.emission_energy_multiplier = 0.3
	var rod: MeshInstance3D = inst.get_node_or_null("RodMesh")
	if rod:
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.3, 0.3, 0.35, 1)
		rmat.emission_enabled = true
		rmat.emission = Color(0.05, 0.05, 0.06)
		rmat.emission_energy_multiplier = 0.3
		rod.material_override = rmat
	var handle: MeshInstance3D = inst.get_node_or_null("HandleMesh")
	if handle:
		handle.material_override = mat
		inst.set_meta("handle_mesh", handle)
	_init_drag_anim(inst, 0.0)

func _setup_side_panel(panel_root: Node3D, p_side: String, pw: float, ph: float) -> void:
	panel_root.set_meta("type", "side_panel")
	panel_root.set_meta("is_open", false)
	panel_root.set_meta("side", p_side)
	panel_root.set_meta("panel_width", pw)

	var side_sign: float = -1.0 if p_side == "left" else 1.0

	var cover_node: Node3D = panel_root.get_node_or_null("Cover")
	if cover_node == null:
		return

	var existing_cover: MeshInstance3D = null
	for child: Node in cover_node.get_children():
		if child is MeshInstance3D:
			existing_cover = child
			break

	if existing_cover:
		panel_root.set_meta("cover", existing_cover)
	else:
		var cover := MeshInstance3D.new()
		var cmesh := BoxMesh.new()
		cmesh.size = Vector3(pw, ph, 0.03)
		cover.mesh = cmesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.25, 0.3, 1)
		mat.roughness = 0.9
		mat.metallic = 0.2
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

func _play_press(mesh_inst: MeshInstance3D, base_h: float) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(mesh_inst, "position:y", base_h - 0.01, 0.08)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_inst, "position:y", base_h, 0.12)

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
	var mesh_inst: MeshInstance3D = null
	if btn_node.has_meta("button_mesh"):
		mesh_inst = btn_node.get_meta("button_mesh")
	if mesh_inst == null:
		mesh_inst = btn_node.get_node_or_null("MeshInstance3D")
	if mesh_inst == null:
		mesh_inst = btn_node.get_node_or_null("Mesh")
	if mesh_inst:
		var base_h: float = mesh_inst.position.y
		_play_press(mesh_inst, base_h)
	var ctrl_name: String = _find_control_name(btn_node)
	control_interacted.emit(ctrl_name)

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
