extends Node

var timer = 1
var mapgens = ["lakes","flatland","test"]
var mapgen_data = {}
var chunks_to_generate = []
var chunks_to_generate_timeout = 0
var chunks_to_generate_time = 0.1
var chunks_to_generate_time_bussy = 0.1
var chunks_to_generate_time_calm = 0.5
var chunks_to_generate_range = 0
var set_bussy = false
var points1 = []
var points2 = []
var points2_timer = 0
var scatters = {}
var set_nex = []
var default_noise = {
	"frequency":0.005,
	"fractal_octaves":5,
	"fractal_lacunarity":2,
	"seed":100,
	"fractal_gain":1,
	"noise_type":FastNoiseLite.TYPE_VALUE
}

func _ready():
	chunks_to_generate_range = ceil(core.settings.ganerate_chunk_range/2)

var set_nex_time = 0

func _process(delta):
	if core.Game == false:
		return
	if set_nex.size() > 0:
		set_nex_time += delta
		if set_nex_time > 0.1:
			var t = (Time.get_unix_time_from_system()*1000)+10
			set_nex_time = 0
			while Time.get_unix_time_from_system()*1000 < t and set_nex.size() > 0:
				var nex = set_nex.pop_back()
				core.set_nodeextractor(nex.file,nex.pos,nex.flag,nex.dir,false)
				await get_tree().process_frame
		
	timer -= delta
	if timer < 0:
		timer = 1
##add chunks to generate
		var new_points = []
		var chunks = core.world.chunks
		for player in core.players.values():
			var player_pos = core.world.tochunkpos(player.body.global_position)
			new_points.push_back(player_pos)
			if points1.has(player_pos) == false:
			
				var s = core.settings.base_size
				for r in chunks_to_generate_range+1:
					for x in range(-s*r,s*(r+1),s):
						for z in range(-s*r,s*(r+1),s):
							var r2 = 2
							for y in range(-s*r2,s*r2+s,s):
								if abs(x) < s*r and abs(y) < s*floor(r/2) and abs(z) < s*r:
									continue
								var chunk_pos = player_pos+Vector3(x,y,z)
#only generate if neighbor has mesh, priority the visible map
								var has_neighbor = false
								for dx in range(-1,2):
									for dy in range(-1,2):
										if has_neighbor:
											break
										for dz in range(-1,2):
											var d = Vector3(dx,dy,dz)
											var neighbor_pos = (chunk_pos+d*s)
											if has_neighbor == false and d != Vector3() and chunks.has(neighbor_pos) and chunks[neighbor_pos].meshinstance.mesh != null:
												has_neighbor = true
												break
#adding chunks to generate list
								if has_neighbor and (chunks.has(chunk_pos) == false or chunks[chunk_pos].generated == false) and chunks_to_generate.has(chunk_pos) == false:
									chunks_to_generate.push_back(chunk_pos)
		points1 = new_points
#chunks to generate
	var chunk_count = chunks_to_generate.size()

##calm status
	if chunk_count == 0 and chunks_to_generate_time == chunks_to_generate_time_bussy:
		chunks_to_generate_timeout -= delta
		if chunks_to_generate_timeout < -2:
			chunks_to_generate_time = chunks_to_generate_time_calm
			chunks_to_generate_range = core.settings.ganerate_chunk_range
			#print("Calm >>> count:",chunk_count," timer:",chunks_to_generate_time," range:",chunks_to_generate_range)
			points2 = points1.duplicate()
			points1.clear()
#bussy status
	elif chunks_to_generate_time == chunks_to_generate_time_calm:
		points2_timer -= delta
		if points2_timer < 0 or set_bussy:
			points2_timer = 1
			chunks_to_generate_timeout = 0
			if points1.size() != points2.size():
				points2 = points1.duplicate()
			else:
				for i in points2.size():
					if set_bussy or points2[i].distance_to(points1[i]) >= core.settings.base_size*core.settings.ganerate_chunk_range/2:
						set_bussy = false
						chunks_to_generate_time = chunks_to_generate_time_bussy
						chunks_to_generate_range = ceil(core.settings.ganerate_chunk_range/2)
						chunks_to_generate.clear()
						points1.clear()
						points2.clear()
						timer = -1
						#print("Bussy <<< count:",chunk_count," timer:",chunks_to_generate_time," range:",chunks_to_generate_range)
						return
##generate timer
	if chunk_count > 0:
		chunks_to_generate_timeout -= delta
		if chunks_to_generate_timeout < 0:
			chunks_to_generate_timeout = chunks_to_generate_time
			var updates_remove = []
			for pos in chunks_to_generate:
#check updates to remove
				var min_distance_for_generate = core.settings.base_size*chunks_to_generate_range
				for point in points1:
					min_distance_for_generate = min(min_distance_for_generate,pos.distance_to(point))
				if min_distance_for_generate >= core.settings.base_size*chunks_to_generate_range:
					updates_remove.push_back(pos)
				else:
#generate
					var exists = core.world.chunks.has(pos)
					updates_remove.push_back(pos)
					core.world.new_chunk(pos)
					if exists == false:
						break
					var state = core.world.update_chunk(pos)
					if state != "air":
						break
			for c in updates_remove:
				chunks_to_generate.erase(c)
##remove chunks
		var chunks_to_remove = []
		for pos in core.world.chunks:
			var max_distance_remove = core.settings.base_size*core.settings.unload_chunk_distance
			for player in core.players.values():
				max_distance_remove = min(max_distance_remove,pos.distance_to(player.body.global_position))
			if max_distance_remove >= core.settings.base_size*core.settings.unload_chunk_distance:
				chunks_to_remove.push_back(pos)
		for pos in chunks_to_remove:
			core.world.delete_chunk(pos)

func gen_map_chunk(pos):
	if core.settings.current_mapgen == "":
		return new_chunk_data()
	var data = Callable(mapgenerators,core.settings.current_mapgen).call(core.world.tochunkpos(pos))
	var air = core.registered_items["air"].id
	if data.list.has(air) == false and data.nodes.has(air):
		data.list.push_back(air)
	return data

func set_chunk_data_id(data:Dictionary,pos:Vector3,id:int=1):
	var p = core.world.tochunkpos(pos)
	var lpos = floor(pos-p)
	var lid = int(lpos.x + (lpos.y*core.world.y_stride) + (lpos.z*core.world.z_stride))
	data.nodes[lid] = id
	if data.list.has(id) == false:
		data.list.push_back(id)
	set_scatters(pos,data,id,lid)
	return data

func new_chunk_data():
	return {
		"nodes":core.world.new_nodes_array(),
		"list":[]
	}
func new_noise(map:Dictionary={}):
	var obnoise = {}
	var node = FastNoiseLite.new()
	for k in map:
		obnoise[k] = true
		node[k] = map[k]
		
	for k in default_noise:
		if obnoise.has(k) == false:
			node[k] = default_noise[k]
	return node

func set_scatters(rel:Vector3,data:Dictionary,id,lid):
	var data_size = data.nodes.size()
	for s in scatters.values():
		if s.generate_in == id and core.save.nodes.has(rel) == false and rel.y >= s.min_height and rel.y <= s.max_height:
			var density = s.map.get_noise_3dv(rel)
			if density >= s.min_density and density <= s.max_density:
				var ore = s.list.pick_random()

				if s.has("generate_near"):
					var near = false
					for p in core.dirrange.new(1,false):
						if core.world.gen_get_node_id(rel+p) == s.generate_near:
							near = true
							break
					if near == false:
						continue
				
				if s.place == "above":
					lid += core.world.y_stride
					rel.y += 1
				elif s.place == "under":
					lid -= core.world.y_stride
					rel.y -= 1
					
				if ore.type == "nex":
					set_nex.push_back({"file":ore.file,"pos":rel,"flag":"bottom","dir":Vector3(1,1,1)})
				elif ore.type == "node":
					if data.list.has(id) == false:
						data.list.push_back(ore.id)
					if lid < 0 or lid >= data_size:
						core.world.gen_node_id(rel,ore.id)
					else:
						data.nodes[lid] = ore.id
			
func register_scatter(scatter):
	if scatter.has("list"):
		scatters[scatter.name] = {"list":[]}
		var reg = scatters[scatter.name]
		if scatter.has("generate_in") and core.registered_items.has(scatter.generate_in):
			reg.generate_in = core.registered_items[scatter.generate_in].id
		else:
			reg.generate_in = core.registered_items.stone.id
		if scatter.has("generate_near") and core.registered_items.has(scatter.generate_near):
			reg.generate_near = core.registered_items[scatter.generate_near].id
		reg.viewcolor = scatter.viewcolor if scatter.has("viewcolor") else Color(1,1,1)
		reg.place = scatter.place if scatter.has("place") else "inside"
		reg.type = scatter.type if scatter.has("type") else "ore"
		reg.spread = scatter.spread if scatter.has("spread") else 1
		reg.count = scatter.count if scatter.has("count") else 1
		reg.seed = scatter.seed if scatter.has("seed") else 1
		reg.min_density = scatter.min_density if scatter.has("min_density") else 0.01
		reg.max_density = scatter.max_density if scatter.has("max_density") else 0.02
		reg.max_height = scatter.max_height if scatter.has("max_height") else 100
		reg.min_height = scatter.min_height if scatter.has("min_height") else -100
		reg.map = new_noise({
			"seed":int(scatter.seed) if scatter.has("seed") else 1,
			"noise_type":FastNoiseLite[str("TYPE_",scatter.noise_type)] if scatter.has("noise_type") else FastNoiseLite.TYPE_VALUE,
			"frequency": scatter.frequency if scatter.has("frequency") else 3,
			"fractal_octaves": scatter.fractal_octaves if scatter.has("fractal_octaves") else 6,
			"fractal_lacunarity": scatter.fractal_lacunarity if scatter.has("fractal_lacunarity") else 2,
			"fractal_gain": scatter.fractal_gain if scatter.has("fractal_gain") else 1.5,
		})
		
		reg.list = []
		
		for l in scatter.list:
			if l.get_extension() == "nex" and FileAccess.file_exists(l):
				reg.list.push_back({"type":"nex","file":l})
			elif core.registered_items.has(l):
				reg.list.push_back({"type":"node","id":core.registered_items[l].id})
