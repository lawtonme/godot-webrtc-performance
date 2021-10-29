extends "player.gd"

var _last_processed_frame := -1
var _pending_inputs := []
var _multiplayer := MultiplayerAPI.new()
var _server
var _client_id: int

onready var _client_node = $"../Client"

func _init() -> void:
	if USE_WEBRTC:
		_server = WebRTCMultiplayer.new()
		_server.initialize(1, true)

		var client_connection := WebRTCPeerConnection.new()
		client_connection.connect("session_description_created", self, "_on_answer_created")
		client_connection.connect("ice_candidate_created", self, "_on_candidate_created")
		_server.add_peer(client_connection, 2)
	else:
		_server = NetworkedMultiplayerENet.new()

	_multiplayer.root_node = self
	_multiplayer.connect("network_peer_connected", self, "_on_client_connected")
	_multiplayer.connect("network_peer_packet", self, "_on_receive_inputs")


func _ready() -> void:
	set_physics_process(false)

	if not USE_WEBRTC:
		_server.create_server(9999)

	_multiplayer.network_peer = _server


func _process(_delta: float) -> void:
	_multiplayer.poll()


func _physics_process(delta: float) -> void:
	for input in _pending_inputs:
		if _last_processed_frame < input.frame:
			process_input(delta, input)

			_last_processed_frame = input.frame
			_send_frame(_last_processed_frame)


func _on_client_connected(id: int) -> void:
	_client_id = id
	set_physics_process(true)


func _on_answer_created(type: String, sdp: String) -> void:
	_server.get_peer(2).connection.set_local_description(type, sdp)
	_client_node._client.get_peer(1).connection.set_remote_description("answer", sdp)


func _on_candidate_created(media: String, index: int, name: String) -> void:
	_client_node._client.get_peer(1).connection.add_ice_candidate(media, index, name)


func _send_frame(frame: int) -> void:
	var stream := StreamPeerBuffer.new()
	stream.put_64(frame)

	_multiplayer.send_bytes(stream.data_array, _client_id, NetworkedMultiplayerPeer.TRANSFER_MODE_UNRELIABLE)


func _on_receive_inputs(_id: int, data: PoolByteArray) -> void:
	var stream := StreamPeerBuffer.new()
	stream.data_array = data

	var input_count := stream.get_u8()
	for _i in range(0, input_count):
		var input := PlayerInput.new()
		input.run_direction = stream.get_8()
		input.jump = stream.get_u8() == 1
		input.frame = stream.get_64()
		
		if _last_processed_frame < input.frame:
			_pending_inputs.push_back(input)
