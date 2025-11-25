@tool
extends EditorPlugin

var dock
var tree
var root
var current_item
var items = {}

var last_dir_basename = ""
var last_dir_name = ""
var last_dir = ""
var last_child
var last_addded_node
var just_added_node = false
var added_node_y = 0

var other = []
var folders = {"items":false,"objects":false,"maps":false,"nature":false,"actors":true,"game":false,"engine":false,"world":false,"scenes":false}

var res_filter = ["import","uid","dat","ico"]

var autoremove= ["blend1","mtl"]

var directories = [
	{"name":"Game","dir":"game/game","color":Color(0.536, 1.0, 1.0, 1.0),"showfilter":["gd"]},
	{"name":"game_features","dir":"game/game_features","color":Color(0.0, 1.0, 1.0, 1.0),"showfilter":["tscn","gd"]},
	#{"name":"Characters","dir":"game/characters","color":Color(1,0,1),"collapse":true,"filter":["png"]},
	#{"name":"maps","dir":"game/Maps","color":Color(1,0.592,0),"showfilter":["tscn"]},
	{"name":"Player","dir":"game/player","color":Color(0.6,0.8,0),"collapse":true,"showfilter":["tscn","gd"]},
	#{"name":"Objects","dir":"game/objects","color":Color(0.231,1,1)},

	#{"name":"World","dir":"engine/world","color":Color(1,0.9,0.2),"showfilter":["gd"]},
	{"name":"Engine","dir":"engine","color":Color(1,0.9,0.2),"showfilter":["gd"]},
	{"name":"Addons","dir":"addons","color":Color(0.5,0.98,0.98),"collapse":true}
]

func _enter_tree():
	dock = preload("res://addons/GameItems/gameitems.tscn").instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR,dock)
	dock.get_node("update").pressed.connect(update)
	dock.get_node("addtoscene").pressed.connect(add_to_scene)
	dock.get_node("copypath").pressed.connect(copy_path)
	dock.get_node("open").pressed.connect(open)
	dock.get_node("run").pressed.connect(run)
	dock.get_node("delsave").pressed.connect(delsave)
	dock.get_node("user").pressed.connect(user)
	dock.get_node("pitch").value_changed.connect(sound_pitch)
	dock.get_node("pitch_value").value_changed.connect(sound_pitch2)
	dock.get_node("snap_to_floor").pressed.connect(snap_to_floor)
	dock.get_node("align_to_floor").pressed.connect(align_to_floor)
	
	tree = dock.get_node("menu")
	root = tree.create_item()
	tree.hide_root = true
	update()

func _exit_tree():
	remove_control_from_docks(dock)
	
func _handles(object):
	return object is Node3D
	
func snap_to_floor(align_object_to_floor=false):
	var nodes = EditorInterface.get_selection().get_selected_nodes()
	var normals = []
	for node in nodes:
		var plugin_root = get_tree().get_edited_scene_root()
		var p = node.global_position
		var cast = PhysicsRayQueryParameters3D.create(p,p+Vector3(0,-1000,0))
		var space = plugin_root.get_world_3d().direct_space_state
		var r = space.intersect_ray(cast)
		if r.has("position") and (align_object_to_floor == false or dock.get_node("snapa").button_pressed):
			var y = 0
			if node is MeshInstance3D:
				y = node.get_aabb().size.y/2
			else:
				for n in node.get_children():
					if n is MeshInstance3D:
						y = n.get_aabb().size.y/2
						break
			#y+(node.scale.y-1)/2
			node.global_transform.origin = Vector3(r.position.x,r.position.y+y,r.position.z)
			
		if r.has("normal") and (align_object_to_floor or dock.get_node("snapa").button_pressed):
			var s = node.scale
			var t = node.global_transform
			t.basis.y = r.normal
			t.basis.x = -t.basis.z.cross(r.normal)
			t.basis = t.basis.orthonormalized()
			node.global_transform = t
			node.scale = s
	
func align_to_floor(align_object_to_floor=true):
	snap_to_floor(true)
	
func _forward_3d_gui_input(camera: Camera3D, event: InputEvent):
	if just_added_node and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		last_addded_node.global_transform.origin.y -= 1
		last_addded_node.global_transform.origin += Vector3(0,added_node_y,0)
		just_added_node = false
		last_addded_node = null
		added_node_y = 0
		return
	elif last_addded_node and event is InputEventMouseMotion:
		var collisions = []
		if last_addded_node is StaticBody3D or last_addded_node is CharacterBody3D:
			collisions.push_back(last_addded_node)
		for n in last_addded_node.get_children():
			if n is StaticBody3D or n is CharacterBody3D:
				collisions.push_back(n)
			for n2 in n.get_children():
				if n2 is StaticBody3D or n2 is CharacterBody3D:
					collisions.push_back(n2)

		var viewport = camera.get_viewport()
		var viewportC = viewport.get_parent()
		var pos = viewport.get_mouse_position()
		var origin = camera.project_ray_origin(pos)
		var dir = camera.project_ray_normal(pos)
		var ray_distance := camera.far
		var cast = PhysicsRayQueryParameters3D.new()
		cast.from = origin
		cast.to = origin + dir * ray_distance
		cast.exclude = collisions
		var plugin_root = get_tree().get_edited_scene_root()
		var space = plugin_root.get_world_3d().direct_space_state
		
		if space.intersect_ray(cast).get("position"):
			if is_instance_valid(last_addded_node) == false or last_addded_node.get("global_transform") == null:
				just_added_node = false
				last_addded_node = null
				added_node_y = 0
				return
			last_addded_node.global_transform.origin = space.intersect_ray(cast).position + Vector3(0,1,0)
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_G and Input.is_key_pressed(KEY_CTRL) and event.is_pressed():
		for n in EditorInterface.get_selection().get_selected_nodes():
			EditorInterface.edit_node(n)
			last_addded_node = n
			just_added_node = true
			break
		
		
		

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 2 and event.is_pressed() and event.is_command_or_control_pressed():
		add_to_scene()

func add_to_scene():
	if tree.get_selected() != null:
		var object_type = tree.get_selected().get_parent().get_text(0)
		if object_type == "items":
			added_node_y = 0.5
		var key = tree.get_selected().get_instance_id()
		var path = items[key]
		var nodes = EditorInterface.get_selection().get_selected_nodes()
		for node in nodes:
			var n = load(path).instantiate()
			if dock.get_node("addtoscene/toparent").button_pressed and node.owner != null:
				node.get_parent().add_child(n)
			else:
				node.add_child(n)
			n.owner = EditorInterface.get_edited_scene_root()
			n.name = path.get_file().split(".")[0]

			EditorInterface.edit_node(n)
			last_addded_node = n
			just_added_node = true
			
func open():
	var key = tree.get_selected().get_instance_id()
	var path = items[key]
	if FileAccess.file_exists(path):
		var ex = path.get_extension()
		if ex == "ogg":
			dock.get_node("sound").stream = load(path)
			dock.get_node("sound").playing = true
			dock.get_node("pitch").visible = true
			dock.get_node("pitch_value").visible = true
			return
		else:
			dock.get_node("pitch").visible = false
			dock.get_node("pitch_value").visible = false
			dock.get_node("pitch").value = 1
			dock.get_node("pitch_value").value = 1
		if ex == "tscn":
			EditorInterface.open_scene_from_path(path)
		else:
			EditorInterface.edit_resource(load(path))
func run():
	var key = tree.get_selected().get_instance_id()
	OS.shell_open(ProjectSettings.globalize_path(items[key]))
func copy_path():
	var key = tree.get_selected().get_instance_id()
	DisplayServer.clipboard_set(items[key])
	
func update():
	tree.clear()
	other = []
	last_dir_basename = ""
	current_item = null
	root = tree.create_item()
	tree.hide_root = true
	
	for i in directories.size():
		scan_dir(directories[i])
	explore_dir("res://res",root,0)

func delsave():
	var s = FileAccess.open(str("user://save/debug.save"),FileAccess.WRITE_READ)
	s.store_var({})
	s.close()

func user():
	OS.shell_open(ProjectSettings.globalize_path("user://"))

func explore_dir(path,current_root,stage):
	var dir = DirAccess.open(path)
	stage += 1
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if dir.current_is_dir():
				var current  = tree.create_item(current_root)
				current.set_text(0,filename)
				current.set_custom_color(0,Color(0,1,0))
				items[current.get_instance_id()] = path +  "/" + filename
				#if stage > 1:
				current.set_collapsed(true)
				explore_dir(path +  "/" + filename,current,stage)
			else:
				var ex = filename.get_extension()
				if res_filter.has(ex) == false:
					var child = tree.create_item(current_root)
					items[child.get_instance_id()] = path +  "/" + filename
					if ex == "png":
						child.set_icon(0,load(path +  "/" + filename.get_file()))
						child.set_icon_max_width(0,128)
					elif autoremove.has(ex):
						child.set_text(0,filename.get_file())
						child.set_custom_color(0,Color(1,0,0))
						var file = str(path,"/",filename)
						print("Remove: ",file)
						OS.move_to_trash(ProjectSettings.globalize_path(file))
					elif ex == "blend":
						child.set_text(0,filename.get_file())
						child.set_custom_color(0,Color(1,0.592,0))
					else:
						child.set_text(0,filename.get_file())
						child.set_custom_color(0,Color(1,1,1))
			filename = dir.get_next()

func sound_pitch(v):
	dock.get_node("sound").pitch_scale = v
	dock.get_node("sound").playing = true
	dock.get_node("pitch_value").value = v
func sound_pitch2(v):
	dock.get_node("sound").pitch_scale = v
	dock.get_node("sound").playing = true
	dock.get_node("pitch").value = v



func scan_dir(prop,sub="",stage=0):
	var path = str("res://",prop.dir,"/",sub)
	var dir = DirAccess.open(path)

	if stage == 0:
		current_item = tree.create_item(root)
		current_item.set_text(0,prop.name)
		current_item.set_collapsed(prop.get("collapse") == true)
		current_item.set_custom_color(0,prop.color)
		items[current_item.get_instance_id()] = path
		last_dir_basename = prop.name
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if dir.current_is_dir():
				last_dir = filename
				last_child = tree.create_item(current_item)
				last_child.set_text(0,filename)
				items[last_child.get_instance_id()] = path +  "/" + filename
				last_dir_name = filename
				last_dir = path +  "/" + filename
				scan_dir(prop, filename,stage+1)
			else:
				var ex = filename.get_extension()


#items
				if autoremove.has(ex):
					var file = str(path,"/",filename)
					print("Remove: ",file)
					OS.move_to_trash(ProjectSettings.globalize_path(file))
				elif res_filter.has(ex) == false and (prop.has("filter") == false or prop.filter.has(ex) == false):
					if stage == 0:
						if ex == "tscn" or (prop.has("showfilter") and prop.showfilter.has(ex)):
							last_child = tree.create_item(current_item)
							if ex == "tscn":
								last_child.set_text(0,filename.get_basename())
							else:
								last_child.set_text(0,filename)
							items[last_child.get_instance_id()] = path +  "/" + filename
							last_child.set_custom_color(0,prop.color)
							last_child.set_collapsed(true)
					elif ex == "tscn" and filename.get_file().split(".")[0] == last_child.get_text(0):
						
						items[last_child.get_instance_id()] = path +  "/" + filename
						last_child.set_custom_color(0,prop.color)
						last_child.set_collapsed(true)
						if FileAccess.file_exists(last_dir + "/icon.png"):
							last_child.set_icon(0,load(last_dir + "/icon.png"))
					
					elif prop.has("showfilter") == false or prop.showfilter.has(ex):
						var child2 = tree.create_item(last_child)	
						if ex == "tscn":
							child2.set_text(0,filename.get_basename())
							#child2.set_custom_font_size(0,18)
						else:
							child2.set_text(0,filename.get_file())
						child2.set_custom_color(0,prop.color)
						items[child2.get_instance_id()] = path +  "/" + filename
			filename = dir.get_next()
			
	
