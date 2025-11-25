extends Node

var max_limit = 5000
var explore = {}
var nodes = []
var time = 0
var player

var markers = {
	"max":Vector3(),
	"min":Vector3(),
	"box":null,
}

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	player = owner.player
#mark
	get_node("../nodeextractor").pressed.connect(func():
		clear()
		if player.pointing.type == "node":
			explore = [round(player.pointing.pos)]
			nodes.clear()
			markers.max = Vector3(-100000,-100000,-100000)
			markers.min = Vector3(100000,100000,100000)
			set_process(true)
	)
	get_node("../nodeextractor_clear").pressed.connect(func():
		set_process(false)
		clear()
	)
#save
	get_node("../nodeextractor_save").pressed.connect(func():
		var reg = owner.to_item()
		if reg != null:
			var listed = {}
			var i = 1
			var list = []
			var size = markers.box.scale
			var meta = {}
			list.resize(size.x*size.y*size.z)
			list.fill(0)
			var index = 0
			for x in size.x:
				for y in size.y:
					for z in size.z:
						var p = Vector3(x,y,z)
						var rel = markers.min+p
						var node = core.getnode(rel)
						if node.name != "air":
							var n = {"name":node.name,"meta":core.world.get_node_meta(rel)}
							if listed.has(n.name) == false:
								listed[n.name] = i
								i += 1
							list[index] = listed[n.name]
							if n.meta.size() > 0:
								meta[p] = n.meta
						index += 1
			core.savefile(str("user://nodeextractor/",reg.name,".nex"),{
				"name":reg.name,
				"size":markers.box.scale,
				"node_list":reg.list,
				"list":list,
				"meta":meta,
			})
			owner.update()
	)
#set
	get_node("../nodeextractor_set").pressed.connect(func():
		var current = owner.get("current")
		if current != null and current.has("name"):
			var pos
			var path
			if player.pointing.type == "node":
				pos = player.pointing.outside
			else:
				pos = round(player.body.global_position)
			if FileAccess.file_exists(str("user://nodeextractor/",current.name,".nex")):
				path = str("user://nodeextractor/",current.name,".nex")
			elif FileAccess.file_exists(str("res://res/nodeextractor/",current.name,".nex")):
				path = str("res://res/nodeextractor/",current.name,".nex")
			core.set_nodeextractor(path,pos)
	)
func clear():
	set_process(false)
	explore.clear()
	nodes.clear()
	if markers.box != null:
		markers.box.queue_free()
	markers.box = null
func loadfile(file):
	var save = core.loadfile(file)
	if save != null:
		return {
			"name":save.name,
			"size":{"readonly":str(int(save.size.x),", ",int(save.size.y),", ",int(save.size.z))},
			"count":{"readonly":str(save.list.size())},
			"list":save.node_list,
		}
	return {}
func update_form():
	var c = owner.to_item()
	var listed = ["air"]
	var size = markers.box.scale
	for x in size.x:
		for y in size.y:
			for z in size.z:
				var node = core.getnode(markers.min+Vector3(x,y,z))
				if node.name != "air" and listed.has(node.name) == false:
					listed.push_back(node.name)
	var def = {
		"name":"" if c == null or c.has("name") == false else c.name,
		"size":{"readonly":str(int(size.x),", ",int(size.y),", ",int(size.z))},
		"count":{"readonly":str(nodes.size())},
		"list":listed,
	}
	owner.from_item("",def)

func _process(delta: float) -> void:
	if explore.size() > 0:
		time -= delta
		if time < 0:
			time = 0.01
			var explore2 = []
			
			for pos in explore:
				for x in range(-1,2):
					for y in range(-1,2):
						for z in range(-1,2):
							var p = pos+Vector3(x,y,z)
							var node = core.getnode(p)
							var reg = core.registered_items[node.name]
							if nodes.has(p) == false and reg.solid:
								if markers.box == null:
									add_box(0,p)
								markers.max = markers.max.max(p)
								markers.min = markers.min.min(p)
								markers.box.global_position = (markers.min+abs(markers.max-markers.min)/2) + core.pos_margin
								markers.box.scale = abs(markers.min-markers.max)+Vector3(1,1,1)
								nodes.push_back(p)
								explore2.push_back(p)
			explore = explore2
			if explore.size() == 0 or nodes.size() > max_limit:
				set_process(false)
				update_form()

func add_box(n,pos):
	var m = MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	var mat = StandardMaterial3D.new()
	var texture
	if n == 0:
		texture = "res://res/textures/nodeextractor/nodeextractor_mark.png"
		if is_instance_valid(markers.box):
			markers.box.queue_free()
		markers.box = m
	mat.albedo_texture = load(texture)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.set_surface_override_material(0,mat)
	core.add_to_map(m,pos)
	
