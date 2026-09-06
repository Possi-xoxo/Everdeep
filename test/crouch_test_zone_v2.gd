extends Node3D
func block(label: String,pos: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.name=label
	add_child(body)
	body.position=pos
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	body.add_child(visual)
func _ready() -> void:
	position=Vector3(45,0,8)
	block("Floor",Vector3(0,-.25,0),Vector3(26,.5,28))
	for item in [["Standing_Clear",-9.0,2.1,2.0],["Low_Beam",-3.0,1.65,.6],["Short_Tunnel",3.0,1.3,5.0],["Too_Low",9.0,.85,3.0]]:
		block(item[0],Vector3(item[1],item[2]+.15,0),Vector3(3,.3,item[3]))
		var sign:=Label3D.new()
		add_child(sign)
		sign.text="%s\n%.2f m clearance"%[item[0],item[2]]
		sign.position=Vector3(item[1],2.5,3)
		sign.font_size=40
	block("Low_Ceiling_Room",Vector3(0,1.45,-8),Vector3(8,.3,6))
	for i in 3: block("Crouch_Curb_"+str(i),Vector3(8,.05*(i+1),-6-i),Vector3(3,.1*(i+1),1))
	block("Curb_Overhang",Vector3(8,1.75,-7),Vector3(4,.3,5))
	block("Crouch_Slope",Vector3(-8,.65,-8),Vector3(3,.3,5))
	get_node("Crouch_Slope").rotation.x=-deg_to_rad(15.0)
	# Dedicated target beside the tunnel, with the existing target contract.
	var target:=Node3D.new()
	target.name="CrouchLockTarget"
	add_child(target)
	target.position=Vector3(3,0,-5)
	target.add_to_group("lock_on_target")
	var point:=Marker3D.new()
	point.name="LockOnPoint"
	target.add_child(point)
	point.position.y=1.0
	var marker:=MeshInstance3D.new()
	var sphere:=SphereMesh.new()
	sphere.radius=.25
	sphere.height=.5
	marker.mesh=sphere
	point.add_child(marker)
