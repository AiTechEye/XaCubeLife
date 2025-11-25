extends Node

var base_size = 50

func colorize_texture(texture,color:Color=Color(1,1,1),alpha:bool=false):
	var img = texture.duplicate().get_image()
	var s = img.get_size()
	img.decompress()
	for y in s.y:
		for x in s.x:
			var c = img.get_pixel(x,y)
			if alpha:
				var c2 = c*color
				if c.a == 0:
					c2 = color
				else:
					c2.a = color.a
				img.set_pixel(x,y,c2)
			elif c.a != 0:
				img.set_pixel(x,y,c*color)
	return ImageTexture.create_from_image(img)
	
func show_gui(player_id:int,formspec=null,refresh=false):
	var player = core.players[player_id]
	if refresh == false:
		player.formspec.showing = formspec != null
		if player.formspec.showing:
			player.formspec.last = formspec
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.formspec.form.background.queue_free()
			player.formspec.form.background = null
			return
	else:
		formspec = player.formspec.last
	generate_gui(player_id,formspec)


func update_wielditems(i:int,player_id:int,forceupdate:bool=false):
	var player = core.players[player_id]
	if player.hands.right_side:
		player.hands.right.hotbar_index += i
		if player.hands.right.hotbar_index >= 8:
			player.hands.right.hotbar_index = 4
		elif player.hands.right.hotbar_index < 4:
			player.hands.right.hotbar_index = 7
		player.hands.right.bar_slot.position.x = player.hands.right.bar_slot.size.x * player.hands.right.hotbar_index
	else:
		player.hands.left.hotbar_index += i
		if player.hands.left.hotbar_index >= 4:
			player.hands.left.hotbar_index = 0
		elif player.hands.left.hotbar_index < 0:
			player.hands.left.hotbar_index = 3
		player.hands.left.bar_slot.position.x = player.hands.left.bar_slot.size.x * player.hands.left.hotbar_index

	var wield_itemr = player.inventory.main[player.hands.right.hotbar_index]
	var wield_iteml = player.inventory.main[player.hands.left.hotbar_index]

	if wield_itemr == null:
		wield_itemr = player.inventory.right_hand[0]
	if wield_itemr.name != player.hands.right.item or forceupdate:
		player.right_side_locked = true
		player.hands.right.mesh.mesh = stuff.item2mesh(wield_itemr.name,true)
		player.hands.right.item = wield_itemr.name
		var r = player.body.get_node("head/camera/right")
		if core.registered_items[wield_itemr.name].type == "node":
			r.position.y = -0.2
		else:
			r.position.y = -0.1
	
	if wield_iteml == null:
		wield_iteml = player.inventory.left_hand[0]
	if wield_iteml.name != player.hands.left.item or forceupdate:
		player.left_side_locked = true
		player.hands.left.mesh.mesh = stuff.item2mesh(wield_iteml.name,true)
		player.hands.left.item = wield_iteml.name
		var l = player.body.get_node("head/camera/left")
		if core.registered_items[wield_iteml.name].type == "node":
			l.position.y = -0.2
		else:
			l.position.y = -0.1

func update_hotbar(player_id:int):
	var player =  core.players[player_id]
	var items = player.body.get_node("ui/hotbar/items")
	for c in items.get_children():
		c.queue_free()
	for index in range(0,8):
		var stack = player.inventory.main[index]
		if stack != null:
			var img = stuff.stack_2invitem(stack,player.hands.right.bar_slot,Vector2(index*player.hands.right.bar_slot.size.x,0) + player.hands.right.bar_slot.size * 0.1)
			items.add_child(img)
			img.owner = items.owner
	core.save.objects[player.name].inventory = player.inventory

func new_background(player_id:int,def:Dictionary={}):
	var player = core.players[player_id]
	if player.formspec.form.background == null:
		player.formspec.form.background = ColorRect.new()
		player.body.get_node("ui/gui").add_child(player.formspec.form.background)
		player.formspec.form.background.owner = player.body.get_node("ui").owner
	var size = Vector2(8,4)
	if def.has("size"):
		size = def.size
	size *= base_size
	player.formspec.form.background.size = size
	player.formspec.form.background.position = (viewport_size(player_id)/2) - (size/2)
	player.formspec.form.background.color = Color(0.1,0.1,0.1,0.9)

func viewport_size(player_id:int):
	return core.players[player_id].body.get_node("ui").get_viewport_rect().size
func generate_gui(player_id:int,specs):
	var player = core.players[player_id]
	if player.formspec.form != null and player.formspec.form.background != null:
		player.formspec.form.background.queue_free()
	player.formspec.form = {"slots":{},"images":{},"ref":{},"background":null,}
	if specs.has("background"):
		new_background(player_id,specs.background)
	else:
		new_background(player_id)
	if specs.has("inv"):
		for inv in specs.inv:
			var inv_ref = inv.ref
			var size = Vector2(1,1)
			var pos = Vector2(0,0)
			
			if inv.has("size"):
				size = inv.size
			if inv.has("pos"):
				pos = inv.pos
			if str(inv_ref) == "current_node":
				inv_ref = player.pointing.pos

			var inventory = stuff.get_inventory(inv_ref,inv.name)
			var callbacks = stuff.get_inv_callbacks(inv_ref)
			if callbacks.has(str(inv.name,".on_gui_open")):
				callbacks[str(inv.name,".on_gui_open")].call()
			
			if player.formspec.form.slots.has(inv.name) == false:
				player.formspec.form.slots[inv.name] = {}
				player.formspec.form.images[inv.name] = {}
			player.formspec.form.slots[inv.name][inv_ref] = []
			player.formspec.form.images[inv.name][inv_ref] = {}
#add slots
			var i = -1
			for y in size.y:
				for x in size.x:
					i += 1
					var slot = TextureRect.new()
					slot.texture = load("res://res/textures/slot.png")
					slot.size = Vector2(base_size,base_size)
					slot.position = Vector2(pos.x+x,pos.y+y)*base_size
					player.formspec.form.background.add_child(slot)
					slot.owner = player.formspec.form.background.owner
					player.formspec.form.slots[inv.name][inv_ref].push_back(slot)	
					
#add itms
					
					if inventory != null and inventory.size() >= i:
						var stack = inventory[i]
						if stack != null:
							var img = stuff.stack_2invitem(stack,slot)
							player.formspec.form.background.add_child(img)
							img.owner = player.formspec.form.background.owner
							player.formspec.form.images[inv.name][inv_ref][i] = img
