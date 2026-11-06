extends Node2D

const R = preload("res://scripts/game_rules.gd")
const LAN_SESSION_SCRIPT = preload("res://scripts/lan_session.gd")
const BG := Color("#0b1118")
const BG_2 := Color("#101a24")
const PANEL := Color("#141f2a")
const PANEL_EDGE := Color("#2c3a45")
const GOLD := Color("#c9a66b")
const IVORY := Color("#eee8dc")
const MUTED := Color("#8b9aa5")
const CELL := 38.0
const O := Vector2(61, 103)
const C := {
	"red": Color("#c95e62"),
	"green": Color("#4d987f"),
	"yellow": Color("#c69c50"),
	"blue": Color("#5d83b4")
}
const LIGHT := {
	"red": Color("#f0d5d1"),
	"green": Color("#d5e7dd"),
	"yellow": Color("#f0e2c4"),
	"blue": Color("#d7e2ef")
}
const N := {"red":"RUBY","green":"JADE","yellow":"AMBER","blue":"SAPPHIRE"}
const PLAYER_META := {
	"red":"THE VANGUARD", "green":"THE KEEPER",
	"yellow":"THE STRATEGIST", "blue":"THE RIVAL"
}

var pieces: Dictionary = {}
var turn := 0
var roll := 0
var phase := "roll"
var mode := "human_ai"
var lan_session: Node
var local_lan_seat := -1
var lan_lobby_open := false
var lan_status := "Host a room or join a player on your Wi-Fi network."
var ip_input: LineEdit
var difficulty := "balanced"
var turns := 0
var captures := 0
var homes := 0
var sixes := 0
var champion := ""
var log: Array[String] = []
var choices: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var rolling := 0.0
var die := 1
var wait_ai := 0.0
var anim_time := 0.0
var anim_length := 0.0
var anim_data: Dictionary = {}
var rules_open := false
var busy := false
var particles: Array[Dictionary] = []
var dice_spin := 0.0
var banner_time := 0.0
var banner_text := ""
var banner_color := GOLD
var pulse := 0.0
var victory_time := 0.0
var victory_announced := false
var ui_scale := 1.0
var ui_offset := Vector2.ZERO

func _ready() -> void:
	rng.randomize()
	lan_session = LAN_SESSION_SCRIPT.new()
	lan_session.name = "LanSession"
	add_child(lan_session)
	lan_session.session_status.connect(_on_lan_status)
	lan_session.action_requested.connect(_on_lan_action)
	lan_session.snapshot_received.connect(_on_lan_snapshot)
	lan_session.roster_changed.connect(_on_lan_roster)
	setup_lan_ip_input()
	get_viewport().size_changed.connect(queue_redraw)
	if not load_match():
		new_match()

func setup_lan_ip_input() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LanInputLayer"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Host IP address, e.g. 192.168.1.10"
	ip_input.text = "192.168.1.10"
	ip_input.position = Vector2(490, 355)
	ip_input.size = Vector2(300, 48)
	ip_input.visible = false
	ip_input.add_theme_font_size_override("font_size", 18)
	ip_input.add_theme_color_override("font_color", IVORY)
	ip_input.add_theme_color_override("font_placeholder_color", MUTED)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("#0d151d")
	input_style.border_color = GOLD.darkened(0.25)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(8)
	ip_input.add_theme_stylebox_override("normal", input_style)
	ip_input.add_theme_stylebox_override("focus", input_style)
	root.add_child(ip_input)

func _on_lan_status(message: String) -> void:
	lan_status = message
	queue_redraw()

func _on_lan_roster(_seats: Dictionary) -> void:
	local_lan_seat = int(lan_session.local_seat)
	if lan_session.is_host():
		publish_lan_state()
		if is_ai_turn(turn):
			wait_ai = 0.7 if phase == "roll" else 0.55
	queue_redraw()

func _on_lan_action(_peer_id: int, seat: int, action: String, payload: Dictionary) -> void:
	if not lan_session.is_host() or seat != turn or champion != "":
		return
	if action == "roll" and phase == "roll" and not busy:
		busy = true
		die = rng.randi_range(1, 6)
		rolling = 0.72
		dice_spin = 0.0
	elif action == "move" and phase == "move" and not busy:
		var token_index := int(payload.get("token", -1))
		for move in choices:
			if int(move.token) == token_index:
				commit_move(move)
				break

func _on_lan_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("disconnected"):
		busy = true
		phase = "lan_disconnected"
		return
	if lan_session.is_host():
		return
	pieces = snapshot.get("pieces", pieces).duplicate(true)
	turn = int(snapshot.get("turn", turn))
	roll = int(snapshot.get("roll", roll))
	die = int(snapshot.get("die", die))
	phase = str(snapshot.get("phase", phase))
	turns = int(snapshot.get("turns", turns))
	captures = int(snapshot.get("captures", captures))
	homes = int(snapshot.get("homes", homes))
	sixes = int(snapshot.get("sixes", sixes))
	var previous_champion := champion
	champion = str(snapshot.get("champion", champion))
	if champion != "" and previous_champion == "":
		victory_time = 0.0
		announce_victory(champion)
		spawn_burst(O + Vector2(285, 285), GOLD, 44)
	choices = snapshot.get("choices", []).duplicate(true)
	if local_lan_seat >= 0:
		lan_lobby_open = false
		ip_input.visible = false
	busy = false
	queue_redraw()

func publish_lan_state() -> void:
	if mode != "lan" or not lan_session.is_host():
		return
	lan_session.publish_snapshot({
		"pieces": pieces, "turn": turn, "roll": roll, "die": die,
		"phase": phase, "turns": turns, "captures": captures,
		"homes": homes, "sixes": sixes, "champion": champion,
		"choices": choices
	})

func _process(delta: float) -> void:
	pulse += delta
	if champion != "":
		victory_time += delta
	if rolling > 0.0:
		rolling = maxf(0.0, rolling - delta)
		dice_spin += delta * 22.0
		if rolling > 0.0 and int(dice_spin * 18.0) % 2 == 0:
			die = rng.randi_range(1, 6)
		if rolling <= 0.0:
			finish_roll()
		queue_redraw()
	if anim_length > 0.0:
		anim_time += delta
		if anim_time >= anim_length:
			finish_animation()
		queue_redraw()
	if wait_ai > 0.0:
		wait_ai = maxf(0.0, wait_ai - delta)
		if wait_ai <= 0.0:
			if phase == "roll" and is_ai_turn(turn):
				ai_begin_roll()
			elif phase == "move" and is_ai_turn(turn):
				ai_choose_move()
	if banner_time > 0.0:
		banner_time = maxf(0.0, banner_time - delta)
	if not particles.is_empty():
		for i in range(particles.size() - 1, -1, -1):
			var particle: Dictionary = particles[i]
			particle.life = float(particle.life) - delta
			particle.pos = particle.pos + particle.velocity * delta
			particle.velocity = particle.velocity * 0.94
			particles[i] = particle
			if float(particle.life) <= 0.0:
				particles.remove_at(i)
		queue_redraw()

func _draw() -> void:
	var viewport := get_viewport_rect().size
	ui_scale = minf(viewport.x / 1280.0, viewport.y / 720.0)
	ui_offset = (viewport - Vector2(1280, 720) * ui_scale) * 0.5
	draw_set_transform(ui_offset, 0.0, Vector2(ui_scale, ui_scale))
	draw_rect(Rect2(0, 0, 1280, 720), BG)
	draw_background_detail()
	draw_header()
	draw_board()
	draw_sidebar()
	if banner_time > 0.0:
		draw_banner()
	if rules_open:
		draw_rules()
	if lan_lobby_open:
		draw_lan_lobby()
	if champion != "":
		draw_victory()
	draw_particles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_background_detail() -> void:
	for i in range(8):
		var x := 740.0 + float(i) * 78.0
		draw_line(Vector2(x, 0), Vector2(x - 240, 720), Color(1, 1, 1, 0.012), 1.0)
	draw_circle(Vector2(1110, 330), 290, Color(0.16, 0.23, 0.29, 0.045))
	draw_circle(Vector2(1110, 330), 230, Color(0.16, 0.23, 0.29, 0.035))

func draw_header() -> void:
	draw_rect(Rect2(0, 0, 1280, 68), Color("#0d151d"))
	draw_line(Vector2(0, 67), Vector2(1280, 67), PANEL_EDGE, 1.0)
	draw_round_rect(Rect2(34, 15, 39, 39), Color("#263744"), 11)
	draw_string(ThemeDB.fallback_font, Vector2(46, 43), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(87, 33), "LUDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, IVORY)
	draw_string(ThemeDB.fallback_font, Vector2(145, 33), "PRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(88, 49), "THE ROYAL BOARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MUTED)
	draw_circle(Vector2(1070, 33), 4, Color("#69b18e"))
	draw_string(ThemeDB.fallback_font, Vector2(1083, 37), "LAN NETWORK" if mode == "lan" else "OFFLINE PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#b4c1c6"))
	draw_string(ThemeDB.fallback_font, Vector2(1198, 37), "v1.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)

func draw_board() -> void:
	draw_panel(Rect2(25, 82, 644, 614), Color("#111c26"))
	draw_round_rect(Rect2(43, 98, 608, 582), Color("#d5cbbc"), 15)
	draw_round_rect(Rect2(49, 104, 596, 570), Color("#eee8dc"), 11)
	var zones := {
		"red": Rect2(O, Vector2(228, 228)),
		"blue": Rect2(O + Vector2(342, 0), Vector2(228, 228)),
		"yellow": Rect2(O + Vector2(342, 342), Vector2(228, 228)),
		"green": Rect2(O + Vector2(0, 342), Vector2(228, 228))
	}
	for color in R.COLORS:
		var zone: Rect2 = zones[color]
		draw_round_rect(zone, C[color], 8)
		draw_round_rect(zone.grow(-17), LIGHT[color], 7)
		draw_string(ThemeDB.fallback_font, zone.position + Vector2(17, 22), N[color], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C[color].darkened(0.18))
		for yard in R.YARDS[color]:
			var center := cell_center(yard)
			draw_circle(center + Vector2(0, 2), 15, Color(0, 0, 0, 0.12))
			draw_circle(center, 14, Color("#f5f1e8"))
			draw_arc(center, 14, 0, TAU, 48, C[color].darkened(0.12), 2.0, true)
	for i in range(R.TRACK.size()):
		var center := cell_center(R.TRACK[i])
		var tile := Rect2(center - Vector2(17, 17), Vector2(34, 34))
		draw_round_rect(tile, Color("#d2cabb"), 4)
		draw_round_rect(tile.grow(-1.5), Color("#fffdf8"), 3)
		if i in R.SAFE:
			draw_safe_mark(center)
		for color in R.COLORS:
			if i == int(R.START[color]):
				draw_circle(center, 4.0, C[color])
	for color in R.COLORS:
		for p in R.LANES[color]:
			var center := cell_center(p)
			draw_round_rect(Rect2(center - Vector2(17, 17), Vector2(34, 34)), C[color].darkened(0.04), 4)
			draw_round_rect(Rect2(center - Vector2(14, 14), Vector2(28, 28)), LIGHT[color], 3)
	draw_center()
	draw_tokens()
	draw_round_rect(Rect2(51, 654, 592, 17), Color("#d6cfc2"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(63, 666), "SAFE SQUARES", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#77736b"))
	draw_string(ThemeDB.fallback_font, Vector2(530, 666), "52-STEP CIRCUIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#77736b"))

func draw_safe_mark(center: Vector2) -> void:
	draw_circle(center, 7.0, Color("#e6d7b7"))
	draw_arc(center, 7.0, 0, TAU, 32, GOLD.darkened(0.1), 1.2, true)
	draw_line(center + Vector2(-3, 0), center + Vector2(3, 0), GOLD, 1.2)
	draw_line(center + Vector2(0, -3), center + Vector2(0, 3), GOLD, 1.2)

func draw_center() -> void:
	var center := O + Vector2(285, 285)
	draw_circle(center, 48, Color("#b8aa94"))
	draw_circle(center, 44, Color("#f7f1e5"))
	var triangles := [
		[Vector2(0, 0), Vector2(-42, -42), Vector2(42, -42), C.red],
		[Vector2(0, 0), Vector2(42, -42), Vector2(42, 42), C.blue],
		[Vector2(0, 0), Vector2(42, 42), Vector2(-42, 42), C.yellow],
		[Vector2(0, 0), Vector2(-42, 42), Vector2(-42, -42), C.green]
	]
	for tri in triangles:
		draw_colored_polygon(PackedVector2Array([center + tri[0], center + tri[1], center + tri[2]]), tri[3])
	draw_circle(center, 5, Color("#fff8e8"))

func draw_tokens() -> void:
	for color in R.COLORS:
		for i in range(4):
			if anim_length > 0.0 and anim_data.color == color and int(anim_data.token) == i:
				continue
			var pos := token_point(color, int(pieces[color][i]), i)
			var can_move := color == R.COLORS[turn] and token_is_legal(i) and is_human(turn)
			draw_token(pos, color, can_move, i)
	if anim_length > 0.0:
		var t := clampf(anim_time / anim_length, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		var start := progress_point(anim_data.color, int(anim_data.from), int(anim_data.token))
		var finish := progress_point(anim_data.color, int(anim_data.to), int(anim_data.token))
		var hop := sin(t * PI) * 10.0
		draw_token(start.lerp(finish, eased) - Vector2(0, hop), anim_data.color, false, int(anim_data.token))

func draw_token(pos: Vector2, color: String, highlight: bool, index: int) -> void:
	if highlight:
		var glow := 0.28 + 0.12 * sin(pulse * 4.0)
		draw_circle(pos, 22, Color(GOLD, glow))
		draw_arc(pos, 20 + sin(pulse * 4.0) * 1.5, 0, TAU, 48, GOLD, 2.2, true)
	draw_circle(pos + Vector2(0, 4), 13, Color(0, 0, 0, 0.25))
	draw_circle(pos, 12.5, C[color].darkened(0.12))
	draw_circle(pos - Vector2(0, 1), 10.5, C[color])
	draw_arc(pos, 10.5, 0, TAU, 48, Color("#fff5df"), 1.5, true)
	draw_circle(pos + Vector2(-3.5, -4), 2.8, Color(1, 1, 1, 0.78))
	draw_string(ThemeDB.fallback_font, pos + Vector2(11, 4), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#fff8e8"))

func draw_lan_lobby() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.025, 0.035, 0.88))
	draw_panel(Rect2(330, 170, 620, 390), Color("#17242e"))
	draw_string(ThemeDB.fallback_font, Vector2(390, 220), "LOCAL NETWORK MULTIPLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(390, 265), "Play together over the same Wi-Fi", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, IVORY)
	draw_string(ThemeDB.fallback_font, Vector2(390, 295), "Host a room on one phone, then join from the others.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	draw_round_rect(Rect2(420, 430, 190, 58), GOLD, 9)
	draw_string(ThemeDB.fallback_font, Vector2(515, 465), "HOST GAME", HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color("#202a30"))
	draw_round_rect(Rect2(670, 430, 190, 58), Color("#344653"), 9)
	draw_string(ThemeDB.fallback_font, Vector2(765, 465), "JOIN GAME", HORIZONTAL_ALIGNMENT_CENTER, 180, 12, IVORY)
	draw_string(ThemeDB.fallback_font, Vector2(640, 505), lan_status, HORIZONTAL_ALIGNMENT_CENTER, 540, 9, Color("#c3cdd2"))
	draw_round_rect(Rect2(560, 525, 160, 38), Color("#263642"), 8)
	draw_string(ThemeDB.fallback_font, Vector2(640, 549), "BACK", HORIZONTAL_ALIGNMENT_CENTER, 140, 10, IVORY)
	var local_addresses: PackedStringArray = IP.get_local_addresses()
	var lan_ip := "Find your phone's Wi-Fi IPv4 address in Android Wi-Fi settings."
	for address in local_addresses:
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			lan_ip = "HOST IP: %s   ·   PORT: 24680" % address
			break
	draw_string(ThemeDB.fallback_font, Vector2(640, 405), lan_ip, HORIZONTAL_ALIGNMENT_CENTER, 550, 9, GOLD)

func draw_sidebar() -> void:
	draw_panel(Rect2(693, 82, 562, 614), Color("#111b25"))
	draw_string(ThemeDB.fallback_font, Vector2(724, 117), "ROYAL ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(724, 157), "The next move is yours.", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, IVORY)
	draw_string(ThemeDB.fallback_font, Vector2(724, 180), "Four houses. One crown. Play your strategy.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
	for i in range(4):
		var color: String = R.COLORS[i]
		var y := 199.0 + float(i) * 53.0
		var active := i == turn
		draw_round_rect(Rect2(718, y, 510, 45), Color("#243440") if active else Color("#192630"), 8)
		if active:
			draw_round_rect(Rect2(718, y, 3, 45), GOLD, 2)
		draw_circle(Vector2(740, y + 22), 6, C[color])
		draw_string(ThemeDB.fallback_font, Vector2(756, y + 19), N[color], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, IVORY)
		draw_string(ThemeDB.fallback_font, Vector2(756, y + 32), PLAYER_META[color], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(1045, y + 27), "LOCAL" if mode == "multiplayer" else ("YOU" if is_human(i) else ("LAN" if mode == "lan" and i in lan_session.seats.values() else "CPU")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD if is_human(i) else MUTED)
		var home_count := 0
		for token in pieces[color]:
			if int(token) == 57:
				home_count += 1
		for dot in range(4):
			draw_circle(Vector2(1120 + dot * 13, y + 22), 3.5, C[color] if dot < home_count else Color("#46535c"))
		draw_string(ThemeDB.fallback_font, Vector2(1190, y + 26), "%d/4" % home_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, IVORY)
	draw_line(Vector2(718, 420), Vector2(1228, 420), PANEL_EDGE, 1)
	var color := R.COLORS[turn]
	draw_string(ThemeDB.fallback_font, Vector2(720, 445), "NOW PLAYING", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(720, 475), N[color], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, C[color])
	var hint := "Roll the dice to begin." if phase == "roll" else "Choose a highlighted token."
	if phase == "ai":
		hint = "The strategist is thinking..."
	if phase == "animating":
		hint = "Moving across the board..."
	if phase == "waiting":
		hint = "Waiting for the host..."
	if phase == "lan_disconnected":
		hint = "LAN connection lost. Return to the lobby."
	if champion != "":
		hint = "A new champion has risen."
	draw_string(ThemeDB.fallback_font, Vector2(720, 494), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
	var roll_ready := phase == "roll" and is_human(turn) and not busy and champion == ""
	draw_round_rect(Rect2(718, 513, 242, 68), Color("#e0c18a") if roll_ready else Color("#43515b"), 10)
	draw_round_rect(Rect2(723, 518, 232, 58), Color("#f0d7a8") if roll_ready else Color("#53616a"), 8)
	draw_dice_face(Rect2(736, 527, 40, 40), die if roll > 0 or rolling > 0 else 1, roll_ready)
	draw_string(ThemeDB.fallback_font, Vector2(791, 542), "ROLL DICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#1b252c") if roll_ready else Color("#d5dadd"))
	draw_string(ThemeDB.fallback_font, Vector2(791, 558), "YOUR TURN" if roll_ready else "WAIT FOR TURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#65533b") if roll_ready else Color("#aab4ba"))
	draw_round_rect(Rect2(976, 513, 252, 68), Color("#263642"), 10)
	draw_string(ThemeDB.fallback_font, Vector2(1000, 553), "NEW MATCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, IVORY)
	draw_line(Vector2(718, 596), Vector2(1228, 596), PANEL_EDGE, 1)
	draw_stat(Vector2(720, 620), "TURNS", str(turns))
	draw_stat(Vector2(865, 620), "CAPTURES", str(captures))
	draw_stat(Vector2(1034, 620), "HOME", str(homes))
	draw_round_rect(Rect2(718, 640, 195, 27), Color("#263642"), 6)
	draw_string(ThemeDB.fallback_font, Vector2(730, 658), "MODE  %s  ↻" % mode_display_name(), HORIZONTAL_ALIGNMENT_LEFT, 180, 9, GOLD)
	draw_round_rect(Rect2(925, 640, 195, 27), Color("#263642"), 6)
	draw_string(ThemeDB.fallback_font, Vector2(937, 658), "AI  %s  ↻" % difficulty.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 180, 9, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(720, 679), "RULES", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(1150, 679), "SAVED LOCALLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, MUTED)

func mode_display_name() -> String:
	match mode:
		"human_ai":
			return "HUMAN VS AI"
		"multiplayer":
			return "MULTIPLAYER"
		"lan":
			return "LAN PLAYERS"
		_:
			return mode.to_upper()

func draw_stat(pos: Vector2, label: String, value: String) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, MUTED)
	draw_string(ThemeDB.fallback_font, pos + Vector2(0, 18), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, IVORY)

func draw_dice_face(rect: Rect2, value: int, active: bool) -> void:
	draw_round_rect(rect, Color("#f7f0e4") if active else Color("#d0d5d7"), 7)
	var positions := {
		1:[Vector2(0.5,0.5)],
		2:[Vector2(0.25,0.25),Vector2(0.75,0.75)],
		3:[Vector2(0.25,0.25),Vector2(0.5,0.5),Vector2(0.75,0.75)],
		4:[Vector2(0.25,0.25),Vector2(0.75,0.25),Vector2(0.25,0.75),Vector2(0.75,0.75)],
		5:[Vector2(0.25,0.25),Vector2(0.75,0.25),Vector2(0.5,0.5),Vector2(0.25,0.75),Vector2(0.75,0.75)],
		6:[Vector2(0.25,0.22),Vector2(0.75,0.22),Vector2(0.25,0.5),Vector2(0.75,0.5),Vector2(0.25,0.78),Vector2(0.75,0.78)]
	}
	for point in positions[clampi(value, 1, 6)]:
		draw_circle(rect.position + Vector2(point.x * rect.size.x, point.y * rect.size.y), 2.5, Color("#26313a"))

func draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)

func draw_panel(rect: Rect2, color: Color = PANEL) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	draw_style_box(style, rect)

func cell_center(point: Vector2i) -> Vector2:
	return O + Vector2(point) * CELL + Vector2(CELL * 0.5, CELL * 0.5)

func progress_point(color: String, pos: int, _index: int) -> Vector2:
	if pos >= 52:
		return cell_center(R.LANES[color][pos - 52])
	return cell_center(R.TRACK[R.absolute(color, pos)])

func token_point(color: String, pos: int, index: int) -> Vector2:
	if pos == -1:
		return cell_center(R.YARDS[color][index])
	if pos == 57:
		return O + Vector2(285 + (index % 2) * 12, 285 + int(index / 2) * 12)
	return progress_point(color, pos, index)

func token_is_legal(index: int) -> bool:
	for move in choices:
		if int(move.token) == index:
			return true
	return false

func new_match() -> void:
	pieces = {"red":[-1,-1,-1,-1], "green":[-1,-1,-1,-1], "yellow":[-1,-1,-1,-1], "blue":[-1,-1,-1,-1]}
	turn = 0
	roll = 0
	phase = "roll"
	turns = 0
	captures = 0
	homes = 0
	sixes = 0
	champion = ""
	log.clear()
	choices.clear()
	busy = false
	rolling = 0.0
	anim_length = 0.0
	wait_ai = 0.0
	particles.clear()
	victory_time = 0.0
	victory_announced = false
	show_banner("A NEW MATCH BEGINS", GOLD)
	save_match()
	queue_redraw()

func human_count() -> int:
	return R.human_player_count(mode)

func is_human(player: int) -> bool:
	if mode == "lan":
		return player == local_lan_seat and local_lan_seat >= 0
	return R.is_human_seat(mode, player)

func is_ai_turn(player: int) -> bool:
	if mode != "lan":
		return not is_human(player)
	if not lan_session.is_host():
		return false
	return player not in lan_session.seats.values()

func roll_dice() -> void:
	if phase != "roll" or not is_human(turn) or busy or champion != "":
		return
	if mode == "lan" and not lan_session.is_host():
		busy = true
		phase = "waiting"
		lan_session.request_action("roll")
		queue_redraw()
		return
	busy = true
	die = rng.randi_range(1, 6)
	rolling = 0.72
	dice_spin = 0.0

func ai_begin_roll() -> void:
	if phase != "roll" or is_human(turn) or busy or champion != "":
		return
	busy = true
	die = rng.randi_range(1, 6)
	rolling = 0.58
	dice_spin = 0.0

func finish_roll() -> void:
	busy = false
	roll = die
	show_banner("%s ROLLED A %d" % [N[R.COLORS[turn]], roll], C[R.COLORS[turn]])
	if roll == 6 and sixes == 2:
		add_log("%s forfeits after three sixes." % N[R.COLORS[turn]])
		sixes = 0
		next_turn()
		return
	sixes = sixes + 1 if roll == 6 else 0
	choices = R.legal_moves(pieces[R.COLORS[turn]], roll)
	if choices.is_empty():
		add_log("%s rolled %d. No legal move." % [N[R.COLORS[turn]], roll])
		if roll != 6:
			next_turn()
		elif is_ai_turn(turn):
			wait_ai = 0.5
	else:
		phase = "move"
		if is_ai_turn(turn):
			wait_ai = 0.55
	if mode == "lan":
		publish_lan_state()
	queue_redraw()

func commit_move(move: Dictionary) -> void:
	if busy or phase != "move":
		return
	if mode == "lan" and not lan_session.is_host():
		busy = true
		phase = "waiting"
		lan_session.request_action("move", {"token": int(move.token)})
		queue_redraw()
		return
	var color: String = R.COLORS[turn]
	anim_data = {"color":color, "token":int(move.token), "from":int(move.from), "to":int(move.to)}
	anim_time = 0.0
	anim_length = clampf(float(int(move.to) - int(move.from)) * 0.075, 0.24, 0.7)
	busy = true
	phase = "animating"

func finish_animation() -> void:
	anim_length = 0.0
	var color: String = anim_data.color
	var index: int = anim_data.token
	var target: int = anim_data.to
	pieces[color][index] = 57 if target == 56 else target
	var captured := false
	if target < 52:
		var absolute_target: int = R.absolute(color, target)
		if absolute_target not in R.SAFE:
			for enemy in R.COLORS:
				if enemy == color:
					continue
				for enemy_index in range(4):
					var enemy_pos: int = pieces[enemy][enemy_index]
					if enemy_pos >= 0 and enemy_pos < 52 and R.absolute(enemy, enemy_pos) == absolute_target:
						pieces[enemy][enemy_index] = -1
						spawn_burst(progress_point(color, target, index), C[color], 12)
						captured = true
	if captured:
		captures += 1
		show_banner("CAPTURE! BONUS TURN", GOLD)
	elif target == 56:
		homes += 1
		spawn_burst(token_point(color, 57, index), GOLD, 20)
		show_banner("TOKEN HOME", GOLD)
	else:
		show_banner("NICE MOVE", C[color])
	turns += 1
	add_log("%s moved token %d%s" % [N[color], index + 1, " · CAPTURE" if captured else ""])
	if R.is_winner(pieces[color]):
		champion = color
		phase = "won"
		busy = false
		victory_time = 0.0
		victory_announced = false
		spawn_burst(O + Vector2(285, 285), GOLD, 44)
		spawn_burst(Vector2(640, 355), C[color], 64)
		announce_victory(color)
		save_match()
		if mode == "lan":
			publish_lan_state()
		queue_redraw()
		return
	if roll != 6 and not captured:
		next_turn()
	else:
		roll = 0
		phase = "roll"
		choices.clear()
		busy = false
		if is_ai_turn(turn):
			wait_ai = 0.65
	save_match()
	if mode == "lan":
		publish_lan_state()
	queue_redraw()

func next_turn() -> void:
	turn = (turn + 1) % 4
	roll = 0
	phase = "roll"
	choices.clear()
	busy = false
	if is_ai_turn(turn):
		wait_ai = 0.7
	if mode == "lan":
		publish_lan_state()
	queue_redraw()

func ai_choose_move() -> void:
	if champion != "" or is_human(turn) or phase != "move" or busy:
		return
	var color: String = R.COLORS[turn]
	var move := R.choose_ai_move(color, pieces, choices, roll, difficulty)
	if not move.is_empty():
		commit_move(move)

func announce_victory(color: String) -> void:
	var announcement: String = R.victory_announcement(color)
	banner_text = "CONGRATULATIONS, %s!" % N[color]
	banner_color = GOLD
	banner_time = 3.2
	victory_announced = true
	# Use the Android device's installed native text-to-speech engine when available.
	var voices: Array = DisplayServer.tts_get_voices()
	if not voices.is_empty():
		DisplayServer.tts_speak(announcement, str(voices[0].get("id", "")), 92, 1.0, 0.92, 7401, true)
	Input.vibrate_handheld(90)

func add_log(message: String) -> void:
	log.push_front(message)
	if log.size() > 6:
		log.pop_back()

func show_banner(message: String, color: Color) -> void:
	banner_text = message
	banner_color = color
	banner_time = 1.35

func spawn_burst(position: Vector2, color: Color, amount: int) -> void:
	for i in range(amount):
		var angle := TAU * float(i) / float(amount) + rng.randf_range(-0.15, 0.15)
		var speed := rng.randf_range(35.0, 115.0)
		particles.append({"pos":position, "velocity":Vector2(cos(angle), sin(angle)) * speed, "life":rng.randf_range(0.35, 0.85), "max_life":0.85, "color":color, "size":rng.randf_range(1.5, 3.8)})

func draw_particles() -> void:
	for particle in particles:
		var alpha := clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
		draw_circle(particle.pos, float(particle.size) * alpha, Color(particle.color, alpha))

func draw_banner() -> void:
	var alpha := minf(1.0, banner_time * 2.0)
	draw_round_rect(Rect2(430, 80, 420, 34), Color(0.06, 0.1, 0.14, 0.9 * alpha), 8)
	draw_string(ThemeDB.fallback_font, Vector2(640, 102), banner_text, HORIZONTAL_ALIGNMENT_CENTER, 400, 9, Color(banner_color, alpha))

func save_match() -> void:
	var config := ConfigFile.new()
	config.set_value("match", "pieces", pieces)
	config.set_value("match", "turn", turn)
	config.set_value("match", "roll", roll)
	config.set_value("match", "mode", mode)
	config.set_value("match", "difficulty", difficulty)
	config.set_value("match", "turns", turns)
	config.set_value("match", "captures", captures)
	config.set_value("match", "homes", homes)
	config.set_value("match", "sixes", sixes)
	config.save("user://ludo_pro_save.cfg")

func load_match() -> bool:
	var config := ConfigFile.new()
	if config.load("user://ludo_pro_save.cfg") != OK:
		return false
	pieces = config.get_value("match", "pieces", {})
	if pieces.size() != 4:
		return false
	for color in R.COLORS:
		if not pieces.has(color) or pieces[color].size() != 4:
			return false
	turn = clampi(int(config.get_value("match", "turn", 0)), 0, 3)
	roll = int(config.get_value("match", "roll", 0))
	mode = str(config.get_value("match", "mode", "human_ai"))
	if mode == "lan" or mode == "solo" or mode == "duo":
		mode = "human_ai"
	elif mode == "local":
		mode = "multiplayer"
	difficulty = str(config.get_value("match", "difficulty", "balanced"))
	turns = int(config.get_value("match", "turns", 0))
	captures = int(config.get_value("match", "captures", 0))
	homes = int(config.get_value("match", "homes", 0))
	sixes = int(config.get_value("match", "sixes", 0))
	phase = "roll"
	choices.clear()
	champion = ""
	busy = false
	wait_ai = 0.0
	queue_redraw()
	return true

func draw_rules() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.78))
	draw_panel(Rect2(290, 112, 700, 500), Color("#17242e"))
	draw_string(ThemeDB.fallback_font, Vector2(340, 163), "THE ROYAL RULEBOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(340, 207), "How to claim the crown", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, IVORY)
	var rules := [
		"Roll a six to release a token from your yard.",
		"Move clockwise around the 52-square outer circuit.",
		"Capture opponents by landing on their square.",
		"Safe squares protect tokens from being captured.",
		"Enter your home lane and reach the center with an exact roll.",
		"A six or capture earns another turn. Three sixes in a row forfeit it.",
		"Bring all four tokens home first to win the match."
	]
	for i in range(rules.size()):
		draw_circle(Vector2(350, 253 + i * 39), 3, GOLD)
		draw_string(ThemeDB.fallback_font, Vector2(367, 258 + i * 39), rules[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d0d9dd"))
	draw_round_rect(Rect2(340, 535, 190, 48), GOLD, 9)
	draw_string(ThemeDB.fallback_font, Vector2(365, 565), "BACK TO GAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#202a30"))

func draw_victory() -> void:
	var reveal := clampf(victory_time / 0.72, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - reveal, 3.0)
	var breathe := 1.0 + sin(victory_time * 2.8) * 0.012
	var panel_size := Vector2(620, 430) * eased
	var panel_rect := Rect2(Vector2(640, 360) - panel_size * 0.5, panel_size)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.025, 0.035, 0.88 * eased))
	if reveal > 0.0:
		draw_circle(Vector2(640, 245), 128.0 * eased, Color(GOLD, 0.035))
		draw_arc(Vector2(640, 245), 104.0 * eased, victory_time, victory_time + TAU * 0.78, 96, Color(GOLD, 0.65 * eased), 1.5, true)
	draw_panel(panel_rect, Color("#17242e"))
	var emblem_scale := eased * breathe
	draw_circle(Vector2(640, 235), 43.0 * emblem_scale, Color("#3a3328"))
	draw_arc(Vector2(640, 235), 43.0 * emblem_scale, 0, TAU, 64, GOLD, 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(640, 248), "♛", HORIZONTAL_ALIGNMENT_CENTER, 80, 34, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(640, 307), "THE ROYAL BOARD ANNOUNCES", HORIZONTAL_ALIGNMENT_CENTER, 440, 9, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(640, 354), "CONGRATULATIONS!", HORIZONTAL_ALIGNMENT_CENTER, 500, 25, IVORY)
	draw_string(ThemeDB.fallback_font, Vector2(640, 401), N[champion] + " IS THE CHAMPION", HORIZONTAL_ALIGNMENT_CENTER, 500, 21, C[champion])
	draw_string(ThemeDB.fallback_font, Vector2(640, 430), "A brilliant victory. The crown is yours.", HORIZONTAL_ALIGNMENT_CENTER, 450, 10, Color("#c3cdd2"))
	draw_string(ThemeDB.fallback_font, Vector2(640, 461), "%d turns   ·   %d captures" % [turns, captures], HORIZONTAL_ALIGNMENT_CENTER, 400, 9, MUTED)
	draw_round_rect(Rect2(520, 495, 240, 54), GOLD, 10)
	draw_round_rect(Rect2(525, 500, 230, 44), Color("#efd8ae"), 7)
	draw_string(ThemeDB.fallback_font, Vector2(640, 528), "PLAY AGAIN", HORIZONTAL_ALIGNMENT_CENTER, 220, 11, Color("#202a30"))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		handle_tap(to_design_point(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_tap(to_design_point(event.position))

func to_design_point(point: Vector2) -> Vector2:
	return (point - ui_offset) / maxf(ui_scale, 0.001)

func handle_tap(point: Vector2) -> void:
	if lan_lobby_open:
		if Rect2(420, 430, 190, 58).has_point(point):
			var error: Error = lan_session.host_game()
			if error == OK:
				local_lan_seat = 0
				lan_lobby_open = false
				ip_input.visible = false
				new_match()
				publish_lan_state()
			lan_status = "Hosting on port 24680. Other players enter this phone's Wi-Fi IP."
			queue_redraw()
		elif Rect2(670, 430, 190, 58).has_point(point):
			var error: Error = lan_session.join_game(ip_input.text)
			if error == OK:
				phase = "waiting"
				busy = true
			queue_redraw()
		elif Rect2(560, 525, 160, 38).has_point(point):
			lan_lobby_open = false
			ip_input.visible = false
			queue_redraw()
		return
	if rules_open:
		if Rect2(340, 535, 190, 48).has_point(point):
			rules_open = false
			queue_redraw()
		return
	if champion != "":
		if Rect2(520, 495, 240, 54).has_point(point):
			if mode == "lan" and not lan_session.is_host():
				return
			new_match()
			if mode == "lan":
				publish_lan_state()
		return
	if Rect2(718, 513, 242, 68).has_point(point):
		roll_dice()
		queue_redraw()
		return
	if Rect2(976, 513, 252, 68).has_point(point):
		if mode == "lan" and not lan_session.is_host():
			return
		new_match()
		if mode == "lan":
			publish_lan_state()
		return
	if Rect2(710, 642, 195, 25).has_point(point):
		var modes := ["human_ai", "multiplayer", "lan"]
		mode = modes[(modes.find(mode) + 1) % modes.size()]
		if mode == "lan":
			lan_lobby_open = true
			ip_input.visible = true
		else:
			if lan_session.is_active():
				lan_session.disconnect_session()
			local_lan_seat = -1
			lan_lobby_open = false
			ip_input.visible = false
			new_match()
		queue_redraw()
		return
	if Rect2(925, 642, 195, 25).has_point(point):
		var levels := ["balanced", "tactical", "champion"]
		difficulty = levels[(levels.find(difficulty) + 1) % levels.size()]
		new_match()
		return
	if Rect2(710, 671, 120, 24).has_point(point):
		rules_open = true
		queue_redraw()
		return
	if phase != "move" or not is_human(turn) or busy:
		return
	var color: String = R.COLORS[turn]
	for move in choices:
		var token_position := token_point(color, int(pieces[color][int(move.token)]), int(move.token))
		if token_position.distance_to(point) < 27.0:
			commit_move(move)
			return
