extends "res://interaction/context_interactable.gd"
signal activated(tower_id: String)
@export var tower_id: String="A"
var lit: bool=false
var material: StandardMaterial3D
var label: Label3D

func _ready() -> void:
	action_text="Activate Tower %s Summit Orb"%tower_id
	priority=2
	var marker:=Marker3D.new()
	marker.name="InteractionPoint"
	add_child(marker)
	var visual:=MeshInstance3D.new()
	var mesh:=SphereMesh.new()
	mesh.radius=.32; mesh.height=.64
	visual.mesh=mesh
	material=StandardMaterial3D.new()
	material.emission_enabled=true
	visual.material_override=material
	add_child(visual)
	label=Label3D.new()
	label.position.y=.7
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=32; label.pixel_size=.006
	add_child(label)
	reset_activation()
	super._ready()

func begin_interaction(player: Node) -> bool:
	if not super.begin_interaction(player): return false
	lit=true; available=false
	material.emission_energy_multiplier=3
	label.text="TOWER %s ORB ACTIVATED"%tower_id
	print(label.text)
	activated.emit(tower_id)
	return true

func reset_activation() -> void:
	lit=false; available=true; activation_count=0
	if material==null: return
	material.albedo_color=Color(1,.62,.15) if tower_id=="A" else Color(.2,.75,1)
	material.emission=material.albedo_color
	material.emission_energy_multiplier=.45
	label.text="TOWER %s SUMMIT\nE: Activate orb"%tower_id
