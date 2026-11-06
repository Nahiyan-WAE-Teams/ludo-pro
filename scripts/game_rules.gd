class_name LudoRules
extends RefCounted

const COLORS := ["red", "green", "yellow", "blue"]
const START := {"red": 0, "green": 13, "yellow": 26, "blue": 39}
const SAFE := [0, 8, 13, 21, 26, 34, 39, 47]
const TRACK := [Vector2i(6,0),Vector2i(6,1),Vector2i(6,2),Vector2i(6,3),Vector2i(6,4),Vector2i(6,5),Vector2i(5,6),Vector2i(4,6),Vector2i(3,6),Vector2i(2,6),Vector2i(1,6),Vector2i(0,6),Vector2i(0,7),Vector2i(0,8),Vector2i(1,8),Vector2i(2,8),Vector2i(3,8),Vector2i(4,8),Vector2i(5,8),Vector2i(6,9),Vector2i(6,10),Vector2i(6,11),Vector2i(6,12),Vector2i(6,13),Vector2i(6,14),Vector2i(7,14),Vector2i(8,14),Vector2i(8,13),Vector2i(8,12),Vector2i(8,11),Vector2i(8,10),Vector2i(8,9),Vector2i(9,8),Vector2i(10,8),Vector2i(11,8),Vector2i(12,8),Vector2i(13,8),Vector2i(14,8),Vector2i(14,7),Vector2i(14,6),Vector2i(13,6),Vector2i(12,6),Vector2i(11,6),Vector2i(10,6),Vector2i(9,6),Vector2i(8,5),Vector2i(8,4),Vector2i(8,3),Vector2i(8,2),Vector2i(8,1),Vector2i(8,0),Vector2i(7,0)]
const LANES := {"red":[Vector2i(7,1),Vector2i(7,2),Vector2i(7,3),Vector2i(7,4),Vector2i(7,5),Vector2i(7,6)],"green":[Vector2i(1,7),Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7),Vector2i(6,7)],"yellow":[Vector2i(7,13),Vector2i(7,12),Vector2i(7,11),Vector2i(7,10),Vector2i(7,9),Vector2i(7,8)],"blue":[Vector2i(13,7),Vector2i(12,7),Vector2i(11,7),Vector2i(10,7),Vector2i(9,7),Vector2i(8,7)]}
const YARDS := {"red":[Vector2i(2,2),Vector2i(4,2),Vector2i(2,4),Vector2i(4,4)],"green":[Vector2i(2,10),Vector2i(4,10),Vector2i(2,12),Vector2i(4,12)],"yellow":[Vector2i(10,10),Vector2i(12,10),Vector2i(10,12),Vector2i(12,12)],"blue":[Vector2i(10,2),Vector2i(12,2),Vector2i(10,4),Vector2i(12,4)]}

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

static func apply_move(color: String, board: Dictionary, move: Dictionary) -> Dictionary:
	var next: Dictionary = board.duplicate(true)
	var target: int = int(move.to)
	next[color][int(move.token)] = 57 if target == 56 else target
	var captured: Array[Dictionary] = []
	if target < 52:
		var landing: int = absolute(color, target)
		if landing not in SAFE:
			for enemy in COLORS:
				if enemy == color:
					continue
				for i in range(4):
					var enemy_pos: int = int(next[enemy][i])
					if enemy_pos >= 0 and enemy_pos < 52 and absolute(enemy, enemy_pos) == landing:
						next[enemy][i] = -1
						captured.append({"color": enemy, "token": i})
	return {"board": next, "captured": captured}

static func threat_count(color: String, progress: int, board: Dictionary) -> int:
	if progress < 0 or progress >= 52:
		return 0
	var target: int = absolute(color, progress)
	if target in SAFE:
		return 0
	var threats := 0
	for enemy in COLORS:
		if enemy == color:
			continue
		for enemy_pos_value in board[enemy]:
			var enemy_pos: int = int(enemy_pos_value)
			if enemy_pos < 0 or enemy_pos >= 52:
				continue
			var distance: int = (target - absolute(enemy, enemy_pos) + 52) % 52
			if distance >= 1 and distance <= 6:
				threats += 1
	return threats

static func attack_potential(color: String, progress: int, board: Dictionary) -> float:
	if progress < 0 or progress >= 52:
		return 0.0
	var origin: int = absolute(color, progress)
	var value := 0.0
	for enemy in COLORS:
		if enemy == color:
			continue
		for enemy_pos_value in board[enemy]:
			var enemy_pos: int = int(enemy_pos_value)
			if enemy_pos < 0 or enemy_pos >= 52:
				continue
			var distance: int = (absolute(enemy, enemy_pos) - origin + 52) % 52
			if distance >= 1 and distance <= 6:
				value += float(7 - distance) * 1.8
	return value

static func evaluate_position(color: String, board: Dictionary) -> float:
	var score := 0.0
	var active_positions: Array[int] = []
	for token_value in board[color]:
		var pos: int = int(token_value)
		if pos == 57:
			score += 420.0
		elif pos == -1:
			score += 7.0
		elif pos >= 52:
			score += 105.0 + float(pos - 52) * 31.0
		else:
			score += 12.0 + float(pos) * 2.25
			var threats: int = threat_count(color, pos, board)
			score -= float(threats) * 13.0
			score += attack_potential(color, pos, board)
			if absolute(color, pos) in SAFE:
				score += 17.0
			active_positions.append(pos)
	# Small formation bonus rewards a useful spread without encouraging risky stacks.
	for i in range(active_positions.size()):
		for j in range(i + 1, active_positions.size()):
			var gap: int = mini(absi(active_positions[i] - active_positions[j]), 52 - absi(active_positions[i] - active_positions[j]))
			if gap >= 1 and gap <= 3:
				score += 2.5
	return score

static func score_move(color: String, all_tokens: Dictionary, move: Dictionary, roll: int) -> int:
	var outcome := apply_move(color, all_tokens, move)
	var next_board: Dictionary = outcome.board
	var captured: Array = outcome.captured
	var score: float = evaluate_position(color, next_board) - evaluate_position(color, all_tokens)
	if move.kind == "home":
		score += 500.0
	if move.kind == "release":
		score += 24.0
	if not captured.is_empty():
		score += 260.0 + float(captured.size() - 1) * 80.0
	if roll == 6 or not captured.is_empty():
		score += 14.0
	# A piece entering the home lane is immune to outer-track attacks.
	if int(move.to) >= 52 and int(move.to) < 56:
		score += 18.0
	# Prefer progress that escapes a near-term enemy capture window.
	if int(move.from) >= 0 and int(move.from) < 52 and threat_count(color, int(move.from), all_tokens) > 0 and int(move.to) >= 52:
		score += 24.0
	return int(round(score * 10.0))

static func extra_turn_lookahead(color: String, board: Dictionary) -> float:
	var expected := 0.0
	for future_roll in range(1, 7):
		var moves: Array[Dictionary] = legal_moves(board[color], future_roll)
		var best := 0.0
		for move in moves:
			var outcome := apply_move(color, board, move)
			var value: float = evaluate_position(color, outcome.board) - evaluate_position(color, board)
			value += float(outcome.captured.size()) * 26.0
			if move.kind == "home":
				value += 50.0
			best = maxf(best, value)
		expected += best / 6.0
	return expected

static func choose_ai_move(color: String, all_tokens: Dictionary, moves: Array[Dictionary], roll: int, difficulty: String) -> Dictionary:
	if moves.is_empty():
		return {}
	var ranked: Array[Dictionary] = []
	for move in moves:
		var score: float = float(score_move(color, all_tokens, move, roll))
		var outcome := apply_move(color, all_tokens, move)
		# A capture or six grants another turn. Champion difficulty plans that bonus turn.
		if difficulty == "champion" and (roll == 6 or not outcome.captured.is_empty()):
			score += extra_turn_lookahead(color, outcome.board) * 5.0
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

static func is_winner(tokens: Array) -> bool:
	for token in tokens:
		if int(token) != 57:
			return false
	return true
