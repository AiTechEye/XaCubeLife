extends Control

var conf = {"save_selected":""}
var saves_list = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	load_conf()
	$play.hide()
	$newname.hide()
	$cancel_new.hide()
	$remove.hide()
	$remove2.hide()
	$createsave.hide()
	$mapgen.hide()
	$mapseed.hide()
	list_saves()

	for m in mapgen.mapgens:
		$mapgen.add_item(m)
	$mapgen.select(0)
	$mapseed/seed.value_changed.connect(func(v):
		$mapseed/value.text = str(int(v))
	)

	$play.pressed.connect(func():
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		core.save_file = str(conf.save_selected,".save")
		core.load_data()
		core.game_setup()
	)
	$new.pressed.connect(func():
		$new.hide()
		$newname.show()
		$cancel_new.show()
		$mapgen.show()
		$mapseed.show()
		$mapseed/seed.value = randi()
	)
	$cancel_new.pressed.connect(func():
		$new.show()
		$newname.text = ""
		$newname.hide()
		$cancel_new.hide()
		$createsave.hide()
		$mapgen.hide()
		$mapseed.hide()
	)
	$createsave.pressed.connect(func():
		core.save_file = str($newname.text,".save")
		core.save = core.save_setup({"mapseed":int($mapseed/seed.value),"mapgen":$mapgen.get_item_text($mapgen.get_selected_items()[0])})
		core.save_data()
		list_saves()
		$newname.text = ""
		$cancel_new.hide()
		$createsave.hide()
		$newname.hide()
		$mapgen.hide()
		$mapseed.hide()
		$new.show()
	)
	$newname.text_changed.connect(func(text):
		if text == "":
			$createsave.hide()
		elif saves_list.has(text) or text.is_valid_filename() == false:
			$createsave.hide()
			$newname.add_theme_color_override("font_color",Color(1,0,0))
		else:
			$newname.add_theme_color_override("font_color",Color(1,1,1))
			$createsave.show()
	)

	$user.pressed.connect(func():
		open_user_dir()
	)
	$saves.item_selected.connect(func(i):
		conf.save_selected = $saves.get_item_text(i)
		save_conf()
		$remove.show()
		$play.show()
	)
	$remove.pressed.connect(func():
		$remove.hide()
		$remove2.show()
	)
	$remove2.pressed.connect(func():
		var file = str($saves.get_item_text($saves.get_selected_items()[0]),".save")
		if FileAccess.file_exists(str("user://save/",file)):
			OS.move_to_trash(ProjectSettings.globalize_path(str("user://save/",file)))
		$saves.deselect_all()
		$play.hide()
		$remove.hide()
		$remove2.hide()
		list_saves()
		
	)
	$remove2.mouse_exited.connect(func():
		if $saves.get_selected_items().size() > 0:
			$remove.show()
			$remove2.hide()
	)
	if core.is_debug and dev.play_debug:
		$play.pressed.emit()

func list_saves():
	saves_list.clear()
	$saves.clear()
	for file in core.list_res("user://save/","save"):
		var label = file.get_file().replace(str(".",file.get_extension()),"")
		$saves.add_item(label)
		$saves.set_item_metadata($saves.item_count-1,label)
		saves_list.push_back(label)
		if label == conf.save_selected:
			$saves.select($saves.item_count-1)
			$remove.show()
			$play.show()
			
func save_conf():
	var s = FileAccess.open("user://conf.dat",FileAccess.WRITE_READ)
	s.store_var(conf)
	
func load_conf():
	if FileAccess.file_exists("user://conf.dat"):
		var s = FileAccess.open("user://conf.dat",FileAccess.READ)
		conf = s.get_var()
		s.close()

func open_user_dir():
	var path = ProjectSettings.globalize_path(OS.get_user_data_dir())
	match OS.get_name():
		"Windows":
			OS.shell_open(path)
			return
		"macOS":
			OS.execute(path,[])
			return
		"Android":
			return
	#else / Linux
	OS.execute(path,[])
	
