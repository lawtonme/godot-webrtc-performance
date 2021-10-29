extends "player.gd"

const _CACHE_SIZE = 255

var _frame := 0
var _last_received_frame := -1
var _input_cache := []
var _multiplayer := MultiplayerAPI.new()
var _client
var _server_connection

onready var _server_node = $"../Server"

func _init() -> void:
	_input_cache.resize(_CACHE_SIZE)

	if USE_WEBRTC:
		_client = WebRTCMultiplayer.new()
		_client.initialize(2, true)

		_server_connection = WebRTCPeerConnection.new()
		_server_connection.connect("session_description_created", self, "_on_offer_created")
		_server_connection.connect("ice_candidate_created", self, "_on_candidate_created")
		_client.add_peer(_server_connection, 1)
	else:
		_client = NetworkedMultiplayerENet.new()

	_multiplayer.root_node = self
	_multiplayer.connect("connected_to_server", self, "_on_connected_to_server")
	_multiplayer.connect("network_peer_packet", self, "_on_receive_frame")


func _ready() -> void:
	set_physics_process(false)

	if USE_WEBRTC:
		_server_connection.create_offer()
	else:
		_client.create_client("localhost", 9999)

	_multiplayer.network_peer = _client


func _process(_delta: float) -> void:
	_multiplayer.poll()


func _physics_process(delta: float) -> void:
	var run_left = 1 if Input.is_action_pressed("run_left") else 0
	var run_right = 1 if Input.is_action_pressed("run_right") else 0

	var input := PlayerInput.new()
	input.run_direction = run_right - run_left
	input.jump = Input.is_action_just_pressed("jump")
	input.frame = _frame

	_input_cache[_frame % _CACHE_SIZE] = input

	process_input(delta, input)

	var inputs := []
	var start_frame = max(max(_last_received_frame, 0), _frame - _CACHE_SIZE)
	for frame in range(start_frame, _frame + 1):
		inputs.push_back(_input_cache[frame % _CACHE_SIZE])

	_send_inputs(inputs)

	_frame += 1


func _on_offer_created(type: String, sdp: String) -> void:
	_client.get_peer(1).connection.set_local_description(type, sdp)
	_server_node._server.get_peer(2).connection.set_remote_description("offer", sdp)


func _on_candidate_created(media: String, index: int, name: String) -> void:
	_server_node._server.get_peer(2).connection.add_ice_candidate(media, index, name)


func _on_connected_to_server() -> void:
	set_physics_process(true)


func _send_inputs(inputs: Array) -> void:
	var stream := StreamPeerBuffer.new()

	stream.put_u8(inputs.size())

	for input in inputs:
		stream.put_8(input.run_direction)
		stream.put_u8(1 if input.jump else 0)
		stream.put_64(input.frame)

	_multiplayer.send_bytes(stream.data_array, 1, NetworkedMultiplayerPeer.TRANSFER_MODE_UNRELIABLE)


func _on_receive_frame(_id: int, data: PoolByteArray) -> void:
	var stream := StreamPeerBuffer.new()
	stream.data_array = data

	var frame = stream.get_64()
	if _last_received_frame < frame:
		_last_received_frame = frame
