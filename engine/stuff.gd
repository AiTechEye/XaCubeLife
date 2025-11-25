extends Node

func new_inventory(size:int = 32,items:Array=[]):
	items.resize(size)
	return items

func inv_clear_invalid_items(ref,inv_name:String):
	var inv = get_inventory(ref,inv_name)
	if inv != null:
		for i in inv.size()-1:
			var stack = inv[i]
			if stack != null and core.registered_items.has(stack.name) == false:
				inv[i] = null
	
func itemstack(item:String,def:Dictionary={}):
	if item.find(" ") > 0:
		def.count = int(item.substr(item.find(" ")+1,-1))
		item = item.substr(0,item.find(" "))
	var reg = core.registered_items.get(item)
	if reg == null:
		return null
	var stack = {
		name = reg.name,
		count = def.count if def.has("count") and def.count <= reg.max_count else reg.max_count,
		meta = {} if def.has("meta") == false else def.meta,
	}
	if reg.type == "item":
		if reg.has("durability"):
			stack.durability = def.durability if def.has("durability") else reg.durability
	return stack

func inv_set_item(item=null,inv_name="",ref=null,index:int=0):
	var stack
	if typeof(item) == TYPE_STRING:
		stack = itemstack(item)
	elif typeof(item) == TYPE_DICTIONARY:
		stack = item.duplicate()
	if stack != null and core.registered_items.has(stack.name) == false or stack != null and stack.count <= 0:
		stack = null
	
	var inv = get_inventory(ref,inv_name)

	inv[index] = stack
	if core.players.has(ref) and inv_name == "main":
		gui.update_hotbar(ref)
		if index < 8:
			gui.update_wielditems(0,ref)


func inv_move_stack(inv_name1:String,ref1,index1:int,inv_name2:String,ref2,index2:int,from_stack1:Dictionary={}):
#move stack1 to stack2
	var inv1 = get_inventory(ref1,inv_name1)
	var inv2 = get_inventory(ref2,inv_name2)
	var stack1 = inv1[index1].duplicate()
	var stack2 = inv2[index2]
	var reg = core.registered_items[stack1.name]
	
	if stack2 == null:
		stack2 = stack1.duplicate()
		stack2.count = 0
	elif stack1.name != stack2.name:
		return
	else:
		stack2 = inv2[index2].duplicate()

	var can_add = reg.max_count - stack2.count
	
	if from_stack1.size() > 0 and from_stack1.count < can_add:
		can_add = from_stack1.count
		stack2.count += can_add
		stack1.count -= can_add
	else:
		if can_add >= stack1.count:
			stack2.count += stack1.count
			stack1.count = 0
		else:
			stack2.count += can_add
			stack1.count -= can_add
	
	
	if stack1.count <= 0:
		stack1 = null
	
	inv1[index1] = stack1
	inv2[index2] = stack2
	
	if core.players.has(ref1) and inv_name1 == "main":
		gui.update_hotbar(ref1)
		if index1 < 8 or index2 < 8:
			gui.update_wielditems(0,ref1)
	elif core.players.has(ref2) and inv_name2 == "main":
		gui.update_hotbar(ref2)
		if index1 < 8 or index2 < 8:
			gui.update_wielditems(0,ref2)

func inv_take_item(item,inv_name,ref,index=-1):
	var stack
	if typeof(item) == TYPE_STRING:
		stack = itemstack(item)
	elif typeof(item) == TYPE_DICTIONARY:
		stack = item.duplicate()
	elif index > -1:
		stack = itemstack("air",{"count":1})
	else:
		return
	var inv = get_inventory(ref,inv_name)
	var hotbar_index = false
	var count = 0
	
	if index > -1:
		var take_from_stack = inv[index]
		if take_from_stack != null:
			take_from_stack.count -= stack.count
			if take_from_stack.count <= 0:
				inv[index] = null
	else:
		for i in inv.size():
			var slot = inv[i]
			if slot != null and slot.name == stack.name:
				if slot.count > stack.count:
					slot.count -= stack.count
					stack.count = 0
				else:
					stack.count -= slot.count
					inv[i] = null
				if i < 8:
					hotbar_index = true
				if stack.count <= 0:
					break
	if core.players.has(ref) and inv_name == "main":
		gui.update_hotbar(ref)
		if hotbar_index or index < 8:
			gui.update_wielditems(0,ref)
	return stack

func inv_add_item(item,inv_name,ref,index=-1):
	var stack
	if typeof(item) == TYPE_STRING:
		stack = itemstack(item)
	elif typeof(item) == TYPE_DICTIONARY:
		stack = item.duplicate()
	else:
		return
	if core.registered_items.has(stack.name) == false:
		return
	var reg = core.registered_items[stack.name]
	var inv = get_inventory(ref,inv_name)
	var count = stack.count
	var max_count = reg.max_count
	var hotbar_index = false

	if index > -1:
		var add_to_stack = inv[index]
		if add_to_stack == null:
			inv[index] = stack.duplicate()
			count = 0
		elif add_to_stack.name == stack.name and add_to_stack.count + stack.count <= reg.max_count:
			count = 0
			inv[index].count += stack.count
		stack.count = count
	else:
		var start = 0
		for i in inv.size():
			var slot = inv[i]
			if slot != null and slot.name == stack.name and slot.count < max_count:
				start = i
				break
		for i in range(start,inv.size()):
			var slot = inv[i]
			if slot != null and slot.name == stack.name:
				var can_add = max_count - slot.count
#add to item
				if can_add <= count:
					slot.count += can_add
					count -= can_add
				else:
#add all to item
					slot.count += count
					count = 0
				if i < 8:
					hotbar_index = true
			elif slot == null:
#add to empty slot
				if max_count <= count:
					inv[i] = itemstack(reg.name,{count=max_count})
					count -= max_count
				else:
#add all to empty slot
					inv[i] = itemstack(reg.name,{count=count})
					count = 0
				if i < 8:
					hotbar_index = true
			stack.count = count
			if count <= 0:
				break
	if core.players.has(ref) and inv_name == "main":
		gui.update_hotbar(ref)
		if hotbar_index or index < 8:
			gui.update_wielditems(0,ref)
	return stack

func create_node_inventory(pos:Vector3,inv_name:String="main",size:int=32):
	var m = core.world.get_node_meta(pos)
	if m.has("inventory") == false:
		m.inventory = {}
	m.inventory[inv_name] = stuff.new_inventory(size)

func get_inventory(ref,inv_name):
	if typeof(ref) == TYPE_INT:
		if core.objects.has(ref):
			return core.objects[ref].inventory[inv_name]
	elif typeof(ref) == TYPE_VECTOR3:
		return core.world.get_node_meta(ref)[inv_name]

func get_inv_callbacks(ref):
	if typeof(ref) == TYPE_INT:
		if core.objects.has(ref):
			return core.objects[ref].formspec.inv_callbacks
	elif typeof(ref) == TYPE_VECTOR3:
		var reg = core.registered_items[core.getnode(ref).name]
		if reg.has("formspec") and reg.formspec.has("inv_callbacks"):
			return reg.formspec.inv_callbacks
		return {}
func get_item_callbacks(reg_name):
	var reg = core.get_reg(reg_name)
	if reg.has("callbacks"):
		return reg.callbacks
	return {}
func stack_2invitem(stack,slot,pos=null,z_index=0):
	var t = TextureRect.new()
	var reg = core.registered_items[stack.name]
	
	if pos != null:
		t.position = pos
	else:
		t.position = slot.position + slot.size * 0.1
	t.size = slot.size * 0.8
	t.texture = reg.inv_image
	t.expand = true
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.clip_contents = true
	t.z_index = z_index
	t.name = "item"
	
	if reg.type == "item" and reg.has("durability"):
		var bar1 = ColorRect.new()
		bar1.size = Vector2(t.size.x,3)
		bar1.position = Vector2(0,t.size.y-4)
		bar1.color = Color(255,0,0)
		t.add_child(bar1)
		var bar2 = ColorRect.new()
		var d1 = float(stack.durability)/float(reg.durability)
		bar2.size = Vector2(t.size.x*d1,3)
		bar2.color = Color(0,255,0)
		bar1.add_child(bar2)
	elif reg.type == "node" or reg.has("tool_ability") == false:
		var p = Label.new()
		p.text = str(stack.count)
		p.size = Vector2(t.size.x/2,5)
		p.position = Vector2(0,t.size.y/2)
		p.name = "count"
		t.add_child(p)
	return t

func item_groups(item):
	var reg = core.registered_items.get(item)
	if reg:
		return reg.groups
	return {}

func player_place(pos:Vector3,node_name:String,player_id:int):
	core.setnode(pos,node_name)
	var stack = itemstack(node_name)
	stack.count = 1
	stuff.inv_take_item(stack,"main",player_id,core.players[player_id].last_index)
	gui.update_hotbar(player_id)
	gui.update_wielditems(0,player_id)
	core.item_sound(pos,"place",player_id)

func item_can_break_node(item:String,node:String):
	var node_reg = core.get_reg(node)
	var item_reg = core.get_reg(item)
	if item_reg.has("tool_ability"):
		if node_reg.groups.has("loose"):
			return node_reg.groups.loose
		for g in node_reg.groups:
			if item_reg.tool_ability.has(g) and item_reg.tool_ability[g] >= node_reg.groups[g]:
				return node_reg.groups[g]
	return 0

func item_wear_by_node(node:String,player_id:int):
	var inv = get_inventory(player_id,"main")
	var player = core.players[player_id]
	var stack = inv[player.last_index]
	if stack != null and stack.has("durability"):
		var wear = item_can_break_node(stack.name,node)
		if wear > 0:
			if stack != null and stack.has("durability"):
				stack.durability -= wear
				if stack.durability <= 0:
					inv_set_item(null,"main",player_id,player.hands.left.hotbar_index)
				else:
					gui.update_hotbar(player_id)
					gui.update_wielditems(0,player_id)

func player_dig(pos:Vector3,player_id:int):
	var stack = stuff.get_item_drop(core.getnode(pos).name)
	core.setnode(pos,"air")
	stuff.inv_add_item(stack,"main",player_id)
func get_item_drop(item:String):
	var reg = core.registered_items.get(item)
	if reg:
		if reg.has("drop"):
			return itemstack(reg.drop.item,reg.drop)
	return itemstack(item)

func item2mesh(item:String, priority_render:bool = false):
	var reg = core.registered_items[item]
	var mesh = Mesh.new()
	var st = SurfaceTool.new()
	
	if reg.type == "node":
		var materials = []
		var materials2 = {}
		var faces = {}
		var mat_index = -1
		var materials_size = reg.materials.size()-1
		var mat
		for d in core.world.default_node.dir_order:
			mat_index += 1
			if mat_index <= materials_size:
				mat = reg.materials[mat_index]
				if materials.has(mat) == false:
					faces[mat] = []
					materials.push_back(mat)
					var mat2 = mat.duplicate()
					mat2.flags_no_depth_test = priority_render
					materials2[mat] = mat2
			faces[mat].push_back(d)
		if materials.size() > 0:
			for material in materials:
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_normal(Vector3.UP)
				for d in faces[material]:
					core.world.add_side(st,d,-core.pos_margin,reg.scale,reg.drawtype)
				st.set_material(materials2[material])
				st.generate_normals()
				mesh = st.commit(mesh)
	else:
		var texture = reg.wield_image
		var data = {}
		var img = texture.get_image()
		var s = img.get_size()
		img.decompress()
		img.flip_y()
		img.flip_x()
		var n = 0
		for y in s.y:
			for x in s.x:
				var color = img.get_pixel(x,y)
				if color.a != 0:
					n += 1
					if n > 1000:
						break
					var mat
					if data.has(color) == false:
						mat = StandardMaterial3D.new()
						mat.albedo_color = color
						mat.flags_no_depth_test = priority_render
						data[color] = {"mat":mat,"faces":[]}
					if x == s.x-1 or img.get_pixel(x+1,y).a == 0:
						data[color].faces.push_back({"dir":Vector3(1,0,0),"pos":Vector3(x,y,0)})
					if x == 0 or img.get_pixel(x-1,y).a == 0:
						data[color].faces.push_back({"dir":Vector3(-1,0,0),"pos":Vector3(x,y,0)})
					if y == s.y-1 or img.get_pixel(x,y+1).a == 0:
						data[color].faces.push_back({"dir":Vector3(0,1,0),"pos":Vector3(x,y,0)})
					if y == 0 or img.get_pixel(x,y-1).a == 0:
						data[color].faces.push_back({"dir":Vector3(0,-1,0),"pos":Vector3(x,y,0)})
					data[color].faces.push_back({"dir":Vector3(0,0,1),"pos":Vector3(x,y,0)})
					data[color].faces.push_back({"dir":Vector3(0,0,-1),"pos":Vector3(x,y,0)})
		for color in data:
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for face in data[color].faces:
				st.set_normal(Vector3.UP)
				core.world.add_side(st,face.dir,face.pos+Vector3(-s.x/2,-s.y/2,-0.5),0.1*reg.scale)
				st.set_material(data[color].mat)
				st.generate_normals()
			mesh = st.commit(mesh)
	return mesh

func new_item_drop(pos,dir,stack):
	var ob = core.new_object("item_drop",pos,load("res://engine/item_drop.tscn").instantiate())
	inv_add_item(stack,"main",ob.id)
	ob.body.apply_central_impulse(dir*3)
	ob.body.setup()


func simple_cube(offset_pos:Vector3=-core.pos_margin):
	var mesh = Mesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for d in core.world.default_node.dir_order:
		core.world.add_side(st,d,offset_pos)
	return st.commit(mesh)

func get_group(item_name:String,group:String):
	var reg = core.get_reg(item_name)
	if reg.groups.has(group):
		return reg.groups[group]
	return -1
