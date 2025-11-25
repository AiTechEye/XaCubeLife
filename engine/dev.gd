extends Node3D

@export var play_debug = false
var player

var give = [
	"water 100",
	"wood 100",
	"stone_pick",
	"stone_hoe",
	"axe_stone",
	"stick 100",
	"stone 100",
	"dev_pick",
	"chest 10",
	"fire 100",
	"apple_tree 10",
	"apple_tree_leaves 100"
]


func _input(_event: InputEvent) -> void:
	if core.is_debug and Input.is_action_just_pressed("test"):
		for p in core.players.values():
			if p != null:
				player = p
				testmap()
				player.body.global_position = Vector3(0,5,0)
				
				for item in ["water 100","wood 100","stone_pick","stone_hoe","axe_stone","stick 100","stone 100","dev_pick","chest 10","fire 100","fire2 10","fire3 10","fire4 10","apple_tree 10","apple_tree_leaves 100"]:
					stuff.inv_add_item(stuff.itemstack(item),"main",player.id)
				
				break
	
func testmap():
	for x in range(-10,11):
		for z in range(-10,11):
			var y = 0
			if abs(x) == 10 or abs(z) == 10:
				y = 1
			core.setnode(Vector3(x,y,z),"grassy")
	for x in range(-2,3):
		for z in range(-2,6):
			if abs(x) == 2 or abs(z) >= 2:
				core.setnode(Vector3(x,1,z),"wood")
			if z > 1 and (z == 5 or x != 0):
				core.setnode(Vector3(x,2,z),"wood")
	for y in range(0,5):
		core.setnode(Vector3(16,y,0),"dirt")
