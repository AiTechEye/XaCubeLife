extends Node
#await get_tree().create_timer(1).timeout
#await get_tree().process_frame


#var t = int(Time.get_unix_time_from_system()*1000)+1000
#while t > int(Time.get_unix_time_from_system()*1000):
	#await get_tree().process_frame
	#print(11)

signal GameLoaded
var settings = {
		#"current_mapgen":"flatland",
		"current_mapgen":"lakes",
		#"current_mapgen":"test",
		"inventory_3D_images":true,
		"ganerate_chunk_range":6,
		"save_timeout":5,
		"unload_chunk_distance":20,
		"item_drop_timeout":300,
		"base_size":16,
	}
	
var sounds = {
	"grass":load("res://res/sounds/step/grass.ogg"),
	"stone":load("res://res/sounds/step/stone.ogg"),
	"sand":load("res://res/sounds/step/sand.ogg"),
	"wood":load("res://res/sounds/step/wood.ogg"),
	"snow":load("res://res/sounds/step/snow.ogg"),
	"clay":load("res://res/sounds/step/clay.ogg"),
	"leaves":load("res://res/sounds/step/leaves.ogg"),
}
var temp = {"sounds":{}}
var is_debug = false
var Game = false
var save_file = "save.dat"
var save = {}
var current_id = 0
var players = {}
var objects = {}
var world
var pos_margin = Vector3(0.5,0.5,0.5)
var content_id_to_name = []
var item3Dimg
var registered_items = {}
var craft_resepts = []

func node_setup(pos,id):
	var reg = registered_items[content_id_to_name[id]]
	if reg.has("on_construct"):
		reg.on_construct.call(pos)

func node_handling(pos,type="",player_id:int=-1):
	if pos != null:
		var reg = registered_items[getnode(pos).name]
		if type == "activate" and reg.has("on_activate"):
			return reg.on_activate.call(pos,player_id)
		elif type == "punch" and reg.has("on_punch"):
			return reg.on_punch.call(pos,player_id)
		elif type == "before_place" and reg.has("on_destruct"):
			reg.on_destruct.call(pos,player_id)
			#return true
		elif type == "place" and reg.has("on_place"):
			reg.on_place.call(pos,player_id)
		elif type == "can_break" and reg.has("can_break"):
			return reg.can_break.call(pos,player_id)
		return true

func _ready() -> void:
	is_debug = OS.is_debug_build()
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var m = StandardMaterial3D.new()
	m.albedo_texture = load(world.default_node.texture)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.default_node.material = m

func save_setup(def:Dictionary):
	return {
		"date_created":"",
		"date_last_played":"",
		"nodes":{},
		"node_meta":{},
		"objects":{},
		"contenteditor":{"items":{},"mapgen_scatter":{}},
		"mapseed":def.mapseed,
		"mapgen":def.mapgen
	}

func game_setup():
	for reg_name in content.items:
		register_item(reg_name,content.items[reg_name])
	for reg_name in save.contenteditor.items:
		register_item(reg_name,save.contenteditor.items[reg_name])
	for scatter in save.contenteditor.mapgen_scatter.values():
		mapgen.register_scatter(scatter)

	load_features()	
	settings.current_mapgen = save.mapgen
	Game = true
	GameLoaded.emit()
	new_player(Vector3(0,2,0))

func register_item(reg_name,def,reset=false):
	def = def.duplicate()
	var new = !registered_items.has(reg_name)
	if reset:
		new = true
		registered_items.erase(reg_name)

	def.name = reg_name
	
	if def.has("max_count") == false:
		def.max_count = 100
	else:
		def.max_count = int(def.max_count)
	if def.has("groups") == false:
		def.groups = {}
	if def.has("speed") == false:
			def.speed = 1
	if def.has("scale") == false:
		def.scale = 1.0

#craft==================
	if def.has("craft") and def.craft.has("recipe"):
		if def.craft.recipe.size() != 9:
			def.craft.recipe.resize(9)
		for ii in 2:
			if def.craft.recipe[0] == "" and def.craft.recipe[3] == "" and def.craft.recipe[6] == "":
				var s = def.craft.recipe.size()
				def.craft.recipe.pop_at(0)
				def.craft.recipe.resize(s)
		for k in def.craft.recipe.size():
			if def.craft.recipe[k] == null:
				def.craft.recipe[k] = ""
		if new == false:
			for c in craft_resepts:
				if c.item == reg_name:
					craft_resepts.erase(c)
					break
		craft_resepts.push_back({
			"item":reg_name,
			"count":def.craft.count if def.craft.has("count") else 1,
			"recipe":def.craft.recipe
		})
	
##nodes===========
	if def.has("type") and def.type == "node":
		def.id = content_id_to_name.size()
		content_id_to_name.push_back(def.name)
#drop
		if def.has("drop") == false:
			def.drop = {}
		if def.drop.has("item") == false:
			def.drop.item = def.name
		if def.drop.has("count") == false:
			def.drop.count = 1

#pointable
		if def.has("pointable") == false:
			def.pointable = true
#physics
		if def.has("solid") == false:
			def.solid = true
		if def.has("viscosity") == false:
			def.viscosity = 0
		if def.has("gravity") == false:
			def.gravity = 1
		if def.has("fluid") == false:
			def.fluid = false
#dynamic
		if def.has("dynamic") == false:
			def.dynamic = false
#replaceable
		if def.has("replaceable") == false:
			def.replaceable = false
#drawtype
		if def.has("drawtype") == false:
			def.drawtype = "default"
		if def.has("node_type") == false:
			def.node_type = "default"
		if def.node_type == "liquid":
			def.drawtype = "liquid"
			
#transparency
		if def.has("transparency") == false:
			def.transparency = "none"
#tiles
		if def.has("tiles") == false:
			def.tiles = [world.default_node.texture]
#inv_image
		if def.has("inv_image"):
			def.inv_image = load(def.inv_image)
		elif def.tiles.size() > 0:
			def.inv_image = load(def.tiles[0])
		else:
			def.inv_image = load("res://res/textures/default.png")
#light
		if def.has("light_energy") and def.has("light_color") == false:
			def.light_color = Color(1,1,1)
		elif def.has("light_energy") == false and def.has("light_color"):
			def.light_energy = 1
			
			
#sounds
		if def.has("sounds") == false:
			def.sounds = {}
		def.sounds = {
			"step":def.sounds.step if def.sounds.has("step") else "res://res/sounds/step/stone.ogg",
			"dig":def.sounds.dig if def.sounds.has("dig") else "res://res/sounds/place_dig/stone_dig.ogg",
			"dug":def.sounds.dug if def.sounds.has("dug") else "res://res/sounds/place_dig/stone_dug.ogg",
			"place":def.sounds.place if def.sounds.has("place") else "res://res/sounds/place_dig/place.ogg",
		}	
#tiles
		def.materials = []
		for t in def.tiles.size():
			var mat
			if new or new == false and t >= registered_items[reg_name].materials.size():
				mat = StandardMaterial3D.new()
			else:
				mat = registered_items[reg_name].materials[t]
			if def.has("color_overlay"):
				mat.albedo_color = def.color_overlay
			else:
				mat.albedo_color = Color(1,1,1)
			mat.albedo_texture = load(def.tiles[t])
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if def.transparency == "alpha":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			elif def.transparency == "scissor":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			if def.drawtype == "simple_cross" or def.drawtype == "boxed_cross":
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if def.has("shading") and def.shading == false:
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			else:
				def.shading = false
			if def.has("uv_scale"):
				mat.uv1_scale = Vector3(1/def.uv_scale.x,1/def.uv_scale.y,1)
			def.materials.push_back(mat)
		if def.has("animation"):
			if def.animation.has("speed") == false:
				def.animation.speed = 1.0
			else:
				def.animation.speed = float(def.animation.speed)
			if def.animation.has("frames") == false:
				def.animation.frames = Vector3(0,1,0)
			else:
				def.animation.frames = Vector3(def.animation.frames.x,def.animation.frames.y,0)
			def.animation.size = Vector3()
			if def.animation.frames.x != 0:
				def.animation.size.x = 1/def.animation.frames.x
			if def.animation.frames.y != 0:
				def.animation.size.y = 1/def.animation.frames.y
			if def.animation.has("tile") == false:
				def.animation.tile = 0
			def.animation.curr_frame = Vector3()
			def.animation.material = def.materials[def.animation.tile]
			def.animation.time = 0
			world.material_animation[def.name] = def.animation
		elif world.material_animation.has(def.name):
			world.material_animation.erase(def.name)
			
	else:
##items===========
		def.type = "item"
		if def.has("durability") or def.has("tool_ability"):
			def.max_count = 1
		if def.has("inv_image"):
			var img = load(def.inv_image)
			var orgpath = img.resource_path
			
			if def.has("color_overlay"):
				img = gui.colorize_texture(img,def.color_overlay)
				img.set_meta("res_path",orgpath)
			def.inv_image = img
		if def.has("wield_image"):
			var img = load(def.wield_image)
			var orgpath = img.resource_path
			if def.has("color_overlay"):
				img = gui.colorize_texture(img,def.color_overlay)
				img.set_meta("res_path",orgpath)
			def.wield_image = img
		elif def.has("inv_image"):
			def.wield_image = def.inv_image
		else:
			def.wield_image = load("res://res/textures/default.png")
		if def.has("sounds") == false:
			def.sounds = {}
		def.sounds = {
			"break":def.sounds.break if def.sounds.has("break") else "res://res/sounds/misc/toolbreak.ogg",
		}	
	registered_items[reg_name] = def
	
func getnode(pos:Vector3):
	var node_name = content_id_to_name[world.get_node_id(pos)]
	var reg = registered_items[node_name]
	if reg.dynamic:
		var lid = world.to_local_id(pos)
		var a = world.chunks[world.tochunkpos(pos)].dynamic_nodes[lid]
		return {"name":node_name,"meshinstance":a.meshinstance,"collision":a.collision}
	return {"name":node_name}

func setnode(pos:Vector3,node_name:String):
	if registered_items.has(node_name):
		save.nodes[pos] = node_name
		world.set_node_id(pos,registered_items[node_name].id)

func add_to_map(node,pos=null):
	var w = world.get_node("map")
	w.add_child(node)
	node.owner = w.owner
	if pos != null:
		node.global_position = pos
func add_to_player(player_id:int,node,ui=false,pos=null):
	var body = players[player_id].body
	if ui:
		body = body.get_node("ui/gui")
	body.add_child(node)
	node.owner = body.owner
	if pos != null:
		node.global_position = pos

func to_facedir(v:Vector3):
	return v/abs(v)

func mark(pos,color=Color(1,1,0),remove=-1):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var m = MeshInstance3D.new()
	m.mesh = PlaneMesh.new()
	m.mesh.orientation = PlaneMesh.FACE_Z
	m.mesh.size = Vector2(0.1,0.1)
	m.material_override = mat
	add_to_map(m,pos)
	if remove > -1:
		if remove == 0:
			await get_tree().process_frame
		else:
			await get_tree().create_timer(remove).timeout
		m.free()
	
func label(pos,text):
	var l = Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.text = str(text)
	world.get_node("world").add_child(l)
	l.owner = world.get_node("world").owner
	l.global_position = pos+pos_margin


func get_object(id):
	return objects[id]

func new_player(pos:Vector3=Vector3(0,10,0),player_name:String="ASDASD"):
	current_id += 1
	var id = current_id
	var player = {
		"player":true,
		"type":"player",
		"name":player_name,
		"id":id,
		"pointing":null,
		"last_index":0,
		"right_side_locked":false,
		"left_side_locked":false,
		"last_step_sound":"res://res/sounds/step/stone.ogg",
		"hands":{
			"right_side":false,
			"right":{
				"item":"",
				"bar_slot":null,
				"hotbar_index":7,
				"mesh":null
			},
			"left":{
				"item":"",
				"bar_slot":null,
				"hotbar_index":0,
				"mesh":null
			}
		},
		"contenteditor":{
			"showing":false,
		},
		"formspec":{
			"last":null,
			"form":null,
			"showing":false,
			"background":{"size":Vector2(8,8)},
			"inv":[
				{"name":"main","ref":id,"pos":Vector2(0,4),"size":Vector2(8,4)},
				{"name":"craft","ref":id,"pos":Vector2(2,0.5),"size":Vector2(3,3)},
				{"name":"craftoutput","ref":id,"pos":Vector2(6,1.5),"size":Vector2(1,1)},
			],
			"inv_callbacks":{
				"craftoutput.allow_put":func(_stack,_from_inv,_index):
			return,
				"craft.allow_take":func(stack,_to_inv,_index):
			return stack,
				"craft.on_put":func(_stack,_index):
			stuff.inv_set_item(get_caft_recipe_result(id,"craft"),"craftoutput",id),
				"craft.on_take":func(_stack,_index):
			stuff.inv_set_item(get_caft_recipe_result(id,"craft"),"craftoutput",id),
				"craftoutput.on_take":func(_stack,_index):
			for i in 9:
				stuff.inv_take_item(null,"craft",id,i)
			stuff.inv_set_item(get_caft_recipe_result(id,"craft"),"craftoutput",id),
				"craft.on_gui_open":func():
			stuff.inv_set_item(get_caft_recipe_result(id,"craft"),"craftoutput",id),
			}
		},
		"inventory":{
			"main":stuff.new_inventory(32),
			"craft":stuff.new_inventory(9),
			"craftoutput":stuff.new_inventory(1),
			"right_hand":stuff.new_inventory(1),
			"left_hand":stuff.new_inventory(1)
		},
		"hotbar_count":8,
		"body":load("res://game/player//player.tscn").instantiate(),
		"meta":{}
	}
	player.body.id = id
	players[id] = player
	objects[id] = player
	
	if save.objects.has(player_name):
		pos = save.objects[player_name].pos
		player.inventory = save.objects[player_name].inventory
		for inv_name in player.inventory:
			stuff.inv_clear_invalid_items(id,inv_name)
	else:
		save.objects[player_name] = {"inventory":{}}
	
	add_to_map(player.body,pos)
	await get_tree().process_frame
	
	var bar = player.body.get_node("ui/hotbar")
	bar.size.x *= 8
	var vs = gui.viewport_size(id)
	var size = (vs/2) - (bar.size/2)
	bar.position = Vector2(size.x,vs.y-bar.size.y)

	player.hands.right.bar_slot = player.body.get_node("ui/hotbar/slotr")
	player.hands.left.bar_slot = player.body.get_node("ui/hotbar/slotl")
	player.hands.right.mesh = player.body.get_node("head/camera/right/hand/item")
	player.hands.left.mesh = player.body.get_node("head/camera/left/hand/item")
	
	stuff.inv_add_item("wieldhand","right_hand",id)
	stuff.inv_add_item("wieldhand","left_hand",id)
	
	player.hands.right.bar_slot.texture = gui.colorize_texture(player.hands.right.bar_slot.texture,Color(1,1,1,0.3),true)
	player.hands.left.bar_slot.texture = gui.colorize_texture(player.hands.left.bar_slot.texture,Color(1,1,1,0.3),true)
	
	gui.update_hotbar(id)
	gui.update_wielditems(0,id)
	
func new_object(type:String="none",pos:Vector3=Vector3(),body=Node3D.new()):
	current_id += 1
	var id = current_id
	var object = {
		"name":"",
		"player":false,
		"type":type,
		"id":id,
		"last_step_sound":"res://res/sounds/step/stone.ogg",
		"inventory":{
			"main":stuff.new_inventory(32),
		},
		"meta":{},
		"body":body,
	}
	body.id = id
	objects[id] = object
	add_to_map(object.body,pos)
	return object

func delete_object(ref):
	if typeof(ref) == TYPE_INT and objects.has(ref):
		ref = objects[ref]
	elif is_instance_valid(ref) and ref.get("id") != null:
		ref = objects[ref.id]
	if typeof(ref) == TYPE_DICTIONARY and ref.has("id") and objects.has(ref.id):
		ref.body.set_process(false)
		ref.body.set_physics_process(false)
		ref.body.queue_free()
		objects.erase(ref.id)

func get_reg(variant):
	var reg_name
	if typeof(variant) == TYPE_VECTOR3:
		reg_name = getnode(variant).name
	elif typeof(variant) == TYPE_STRING:
		reg_name = variant
	else:
		reg_name = "air"
	if registered_items.has(reg_name):
		return registered_items[reg_name]
	return {}

func item_sound(pos,type="step",id=-1):
	if type == "break":
		play_sound("res://res/sounds/misc/tool_breaks.ogg",pos)
		return
	var node_name = getnode(pos).name
	var reg = registered_items[node_name]
	if type == "step":
		var sound = reg.sounds.step
		if objects.has(id):
			if sound == "" :
				sound = objects[id].last_step_sound
			else:
				objects[id].last_step_sound = sound
		play_sound(sound,pos)
	elif type == "dig":
		play_sound(reg.sounds.dig,pos)
	elif type == "dug":
		play_sound(reg.sounds.dug,pos)
	elif type == "place":
		play_sound(reg.sounds.place,pos)

func play_sound(sound:String,position:Vector3,pitch=randf_range(0.9,1.1),distance=50):
	if temp.sounds.has(sound) == false:
		if FileAccess.file_exists(sound) == false:
			return
		temp.sounds[sound] = load(sound)
	var s = AudioStreamPlayer3D.new()
	s.position = position
	s.max_distance = distance
	add_to_map(s)
	s.stream = temp.sounds[sound]
	s.pitch_scale = pitch
	s.playing = true
	await s.finished
	s.queue_free()

func get_caft_recipe_result(ref,inv_name):
	var inv = stuff.get_inventory(ref,inv_name).duplicate()
	var count = 1
	var item

#sort empty lots
	var inv_num = 0
	for i in inv:
		if i != null:
			inv_num += 1
	if inv_num == 1:
		inv.sort_custom(func(a,b):
			return a != null and b == null
		)
	else:
		for i in 2:
			if inv[0] == null and inv[3] == null and inv[6] == null:
				var s = inv.size()
				inv.pop_at(0)
				inv.resize(s)
			if inv[0] == null and inv[1] == null and inv[2] == null:
				var s = inv.size()
				inv.pop_at(0)
				inv.pop_at(0)
				inv.pop_at(0)
				inv.resize(s)
	for craft in craft_resepts:
		var i = -1
		item = craft.item
		for item_name in craft.recipe:
			i += 1
			var inv_item = inv[i].name if inv[i] != null else ""
			if item_name != inv_item and (item_name.substr(0,6) != "group:" or inv_item == "" or stuff.get_group(inv_item,item_name.substr(6,-1)) == -1):
				item = null
				break
		if item != null:
			count = craft.count
			break
	if item != null:
		return stuff.itemstack(item,{"count":count})

func rot_to_facedir(rot:int):
	var p = PI/2
	return round(rot/p)*p
func from_object_facedir(id:int):
	var y = get_object(id).body.rotation.y
	var p = PI/2
	return round(y/p)*p

func save_data():
	if DirAccess.dir_exists_absolute("user://save") == false:
		DirAccess.make_dir_absolute("user://save")
	var s = FileAccess.open(str("user://save/",save_file),FileAccess.WRITE_READ)
	s.store_var(save)
	
func load_data():
	var s = {}
	if DirAccess.dir_exists_absolute("user://save/") == false:
		DirAccess.make_dir_absolute("user://save/")
	if FileAccess.file_exists(str("user://save/",save_file)):
		s = FileAccess.open(str("user://save/",save_file),FileAccess.READ)
		save = s.get_var()

func savefile(path,v):
	if DirAccess.dir_exists_absolute(path.get_base_dir()) == false:
		DirAccess.make_dir_absolute(path.get_base_dir())
	var s = FileAccess.open(path,FileAccess.WRITE_READ)
	s.store_var(v)
	
func loadfile(path):
	if path != null and FileAccess.file_exists(path):
		var s = FileAccess.open(path,FileAccess.READ)
		return s.get_var()

func remove_file(path):
	if FileAccess.file_exists(path):
		OS.move_to_trash(ProjectSettings.globalize_path(path))

func list_res(path,type,files=[]):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if dir.current_is_dir() == false:
				var file_in_dir = str(dir.get_current_dir(),"/",filename)
				if file_in_dir.get_extension() == type:
					files.push_back(file_in_dir)
			else:
				files = list_res(str(path,"/",filename),type,files)
			filename = dir.get_next()
	return files


func load_features(path="res://game/game_features/",files=[],sub=false):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if dir.current_is_dir() == false:
				var file_in_dir = str(dir.get_current_dir(),"/",filename)
				if file_in_dir.get_extension() == "tscn":
					files.push_back(file_in_dir)
			else:
				files = load_features(str(path,"/",filename),files,true)
			filename = dir.get_next()
	if sub == false:
		for file in files:
			add_to_map(load(file).instantiate())
	return files

func set_nodeextractor(file,pos,flag="bottom",dir=Vector3(1,1,1),update=true):
	var sav
	if temp.has("nodeextractor") == false:
		temp.nodeextractor = {}
	if temp.nodeextractor.has(file):
		sav = temp.nodeextractor[file]
	else:
		sav = loadfile(file)
	if sav != null:
		temp.nodeextractor[file] = sav
		var size = sav.size
		var s = sav.node_list.size()
		var index = 0
		#var reg = owner.to_item()
		var margin = Vector3()
		if flag == "center":
			margin = Vector3()
		elif flag == "bottom":
			margin = Vector3(0,size.y/2,0)
		elif flag == "top":
			margin = Vector3(0,size.y,0)

		for x in range(0,size.x) if dir.x > 0 else range(size.x,0,-1):
			for y in range(0,size.y) if dir.y > 0 else range(size.y,0,-1):
				for z in range(0,size.z) if dir.z > 0 else range(size.z,0,-1):
					var i = sav.list[index]
					var node = sav.node_list[i]
					if i < s and node != "air":
						var p = Vector3(x,y,z)
						var rel = (pos+p-size/2) + margin
						if update:
							setnode(rel,node)
							if sav.meta.has(p):
								world.set_node_meta(rel,sav.meta[p])
						else:
							world.gen_node_id(rel,registered_items[node].id)
					index += 1

class dirrange:#dirrange.new(1,false)
	static var _a
	static var _v
	static var _center
	func _init(a:int,center:bool=true):
		_a = abs(a)
		_v = Vector3(-abs(a),-abs(a),-abs(a))
		_center = center
	func _iter_init(iter):
		iter[0] = _v
		return iter[0].z <= _a
	func _iter_next(iter):
		if iter[0].x < _a:
			iter[0].x += 1
			if _center == false and iter[0] == Vector3():
				iter[0].x += 1
		else:
			iter[0].x = -_a
			if iter[0].y < _a:
				iter[0].y += 1
			else:
				iter[0].y = -_a
				iter[0].z += 1
		_v = iter[0]
		return iter[0].z <= _a
	func _iter_get(_iter):
		return _v
