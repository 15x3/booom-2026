extends Node3D

var _particles: GPUParticles3D = null
var _flash: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _lifetime: float = 0.8
var _elapsed: float = 0.0
var _is_boss: bool = false
var _shard_color: Color = Color(1.0, 0.7, 0.2)

func setup(color: Color, is_boss: bool, lifetime: float = 0.8) -> void:
	_shard_color = color
	_is_boss = is_boss
	_lifetime = lifetime

func _ready() -> void:
	_create_flash()
	_create_particles()
	if _is_boss:
		_create_ring()

func _create_flash() -> void:
	_flash = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	_flash.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy = 4.0
	_flash.material_override = mat
	add_child(_flash)
	_flash.scale = Vector3.ONE * 0.1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_flash, "scale", Vector3.ONE * 2.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15).set_trans(Tween.TRANS_LINEAR)

func _create_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.emitting = true
	_particles.one_shot = true
	_particles.explosiveness = 0.9
	_particles.randomness = 0.8
	_particles.lifetime = _lifetime * 0.6
	var count := 20 if _is_boss else 12
	_particles.amount = count
	_particles.local_coords = false

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	_particles.draw_pass_1 = mesh

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.3
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 180.0
	proc.gravity = Vector3(0, -5.0, 0)
	proc.initial_velocity_min = 3.0
	proc.initial_velocity_max = 8.0
	proc.scale_min = 0.3
	proc.scale_max = 1.0
	proc.damping_min = 2.0
	proc.damping_max = 4.0

	var grad := Gradient.new()
	grad.colors = PackedColorArray([_shard_color, Color(_shard_color.r, _shard_color.g, _shard_color.b, 0.0)])
	grad.offsets = PackedFloat32Array([0.3, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	proc.color_ramp = grad_tex
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	proc.scale_curve = scale_tex

	_particles.process_material = proc
	add_child(_particles)

func _create_ring() -> void:
	_ring = MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.1
	ring_mesh.bottom_radius = 0.1
	ring_mesh.height = 0.05
	_ring.mesh = ring_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy = 3.0
	_ring.material_override = mat
	_ring.rotation.x = deg_to_rad(90.0)
	add_child(_ring)
	_ring.scale = Vector3.ONE * 0.1
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_ring, "scale", Vector3(8.0, 8.0, 8.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_trans(Tween.TRANS_LINEAR)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
