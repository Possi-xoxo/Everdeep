extends "res://test/mantle_test_zone_v2.gd"
func _ready() -> void:
	position=Vector3(150,0,-10)
	var floor_body:=block("Floor",Vector3(0,-.25,0),Vector3(50,.5,30))
	floor_body.get_child(1).position.y=-.007
	block("BroadPlatform",Vector3(-15,1,0),Vector3(4,2,4))
	add_sign("SUPPORT EDGE / COYOTE",Vector3(-15,3,3))
	block("SupportedBeam",Vector3(-7,1,0),Vector3(.5,2,6))
	add_sign("0.50m beam\nNarrower than body",Vector3(-7,3,4))
	block("UnsupportedBeam",Vector3(0,1,0),Vector3(.15,2,6))
	add_sign("0.15m beam\nInsufficient footprint",Vector3(0,3,4))
	block("MantleSupport",Vector3(7,.875,0),Vector3(3,1.75,2))
	add_sign("1.75m mantle / 0.15m landing",Vector3(7,2.6,2))
	block("NarrowMantle",Vector3(14,.875,0),Vector3(.5,1.75,2))
	add_sign("Narrow mantle top",Vector3(14,2.6,2))
	add_sign("GROUND SUPPORT LAB\nEnable GroundSupportProbe debug\nStairs / slopes / curbs: existing STEP LAB west",Vector3(0,2,10))
