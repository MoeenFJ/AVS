extends Node

var udp: PacketPeerUDP
var car: Car
const PORT = 4242

func _ready():
	car = get_parent()
	udp = PacketPeerUDP.new()
	
	# Bind to localhost on your chosen port
	if udp.bind(PORT, "127.0.0.1") == OK:
		print("UDP Server listening on port ", PORT)
	else:
		print("Failed to bind UDP port.")

func _process(_delta):
	# Check if any data packets have arrived
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var data = packet.get_string_from_utf8().strip_edges()
		
		if not data.is_empty():
			print("Raw UDP Data: ", data)
			
			if data.begins_with("s"):
				data = data.trim_prefix("s ")
				var amnt = data.to_float()
				car.ai_steer = deg_to_rad(amnt)
			if data.begins_with("a"):
				data = data.trim_prefix("a ")
				var amnt = data.to_float()
				car.ai_acceleration = amnt;
				#car.app
				
	print('steer ', car.steering)
	print('speed ', car.linear_velocity)

func _exit_tree():
	if udp:
		udp.close()
