extends CharacterBody3D

var direction = Vector3()
var gravity = -27
var current_gravity = -27
var jump_height = 9
var walk_speed = 5
var run_speed = 10
var movespeed = walk_speed
var fpv_camera_angle = 0
var fpv_mouse_sensitivity = 0.3
var fly_mode = true
var id
var breaking = 0
var place_time = 0
var in_air = false
var inside_solid = true
var inside_node = "air"
var last_steppos = Vector3()
var last_pos = Vector3()
var player
var node_reg

@onready var rhand_anim = $head/camera/right/anim
@onready var lhand_anim = $head/camera/left/anim

func _ready() -> void:
	player = core.objects[id]

func get_pointed_pos():
	var collider = $head/camera/ray.get_collider()
	var trans = $head/camera.get_global_transform()#.basis.z*0.00001
	var result = {"pos":null,"type":"none"}
	
	var aim2 = -trans.basis.z*0.5
	for i in 8:
		var p = trans.origin+(aim2*i)
		var node = core.getnode(p).name
		var reg = core.get_reg(node)
		if reg.pointable:
			result = {"pos":floor(p)+core.pos_margin,"outside":floor(trans.origin+(aim2*(i-1)))+core.pos_margin,"type":"node"}
			if reg.solid == false:
				return result
	if $head/camera/ray.is_colliding() and collider != self and inside_solid == false:
		var aim1 = trans.basis.z*0.00001
		var p = $head/camera/ray.get_collision_point()
		if collider == core.world.get_node("chunk/collision"):
			var pos = floor(p-aim1)+core.pos_margin
			var reg = core.get_reg(core.getnode(pos).name)
			if reg.pointable:
				return {"pos":pos,"outside":floor(p+aim1)+core.pos_margin,"type":"node"}
		elif is_instance_valid(collider):
			return {"pos":p,"ref":collider,"type":"object"}
	return result
func _process(delta):
	direction = Vector3()
	var aim = get_global_transform().basis

#if inside unloaded chunk
	if last_pos != round(global_position) or core.getnode(global_position).name != inside_node:
		last_pos = round(global_position)
		core.save.objects[player.name].pos = last_pos
		
		inside_node = core.getnode(global_position).name
		node_reg = core.get_reg(inside_node)
		inside_solid = node_reg.solid
		$ui/player_info.text = str("inside:",inside_node,"\nchunk:",core.world.tochunkpos(global_position),"\nPos:",round(global_position))
		var nv = velocity.normalized()*5
		var chunk = core.world.chunks.get(core.world.tochunkpos(global_position+nv))
		if chunk == null:
			mapgen.set_bussy = true
			core.world.new_chunk(global_position+nv)
		if chunk != null and chunk.meshinstance.mesh == null:
			var s = chunk.list.size()
			if s > 1 or s > 0 and core.world.id_to_reg(chunk.list[0]).name != "air":
				mapgen.set_bussy = true
				core.world.update_chunk(global_position+nv)
	if player.formspec.showing:
		velocity.y += current_gravity * delta
	elif player.contenteditor.showing:
		return
	else:
		if Input.is_key_pressed(KEY_W):
			direction -= aim.z
		if Input.is_key_pressed(KEY_S):
			direction += aim.z
		if Input.is_key_pressed(KEY_A):
			direction -= aim.x
		if Input.is_key_pressed(KEY_D):
			direction += aim.x
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_height
		if Input.is_action_pressed("run"):
			movespeed = run_speed
		else:
			movespeed = walk_speed
		if Input.is_action_just_pressed("fly_mode"):
				lhand_anim.play("stand",0.1)
				rhand_anim.play("stand",0.1)
				fly_mode = fly_mode == false
				#$Collision.disabled = fly_mode
				velocity = Vector3(0,0,0)
		if fly_mode:
			var fly_speed = walk_speed*0.05
			if Input.is_key_pressed(KEY_SPACE):
				direction.y += 1
			elif Input.is_key_pressed(KEY_SHIFT):
				direction.y = -1
			else:
				velocity = Vector3()
			if Input.is_key_pressed(KEY_CTRL):
				fly_speed = walk_speed*0.01
			direction = direction.normalized()
			global_position += direction.lerp(direction,delta)*fly_speed
			playerlight()
		else:
			if inside_solid:
				velocity = Vector3()
			else:
				velocity.y += current_gravity * delta
				move(delta)
		handling(delta)
func handling(delta):
	player.pointing = get_pointed_pos()
	
	if player.pointing.type == "node":
		var pointed_node = core.getnode(player.pointing.pos).name
		marker()
		$ui/node_info.text = str("pointing at:",pointed_node,"\npointed pos:",player.pointing.pos,"\npointed outside:",player.pointing.outside,"\npointed chunk pos:",core.world.tochunkpos(player.pointing.pos))
		if Input.is_action_just_pressed("rmb") and player.right_side_locked:
			player.right_side_locked = false
		elif Input.is_action_pressed("rmb") and player.right_side_locked == false:
			player.last_index = player.hands.right.hotbar_index
			var item = get_wielditem(true)
			var s = core.get_reg(item.name).speed
			hand(delta,item,pointed_node,s)
			if rhand_anim.current_animation != "pick":
				rhand_anim.play("pick",0,max(1,s))

		if Input.is_action_just_pressed("lmb") and player.left_side_locked:
			player.left_side_locked = false
		elif Input.is_action_pressed("lmb") and player.left_side_locked == false:
			player.last_index = player.hands.left.hotbar_index
			var item = get_wielditem(false)
			var s = core.get_reg(item.name).speed
			hand(delta,item,pointed_node,s)
			if lhand_anim.current_animation != "pick":
				lhand_anim.play("pick",0,max(1,s))
		if place_time <= 0.25:
			place_time += delta		
	else:
		if Input.is_action_just_pressed("rmb") or Input.is_action_just_pressed("lmb"):
			var s = 0 if Input.is_action_just_pressed("rmb") else 1
			wielditem_callbacks("on_use",s)
		if player.pointing.type == "object":
			marker()
		else:
			$ui/node_info.text = str("pointing at:none")
			marker()

func marker():
	if player.pointing.type == "none":
		$marker/marker.hide()
	elif player.pointing.type == "object":
		$marker/marker.show()
		var size = Vector3()
		for n in player.pointing.ref.get_children():
			if n is CollisionShape2D:
				size = size.max(n.shape.size*n.scale)
			elif n is MeshInstance3D:
				size = size.max(n.get_aabb().size*n.scale)
		$marker/marker.global_position = player.pointing.ref.global_position
		if size != $marker/marker.mesh.size:
			$marker/marker.mesh.size = size+Vector3(0.01,0.01,0.01)
			$marker/marker.rotation = player.pointing.ref.rotation
	elif player.pointing.type == "node":
		$marker/marker.show()
		$marker/marker.global_position = player.pointing.pos
		if $marker/marker.mesh.size != Vector3(1.01,1.01,1.01):
			$marker/marker.rotation = Vector3()
			$marker/marker.mesh.size = Vector3(1.01,1.01,1.01)

func move(delta):
	var tv = velocity
	tv = velocity.lerp(direction * movespeed,15 * delta)
	velocity.x = tv.x
	velocity.z = tv.z
	set_velocity(velocity)
	set_up_direction(Vector3(0,1,0))
	move_and_slide()
	playerlight()
	
	if is_on_floor() and (last_steppos.distance_to(global_position) > 1.75 or in_air):
		last_steppos = global_position
		core.item_sound(global_position+Vector3(0,-1,0),"step",id)
	if node_reg.viscosity != 0:
		velocity *= 1-node_reg.viscosity 
	if node_reg.gravity != 1:
		current_gravity = gravity * node_reg.gravity 
	elif current_gravity != gravity:
		var front = core.getnode(global_position+Vector3(0,-1,0)+direction)
		var down = core.getnode(global_position+Vector3(0,-1,0))
		if Input.is_action_pressed("jump") and core.get_reg(front.name).solid and core.get_reg(down.name).fluid:
			current_gravity = 1
		else:
			current_gravity = gravity
	if node_reg.fluid:
		lhand_anim.play("stand",0.1)
		rhand_anim.play("stand",0.1)
		if Input.is_action_pressed("jump"):
			velocity.y = jump_height*node_reg.viscosity 
		elif Input.is_action_pressed("crawl"):
			velocity.y = -jump_height*node_reg.viscosity 
	if Input.is_action_just_pressed("jump") or is_on_floor() == false and in_air == false:
		in_air = true
		if rhand_anim.current_animation != "pick":
			rhand_anim.play("jump",0,1)
		if lhand_anim.current_animation != "pick":
			lhand_anim.play("jump",0,1)
	elif is_on_floor() and in_air:
		in_air = false
		if rhand_anim.current_animation != "pick":
			rhand_anim.play_backwards("jump",0.1)
		if lhand_anim.current_animation != "pick":
			lhand_anim.play_backwards("jump",0.1)
	elif is_on_floor() and direction != Vector3():
		if rhand_anim.current_animation != "pick":
			rhand_anim.play("walk",0.1)
		if lhand_anim.current_animation != "pick":
			lhand_anim.play("walk",0.1)
	elif is_on_floor() and direction == Vector3():
		if rhand_anim.current_animation != "pick" and rhand_anim.current_animation != "stand":
			rhand_anim.play("stand",0.1)
		if lhand_anim.current_animation != "pick" and lhand_anim.current_animation != "stand":
			lhand_anim.play("stand",0.1)

func hand(delta,item,pointed_node,speed):
	var reg = core.registered_items[item.name]
	var just_pressed = (Input.is_action_just_pressed("rmb") or Input.is_action_just_pressed("lmb"))
	
	if reg.type == "node":
		if just_pressed and core.node_handling(player.pointing.outside,"before_place",id) == false:
			return
		elif place_time > 0.25 and player.pointing.outside.distance_to(global_position) > 0.75:
			place_time = 0
			if core.get_reg(core.getnode(player.pointing.outside)).replaceable:
				if wielditem_callbacks("on_place",0 if Input.is_action_just_pressed("rmb") else 1) == false:
					return
				stuff.player_place(player.pointing.outside,item.name,id)
				core.node_handling(player.pointing.outside,"place",id)
				wielditem_callbacks("after_place",0 if Input.is_action_just_pressed("rmb") else 1)
	elif reg.type == "item":
		if just_pressed and core.node_handling(player.pointing.pos,"punch",id) == false:
			return
		elif just_pressed and wielditem_callbacks("on_use",0 if Input.is_action_just_pressed("rmb") else 1) == false:
			return
		var breaking_speed = stuff.item_can_break_node(item.name,pointed_node)
		if breaking_speed > 0 and core.node_handling(player.pointing.pos,"can_break",id) != false and node_breaking(delta*(speed*breaking_speed)):
			stuff.player_dig(player.pointing.pos,id)
			stuff.item_wear_by_node(pointed_node,id)
			$marker/marker.hide()

func digging_sound():
	if player.pointing.type == "node" and breaking > 0:
		core.item_sound(player.pointing.pos,"dig",id)

func node_breaking(delta):
	var step1 = floor((breaking)*5)*2
	breaking += delta
	var step2 = floor((breaking)*5)*2
	if player.pointing.pos != $marker/crack.global_position:
		breaking = 0
		$marker/crack.global_position = player.pointing.pos
		$marker/crack.show()
		step1 = 1
		step2 = 0
	if step1 != step2:
		if breaking >= 1.0:
			breaking = 0
			$marker/crack.hide()
			core.item_sound(player.pointing.pos,"dug",id)
			return true
		var m = $marker/crack.get_surface_override_material(0)
		m.uv1_scale = Vector3(1,0.2,1)
		m.uv1_offset = Vector3(0,step2*0.1,0)
		$marker/crack.set_surface_override_material(0,m)
	return false
func get_wielditem(right=true):
	var inv = player.inventory
	var stack
	if right:
		stack = inv.main[player.hands.right.hotbar_index]
		if stack == null:
			stack = inv.right_hand[0]
	else:
		stack = inv.main[player.hands.left.hotbar_index]
		if stack == null:
			stack = inv.left_hand[0]
	return stack

var move_item = {
	"object":null,
	"inv":"",
	"index":0,
	"stack":null,
	"relpos":Vector2(),
	"image":null,
}

func _input(event: InputEvent) -> void:
	if player.contenteditor.showing:
		if Input.is_key_pressed(KEY_ESCAPE):
			get_tree().quit()
		return
	elif event is InputEventMouseMotion and player.formspec.showing == false:
		var view_speed = fpv_mouse_sensitivity
		var relx = event.relative.x
		var rely = event.relative.y
		rotate_y(deg_to_rad(-relx * view_speed))
		var change = -rely * view_speed
		if change + fpv_camera_angle < 90 and change + fpv_camera_angle > -90:
			$head/camera.rotate_x(deg_to_rad(change))
			fpv_camera_angle += change

	var hands = player.hands

	if Input.is_action_just_pressed("contenteditor"):
		toggle_contenteditor()
	elif Input.is_key_pressed(KEY_ESCAPE):
		if player.formspec.showing:
			gui.show_gui(id)
		else:
			get_tree().quit()
		return
	elif Input.is_action_just_pressed("dropitem_left") or Input.is_action_just_pressed("dropitem_right"):
		var i = hands.right.hotbar_index
		if Input.is_action_just_pressed("dropitem_left"):
			i = hands.left.hotbar_index
		var item = stuff.get_inventory(id,"main")[i]
		if item != null:
			var aim = player.body.get_node("head/camera").get_global_transform().basis
			item = item.duplicate()
			if Input.is_key_pressed(KEY_SHIFT):
				item.count = 1
			stuff.new_item_drop(player.body.global_position-(aim.z),-aim.z,item)
			stuff.inv_take_item(item,"main",id,i)
	elif Input.is_action_just_pressed("swap_side"):
		hands.right_side = !hands.right_side
		for i in 2:
			wielditem_callbacks("on_swap",i)
	elif Input.is_action_just_pressed("activate"):
		if player.formspec.showing:
			gui.show_gui(id)
		elif player.pointing.type == "node" and core.node_handling(player.pointing.pos,"activate",id) == false:
			return
		else:
			gui.show_gui(id,player.formspec)
		return
	elif player.formspec.showing:
		if event is InputEventMouseMotion:
			if move_item.stack != null and player.formspec.form.has("slots"):
				move_item.image.global_position = get_viewport().get_mouse_position() + move_item.relpos
		if event is InputEventMouseButton:
			if event.button_index >= 1 and event.button_index <= 3:
				if player.formspec.form.has("slots"):
					var mp = get_viewport().get_mouse_position()
#pick item from slot
					if event.is_pressed() and move_item.stack == null:
						for inv in player.formspec.form.slots:
							
							for ref in player.formspec.form.slots[inv]:
								var i = -1
								for slot in player.formspec.form.slots[inv][ref]:
									i += 1
									if Rect2(slot.global_position,slot.size).has_point(mp):
										var stack = stuff.get_inventory(ref,inv)[i]
										if stack != null:
											move_item.ref = ref
											move_item.inv = inv
											move_item.index = i
											move_item.relpos = slot.global_position-mp
											move_item.stack = stack.duplicate()
											move_item.image = player.formspec.form.images[inv][ref][i]
											move_item.image.z_index = 1
	#pick 50% from slot
											if event.button_index == 2 and stack.count > 1:
												var c = float(stack.count)/2
												var count = int(floor(c))
												var move_count = int(ceil(c))
												if count <= 0:
													move_item.image.hide()
												move_item.image.get_node("count").text = str(count)
												var img = stuff.stack_2invitem(move_item.stack,slot,null,2)
												player.formspec.form.background.add_child(img)
												img.owner = player.formspec.form.background.owner
												move_item.image = img
												move_item.stack.count = move_count
												img.get_node("count").text = str(move_count)
											elif event.button_index == 3 and stack.count > 1:
	#pick 10 from slot
												var move_count
												if stack.count-10 <= 0:
													move_count = stack.count
													move_item.image.hide()
												else:
													move_count = 10
												move_item.image.get_node("count").text = str(stack.count-move_count)
												move_item.stack.count = move_count
												var img = stuff.stack_2invitem(move_item.stack,slot,null,2)
												player.formspec.form.background.add_child(img)
												img.owner = player.formspec.form.background.owner
												move_item.image = img
												img.get_node("count").text = str(move_count)
										return
					elif move_item.stack != null:
#add to a slot
						for inv in player.formspec.form.slots:
							if move_item.stack != null:
								for ref in player.formspec.form.slots[inv]:
									var i = -1
									for slot in player.formspec.form.slots[inv][ref]:
										i += 1
										if Rect2(slot.global_position,slot.size).has_point(mp):
											if i != move_item.index or inv != move_item.inv:
												var callbacks1 = stuff.get_inv_callbacks(ref)
												var callbacks2 = stuff.get_inv_callbacks(move_item.ref)

												if event.is_pressed() and event.button_index == 2:
													move_item.stack.count = 1
												elif event.is_pressed() and event.button_index == 3:
													move_item.stack.count = 10

												if callbacks2.has(str(inv,".allow_put")):
													move_item.stack = callbacks2[str(inv,".allow_put")].call(move_item.stack,move_item.inv,i)
													if move_item.stack == null or move_item.stack.count == 0:
														break
												if callbacks1.has(str(inv,".allow_take")):
													move_item.stack = callbacks1[str(inv,".allow_take")].call(move_item.stack,inv,move_item.index)
													if move_item.stack == null or move_item.stack.count == 0:
														break
														
												stuff.inv_move_stack(move_item.inv,move_item.ref,move_item.index,inv,ref,i,move_item.stack)
												
												if callbacks1.has(str(move_item.inv,".on_take")):
													callbacks1[str(move_item.inv,".on_take")].call(move_item.stack,move_item.index)
												if callbacks2.has(str(inv,".on_put")):
													callbacks2[str(inv,".on_put")].call(move_item.stack,i)
				
											move_item.stack = null
											break
						move_item.stack = null
						gui.show_gui(id,null,true)
						return
		return
#hotbar
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == 4:
			gui.update_wielditems(-1,id)
		elif event.button_index == 5:
			gui.update_wielditems(1,id)

func playerlight():
	var env = $head/camera.environment
	if global_position.y <= 0:
		var c = 1+(global_position.y*0.01)
		if c < 0:
			c = 0
		env.ambient_light_color = Color(c,c,c)
		env.ambient_light_energy = c
		env.background_energy_multiplier = c*2
	elif env.ambient_light_energy != 1:
		env.ambient_light_color = Color(1,1,1)
		env.ambient_light_energy = 1
		env.background_energy_multiplier = 2

func toggle_contenteditor():
	player.contenteditor.showing = !player.contenteditor.showing
	$contenteditor.visible = player.contenteditor.showing
	if player.contenteditor.showing:
		$head.hide()
		$ui.hide()
		$contenteditor.update()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		$head.show()
		$ui.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func wielditem_callbacks(callback,side):
	var item = get_wielditem(side == 0)
	var callbacks = stuff.get_item_callbacks(item.name)
	if callbacks.has(callback):
		var v = callbacks[callback].call(player.pointing,id,side == 0)
		if typeof(v) == TYPE_BOOL:
			return v
	return true
