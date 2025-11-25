@tool
extends Control

var panels = {}
var last_scroll = 0
var current = {}
var clear_buttons = {}
var last_focused = ""
var listcall
var list_inside = false
var selected_object = 0
var current_selected_regname = 0
var player
var deleted_objects = []
var mapgen_scatter_map = {
	"pos":Vector2(),
	"last_pos":Vector2(),
	"offset":Vector2(),
	"default_map_size":64,
	"map_size":64,
}
var specs = {
	"type":{
		"type":{"value":"node","options":["node","item","mapgen_scatter","nodeextractor","object"]},
	},
	"node":{
		"name":"",
		"max_count":{"value":100,"min":1,"max":100},
		"dynamic":false,
		"solid":true,
		"pointable":true,
		"shading":true,
		"replaceable":false,
		"fluid":false,
		"inv_image":".png",
		"speed":{"value":1.0,"min":0.1,"max":20.0},
		"viscosity":{"value":0.0,"min":0,"max":1},
		"gravity":{"value":0.0,"min":0.0,"max":100.0},
		"light_energy":{"value":0.0,"min":0.0,"max":10.0},
		"scale":{"value":1.0,"min":0.1,"max":2.0},
		"light_color":{"value":Color(1,1,1)},
		"color_overlay":{"value":Color(1,1,1)},
		"drawtype":{"value":"default","options":["default","simple_cross","boxed_cross"]},
		"node_type":{"value":"default","options":["default","liquid","fire"]},
		"transparency":{"value":"none","options":["none","alpha","scissor"]},
		"groups":"groups",
		"tiles":".png",
		"drop":{"item":"item","count":1},
		"craft":{
			"count":1,
			"recipe":[
				"item/groups:","item/groups:","item/groups:",
				"item/groups:","item/groups:","item/groups:",
				"item/groups:","item/groups:","item/groups:",
			],
		},
		"sounds":{
			"step":".ogg",
			"dig":".ogg",
			"dug":".ogg",
			"place":".ogg",
		},
		"uv_scale":Vector2(1,1),
		"animation":{
			"speed":1,
			"frames":Vector2(0,1),
			"tile":0,
		},
		"callbacks":{
			"before_place":false,
			"on_place":false,
			"after_place":false,
			"on_swap":false,
		},
	},
	"item":{
		"name":"",
		"max_count":{"value":100,"min":1,"max":100},
		"durability":{"value":100,"min":1,"max":1000},
		"inv_image":".png",
		"wield_image":".png",
		"speed":{"value":1.0,"min":0.1,"max":20.0},
		"scale":{"value":1.0,"min":0.1,"max":2.0},
		"transparency":{"value":"none","options":["none","alpha","scissor"]},
		"color_overlay":{"value":Color(1,1,1)},
		"groups":"groups",
		"tool_ability":"groups",
		"craft":{
			"count":1,
			"recipe":[
				"item/groups:","item/groups:","item/groups:",
				"item/groups:","item/groups:","item/groups:",
				"item/groups:","item/groups:","item/groups:",
			],
		},
		"callbacks":{
			"on_use":false,
			"on_swap":false,
		},
	},
	"nodeextractor":{
		"name":"",
		"size":{"readonly":""},
		"count":{"readonly":""},
		"list":"node",
	},
	"mapgen_scatter":{
		"name":"",
		"viewcolor":{"value":Color(1,1,1)},
		"list":"node/.nex",
		"generate_in":"node",
		"generate_near":"node",
		"place":{"value":"inside","options":["inside","above","under"]},
		#"spread":{"value":1,"min":1,"max":10},
		"min_density":{"value":0.02,"min":0.01,"max":1.0},
		"max_density":{"value":0.03,"min":0.01,"max":1.0},
		"max_height":{"value":100,"min":-1000,"max":1000},
		"min_height":{"value":-100,"min":-1000,"max":1000},
		"seed":{"value":1,"min":0,"max":100},
		"noise_type":{"value":"VALUE","options":["VALUE","VALUE_CUBIC","CELLULAR","PERLIN","SIMPLEX","SIMPLEX_SMOOTH"]},
		"frequency":{"value":0.05,"min":0.01,"max":0.1},
		"fractal_octaves":{"value":3,"min":1,"max":6},
		"fractal_lacunarity":{"value":2,"min":1,"max":2},
		"fractal_gain":{"value":0.5,"min":0.1,"max":1.0},
	},
	"object":{},
}

@export_tool_button("Clear","Tree") var clear = func():
	clear_forms()
		
@export_tool_button("Update","Tree") var updatelist = func():
	update()

func clear_forms():
	for n in ["node","item","object","mapgen_scatter","nodeextractor"]:
		var no = get_node(str("properties/",n))
		no.hide()
		for c in no.get_children():
			c.queue_free()

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent().player

	list_specs($properties/type,specs.type,true)
	$scrollbar.value_changed.connect(func(v):
		var rel = (last_scroll - v)
		last_scroll = v
		for s in $properties.get_children():
			s.position.y += rel
	)
	$togglecode.pressed.connect(func():
		$code.visible = !$code.visible
	)
	$properties/node.pressed.connect(func():
		to_item()
	)
	$properties/chunks.pressed.connect(func():
		to_item(true)
	)
	$properties/item.pressed.connect(func():
		to_item()
	)
	$properties/save_item.pressed.connect(func():
		to_item(false,true)
	)
	$properties/save_node.pressed.connect(func():
		
		to_item(false,true)
	)
	$properties/get_item.pressed.connect(func():
		if current.has("name") and core.registered.has(current.name):
			var count = current.max_count if current.has("max_count") else 100
			stuff.inv_add_item(stuff.itemstack(str(current.name," ",count)),"main",player.id)
	)
	$properties/get_node.pressed.connect(func():
		if current.has("name") and core.registered.has(current.name):
			var count = current.max_count if current.has("max_count") else 100
			stuff.inv_add_item(stuff.itemstack(str(current.name," ",count)),"main",player.id)
	)
	$properties/object.pressed.connect(func():
		to_item()
	)
	$objects.item_selected.connect(func(v):
		from_item($objects.get_item_text(v))
		current_selected_regname = $objects.get_item_text(v)
		selected_object = v	
	)
	$properties/mapgen_scatter_save.pressed.connect(func():
		to_item(false,true)
	)
	$properties/mapgen_scatter.pressed.connect(func():
		to_item()
	)
	
func show_sub():
	var buttons = [
		["properties/node","properties/get_node","properties/chunks","properties/save_item"],
		["properties/item","properties/get_item","properties/save_node"],
		["properties/nodeextractor","properties/nodeextractor_save","properties/nodeextractor_set","properties/nodeextractor_clear"],
		["properties/mapgen_scatter","properties/mapgen_scatter_save","mapgen_scatter_map"],
	]
	for b in buttons:
		for b1 in b:
			get_node(b1).visible = get_node(b[0]).visible
	update_map()
	
func _input(event: InputEvent) -> void:
	if visible == false:
		return
	elif event is InputEventMouseMotion and $list.visible:
		var inside = Rect2($list.global_position,$list.size+Vector2(10,0)).has_point(get_global_mouse_position())
		if list_inside and inside == false:
			$list.hide()
			list_inside = false
			update()
		elif inside:
			list_inside = true
	elif Input.is_action_just_pressed("contenteditor") and Rect2($properties.global_position,$properties.size).has_point(get_global_mouse_position()) == false:
		mapgen_scatter_map.pos = Vector2()
		await get_tree().process_frame
		get_parent().toggle_contenteditor()
	var p = $mapgen_scatter_map.get_global_mouse_position()
	if $mapgen_scatter_map.get_global_rect().has_point(p):
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if mapgen_scatter_map.last_pos != p:
				mapgen_scatter_map.last_pos = p
				var rel = (mapgen_scatter_map.pos-p) - mapgen_scatter_map.offset
				mapgen_scatter_map.pos -= rel.round()
				update_map()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP) and mapgen_scatter_map.map_size-32 >= 32:
			mapgen_scatter_map.map_size -= 32
			update_map()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN) and mapgen_scatter_map.map_size+32 <= 256:
			mapgen_scatter_map.map_size += 32
			update_map()
		else:
			mapgen_scatter_map.offset = mapgen_scatter_map.pos - p
	
func update_stuff():
	var type = objecttype()
	if type == "mapgen_scatter":
		to_item()
		update_map()

func update():
	var editor = Engine.is_editor_hint()
	if editor:
		panels.clear()
	var scroll = last_scroll
	$scrollbar.value = 0
	clear_buttons.clear()
	$list.hide()
	
	clear_forms()
	await get_tree().create_timer(0.01).timeout
	var type = objecttype()
	var tree = get_node(str("properties/",type))
	var y = list_specs(tree,specs[type],editor)
	tree.show()
	show_sub()
	update_stuff()
	$scrollbar.value = scroll

	var sy = get_viewport_rect().size.y
	if y > sy:
		$scrollbar.max_value = sy + y-sy
		$scrollbar.page = sy
	else:
		$scrollbar.max_value = sy
		$scrollbar.page = sy
	if editor == false:
		var i = 2
		$objects.clear()
		$objects.add_item("Empty")
		$objects.add_item("Reset Default")
		$objects.add_item("Delete Save")
		
		get_node("../head").visible = type == "item"
		get_node("../ui").visible = type == "item"
		
		if editor == false and content.items.has(current_selected_regname):
			$objects.set_item_disabled(1,false)
		else:
			$objects.set_item_disabled(1,true)
		if editor == false and (core.save.contenteditor.items.has(current_selected_regname) or core.save.contenteditor.mapgen_scatter.has(current_selected_regname) or FileAccess.file_exists(str("user://nodeextractor/",current_selected_regname,".nex"))):
			$objects.set_item_disabled(2,false)
		else:
			$objects.set_item_disabled(2,true)
		if type == "item" or type == "node":
			for reg in core.registered_items.values():
				if reg.type == type:
					i += 1
					$objects.add_item(reg.name)
					if deleted_objects.has(reg.name):
						$objects.set_item_custom_fg_color(i,Color(1,0,0))
					if core.save.contenteditor.items.has(reg.name):
						$objects.set_item_custom_fg_color(i,Color(0,1,0))
					if reg.has("inv_image"):
						$objects.set_item_icon(i,reg.inv_image)
					elif reg.has("wield_image"):
						$objects.set_item_icon(i,reg.wield_image)
					if i == selected_object:
						$objects.select(i)
		elif type == "mapgen_scatter":
			for reg in content.mapgen_scatter.values():
				i += 1
				$objects.add_item(reg.name)
				if i == selected_object:
					$objects.select(i)
			for reg in core.save.contenteditor.mapgen_scatter.values():
				i += 1
				$objects.add_item(reg.name)
				$objects.set_item_custom_fg_color(i,Color(0,1,0))
				if i == selected_object:
					$objects.select(i)
		elif type == "nodeextractor":
			list_files("nex",$objects)

func fixname(s,cutoff=false):
	if s.find(".") > 0:
		var s2 = s.split(".")
		s = s2[s2.size()-1]
	if cutoff and s.length() > 13:
		if s.find("_") > 0:
			s = s.substr(s.find("_")+1,-1)
		else:
			s = s.substr(0,13)
	return str(s.substr(0,1).to_upper(),s.substr(1,-1).replace("_"," "))

func new_button(tree,y,specname,set_showen):
	var butt = Button.new()
	if panels.has(specname) == false:
		panels[specname] = set_showen
	var showen = panels[specname]
	var st = StyleBoxFlat.new()
	st.bg_color = Color(Color(0,0.6,1))
	butt.add_theme_stylebox_override("normal",st)
	butt.add_theme_color_override("font_color",Color(1,1,1))
	butt.text = fixname(specname)
	butt.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	y = add_to(tree,butt,y)
	butt.pressed.connect(func():
		panels[specname] = !panels[specname]
		update()
	)
	return {"button":butt,"y":y,"showen":showen}
	
func new_lineedit(text):
	var s = LineEdit.new()
	s.text = text
	s.alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override("font_color",Color(1,1,1))
	s.add_theme_color_override("font_uneditable_color",Color(1,0.7,1))
	var stbf = StyleBoxFlat.new()
	stbf.bg_color = Color(0.2,0.2,0.2)
	stbf.border_color = Color(0.3,0.3,0.3)
	stbf.set_border_width_all(2)
	s.add_theme_stylebox_override("normal",stbf)
	s.add_theme_stylebox_override("readonly",stbf)
	s.text_changed.connect(func(text2):
		s.tooltip_text = text2
		update_stuff()
	)
	return s

func new_label(parent,text,pos):
	var l = Label.new()
	parent.add_child(l)
	l.owner = parent.owner
	l.position = pos
	l.add_theme_constant_override("outline_size",10)
	l.text = fixname(text,true)

func slider_value(slider):
	slider.mouse_entered.connect(func():
		if slider.has_node("value") == false:
			var l = Label.new()
			slider.add_child(l)
			l.owner = slider.owner
			l.global_position = Vector2($scrollbar.global_position.x+$scrollbar.size.x+60,l.global_position.y-10)
			l.add_theme_font_size_override("font_size",30)
			l.add_theme_constant_override("outline_size",20)
			l.name = "value"
			if floor(slider.value) == slider.value:
				l.text = str(int(slider.value))
			else:
				l.text = str(slider.value)
	)
	slider.mouse_exited.connect(func():
		if slider.has_node("value"):
			slider.get_node("value").free()
	)
	slider.drag_ended.connect(func(_v):
		if is_instance_valid(slider) and slider.has_node("value"):
			if Rect2(slider.global_position,slider.size).has_point(get_global_mouse_position()) == false:
				slider.get_node("value").free()
	)
	slider.value_changed.connect(func(v):
		if slider.has_node("value") == false:
			slider.mouse_entered.emit()
		if floor(v) == v or v == 0:
			v = int(v)
		slider.get_node("value").text = str(v)
		update_stuff()
	)

func add_to(menu,s,y):
	menu.add_child(s)
	s.owner = menu.owner
	s.position.x = 0
	s.global_position.y = y
	s.size.x = menu.size.x
	if s.visible:
		y += s.size.y
	return y

func clearbutton(s,specname,value,x_marginal=0):
	if current.has(specname):# and typeof(value) == TYPE_STRING:
		if current[specname] == value:
			current.erase(specname)
			if clear_buttons.has(specname) and is_instance_valid(clear_buttons[specname]):
				clear_buttons[specname].free()
				clear_buttons.erase(specname)
		elif clear_buttons.has(specname) == false:
			var b = Button.new()
			var st1 = StyleBoxFlat.new()
			st1.bg_color = Color(Color(1,0,0))
			b.add_theme_stylebox_override("normal",st1)
			b.add_theme_color_override("font_color",Color(1,1,1))
			var st2 = StyleBoxFlat.new()
			st2.bg_color = Color(Color(0.5,0,0))
			b.add_theme_stylebox_override("hover",st2)
			b.text = "X"
			add_to(s.get_parent(),b,0)
			b.size = Vector2(20,20)
			b.global_position = Vector2($scrollbar.global_position.x+$scrollbar.size.x+(b.size.x*x_marginal),s.global_position.y)
			clear_buttons[specname] = b
			b.pressed.connect(func():
				current.erase(specname)
				update()
			)

func list_specs(tree,spectype,set_showen):
	var y = tree.global_position.y+tree.size.y
	for specname in spectype:
		var spec = spectype[specname]
		y = add_specs(tree,specname,spec,set_showen,y)
	return y

func add_specs(tree,specname,spec,set_showen,y):
	if specname == "groups" or specname == "tiles" or specname == "list" or specname == "tool_ability":
		var showen = set_showen
		if specname.find(".") == -1:
			var a = new_button(tree,y,specname,set_showen)
			tree = a.button
			showen = a.showen
			y = a.y
			
		if current.has(specname) == false or current[specname].size() == 0:
			current[specname] = [{"name":"","count":1}]
		elif current[specname][current[specname].size()-1].name != "":
			current[specname].push_back({"name":"","count":1})
		for i in current[specname].size():
			var l = new_lineedit(current[specname][i].name)
			l.placeholder_text = spec
			l.clear_button_enabled = true
			l.visible = showen
			l.text = current[specname][i].name
			y = add_to(tree,l,y)
			if last_focused == str(i):
				last_focused = ""
				l.grab_focus()
				l.caret_column = l.text.length()
			l.focus_entered.connect(func():
				list(l,spec)
			)
			l.text_changed.connect(func(v):
				current[specname][i].name = v
				if v != "" and i == current[specname].size()-1:
					current[specname].push_back({"name":"","count":1})
					last_focused = str(i)
					update()
				elif v == "" and i < current[specname].size()-1:
					current[specname].pop_at(i)
					update()
			)
			#l.text_changed.emit(l.text)
			if (specname == "tiles" or specname == "list") and i > 4:
				break
			elif specname != "tiles" and specname != "list":
				l.size.x = tree.size.x/2
				var s = HSlider.new()
				s.step = 1
				s.min_value = 0
				s.max_value = 100
				s.value = current[specname][i].count
				s.visible = showen
				slider_value(s)
				add_to(tree,s,y)
				s.position.x = tree.size.x/2
				s.global_position.y -= tree.size.y
				s.size.x = tree.size.x/2
				s.value_changed.connect(func(v):
					current[specname][i].count = int(v)
					update_stuff()
				)
	elif typeof(spec) == TYPE_VECTOR2:
		var p = 1
		for i in range(0,2):
			p += 1
			var prop = str(specname,i)
			var s = HSlider.new()
			s.step = 1
			s.min_value = 0
			s.max_value = 100
			s.value = current[prop] if current.has(prop) else 0
			if specname.find(".") > 0:
				s.visible = set_showen
			slider_value(s)
			if i == 0:
				add_to(tree,s,y)
				new_label(s,specname,Vector2(-tree.size.x/2,0))
			else:
				y = add_to(tree,s,y)+10
			s.position.x = (tree.size.x/4)*p
			s.size.x = tree.size.x/4
			s.value_changed.connect(func(v):
				current[prop] = v
				clearbutton(s,prop,0,i)
				update_stuff()
			)
			clearbutton(s,prop,0,i)
	elif typeof(spec) == TYPE_BOOL:
		var s = CheckBox.new()
		s.text = fixname(specname)
		if specname.find(".") > 0:
				s.visible = set_showen
		y = add_to(tree,s,y)
		s.button_pressed = current[specname] if current.has(specname) else spec
		s.toggled.connect(func(v):
			current[specname] = v
			clearbutton(s,specname,spec)
			update_stuff()
		)
		clearbutton(s,specname,spec)
	elif typeof(spec) == TYPE_STRING or typeof(spec) == TYPE_DICTIONARY and spec.has("readonly") and typeof(spec.readonly) == TYPE_STRING:
		var readonly = !false
		var text = ""
		var placeholder = ""

		if typeof(spec) == TYPE_DICTIONARY:
			if current.has(str(specname,".readonly")):
				readonly = !true
				text = current[str(specname,".readonly")] if current.has(str(specname,".readonly")) else ""
				placeholder = spec.readonly
		else:
			placeholder = spec
			text = current[specname] if current.has(specname) else ""

		var s = new_lineedit(text)
		if specname.find(".") > 0:
			s.visible = set_showen
		y = add_to(tree,s,y)
		s.position.x = tree.size.x/2
		s.size.x = tree.size.x/2
		new_label(s,specname,Vector2(-tree.size.x/2,0))
		s.text = text
		s.placeholder_text = placeholder
		s.tooltip_text = text
		s.editable = readonly
		s.text_changed.connect(func(v):
			s.tooltip_text = v
			current[specname] = v
			clearbutton(s,specname,"")
			if specname == "name":
				var type = objecttype()
				s.add_theme_color_override("font_color",Color())
				var st = StyleBoxFlat.new()
				st.bg_color =Color(1,1,1)
				if v == "":
					st.bg_color = Color(1,0.3,0.3)
					s.tooltip_text = "Name is required"
				elif v.is_valid_filename() == false:
					st.bg_color = Color(1,0.3,0.3)
					s.tooltip_text = "Invalid Name"
				elif core.registered_items.has(v):
					if type == "item" or type == "node":
						if core.registered_items[v].type != type:
							st.bg_color = Color(1,0.3,0.3)
							s.tooltip_text = str("object exists as a ",core.registered_items[v].type,"\n(current is: ",objecttype(),")")
						else:
							st.bg_color = Color(1,1,0)
							s.tooltip_text = "Item exists, will be overwritem"
				if type == "nodeextractor":
					if FileAccess.file_exists(str("res://res/nodeextractor/",v)):
						st.bg_color = Color(1,1,0)
						s.tooltip_text = "Item exists, will be overwritem"
				elif type == "mapgen_scatter" and core.save.contenteditor.mapgen_scatter.has(v):
					st.bg_color = Color(1,1,0)
					s.tooltip_text = "Item exists, will be overwritem"
				s.add_theme_stylebox_override("normal",st)
		)
		clearbutton(s,specname,"")
		if specname == "name":
			s.text_changed.emit(s.text)
		s.focus_entered.connect(func():
			list(s,placeholder)
		)
		
		
	elif typeof(spec) == TYPE_ARRAY:
		var x = 0
		for n in spec.size():
			var prop = str(specname,n)
			var item = spec[n]
			var s = new_lineedit(current[prop] if current.has(prop) else "")
			s.placeholder_text = item.get_extension() if item.get_extension() != "" else item
			if specname.find(".") > 0:
				s.visible = set_showen
			s.tooltip_text = item
			if spec.size() != 9:
				y = add_to(tree,s,y)
				s.text_changed.connect(func(v):
					current[prop] = v
					clearbutton(s,prop,item)
					s.tooltip_text = v
					update_stuff()
				)
				clearbutton(s,prop,item)
				s.focus_entered.connect(func():
					list(s,item)
				)
			else:
				add_to(tree,s,y)
				s.size = Vector2(tree.size.x/3,tree.size.x/3)
				s.position.x = (tree.size.x/3)*x
				s.global_position.y = y
				s.text_changed.connect(func(v):
					current[prop] = v
					clearbutton(s,prop,item,x)
					s.tooltip_text = v
					update_stuff()
				)
				clearbutton(s,prop,item,x)
				if s.visible:
					x += 1
					if x > 2 or n == spec.size()-1:
						x = 0
						y += s.size.y
				s.focus_entered.connect(func():
					list(s,item)
				)
	elif typeof(spec) == TYPE_DICTIONARY:
		var butt
		var showen
		if spec.size() == 1 or spec.size() == 3 and spec.has("value") and spec.has("max") and spec.has("min"):
			butt = tree
			showen = true
		else:
			var a = new_button(tree,y,specname,set_showen)
			butt = a.button
			showen = a.showen
			butt.name = specname
			y = a.y
		if spec.has("value") and (typeof(spec.value) == TYPE_FLOAT or typeof(spec.value) == TYPE_INT):
			
			var s = HSlider.new()
			s.step = 0.01
			s.min_value = spec.min
			s.max_value = spec.max
			s.value = current[specname] if current.has(specname) else spec.value
			s.name = specname
			s.visible = showen
			slider_value(s)
			if typeof(spec.value) == TYPE_INT:
				s.step = 1
				s.rounded = true
			s.value_changed.connect(func(v):
				current[specname] = v
				clearbutton(s,specname,spec.value)
				update_stuff()
			)
			y = add_to(butt,s,y)
			clearbutton(s,specname,spec.value)
			s.position.x = $properties.size.x/2
			s.size.x = $properties.size.x/2
			new_label(s,specname,Vector2(-$properties.size.x/2,-5))
		elif spec.has("options") and typeof(spec.options) == TYPE_ARRAY:
			var s = ItemList.new()
			s.name = specname
			var index = 0
			for i in spec.options.size():
				s.add_item(spec.options[i])
				if spec.options[i] == current.get(specname):
					index = i
			s.select(index)
			s.visible = showen
			s.size = Vector2(tree.size.x,min(spec.options.size()*31,93))
			y = add_to(butt,s,y)
			s.item_selected.connect(func(v):
				if str(owner.get_path_to(s)).find("type/type/type") > 0:
					selected_object = -1
					current.clear()
				current[specname] = s.get_item_text(v)
				clearbutton(s,specname,spec.options[0])
				update()
			)
			clearbutton(s,specname,spec.options[0])
		elif spec.has("value") and typeof(spec.value) == TYPE_COLOR:
			var s = ColorPickerButton.new()
			s.edit_alpha = false
			s.edit_intensity = false
			s.name = specname
			s.size.y = 25
			s.color = current[specname] if current.has(specname) else spec.value
			s.visible = showen
			s.add_theme_stylebox_override("normal",StyleBoxFlat.new())
			y = add_to(butt,s,y)
			s.position.x = $properties.size.x/2
			s.size.x = $properties.size.x/2
			new_label(s,specname,Vector2(-$properties.size.x/2,-5))
			s.color_changed.connect(func(v):
				current[specname] = v
				clearbutton(s,specname,spec.value)
				update_stuff()
			)
			clearbutton(s,specname,spec.value)
		else:
			for op in spec:
				var value = spec[op]
				if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
					var prop = str(specname,".",op)
					var s = HSlider.new()
					if typeof(value) == TYPE_INT:
						s.step = 1
						s.min_value = 1
						s.max_value = 100
					else:
						s.step = 0.01
						s.min_value = 0.01
						s.max_value = 100.0
					s.value = current[prop] if current.has(prop) else value
					s.rounded = true
					s.visible = showen
					y = add_to(butt,s,y)
					s.position.x = $properties.size.x/2
					s.size.x = $properties.size.x/2
					new_label(s,op,Vector2(-$properties.size.x/2,-5))
					slider_value(s)
					s.value_changed.connect(func(v):
						current[prop] = v
						clearbutton(s,prop,value)
						update_stuff()
					)
					clearbutton(s,prop,value)
				else:
					y = add_specs(butt,str(specname,".",op),value,showen,y)
	return y

func list(node,text):
	$list.clear()
	for s in text.split("/"):
		var filetype = s.get_extension()
		if filetype != "":
			list_files(filetype,node)
		elif s == "item":
			for reg in core.registered_items.values():
				list_menu(reg.name,reg.name,reg.inv_image)
			list_setup(node)
		elif s == "node":
			for reg in core.registered_items.values():
				if reg.type == "node":
					list_menu(reg.name,reg.name,reg.inv_image)
			list_setup(node)
		elif s == "groups":
			list_groups(node)
		elif s == "groups:":
			list_groups(node,"groups:")

func list_groups(node,add=""):
	var gr = []
	for reg in core.registered_items.values():
		for g in reg.groups:
			if gr.has(g) == false:
				gr.push_back(g)
				list_menu(str(add,g),str(add,g))
	list_setup(node)
	
func list_files(filetype,node):
	var path
	if filetype == "png":
		path = "res://res/textures"
	elif filetype == "ogg":
		path = "res://res/sounds"
	elif filetype == "nex":
		for p in ["res://res/nodeextractor","user://nodeextractor"]:
			for file in list_res(p,filetype):
				var label = file.get_file().replace(str(".",file.get_extension()),"")
				if node == $objects:
					$objects.add_item(label)
					if p == "user://nodeextractor":
						$objects.set_item_custom_fg_color($objects.item_count-1,Color(0,1,0))
					$objects.set_item_metadata($objects.item_count-1,file)
				else:
					list_menu(file,str(label,".nex"),null,Color(0,1,0))
				if $objects.item_count-1 == selected_object:
					$objects.select($objects.item_count-1)
		if node != $objects:
			list_setup(node)
		return
	else:
		return
	for file in list_res(path,filetype):
		var dir = file.get_slice("/",file.get_slice_count("/")-2)
		var label = file.get_file().replace(str(".",file.get_extension()),"")
		if dir != "textures" and dir != "sounds":
			label = str(dir,"/",label)
		list_menu(file,label,file)
	list_setup(node)

func list_setup(node):
	var pos = node.global_position+node.size
	var s = get_viewport_rect().size
	if pos.y+$list.size.y > s.y:
		pos.y = (s.y-$list.size.y)-10
	$list.global_position = Vector2($scrollbar.global_position.x+$scrollbar.size.x+60,pos.y)
	if $list.has_connections("item_selected"):
		$list.disconnect("item_selected",listcall)
	listcall = func(i):
		$list.hide()
		list_inside = false
		if is_instance_valid(node):
			node.tooltip_text = $list.get_item_metadata(i)
			node.text = $list.get_item_metadata(i)
			node.text_changed.emit($list.get_item_metadata(i))
	$list.item_selected.connect(listcall)
	$list.show()
	
func list_menu(text,label,icon=null,color=Color(1,1,1)):
	$list.add_item(label)
	$list.set_item_metadata($list.item_count-1,text)
	$list.set_item_custom_fg_color($list.item_count-1,color)
	if icon != null and (typeof(icon) == TYPE_STRING or icon.resource_path.get_extension() == "png"):
		if typeof(icon) == TYPE_STRING:
			$list.set_item_icon($list.item_count-1,load(icon))
		else:
			$list.set_item_icon($list.item_count-1,icon)

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

func update_map():
	if mapgen_scatter_map.pos == Vector2():
		var p = round(player.body.global_position)
		mapgen_scatter_map.pos = Vector2(p.x,p.z)
	var w = mapgen_scatter_map.map_size/2
	var image = Image.create_empty(mapgen_scatter_map.map_size,mapgen_scatter_map.map_size,true,Image.FORMAT_RGB8)
	for x in mapgen_scatter_map.map_size:
		for z in mapgen_scatter_map.map_size:
			var pos2d = Vector3(mapgen_scatter_map.pos.x+(x-w),0,mapgen_scatter_map.pos.y+(z-w))
			for ob in mapgen.scatters.values():
				var n = abs(ob.map.get_noise_2d(pos2d.x,pos2d.z))
				if n >= ob.min_density and n <= ob.max_density:
					image.fill_rect(Rect2i(x,z,1,1),ob.viewcolor)
			var ppos = round(player.body.global_position)
			if Rect2(ppos.x,ppos.z,2,2).has_point(Vector2(pos2d.x,pos2d.z)):
				image.fill_rect(Rect2i(x,z,1,1),Color(1,0,0))
	$mapgen_scatter_map.texture = ImageTexture.create_from_image(image)

func objecttype():
	var t = $properties/type/type/type
	if t == null:
		return "node"
	return t.get_item_text(t.get_selected_items()[0])

func from_item(regname,def={}):
	current.clear()
	var object_type = objecttype()
	if regname == "Empty":
		update()
		return
	elif regname == "Reset Default":
		if content.items.has(current_selected_regname):
			core.register_item(current_selected_regname,content.items[current_selected_regname],true)
			if objecttype() == "item":
				gui.update_hotbar(player.id)
				gui.update_wielditems(0,player.id,true)
			regname = current_selected_regname
		else:
			return
	elif regname == "Delete Save":
		if object_type == "node" or object_type == "item":
			core.save.contenteditor.items.erase(current_selected_regname)
			deleted_objects.push_back(current_selected_regname)
		elif object_type == "nodeextractor":
			core.remove_file(str("user://nodeextractor/",current_selected_regname,".nex"))
		elif object_type == "mapgen_scatter":
			core.save.contenteditor.mapgen_scatter.erase(current_selected_regname)
			mapgen.scatters.erase(current_selected_regname)
			update_map()
		core.save_data()
		update()
		return
	
	if object_type == "item" or object_type == "node":
		def = core.registered_items[regname]
	elif object_type == "nodeextractor" and regname != "":
		var i = $objects.get_selected_items()[0]
		def = $properties/nodeextractor.loadfile($objects.get_item_metadata(i))
	elif object_type == "mapgen_scatter" and regname != "":
		def = core.save.contenteditor.mapgen_scatter[regname]
		
	for specname in def:
		var value = def[specname]
		var type = typeof(value)
		
		if type == TYPE_DICTIONARY:
			value = value.duplicate()
		if type == TYPE_OBJECT:
			if value.resource_path == "":
				value = value.get_meta("res_path")
			else:
				value = value.resource_path
			type = TYPE_STRING
		elif specname == "id":
			continue
		elif type == TYPE_DICTIONARY:
			for d in value.duplicate():
				if typeof(value[d]) == TYPE_CALLABLE:
					value[d] = true
#groups
		if specname == "groups" or specname == "tiles" or specname == "list" or specname == "tool_ability":
			current[specname] = []
			for g in value:
				if type == TYPE_ARRAY:
					current[specname].push_back({"name":g,"count":0})
				else:
					current[specname].push_back({"name":g,"count":value[g]})
#craft
		elif specname == "craft":
			for i in value.recipe.size():
				current[str("craft.recipe",i)] = value.recipe[i]
			current["craft.count"] = value.count if value.has("count") else 1
#vector
		elif type == TYPE_VECTOR2 or type == TYPE_VECTOR3:
			for i in 2:
				current[str(specname,i)] = value[i]
#DICTIONARY
		elif type == TYPE_DICTIONARY:
			for subname in value:
				var t = typeof(value[subname])
				if t == TYPE_VECTOR2 or t == TYPE_VECTOR3:
					for i in 2:
						current[str(specname,".",subname,i)] = value[subname][i]
				else:
					current[str(specname,".",subname)] = value[subname]
#else
		elif type == TYPE_BOOL or type == TYPE_INT or type == TYPE_FLOAT or type == TYPE_STRING or type == TYPE_COLOR or type == TYPE_ARRAY:
			current[specname] = value
	update()

func to_item(update_world=false,save=false):
	var object_type = objecttype()
	var text_to_replace = {}
	var reg = {"type":object_type}
	
	if current.has("name") == false or (object_type == "item" or object_type == "node") and core.registered_items.has(current.name) and core.registered_items[current.name].type != object_type:
		return

	for specname in current:
		var value = current[specname]
		var type = typeof(value)
		var last_chr = 1 if specname.substr(specname.length()-1,-1).is_valid_int() else 0
		var vec_name = specname.substr(specname.find(".")+1,-1)
		var spec_name = specname.substr(0,specname.find("."))
		var subname = specname.substr(specname.find(".")+1,specname.length()-specname.find(".")-1-last_chr)
		
#groups
		if (specname == "groups" or specname == "tool_ability") and value.size() > 1:
			var groups = {}
			for g in value:
				if g.name != "":
					groups[g.name] = g.count
			reg[specname] = groups	
#tiles
		elif specname == "tiles" or specname == "list":
			if value.size() == 1:
				continue
			reg[specname] = []
			for g in value:
				if g.name != "":
					reg[specname].push_back(g.name)
#craft
		elif specname.substr(0,12) == "craft.recipe":
			if reg.has("craft") == false:
				reg.craft = {"recipe":[],"count":1}
			elif reg.craft.has("recipe") == false:
				reg.craft.recipe = []
			var i = int(specname.substr(7,-1))
			if reg.craft.recipe.size() < i+1:
				reg.craft.recipe.resize(i+1)
			reg.craft.recipe[i] = value
			if i == 8:
				while reg.craft.recipe.size() > 0:
					var s = reg.craft.recipe[reg.craft.recipe.size()-1]
					if s == null or s == "":
						reg.craft.recipe.pop_back()
					else:
						break
#vector
		elif specs[object_type].has(subname) and typeof(specs[object_type][subname]) == TYPE_VECTOR2 or typeof(specs[object_type].get(spec_name)) == TYPE_DICTIONARY and typeof(specs[object_type][spec_name].get(subname)) == TYPE_VECTOR2:
			var specs_
			var reg_
			if specs[object_type].has(subname) and typeof(specs[object_type][subname]) == TYPE_VECTOR2:
				specs_ = specs[object_type]
				reg_ = reg
			else:
				specs_ = specs[object_type][spec_name]
				if reg.has(spec_name) == false:
					reg[spec_name] = {}
				reg_ = reg[spec_name]
			if reg_.has(subname) == false:
				if typeof(specs_) == TYPE_VECTOR2:
					reg_[subname] = Vector2()
					type = TYPE_VECTOR2
				else:
					reg_[subname] = Vector3()
					type = TYPE_VECTOR3
			reg_[subname][int(vec_name.right(1))] = float(value)
#DICTIONARY:
		elif specs[object_type].has(spec_name) and typeof(specs[object_type][spec_name]) == TYPE_DICTIONARY and specs[object_type][spec_name].has("value") == false:
			if reg.has(spec_name) == false:
				reg[spec_name] = {}
			if reg[spec_name].has(subname) == false:
				reg[spec_name][subname] = {}

			if specs[object_type][spec_name].has(subname) == false:
				continue
			elif typeof(specs[object_type][spec_name][subname]) == TYPE_INT:
				value = int(value)
			reg[spec_name][subname] = value
#else
		elif type == TYPE_COLOR or type == TYPE_BOOL or type == TYPE_INT or type == TYPE_FLOAT or type == TYPE_STRING and value != "":
			reg[specname] = value
			if type == TYPE_COLOR:
				text_to_replace[str(value)] = str("Color",str(value))


	

#nodeextractor or object
	if object_type == "nodeextractor" or object_type == "object":
		return reg
	elif OS.is_debug_build():
#to code
		save_object(reg,text_to_replace)
#mapgen_scatter
	if save and object_type == "mapgen_scatter":
		core.save.contenteditor.mapgen_scatter[reg.name] = reg
		core.save_data()
		update()
	elif object_type == "mapgen_scatter":
		mapgen.register_scatter(reg)
		update_map()
#save item or node
	elif save and (object_type == "item" or object_type == "node"):
		core.save.contenteditor.items[reg.name] = reg
		core.save_data()
		core.register_item(reg.name,reg)
		update()
		for i in $objects.item_count:
			var l = $objects.get_item_text(i)
			if l == reg.name:
				$objects.select(i)
				selected_object = i
				break
#node
	elif object_type == "node":
		if save:
			core.save.contenteditor.items[reg.name] = reg
			core.save_data()
			core.register_item(reg.name,reg)
			update()
		core.register_item(reg.name,reg)
		var pointed = get_parent().get_pointed_pos()
		if pointed.type == "node":
			if core.getnode(pointed.pos).name == reg.name:
				core.setnode(pointed.pos,reg.name)
			else:
				core.setnode(pointed.outside,reg.name)
			reg = core.registered_items[reg.name]
		if update_world:
			var count = 1000
			var p = []
			for pos in core.world.chunks:
				if core.world.chunks[pos].list.has(reg.id):
					if p.size() < 1000:
						p.push_back(pos)
					else:
						break
			for pos in p:
				if p.size() < 100:
					core.world.update_chunk(pos)
				else:
					mapgen.chunks_to_generate.push_back(pos)
					count -= 1
					if count < 0:
						break
#item
	elif object_type == "item":
		core.register_item(reg.name,reg)
		gui.update_hotbar(player.id)
		gui.update_wielditems(0,player.id,true)
		update()

func save_object(reg={},text_to_replace={}):
	var text3 = ""
	var br = -1
	var st = false
	var callbacks = ""
	if reg.has("callbacks"):
		callbacks = "\n		\"callbacks\":{"
		for sub in reg.callbacks:
			callbacks = str(callbacks,"\n			\"",sub,"\":","func(_pointing,_id,_right_side):\n			pass\n			,")
		callbacks = str(callbacks,"\n		")
	
	reg = str(reg)
	for t in text_to_replace:
		reg = reg.replace(t,text_to_replace[t])
	text_to_replace = {
		"&":"",
		": ":":",
		"} ":"}",
		" }":"}",
		"{ ":"{",
		", ":",",
	}
#replacing
	var callbacks_sub = 0
	for t in text_to_replace:
		reg = reg.replace(t,text_to_replace[t])
	for l in reg.length():
		var i = reg[l]
		if i == "{":
			br += 1
		elif i == "}":
			br -= 1
		if i == "\"" and st == false:
			st = true
		elif i == "\"" and st:
			st = false
		if i == "," and br == 0 and st == false:
			text3 = str(text3,i,"\n","		")
		elif i == "}" and l+1 == reg.length():
			text3 = str(text3,"\n","	",i)
		elif l == 1:
			text3 = str(text3,"\n","		",i)
		elif callbacks_sub == 0 and reg.substr(l-12,12) == "\"callbacks\":":
			callbacks_sub = l
		elif callbacks_sub > 0 and i == "}":
			text3 = str(text3.substr(0,callbacks_sub),callbacks,i)
		else:
			text3 = str(text3,i)
	$code.text = text3
	$togglecode.show()
