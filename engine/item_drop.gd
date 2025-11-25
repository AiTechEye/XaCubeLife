extends RigidBody3D

var timer = 300
var timeout_check = 0
var sleep = false
var id

func _ready() -> void:
	timer = core.settings.item_drop_timeout
	$area.body_entered.connect(func(body):
		if body.get("id") != null and core.objects.get(body.id) != null:
			var ob = core.objects[body.id]
			if ob.type == "player" and timer < core.settings.item_drop_timeout-0.1:
				var inv1 = stuff.get_inventory(id,"main")
				var stack = stuff.inv_add_item(inv1[0],"main",body.id)
				var new_count = inv1[0].count-stack.count
				stack.count = new_count
				stuff.inv_take_item(stack,"main",id)
				if inv1[0] == null:
					core.delete_object(self)
			elif ob.type == "item_drop" and id != ob.id:
				var inv1 = stuff.get_inventory(id,"main")
				var inv2 = stuff.get_inventory(ob.id,"main")
				if inv1 != null and inv2 != null and inv1[0].name == inv2[0].name:# and (inv1.count < core.registered_items[inv2.name].max_count):
					stuff.inv_move_stack("main",id,0,"main",ob.id,0)
					if inv1[0] == null:
						core.delete_object(self)
	)

func _process(delta):
	timer -= delta
	if timeout_check < 0:
		if core.world.chunk_exists(position) == false or linear_velocity.length() < 0.05:
			sleep = true
			sleeping = true
			timeout_check = 0.5
		elif sleep:
			sleeping = false
			sleep = false
	else:
		timeout_check -= delta
	if timer < 0:
		set_process(false)
		core.delete_object(id)

func setup():
	var stack = stuff.get_inventory(id,"main")[0]
	if stack == null:
		core.delete_object(id)
		return
	$mesh.mesh = stuff.item2mesh(stack.name)
	var item_type = core.registered_items[stack.name].type
	if item_type != "node":
		var a = $mesh.get_aabb()
		$collision.shape.size = a.size

#var on_floor = false
#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#if timeout_check <= 0:
		#var normal = state.get_contact_local_normal(0)
		#on_floor = normal.dot(Vector3.UP) > 0.99
