extends Node3D

var base_size = 16
var y_stride = base_size*base_size
var z_stride = base_size
var chunk_size = base_size*base_size*base_size
var chunks = {}
var chunks_to_update = {}
var update_timeout = 0.01
var material_animation = {}
var save_time = 0
var active_node_types = {
	"time":0,
	"timeout":0.1,
	"liquid":{}
	}
		
func _enter_tree() -> void:
	core.world = self

func tochunkpos(pos):
	return floor(pos/base_size)*base_size

func chunk_exists(pos:Vector3):
	return chunks.has(tochunkpos(pos))

func gen_node_id(pos,id=0):
	var p = tochunkpos(pos)
	if chunks.has(p) == false:
		new_chunk(p)
	chunks[p].nodes[to_local_id(pos)] = id

func gen_get_node_id(pos=Vector3()):
	var p = tochunkpos(pos)
	if chunks.has(p):
		var lpos = floor(pos-p)
		return chunks[p].nodes[int(lpos.x + (lpos.y*y_stride) + (lpos.z*z_stride))]
	return -1


func set_node_id(setpos,id=1,update=true):
	var pos = floor(setpos)
	var p = tochunkpos(pos)
	if chunks.has(p) == false:
		new_chunk(p)
	var lpos = pos-p
	var lid = int(lpos.x + (lpos.y*y_stride) + (lpos.z*z_stride))
	var curr_lid = chunks[p].nodes[lid]
	var old_reg = id_to_reg(curr_lid)
	var reg = id_to_reg(id)
	
	set_node_meta(pos,null)
	core.node_setup(pos,id)
#==== dynamic nodes
	if old_reg.dynamic:#old
		delete_dynamic_node(pos,lid)
	if reg.dynamic:#new
		var chunk_mesh = chunks[p].meshinstance.mesh
		new_dynamic_node(pos,id,lid)
		if (old_reg.dynamic or old_reg.name == "air") and chunk_mesh != null:
			return
#==== update nodes
	chunks[p].nodes[lid] = id
	if update:
		chunks_to_update[p] = update_timeout*(chunks_to_update.size()+1)
		if chunks[p].list.has(id) == false:
			chunks[p].list.push_back(id)
		for d in default_node.dir_order:
			var p2 = tochunkpos(pos+d)
			if p2 != p:
				chunks_to_update[p2] = update_timeout
#=== active node types
		for dir in default_node.all_around:
			var rel = pos+dir
			var regs = id_to_reg(get_node_id(rel))
			if active_node_types.has(regs.drawtype) and active_node_types[regs.drawtype].has(rel) == false:
				active_node_types[regs.drawtype][rel] = {"name":regs.name,"id":regs.id,"pos":rel}

func get_node_id(pos=Vector3()):
	var p = tochunkpos(pos)
	if chunks.has(p) == false:
		new_chunk(p)
	var lpos = floor(pos-p)
	return chunks[p].nodes[int(lpos.x + (lpos.y*y_stride) + (lpos.z*z_stride))]

func to_local_id(pos=Vector3()):
	var p = tochunkpos(pos)
	var lpos = floor(pos-p)
	return int(lpos.x + (lpos.y*y_stride) + (lpos.z*z_stride))

func set_node_meta(pos=Vector3(),meta=null):
	var p = tochunkpos(pos)
	if chunks.has(p):
		var lpos = floor(pos-p)
		var id = int(lpos.x + (lpos.y*y_stride) + (lpos.z*z_stride))
		if meta != null:
			if core.save.node_meta.has(p) == false:
				core.save.node_meta[p] = {}
			if typeof(meta) != TYPE_DICTIONARY:
				push_error(str("Meta: ",type_string(typeof(meta))," instead of Dictionary"))
				return
			core.save.node_meta[p][id] = meta
		elif core.save.node_meta.has(p):
			core.save.node_meta[p].erase(id)
			if core.save.node_meta[p].size() == 0:
				core.save.node_meta.erase(p)

func get_node_meta(pos=Vector3()):
	var p = tochunkpos(pos)
	if chunks.has(p):
		var lpos = floor(pos-p)
		var id = int(lpos.x + (lpos.y*y_stride) + (lpos.z*z_stride))
		if core.save.node_meta.has(p) == false or core.save.node_meta[p].has(id) == false:
			return {}
		return core.save.node_meta[p][id]
	return {}
func id_to_reg(id):
	var nodename = core.content_id_to_name[id]
	return core.registered_items[nodename]

#chunks to update after edited
func _exit_tree() -> void:
	core.save_data()

func _process(delta: float) -> void:
	if core.Game == false:
		return
	save_time += delta
	if save_time >= core.settings.save_timeout:
		save_time = 0
		core.save_data()
		
	if chunks_to_update.size() > 0:
		for p in chunks_to_update:
			chunks_to_update[p] -= delta
			if chunks_to_update[p] < 0:
				chunks_to_update.erase(p)
				update_chunk(p)
	for anim in material_animation.values():
		anim.time -= delta
		if anim.time <= 0:
			anim.time = 1/anim.speed
			anim.curr_frame += anim.size
			if anim.curr_frame.x >= 1 or anim.curr_frame.y >= 1:
				anim.curr_frame = Vector3()
			anim.material.uv1_offset = anim.curr_frame
		
	active_node_types.time -= delta
	if active_node_types.time < 0:
		active_node_types.time = active_node_types.timeout
		var air = core.registered_items["air"].id
		var nodes_to_remove = []
		for q in active_node_types.liquid.values():
			var nodes_to_flood = [q.pos]
			var nodes_to_share = [q.pos]
			var neighbors_liquid = 0
			var m = get_node_meta(q.pos)
			if m.has("liquid") == false:
				m.liquid = 1.0
				set_node_meta(q.pos,m)
			for dir in default_node.liquid_dir_order:
				var id = get_node_id(q.pos+dir)
#fallng
				if id == air:
					if dir.y == -1:
						set_node_id(q.pos,air)
						if m.has("liquid_fall_height") == false:
							m.liquid_fall_height = -1
						else:
							m.liquid_fall_height -= 1
							if m.liquid_fall_height <= -100:
								nodes_to_remove.push_back(q.pos)
								break
						set_node_id(q.pos+dir,q.id)
						set_node_meta(q.pos+dir,m)
						break
					else:
						nodes_to_flood.push_back(q.pos+dir)
				elif id == q.id:
##liquid under
					var m2 = get_node_meta(q.pos+dir)
					if m2.has("liquid"):
						if dir.y == -1 and m2.liquid < 1.0:
							var h = 1.0 - m2.liquid
							if h >= m.liquid:
								h = m.liquid
							h = round(h*1000)/1000
							m2.liquid += h
							m.liquid -= h
							if m.liquid < 0.01:
								set_node_id(q.pos,air)
								nodes_to_remove.push_back(q.pos)
							nodes_to_share.clear()
							break
						elif abs(m2.liquid - m.liquid) > 0.005:
							neighbors_liquid += m2.liquid
							nodes_to_share.push_back(q.pos+dir)
			var s1 = nodes_to_flood.size()
			var s2 = nodes_to_share.size()
#add to free space
			if s1 > 1:
				var h = m.liquid/s1
				if is_inf(h) or h < 0.01:
					set_node_id(q.pos,air)
					nodes_to_remove.push_back(q.pos)
					continue
				for p in nodes_to_flood:
					set_node_id(p,q.id)
					set_node_meta(p,{"liquid":h})
#share with liquids
			elif s2 > 1:
				var h = (m.liquid+neighbors_liquid)/s2
				if h < 0.01:
					set_node_id(q.pos,air)
					nodes_to_remove.push_back(q.pos)
					continue
				elif h > 0.95:
					h = 1.0
				var update = round((h+m.liquid)*100)/100 == round((h+m.liquid)*10)/10
				h = round(h*1000)/1000
				for p in nodes_to_share:
					set_node_id(p,q.id,update)
					set_node_meta(p,{"liquid":h})
			else:
				nodes_to_remove.push_back(q.pos)
		for pos in nodes_to_remove:
			active_node_types.liquid.erase(pos)
		if active_node_types.liquid.size() > 0:
			for ob in core.objects.values():
				var pos = floor(ob.body.global_position)
				var m = get_node_meta(pos)
				if m.has("liquid"):
					for dir in default_node.all_around:
						var rel = pos+dir
						if dir.y != 1 and active_node_types.liquid.has(rel):
							var m2 = get_node_meta(rel)
							if m2.has("liquid") and m2.liquid < m.liquid:
								var d = rel.direction_to(pos)
								if ob.body.get("velocity") != null:
									ob.body.velocity = d*10
								elif ob.body.get("linear_velocity") != null:
									ob.body.linear_velocity = -d*5

func update_chunk(pos,dynamic_lid=-1):
	var p = tochunkpos(pos)
	var relpos = p

	if chunks.has(p) == false:
		return ""
	chunks[p].generated = true
	for l in chunks[p].light:
		l.free()
	chunks[p].light.clear()
#air only
	var list = chunks[p].list
	var all_is_same = list.size() == 1
	var air = core.registered_items["air"].id
	
	if all_is_same and list[0] == air:
		chunks[p].meshinstance.mesh = null
		chunks[p].collision.shape = null
		return "air"
	
	var materials = []
	var faces = {}
	var faces_count = 0
	var size = base_size
	var mapgen_current = core.settings.current_mapgen != ""
#dynamic
	if dynamic_lid > -1:
		size = 0
		var mat_index = -1
		var mat
		var reg = core.registered_items[core.getnode(pos).name]
		for d in default_node.dir_order:
			mat_index += 1
			if mat_index <= reg.materials.size()-1:
				mat = reg.materials[mat_index]
				if materials.has(mat) == false:
					faces[mat] = []
					materials.push_back(mat)
			faces[mat].push_back({"dir":d,"pos":-core.pos_margin*2,"solid":reg.solid,"scale":reg.scale,"drawtype":reg.drawtype})
			faces_count += 1
		if reg.has("light_energy"):
			add_light(reg,pos)
		
#check sides to add

	for y in size:
		for z in size:
			for x in size:
				var rel = Vector3(x,y,z)
				var reg_id = get_node_id(relpos+rel)
				if reg_id == air or all_is_same and x > 1 and x < size-1 and y > 1 and y < size-1 and z > 1 and z < size-1:
					continue
				var reg = id_to_reg(reg_id)

				if reg.dynamic == false:
					var mat_index = -1
					var mat
					var materials_size = reg.materials.size()-1
					var face_added = false
					for d in default_node.dir_order:
						mat_index += 1
						var neighbor_id = get_node_id(p+rel+d)
						var reg_neighbor = id_to_reg(neighbor_id)
						if mat_index <= materials_size:
							mat = reg.materials[mat_index]
							if materials.has(mat) == false:
								faces[mat] = []
								materials.push_back(mat)
						if mapgen_current and chunks.has(tochunkpos(p+rel+d)) == false:#dont add sides to empty space
							continue
						if reg.transparency != "none" and reg_id != neighbor_id or reg.transparency == "none" and reg_neighbor.transparency != "none":
							faces[mat].push_back({"dir":d,"pos":rel,"solid":reg.solid,"scale":reg.scale,"drawtype":reg.drawtype})
							faces_count += 1
							face_added = true
					if face_added and reg.has("light_energy"):
						add_light(reg,p+rel)
#add material & sides
	
	if faces_count == 0:
		chunks[p].meshinstance.mesh = null
		chunks[p].collision.shape = null
		return "no mesh"
	var mesh = Mesh.new()
	var st = SurfaceTool.new()
	var st_collision = SurfaceTool.new()
	st_collision.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for material in materials:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for f in faces[material]:
			add_side(st,f.dir,f.pos+core.pos_margin,f.scale,f.drawtype,p)
			if f.solid:
				add_side(st_collision,f.dir,f.pos+core.pos_margin,f.scale,f.drawtype)
		st.set_material(material)
		st.generate_normals()
		st.set_smooth_group(1)
		mesh = st.commit(mesh)
	
	if dynamic_lid > -1:
		chunks[p].dynamic_nodes[dynamic_lid].meshinstance.mesh = mesh
		chunks[p].dynamic_nodes[dynamic_lid].collision.shape = st_collision.commit().create_trimesh_shape()
	else:
		chunks[p].meshinstance.mesh = mesh
		chunks[p].collision.shape = st_collision.commit().create_trimesh_shape()
	return "updated"
func add_side(st:SurfaceTool,dir:Vector3=Vector3(),pos:Vector3=Vector3(),scaled:float=1.0,drawtype:String="default",chunk_pos:Vector3=Vector3()):
	var f = default_node.faces
	if scaled != 1.0:
		var f_scaled = {}
		for key in f:
			f_scaled[key] = []
			for vec in f[key]:
				f_scaled[key].push_back(vec*scaled)
		f = f_scaled
	if drawtype == "simple_cross":
		var c = default_node.cross
		var s = Vector3(0,(scaled-1)/2,0)
		add_vertex(st,c.x1,c.x2,pos+s,false,scaled)
		add_vertex(st,c.z1,c.z2,pos+s,false,scaled)
	elif drawtype == "liquid":
		var m = get_node_meta(chunk_pos+pos)
		if m.has("liquid") == false:
			m.liquid = 1.0
			set_node_meta(chunk_pos+pos,m)
		var F = {}
		for d in f:
			F[d] = []
			for i in f[d].size():
				var v = f[d][i]
				v.y *= m.liquid
				F[d].push_back(v)
		f = F
		drawtype = "default"
	if drawtype == "boxed_cross":
		var c = default_node.cross
		var s = Vector3(0,(scaled-1)/2,0)
		add_vertex(st,c.x1,c.x2,pos+s,false,scaled)
		add_vertex(st,c.z1,c.z2,pos+s,false,scaled)
		add_vertex(st,f.x1,f.x2,Vector3(1,0,0)+pos+s,true,scaled)#x+
		add_vertex(st,f.x1,f.x2,pos+s,false,scaled)#x-
		add_vertex(st,f.z1,f.z2,Vector3(0,0,1)+pos+s,true,scaled)#z+
		add_vertex(st,f.z1,f.z2,pos+s,false,scaled)#z-
	elif drawtype == "default":
		#var s = Vector3(0,(scaled-1)/2,0)
		#if dir.x == 1:
			#add_vertex(st,f.x1,f.x2,Vector3(1,0,0)+pos+s,true,scaled)#x+
		#elif dir.x == -1:
			#add_vertex(st,f.x1,f.x2,pos+s,false,scaled)#x-
		#elif dir.y == 1:
			#add_vertex(st,f.y1,f.y2,pos+s,false,scaled)#y+
		#elif dir.y == -1:
			#add_vertex(st,f.y1,f.y2,Vector3(0,-1,0)+pos+s,true,scaled)#y-
		#elif dir.z == 1:
			#add_vertex(st,f.z1,f.z2,Vector3(0,0,1)+pos+s,true,scaled)#z+
		#elif dir.z == -1:
			#add_vertex(st,f.z1,f.z2,pos+s,false,scaled)#z-
			
		if dir.x == 1:
			add_vertex(st,f.x1,f.x2,(Vector3(1,0,0)+pos)*scaled,true)#x+
		elif dir.x == -1:
			add_vertex(st,f.x1,f.x2,pos*scaled)#x-
		elif dir.y == 1:
			add_vertex(st,f.y1,f.y2,pos*scaled)#y+
		elif dir.y == -1:
			add_vertex(st,f.y1,f.y2,(Vector3(0,-1,0)+pos)*scaled,true)#y-
		elif dir.z == 1:
			add_vertex(st,f.z1,f.z2,(Vector3(0,0,1)+pos)*scaled,true)#z+
		elif dir.z == -1:
			add_vertex(st,f.z1,f.z2,pos*scaled)#z-

func add_vertex(st:SurfaceTool,ver1:PackedVector3Array,ver2:PackedVector3Array,vec:Vector3=Vector3(),mirror:bool=false,scaled:float=1.0):
	var uv1 = default_node.uv1
	var uv2 = default_node.uv2
	var r = range(2,-1,-1) if mirror else range(0,3,1)
	var spos = Vector3(1,1,1)*((1-scaled)/2)
	
	for i in r:
		st.set_uv(uv1[i])
		st.add_vertex((ver1[i]*scaled)+vec+spos)
	for i in r:
		st.set_uv(uv2[i])
		st.add_vertex((ver2[i]*scaled)+vec+spos)

func add_light(reg,pos):
	var l = OmniLight3D.new()
	var m = core.pos_margin
	if reg.dynamic:
		m = Vector3()
	l.light_color = reg.light_color
	l.light_energy = reg.light_energy
	l.omni_range = reg.light_energy*2
	l.light_specular = 0.1*reg.light_energy
	core.add_to_map(l,pos+m)
	chunks[tochunkpos(pos)].light.push_back(l)

func delete_chunk(pos:Vector3):
	var p = tochunkpos(pos)
	if chunks.has(p):
		chunks[p].meshinstance.free()
		chunks[p].collision.free()
		chunks.erase(p)
		core.save.node_meta.erase(p)
		
func new_nodes_array(nodes:Array=[]):
	if nodes.size() != chunk_size:
		nodes.resize(chunk_size)
		nodes.fill(0)
	return nodes
func new_chunk(pos:Vector3):
	var p = tochunkpos(pos)
	if chunks.has(p) == false:
		var mesh = MeshInstance3D.new()
		$chunk/mesh.add_child(mesh)
		mesh.owner = $chunk/mesh.owner
		mesh.name = str(p.x,".",p.y,".",p.z)
		mesh.position = p-core.pos_margin
		var col = CollisionShape3D.new()
		$chunk/collision.add_child(col)
		col.owner = $chunk/collision.owner
		col.name = str(p.x,".",p.y,".",p.z)
		col.position = p-core.pos_margin
		var data = mapgen.gen_map_chunk(pos)
		
		chunks[p] = {"nodes":data.nodes,"light":[],"list":data.list,"generated":false,"meshinstance":mesh,"collision":col,"pos":p,"dynamic_nodes":{}}
		
#saves
		var aabb = AABB(mesh.position,Vector3(base_size,base_size,base_size))
		var s = core.save.nodes
		for npos in s:
			if aabb.has_point(npos) and core.registered_items.has(s[npos]):
				var lid = to_local_id(npos)
				var reg = core.registered_items[s[npos]]
				data.nodes[lid] = reg.id
				if reg.dynamic:
					new_dynamic_node(npos,reg.id,lid)
				if data.list.has(reg.id) == false:
					data.list.push_back(reg.id)

func delete_dynamic_node(pos:Vector3,lid:int):
	var p = tochunkpos(pos)
	if chunks[p].dynamic_nodes.has(lid):
		var dn = chunks[p].dynamic_nodes[lid]
		dn.collision.free()
		dn.meshinstance.free()
		chunks[p].dynamic_nodes.erase(lid)
	
func new_dynamic_node(pos:Vector3,id:int,lid:int):
	var p = tochunkpos(pos)
	var pos2 = pos+core.pos_margin
	var mesh = MeshInstance3D.new()
	$chunk/mesh.add_child(mesh)
	mesh.owner = $chunk/mesh.owner
	mesh.global_position = pos2
	var col = CollisionShape3D.new()
	$chunk/collision.add_child(col)
	col.owner = $chunk/collision.owner
	col.global_position = pos2
	chunks[p].nodes[lid] = id
	chunks[p].dynamic_nodes[lid] = {"meshinstance":mesh,"collision":col}
	update_chunk(pos,lid)
	
var default_node = {
	"texture":"res://res/textures/default.png",
	"uv1":[Vector2(0,0),Vector2(1,0),Vector2(0,1)],
	"uv2":[Vector2(0,1),Vector2(1,0),Vector2(1,1)],
	"dir_order":[Vector3(0,1,0),Vector3(0,-1,0),Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)],
	"all_around":[Vector3(0,0,0),Vector3(0,1,0),Vector3(0,-1,0),Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)],
	"liquid_dir_order":[Vector3(0,-1,0),Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)],
	"cross":{
		"x1":[Vector3(0,1,0),Vector3(1,1,1),Vector3(0,0,0)],
		"x2":[Vector3(0,0,0),Vector3(1,1,1),Vector3(1,0,1)],
		"z1":[Vector3(1,1,0),Vector3(0,1,1),Vector3(1,0,0)],
		"z2":[Vector3(1,0,0),Vector3(0,1,1),Vector3(0,0,1)],
	},
	"faces":{
		"x1":[Vector3(0,1,0),Vector3(0,1,1),Vector3(0,0,0)],#north x+ south x-
		"x2":[Vector3(0,0,0),Vector3(0,1,1),Vector3(0,0,1)],
		"y1":[Vector3(0,1,0),Vector3(1,1,0),Vector3(0,1,1)],#up y+ down y-
		"y2":[Vector3(0,1,1),Vector3(1,1,0),Vector3(1,1,1)],
		"z1":[Vector3(1,1,0),Vector3(0,1,0),Vector3(1,0,0)],#east z+ west z-
		"z2":[Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,0)],
	}
}
