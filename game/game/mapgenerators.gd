extends Node

func lakes(pos):
	var nodes = mapgen.new_chunk_data()
	if mapgen.mapgen_data.has("lakes") == false:
		mapgen.mapgen_data.lakes = {
			"terrain":mapgen.new_noise({"seed":core.save.mapseed})
		}

	var grassy = core.registered_items["grassy"].id
	var dirt = core.registered_items["dirt"].id
	var stone = core.registered_items["stone"].id
	var water = core.registered_items["water"].id
	var grass1 = core.registered_items["grass1"].id
	var s = core.settings.base_size
	
	for x in range(0,s):
		for z in range(0,s):
			var density = (floor(mapgen.mapgen_data.lakes.terrain.get_noise_2d(pos.x+x,pos.z+z)*10))
			var density2 = abs(density)*-2
			for y in range(0,s):
				var lid = int(x + (y*core.world.y_stride) + (z*core.world.z_stride))
				var rel = Vector3(pos.x+x,pos.y+y,pos.z+z)
				var id
				if rel.y < density and rel.y >= density2 or rel.y < 0 and rel.y <= density and rel.y >= density2:
					id = dirt
				elif rel.y == density:
					id = grassy
				elif randi_range(1,10) == 1 and nodes.nodes[lid-core.world.y_stride] == grassy:
					id = grass1
				elif rel.y < density2:
					id = stone
				elif rel.y <= 0:
					id = water
				else:
					continue
				nodes = mapgen.set_chunk_data_id(nodes,rel,id)
	return nodes

func test(pos):
	var nodes = mapgen.new_chunk_data()
	var grassy = core.registered_items["grassy"].id
	var dirt = core.registered_items["dirt"].id
	var stone = core.registered_items["stone"].id
	var air = core.registered_items["air"].id
	var s = core.settings.base_size

	for x in range(0,s):
		for z in range(0,s):
			for y in range(0,s):
				var lid = int(x + (y*core.world.y_stride) + (z*core.world.z_stride))
				var rel = Vector3(pos.x+x,pos.y+y,pos.z+z)
				var id = air
				var rel2 = abs(rel)
				
				if rel.y == 1 and nodes.nodes[lid-core.world.y_stride] == grassy and (rel2.x == 10 or rel2.z == 10):
					id = grassy
					nodes.nodes[lid-core.world.y_stride] = dirt
				elif rel2.x <= 10 and rel2.z <= 10:
					if rel.y == 0:
						id = grassy
					elif rel.y < 0 and rel.y >= -2:
						id = dirt
					elif rel.y <= -3 and rel.y >= -10:
						id = stone
				
				nodes = mapgen.set_chunk_data_id(nodes,rel,id)
	return nodes

func flatland(pos):
	var data = mapgen.new_chunk_data()
	var grassy = core.registered_items["grassy"].id
	var dirt = core.registered_items["dirt"].id
	var stone = core.registered_items["stone"].id
	var s = core.settings.base_size#/2
	for x in range(0,s):
		for z in range(0,s):
			for y in range(0,s):
				var rel = Vector3(x,y,z)+pos
				var id
				if rel.y == 0:
					id = grassy
				elif rel.y < 0 and rel.y >= -4:
					id = dirt
				elif rel.y < -4:
					id = stone
				else:
					continue
				data = mapgen.set_chunk_data_id(data,rel,id)
	return data
