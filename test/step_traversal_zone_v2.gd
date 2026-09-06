extends "res://test/player_v2_lab.gd"
## Separate east wing, preserving every original lab obstacle and test coordinate.
func _ready() -> void:
	_box("StepZoneFloor",Vector3(77,-0.25,-10),Vector3(100,0.5,80),Color(0.22,0.28,0.30))
	_label("STEP TRAVERSAL LAB — F4 probes — approach from +Z",Vector3(66,1,16))
	for i in 10:
		var h := (i+1)*0.05
		var x := 38.0+i*6.0
		_box("Curb%02d" % ((i+1)*5),Vector3(x,h/2,0),Vector3(3,h,8),Color(0.25,0.55,0.38) if h<=0.35 else Color(0.65,0.32,0.25))
		_label("%d cm" % ((i+1)*5),Vector3(x,h,4.8))
	for i in 3:
		var h := 0.10+i*0.05
		var x := 42.0+i*10.0
		for n in 6:
			_box("Stairs%d_%d" % [i,n],Vector3(x,(n+1)*h/2,-22-n*0.6),Vector3(4,(n+1)*h,0.6),Color(0.35,0.42+i*0.08,0.6))
		_box("StairLanding%d" % i,Vector3(x,3*h,-29),Vector3(4,6*h,7.4),Color(0.35,0.5,0.6))
		_label("6 x %d cm / 60 cm treads" % roundi(h*100),Vector3(x,0.2,-19))
	_box("DiagonalCurb",Vector3(105,0.1,0),Vector3(6,0.2,4),Color.CADET_BLUE)
	get_node("DiagonalCurb").rotation.y = deg_to_rad(35)
	_label("35 degree diagonal / 20 cm",Vector3(105,0.4,5))
	_box("NarrowCurb",Vector3(115,0.1,0),Vector3(0.25,0.2,6),Color.CORAL)
	_label("Narrow edge",Vector3(115,0.4,5))
	_box("TallWall",Vector3(78,1.5,-24),Vector3(5,3,1),Color.INDIAN_RED)
	_label("WALL — reject",Vector3(78,0.2,-20))
	_box("CeilingCurb",Vector3(88,0.1,-24),Vector3(4,0.2,5),Color.CADET_BLUE)
	_box("LowCeiling",Vector3(88,2.05,-24),Vector3(5,0.3,7),Color.INDIAN_RED)
	_label("1.90 m ceiling / 20 cm curb — reject",Vector3(88,0.2,-19))
	_ramp("ComparisonRamp",Vector3(100,0,-25),4,8,0.35,Color.SEA_GREEN)
	_label("Shallow ramp",Vector3(100,0.2,-19))
	_box("SlopedTop",Vector3(111,0.20,-24),Vector3(4,0.2,4),Color.GOLDENROD)
	get_node("SlopedTop").rotation.x = deg_to_rad(12)
	_label("12 degree top",Vector3(111,0.2,-19))
	_box("SteepTop",Vector3(120,0.20,-24),Vector3(3,0.15,0.7),Color.INDIAN_RED)
	get_node("SteepTop").rotation.x = deg_to_rad(55)
	_label("55 degree top — reject",Vector3(120,0.2,-19))
	_box("SupportedNarrowCurb",Vector3(100,0.1,18),Vector3(0.4,0.2,4),Color.SEA_GREEN)
	_label("40 cm wide / 20 cm high — test both sides",Vector3(100,0.4,22))
	_box("CornerRefinementCurb",Vector3(110,0.1,18),Vector3(3,0.2,3),Color.CADET_BLUE)
	_label("20 cm corner — diagonal entry",Vector3(110,0.4,22))
	_box("UnsafeThinRefinement",Vector3(120,0.1,18),Vector3(0.15,0.2,4),Color.CORAL)
	_label("15 cm rail — reject both sides",Vector3(120,0.4,22))
