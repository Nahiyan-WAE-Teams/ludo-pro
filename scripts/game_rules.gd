class_name LudoRules
extends RefCounted

const COLORS := ["red", "green", "yellow", "blue"]
const START := {"red": 0, "green": 13, "yellow": 26, "blue": 39}
const SAFE := [0, 8, 13, 21, 26, 34, 39, 47]
const TRACK := [Vector2i(6,0),Vector2i(6,1),Vector2i(6,2),Vector2i(6,3),Vector2i(6,4),Vector2i(6,5),Vector2i(5,6),Vector2i(4,6),Vector2i(3,6),Vector2i(2,6),Vector2i(1,6),Vector2i(0,6),Vector2i(0,7),Vector2i(0,8),Vector2i(1,8),Vector2i(2,8),Vector2i(3,8),Vector2i(4,8),Vector2i(5,8),Vector2i(6,9),Vector2i(6,10),Vector2i(6,11),Vector2i(6,12),Vector2i(6,13),Vector2i(6,14),Vector2i(7,14),Vector2i(8,14),Vector2i(8,13),Vector2i(8,12),Vector2i(8,11),Vector2i(8,10),Vector2i(8,9),Vector2i(9,8),Vector2i(10,8),Vector2i(11,8),Vector2i(12,8),Vector2i(13,8),Vector2i(14,8),Vector2i(14,7),Vector2i(14,6),Vector2i(13,6),Vector2i(12,6),Vector2i(11,6),Vector2i(10,6),Vector2i(9,6),Vector2i(8,5),Vector2i(8,4),Vector2i(8,3),Vector2i(8,2),Vector2i(8,1),Vector2i(8,0),Vector2i(7,0)]
const LANES := {"red":[Vector2i(7,1),Vector2i(7,2),Vector2i(7,3),Vector2i(7,4),Vector2i(7,5),Vector2i(7,6)],"green":[Vector2i(1,7),Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7),Vector2i(6,7)],"yellow":[Vector2i(7,13),Vector2i(7,12),Vector2i(7,11),Vector2i(7,10),Vector2i(7,9),Vector2i(7,8)],"blue":[Vector2i(13,7),Vector2i(12,7),Vector2i(11,7),Vector2i(10,7),Vector2i(9,7),Vector2i(8,7)]}
const YARDS := {"red":[Vector2i(2,2),Vector2i(4,2),Vector2i(2,4),Vector2i(4,4)],"green":[Vector2i(2,10),Vector2i(4,10),Vector2i(2,12),Vector2i(4,12)],"yellow":[Vector2i(10,10),Vector2i(12,10),Vector2i(10,12),Vector2i(12,12)],"blue":[Vector2i(10,2),Vector2i(12,2),Vector2i(10,4),Vector2i(12,4)]}

static func active_player_indices(player_count: int) -> Array[int]:
	match clampi(player_count, 2, 4):
		2:
			return [0, 2]
		3:
			return [0, 1, 2]
		_:
			return [0, 1, 2, 3]

static func next_active_player(current: int, player_count: int) -> int:
	var active := active_player_indices(player_count)
	var index := active.find(current)
	if index < 0:
		return active[0]
	return active[(index + 1) % active.size()]

static func active_player_colors(player_count: int = 4) -> Array[String]:
	var result: Array[String] = []
	for index in active_player_indices(player_count):
		result.append(COLORS[index])
	return result

static func human_player_count(mode: String, player_count: int = 4) -> int:
	match mode:
		"human_ai":
			return 1
		"multiplayer":
			return active_player_indices(player_count).size()
		"lan":
			return 0
		_:
			return 1

static func is_human_seat(mode: String, player: int, local_lan_seat: int = -1, player_count: int = 4) -> bool:
	if player not in active_player_indices(player_count):
		return false
	if mode == "human_ai":
		return player == 0
	if mode == "multiplayer":
		return true
	if mode == "lan":
		return player == local_lan_seat and local_lan_seat >= 0
	return player == 0

static func team_colors(color: String) -> Array[String]:
	if color == "red" or color == "yellow":
		return ["red", "yellow"]
	return ["green", "blue"]

static func is_team_winner(board: Dictionary, color: String) -> bool:
	for teammate in team_colors(color):
		if not is_winner(board[teammate]):
			return false
	return true

static func team_victory_announcement(color: String) -> String:
	var names := {"red":"Ruby & Amber", "yellow":"Ruby & Amber", "green":"Jade & Sapphire", "blue":"Jade & Sapphire"}
	return "Congratulations, %s team! You are the Ludo Pro champions!" % names.get(color, "Winning")

static func absolute(color: String, progress: int) -> int:
	return (int(START[color]) + progress) % 52

static func legal_moves(tokens: Array, roll: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if roll < 1 or roll > 6:
		return result
	for i in range(tokens.size()):
		var pos: int = int(tokens[i])
		if pos == 57:
			continue
		if pos == -1 and roll == 6:
			result.append({"token": i, "from": -1, "to": 0, "kind": "release"})
		elif pos >= 0 and pos < 57 and pos + roll <= 56:
			result.append({"token": i, "from": pos, "to": pos + roll, "kind": "home" if pos + roll == 56 else "move"})
	return result

static func is_forfeited_third_six(roll: int, consecutive_sixes: int) -> bool:
	return roll == 6 and consecutive_sixes >= 2

static func next_six_streak(roll: int, consecutive_sixes: int) -> int:
	return consecutive_sixes + 1 if roll == 6 else 0

static func earns_bonus_turn(roll: int, captured: bool) -> bool:
	return roll == 6 or captured

static func is_blockade_at(board: Dictionary, absolute_square: int, player_count: int = 4) -> bool:
	for color in active_player_colors(player_count):
		var occupants := 0
		for token_value in board[color]:
			var progress := int(token_value)
			if progress >= 0 and progress < 52 and absolute(color, progress) == absolute_square:
				occupants += 1
				if occupants >= 2:
					return true
	return false

static func legal_moves_for_board(color: String, board: Dictionary, roll: int, player_count: int = 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for move in legal_moves(board[color], roll):
		var from_progress := int(move.from)
		var to_progress := int(move.to)
		var path_blocked := false
		var first_step := 0 if from_progress == -1 else from_progress + 1
		var last_track_progress := mini(to_progress, 51)
		if first_step <= last_track_progress:
			for progress in range(first_step, last_track_progress + 1):
				var square := absolute(color, progress)
				if is_blockade_at(board, square, player_count):
					path_blocked = true
					break
		if not path_blocked:
			result.append(move)
	return result

static func apply_move(color: String, board: Dictionary, move: Dictionary, team_match: bool = false, player_count: int = 4) -> Dictionary:
	var next: Dictionary = board.duplicate(true)
	var target: int = int(move.to)
	next[color][int(move.token)] = 57 if target == 56 else target
	var captured: Array[Dictionary] = []
	if target < 52:
		var landing: int = absolute(color, target)
		if landing not in SAFE:
			for enemy in active_player_colors(player_count):
				if enemy == color or (team_match and enemy in team_colors(color)):
					continue
				for i in range(4):
					var enemy_pos: int = int(next[enemy][i])
					if enemy_pos >= 0 and enemy_pos < 52 and absolute(enemy, enemy_pos) == landing:
						next[enemy][i] = -1
						captured.append({"color": enemy, "token": i})
	return {"board": next, "captured": captured}

static func opponent_priority(enemy: String, board: Dictionary) -> float:
	var home_count := 0
	var advanced_count := 0
	for token_value in board[enemy]:
		var pos: int = int(token_value)
		if pos == 57:
			home_count += 1
		elif pos >= 44 and pos < 57:
			advanced_count += 1
	return 1.0 + float(home_count) * 0.22 + float(advanced_count) * 0.08

static func threat_count(color: String, progress: int, board: Dictionary, team_match: bool = false, player_count: int = 4) -> int:
	if progress < 0 or progress >= 52:
		return 0
	var target: int = absolute(color, progress)
	if target in SAFE:
		return 0
	var threats := 0
	for enemy in active_player_colors(player_count):
		if enemy == color or (team_match and enemy in team_colors(color)):
			continue
		for enemy_pos_value in board[enemy]:
			var enemy_pos: int = int(enemy_pos_value)
			if enemy_pos < 0 or enemy_pos >= 52:
				continue
			var distance: int = (target - absolute(enemy, enemy_pos) + 52) % 52
			if distance >= 1 and distance <= 6:
				threats += 1
	return threats

static func attack_potential(color: String, progress: int, board: Dictionary, team_match: bool = false, player_count: int = 4) -> float:
	if progress < 0 or progress >= 52:
		return 0.0
	var origin: int = absolute(color, progress)
	var value := 0.0
	for enemy in active_player_colors(player_count):
		if enemy == color or (team_match and enemy in team_colors(color)):
			continue
		for enemy_pos_value in board[enemy]:
			var enemy_pos: int = int(enemy_pos_value)
			if enemy_pos < 0 or enemy_pos >= 52:
				continue
			var distance: int = (absolute(enemy, enemy_pos) - origin + 52) % 52
			if distance >= 1 and distance <= 6:
				value += float(7 - distance) * 1.8 * opponent_priority(enemy, board)
	return value

static func evaluate_single_color(color: String, board: Dictionary, team_match: bool = false, player_count: int = 4) -> float:
	var score := 0.0
	var active_positions: Array[int] = []
	for token_value in board[color]:
		var pos: int = int(token_value)
		if pos == 57:
			score += 420.0
		elif pos == -1:
			score += 7.0
		elif pos >= 52:
			score += 150.0 + float(pos - 52) * 35.0
		else:
			score += 12.0 + float(pos) * 2.25
			var threats: int = threat_count(color, pos, board, team_match, player_count)
			score -= float(threats) * (13.0 + float(pos) * 0.34)
			score += attack_potential(color, pos, board, team_match, player_count)
			if absolute(color, pos) in SAFE:
				score += 17.0
			active_positions.append(pos)
	for i in range(active_positions.size()):
		for j in range(i + 1, active_positions.size()):
			var gap: int = mini(absi(active_positions[i] - active_positions[j]), 52 - absi(active_positions[i] - active_positions[j]))
			if gap >= 1 and gap <= 3:
				score += 2.5
	return score

static func evaluate_position(color: String, board: Dictionary, team_match: bool = false, player_count: int = 4) -> float:
	var score := evaluate_single_color(color, board, team_match, player_count)
	if team_match:
		for teammate in team_colors(color):
			if teammate != color:
				score += evaluate_single_color(teammate, board, true, player_count)
	return score

static func score_move(color: String, all_tokens: Dictionary, move: Dictionary, roll: int, team_match: bool = false, player_count: int = 4) -> int:
	var outcome := apply_move(color, all_tokens, move, team_match, player_count)
	var next_board: Dictionary = outcome.board
	var captured: Array = outcome.captured
	var score: float = evaluate_position(color, next_board, team_match, player_count) - evaluate_position(color, all_tokens, team_match, player_count)
	if move.kind == "home":
		score += 500.0
	if move.kind == "release":
		score += 24.0
	if not captured.is_empty():
		score += 260.0 + float(captured.size() - 1) * 80.0
		for victim in captured:
			score += float(int(all_tokens[victim.color][int(victim.token)]) / 52.0) * 28.0
			score += float(4 - count_home_tokens(victim.color, all_tokens)) * 12.0
	if roll == 6 or not captured.is_empty():
		score += 14.0
	# A piece entering the home lane is immune to outer-track attacks.
	if int(move.to) >= 52 and int(move.to) < 56:
		score += 18.0
	# Prefer progress that escapes a near-term enemy capture window.
	if int(move.from) >= 0 and int(move.from) < 52 and threat_count(color, int(move.from), all_tokens, team_match, player_count) > 0 and int(move.to) >= 52:
		score += 24.0
	return int(round(score * 10.0))

static func extra_turn_lookahead(color: String, board: Dictionary, team_match: bool = false, player_count: int = 4) -> float:
	var expected := 0.0
	for future_roll in range(1, 7):
		var moves: Array[Dictionary] = legal_moves_for_board(color, board, future_roll, player_count)
		var best := 0.0
		for move in moves:
			var outcome := apply_move(color, board, move, team_match, player_count)
			var value: float = evaluate_position(color, outcome.board, team_match, player_count) - evaluate_position(color, board, team_match, player_count)
			value += float(outcome.captured.size()) * 26.0
			if move.kind == "home":
				value += 50.0
			best = maxf(best, value)
		expected += best / 6.0
	return expected

static func reply_utility(player: String, opponent: String, before: Dictionary, after: Dictionary, captured: Array, team_match: bool = false, player_count: int = 4) -> float:
	var player_gain: float = evaluate_position(player, after, team_match, player_count) - evaluate_position(player, before, team_match, player_count)
	var opponent_gain: float = evaluate_position(opponent, after, team_match, player_count) - evaluate_position(opponent, before, team_match, player_count)
	return opponent_gain * 1.15 - player_gain * 1.25 + float(captured.size()) * 42.0

# Expectimax over the next three opponents. Each opponent observes the same board,
# receives an unknown fair die roll, then chooses the response with the best outcome.
static func multi_opponent_reply_risk(player: String, board: Dictionary, opponent_order: Array, depth: int = 3, team_match: bool = false, player_count: int = 4, consecutive_sixes: int = 0) -> float:
	if depth <= 0 or opponent_order.is_empty():
		return 0.0
	var opponent: String = str(opponent_order[0])
	var remaining: Array = opponent_order.slice(1)
	var is_teammate := team_match and opponent in team_colors(player)
	var expected := 0.0
	for die_roll in range(1, 7):
		# Three consecutive sixes forfeit the turn before any move is made.
		if is_forfeited_third_six(die_roll, consecutive_sixes):
			expected += multi_opponent_reply_risk(player, board, remaining, depth - 1, team_match, player_count, 0) / 6.0
			continue
		var moves: Array[Dictionary] = legal_moves_for_board(opponent, board, die_roll, player_count)
		var best_value := INF if is_teammate else -INF
		if moves.is_empty():
			var next_streak := next_six_streak(die_roll, consecutive_sixes)
			var continuation_order: Array = opponent_order if die_roll == 6 else remaining
			best_value = multi_opponent_reply_risk(player, board, continuation_order, depth - 1, team_match, player_count, next_streak)
		else:
			for move in moves:
				var outcome := apply_move(opponent, board, move, team_match, player_count)
				var immediate: float
				if is_teammate:
					immediate = -(evaluate_position(player, outcome.board, true, player_count) - evaluate_position(player, board, true, player_count))
				else:
					immediate = reply_utility(player, opponent, board, outcome.board, outcome.captured, team_match, player_count)
				var earns_bonus := earns_bonus_turn(die_roll, not outcome.captured.is_empty())
				var next_streak := consecutive_sixes + 1 if die_roll == 6 else 0
				var continuation_order: Array = opponent_order if earns_bonus else remaining
				var continuation: float = multi_opponent_reply_risk(player, outcome.board, continuation_order, depth - 1, team_match, player_count, next_streak)
				if is_teammate:
					best_value = minf(best_value, immediate + continuation)
				else:
					best_value = maxf(best_value, immediate + continuation)
		expected += (0.0 if best_value == INF or best_value == -INF else best_value) / 6.0
	return expected

static func next_opponent_order(color: String, team_match: bool = false, player_count: int = 4) -> Array[String]:
	var order: Array[String] = []
	var active := active_player_indices(player_count)
	var start_index: int = COLORS.find(color)
	for offset in range(1, COLORS.size()):
		var next_index: int = (start_index + offset) % COLORS.size()
		if next_index not in active:
			continue
		# Include teammates too: their intervening moves can change the board.
		order.append(COLORS[next_index])
	return order

static func victory_announcement(color: String) -> String:
	var names := {"red":"Ruby", "green":"Jade", "yellow":"Amber", "blue":"Sapphire"}
	return "Congratulations, %s! You are the Ludo Pro champion!" % names.get(color, "Player")

static func choose_ai_move(color: String, all_tokens: Dictionary, moves: Array[Dictionary], roll: int, difficulty: String, team_match: bool = false, player_count: int = 4) -> Dictionary:
	if moves.is_empty():
		return {}
	var ranked: Array[Dictionary] = []
	for move in moves:
		var score: float = float(score_move(color, all_tokens, move, roll, team_match, player_count))
		var outcome := apply_move(color, all_tokens, move, team_match, player_count)
		# A capture or six grants another turn. Champion difficulty plans that bonus turn.
		if difficulty == "champion":
			var earns_bonus := earns_bonus_turn(roll, not outcome.captured.is_empty())
			if earns_bonus:
				score += extra_turn_lookahead(color, outcome.board, team_match, player_count) * 5.0
			else:
				var reply_risk: float = multi_opponent_reply_risk(color, outcome.board, next_opponent_order(color, team_match, player_count), 3, team_match, player_count)
				score -= reply_risk * 0.72
		ranked.append({"move": move, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) > float(b.score)
	)
	if difficulty == "champion":
		return ranked[0].move
	var margin := 90.0 if difficulty == "tactical" else 260.0
	var candidates: Array[Dictionary] = []
	for item in ranked:
		if float(item.score) >= float(ranked[0].score) - margin:
			candidates.append(item.move)
	return candidates[randi() % candidates.size()]

static func count_home_tokens(color: String, board: Dictionary) -> int:
	var count := 0
	for token_value in board[color]:
		if int(token_value) == 57:
			count += 1
	return count

static func is_winner(tokens: Array) -> bool:
	for token in tokens:
		if int(token) != 57:
			return false
	return true
