extends WindowDialog

# We can't play audio until we streamed enough of the file. This value
# (how many bytes needed) is experimentally derived.
const _BYTES_NEEDED_TO_PLAY_FILE = 8192 # 8kb

var item:Dictionary # URL, etc.

var thread:Thread # BG thread that buffers data
var buffer:PoolByteArray = PoolByteArray() # buffered data

func _ready():
	thread = Thread.new()
	thread.start(self, "_start_streaming")
	
	###
	# Wait until we have enough data loaded that we can start. Otherwise, no audio.
	###
	while len(buffer) < _BYTES_NEEDED_TO_PLAY_FILE:
		OS.delay_msec(100)
		
	_copy_and_start()
	$AudioStreamPlayer.connect("finished", self, "_on_finished")

#func _process(t):
	#$StatusLabel.text = "Streamed: " + str(len(buffer) / 1024.0 / 1024.0) + " mb"
	#if $AudioStreamPlayer.playing:
#		print("Playing " + _seconds_to_time($AudioStreamPlayer.get_playback_position()) + " / " + _seconds_to_time(item.duration_minutes * 60))
#		print("Streamed: " + str(len(buffer) / 1024.0 / 1024.0) + " mb")

func _seconds_to_time(seconds:float):
	var int_seconds:int = seconds
	var minutes = int_seconds / 60
	var hours = minutes / 60
	
	if minutes < 60:
		return str(minutes) + ":" + str(int_seconds % 60)
	else:
		return str(hours) + ":" + str(minutes % 60) + ":" + str(int_seconds % 60)

func _copy_and_start(position = 0):
	var ogg_stream = AudioStreamOGGVorbis.new()
	ogg_stream.data = buffer
	 # crashes here
	#$AudioStreamPlayer.stream = ogg_stream
	if $AudioStreamPlayer.stream == null:
		$AudioStreamPlayer.stream = ogg_stream
		
	$AudioStreamPlayer.stream.data = buffer
	print("@4")
	$AudioStreamPlayer.play(position)
	print("@5")

func _on_finished():
	print("Finished")
	_copy_and_start($AudioStreamPlayer.get_playback_position())
	
func _start_streaming(params):
	var start = item.url.find("://") + 3
	var stop = item.url.find("/", start)
	var host = item.url.substr(start, stop - start)
	var use_ssl = item.url.find("https://") > -1
	
	var url = item.url.substr(stop, len(item.url))
	
	# Stream the file
	var http = HTTPClient.new()
	var error = http.connect_to_host(host, -1, use_ssl)
		
	############################################################
	# http://codetuto.com/2015/05/using-httpclient-in-godot/
	
	while(http.get_status() != HTTPClient.STATUS_CONNECTED):
		http.poll()
		OS.delay_msec(100)

	var headers = [
		"User-Agent: Pirulo/1.0 (Godot)",
		"Accept: */*"
	]

	# TODO: do everything below in a background thread as we play
	error = http.request(HTTPClient.METHOD_GET, url, headers)

	while (http.get_status() == HTTPClient.STATUS_REQUESTING):
		http.poll()
		OS.delay_msec(100)

	if(http.has_response()):
		headers = http.get_response_headers_as_dictionary()
		while(http.get_status() == HTTPClient.STATUS_BODY):
			http.poll()
			var chunk = http.read_response_body_chunk()
			if(chunk.size() == 0):
				OS.delay_usec(100)
			else:
				buffer.append_array(chunk)
