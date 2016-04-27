extends Position3D

# Member variables
const SPEED = 4.0

var begin = Vector3()
var end = Vector3()

var path = []
var navmesh;
var game;
var local = false;

func _ready():
	local = false;
	navmesh = get_node("/root/game");
	game = get_node("/root/game");
	
	set_process(true);
	set_process_input(true)

func move_to_pos(p):
	end = p
	
	_update_path()

func _update_path():
	var p = navmesh.get_simple_path(begin, end, true)
	path = Array(p) # Vector3array too complex to use, convert to regular array
	path.invert()

func _input(event):
	if get_node("/root/game").client_connected && local && (event.type == InputEvent.MOUSE_BUTTON and event.button_index == BUTTON_LEFT and event.pressed) && !is_in_rect(event.pos, get_node("/root/game/gui").get_rect()):
		var cam = get_viewport().get_camera();
		var from = cam.project_ray_origin(event.pos)
		var to = from + cam.project_ray_normal(event.pos)*100
		var p = navmesh.get_closest_point_to_segment(from, to)
		
		game.client_peer.send_var([game.MOVE_TO, game.client_id, var2str(p)], 0, GDNetMessage.RELIABLE)

func is_in_rect(pos, rect):
	return (pos.x >= rect.pos.x  && pos.x <= rect.size.width) && (pos.y >= rect.pos.y  && pos.y <= rect.size.height);

func _process(delta):
	var cam = get_viewport().get_camera();
	get_node("name").set_pos(cam.unproject_position(get_global_transform().origin+Vector3(0,1,0))-get_node("name").get_rect().size/2);
	
	if (path.size() > 1):
		var to_walk = delta*SPEED
		var to_watch = Vector3(0, 1, 0)
		while(to_walk > 0 and path.size() >= 2):
			var pfrom = path[path.size() - 1]
			var pto = path[path.size() - 2]
			to_watch = (pto - pfrom).normalized()
			var d = pfrom.distance_to(pto)
			if (d <= to_walk):
				path.remove(path.size() - 1)
				to_walk -= d
			else:
				path[path.size() - 1] = pfrom.linear_interpolate(pto, to_walk/d)
				to_walk = 0
		
		var atpos = path[path.size() - 1]
		var atdir = to_watch
		atdir.y = 0
		
		var t = Transform()
		t.origin = atpos
		t=t.looking_at(atpos + atdir, Vector3(0, 1, 0))
		set_transform(t)
		
		if (path.size() < 2):
			path = []
