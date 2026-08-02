extends Node

var serial: GdSerial
var car  : VehicleBody3D
func _ready():
	serial = GdSerial.new()
	serial.set_port("/dev/pts/7")
	serial.set_baud_rate(115200)
	car = get_parent()
	
	
	if serial.open():
		serial.writeline("Hello!")
func _process(delta):
	if serial and serial.is_open():
		# Check if data is available
		if serial.bytes_available() > 0:
			var data = serial.readline()
			print("Raw Serial Data: ", data)
			if data.begins_with("s"):
					data = data.trim_prefix("s ")
					var amnt = data.to_float()
					car.steering= deg_to_rad(amnt)
	print('steer ', car.steering)
	print('speed ', car.linear_velocity)
				
					
					
func _exit_tree():
	serial.close()
