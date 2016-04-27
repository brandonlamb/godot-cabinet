extends Navigation

var camrot = 0.0

var client = null
var client_peer = null
var client_id = -1;
var server = null

var server_hosted = false;
var client_connected = false;

var robot = preload("res://robot.scn");

class Client:
	var connected = false;
	var peer = null;
	var address = GDNetAddress.new();
	var name = "Unnamed";

var clients = [];

const NEW_CLIENT = 0;
const SPAWN = 1;
const MOVE_TO = 2;
const NAME = 3;
const CHAT = 4;
const DISCONNECT = 5;

var delay = 0.0;

func _ready():
	server = GDNetHost.new()
	client = GDNetHost.new()
	
	clients.resize(32);
	for i in range(clients.size()):
		clients[i] = Client.new();
	
	randomize();
	get_node("gui/name").set_text("Irul"+str(int(rand_range(99,999))));
	get_node("gui/host").connect("pressed", self, "on_btnHost");
	get_node("gui/connect").connect("pressed", self, "on_btnConnect");
	get_node("gui/log").set_readonly(true);
	get_node("gui/log").set_wrap(true);
	
	set_process(true);
	set_process_input(true);

func on_btnHost():
	get_node("gui/host").set_disabled(true);
	
	var address = GDNetAddress.new()
	address.set_host(get_node("gui/ip").get_text())
	address.set_port(get_node("gui/port").get_text().to_int())
	
	server.bind(address)
	server_hosted = true;
	add_log("Listening..");

func on_btnConnect():
	get_node("gui/connect").set_disabled(true);
	
	if !client_connected:
		var address = GDNetAddress.new()
		address.set_host(get_node("gui/ip").get_text())
		address.set_port(get_node("gui/port").get_text().to_int())
		
		client.bind();
		client_peer = client.connect(address)
		add_log(str("Connecting to ",address.get_host(),":",address.get_port()," .. "));
	
	else:
		client_peer.disconnect();

func add_bot(name, pos):
	var inst = robot.instance();
	inst.set_name(name);
	inst.set_translation(pos);
	get_node("robots").add_child(inst);

func add_log(text):
	get_node("gui/log").cursor_set_line(0);
	get_node("gui/log").insert_text_at_cursor(text+"\n");
	get_node("gui/log").cursor_set_line(0);

func send_chat(msg):
	if !client_connected || client_id == -1 || msg == "":
		return;
	
	client_peer.send_var([CHAT, client_id, msg], 0, GDNetMessage.RELIABLE);

func server_broadcast_msg(msg):
	for i in range(clients.size()):
		if !clients[i].connected:
			continue;
		clients[i].peer.send_var([CHAT, "Server", msg], 0, GDNetMessage.RELIABLE)

func get_cid_by_address(addr):
	for i in range(clients.size()):
		if !clients[i].connected:
			continue;
		if clients[i].address.get_host() == addr.get_host() && clients[i].address.get_port() == addr.get_port():
			return i;
	return -1;

func get_unused_id():
	for i in range(clients.size()):
		if !clients[i].connected:
			return i;
	return -1;

func net_process():
	while client.is_event_available():
		var event = client.get_event()
		
		if (event.get_event_type() == GDNetEvent.CONNECT):
			add_log("Connected")
			client_connected = true;
			
			get_node("gui/connect").set_disabled(false);
			get_node("gui/connect").set_text("Disconnect");
			
		if (event.get_event_type() == GDNetEvent.RECEIVE):
			var data = event.get_var();
			if data[0] == NEW_CLIENT:
				if !server_hosted:
					add_bot("robot_"+str(data[1]), Vector3(data[2],data[3],data[4]));
			
			if data[0] == SPAWN:
				client_id = data[1];
				client_peer.send_var([NAME, client_id, get_node("gui/name").get_text()], 0);
				
				if !has_node("robots/robot_"+str(client_id)) && !server_hosted:
					add_bot("robot_"+str(client_id), Vector3(data[2],data[3],data[4]));
				get_node("robots/robot_"+str(client_id)).local = true;
			
			if data[0] == MOVE_TO:
				var id = data[1];
				var begin = str2var(data[2]);
				var end = str2var(data[3]);
				
				get_node("robots/robot_"+str(id)).begin = begin;
				get_node("robots/robot_"+str(id)).move_to_pos(end);
			
			if data[0] == NAME:
				get_node("robots/robot_"+str(data[1])).get_node("name").set_text(data[2]);
			
			if data[0] == CHAT:
				add_log(str(data[1],": ",data[2]));
			
			if data[0] == DISCONNECT:
				get_node("robots/robot_"+str(data[1])).queue_free();
			
		if (event.get_event_type() == GDNetEvent.DISCONNECT):
			client_connected = false;
			client.unbind();
			
			if !server_hosted:
				for i in get_node("robots").get_children():
					i.queue_free();
			
			add_log("Disconnected");
			
			get_node("gui/connect").set_disabled(false);
			get_node("gui/connect").set_text("Connect");

	while server.is_event_available():
		var event = server.get_event()
		
		if (event.get_event_type() == GDNetEvent.CONNECT):
			var peer = server.get_peer(event.get_peer_id())
			var address = peer.get_address();
			print("Peer connected from ", address.get_host(), ":", address.get_port())
			
			var cid = get_unused_id();
			
			#if cid == -1:
				# TODO: disconnect user
			
			for i in range(clients.size()):
				if !clients[i].connected:
					continue;
				
				clients[i].peer.send_var([NEW_CLIENT, cid, 0.0, 0.0, 0.0], 0)
				
				var pos = get_node("robots/robot_"+str(i)).get_translation();
				peer.send_var([NEW_CLIENT, i, pos.x, pos.y, pos.z], 0, GDNetMessage.RELIABLE)
				peer.send_var([NAME, i, clients[i].name], 0, GDNetMessage.RELIABLE)
			
			clients[cid] = Client.new();
			clients[cid].connected = true;
			clients[cid].peer = peer;
			clients[cid].address = address;
			
			add_bot("robot_"+str(cid), Vector3());
			
			peer.send_var([SPAWN, cid, 0.0, 0.0, 0.0], 0, GDNetMessage.RELIABLE)
			
		
		elif (event.get_event_type() == GDNetEvent.RECEIVE):
			var data = event.get_var()
			
			if data[0] == MOVE_TO:
				for i in range(clients.size()):
					if !clients[i].connected:
						continue;
					
					var id = data[1];
					
					var begin = get_closest_point(get_node("robots/robot_"+str(id)).get_translation())
					var end = str2var(data[2]);
					
					get_node("robots/robot_"+str(id)).begin = begin;
					get_node("robots/robot_"+str(id)).move_to_pos(end);
					
					if i == id && client_id == id && server_hosted:
						continue;
					
					clients[i].peer.send_var([MOVE_TO, data[1], var2str(begin), data[2]], 0, GDNetMessage.RELIABLE)
			
			if data[0] == NAME:
				for i in range(clients.size()):
					if !clients[i].connected:
						continue;
					
					var id = data[1];
					clients[id].name = data[2];
					
					get_node("robots/robot_"+str(id)).get_node("name").set_text(data[2]);
					
					if i == id && client_id == id && server_hosted:
						continue;
					
					clients[i].peer.send_var([NAME, data[1], data[2]], 0, GDNetMessage.RELIABLE)
				
				server_broadcast_msg(str(data[2]," joined the game."));
			
			if data[0] == CHAT:
				var id = data[1];
				var name = clients[id].name;
				
				add_log(str(name,": ",data[2]));
				
				for i in range(clients.size()):
					if !clients[i].connected:
						continue;
					
					if i == client_id && server_hosted:
						continue;
					
					clients[i].peer.send_var([CHAT, name, data[2]], 0, GDNetMessage.RELIABLE)
		
		elif (event.get_event_type() == GDNetEvent.DISCONNECT):
			var peer = server.get_peer(event.get_peer_id())
			var address = peer.get_address();
			print("Peer disconnected from ", address.get_host(), ":", address.get_port())
			
			var cid = get_cid_by_address(address);
			server_broadcast_msg(str(clients[cid].name," disconnected from the game."));
			
			clients[cid].connected = false;
			
			get_node("robots/robot_"+str(cid)).queue_free();
			
			for i in range(clients.size()):
				if !clients[i].connected:
					continue;
				
				if i == client_id && server_hosted:
					continue;
				
				clients[i].peer.send_var([DISCONNECT, cid], 0, GDNetMessage.RELIABLE)
		
func _process(delta):
	net_process();

func _input(event):
	if (event.type == InputEvent.MOUSE_MOTION):
		if (event.button_mask&BUTTON_MASK_RIGHT):
			camrot -= event.relative_x*0.005
			get_node("cambase").set_rotation(Vector3(0, camrot, 0))
	
	if event.type == InputEvent.KEY:
		if event.pressed && event.scancode == KEY_RETURN:
			if get_node("gui/chatbox").is_visible() && get_node("gui/chatbox").has_focus():
				get_node("gui/chatbox").hide();
				send_chat(get_node("gui/chatbox").get_text());
			else:
				get_node("gui/chatbox").set_text("");
				get_node("gui/chatbox").show();
				get_node("gui/chatbox").grab_focus();