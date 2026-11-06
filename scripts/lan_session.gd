class_name LanSession
extends Node

signal session_status(message: String)
signal action_requested(peer_id: int, seat: int, action: String, payload: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal roster_changed(seats: Dictionary)

const PORT := 24680
const MAX_PLAYERS := 4

var peer: ENetMultiplayerPeer
var seats: Dictionary = {}
var local_seat := -1
var connected := false

func host_game(port: int = PORT) -> Error:
	disconnect_session()
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		peer = null
		session_status.emit("Could not host LAN game (%s)." % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	seats = {1: 0}
	local_seat = 0
	connected = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_status.emit("LAN room ready. Share your local IP and port %d." % port)
	roster_changed.emit(seats.duplicate(true))
	return OK

func join_game(address: String, port: int = PORT) -> Error:
	disconnect_session()
	if address.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address.strip_edges(), port)
	if error != OK:
		peer = null
		session_status.emit("Could not join LAN room (%s)." % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	session_status.emit("Connecting to %s..." % address)
	return OK

func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	seats.clear()
	local_seat = -1
	connected = false

func is_host() -> bool:
	return connected and multiplayer.is_server()

func is_active() -> bool:
	return connected and multiplayer.multiplayer_peer != null

func request_action(action: String, payload: Dictionary = {}) -> void:
	if not is_active() or local_seat < 0:
		return
	if is_host():
		action_requested.emit(1, local_seat, action, payload)
	else:
		request_action_remote.rpc_id(1, action, payload)

func publish_snapshot(snapshot: Dictionary) -> void:
	if not is_host():
		return
	snapshot_received.emit(snapshot)
	receive_snapshot.rpc(snapshot)

func seat_for_peer(peer_id: int) -> int:
	return int(seats.get(peer_id, -1))

func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	var used: Array = seats.values()
	var assigned := -1
	for candidate in range(MAX_PLAYERS):
		if candidate not in used:
			assigned = candidate
			break
	if assigned < 0:
		peer.disconnect_peer(peer_id)
		return
	seats[peer_id] = assigned
	roster_changed.emit(seats.duplicate(true))
	receive_roster.rpc_id(peer_id, seats.duplicate(true))
	session_status.emit("Player %d joined the LAN room." % (assigned + 1))

func _on_peer_disconnected(peer_id: int) -> void:
	if is_host() and seats.has(peer_id):
		var departed: int = int(seats[peer_id])
		seats.erase(peer_id)
		roster_changed.emit(seats.duplicate(true))
		session_status.emit("Player %d disconnected." % (departed + 1))

func _on_connected_to_server() -> void:
	connected = true
	session_status.emit("Connected. Waiting for the host to assign your seat.")

func _on_server_disconnected() -> void:
	connected = false
	local_seat = -1
	session_status.emit("The host disconnected.")
	snapshot_received.emit({"disconnected": true})

func _on_connection_failed() -> void:
	connected = false
	session_status.emit("Connection failed. Check the host IP and Wi-Fi network.")

@rpc("any_peer", "call_remote", "reliable")
func request_action_remote(action: String, payload: Dictionary) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var seat := seat_for_peer(sender)
	if seat >= 0:
		action_requested.emit(sender, seat, action, payload)

@rpc("authority", "call_remote", "reliable")
func receive_roster(roster: Dictionary) -> void:
	seats = roster.duplicate(true)
	local_seat = seat_for_peer(multiplayer.get_unique_id())
	connected = true
	roster_changed.emit(seats.duplicate(true))
	session_status.emit("Joined as player %d." % (local_seat + 1))

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(snapshot: Dictionary) -> void:
	snapshot_received.emit(snapshot)
