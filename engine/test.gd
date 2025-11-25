@tool
extends Node3D

@export var test = false:
	set(v):
		if Engine.is_editor_hint():
			test = v
			for c in $a.get_children():
				c.free()

@export_tool_button("TEST") var test_func = testing

func testing():
	for c in $a.get_children():
		c.free()

func nearest_pos(height:int,width:int,call_func:Callable):
	for r in width:
		var y = -height
		var a = Vector3(-r,y,-r)
		var b = Vector3(r,y,-r)
		while y <= height:
			if y == -height or y == height:
				for x in range(-r,r+1):
					for z in range(-r,r+1):
						call_func.call(Vector3(x,y,z))
				y += 1
				a = Vector3(-r,y,-r)
				b = Vector3(r,y,r)
			elif a.x < r:
				a.x += 1
				call_func.call(a)
			elif a.z < r:
				a.z += 1
				call_func.call(a)
			elif b.x > -r:
				b.x -= 1
				call_func.call(a)
			elif b.z > -r:
				b.z -= 1
				call_func.call(a)
			else:
				y += 1
				a = Vector3(-r,y,-r)
				b = Vector3(r,y,r)

func label(pos,text,color=Color(1,1,1)):
	var l = Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.text = str(text)
	l.modulate = color
	$a.add_child(l)
	l.owner = $a.owner
	l.global_position = pos
