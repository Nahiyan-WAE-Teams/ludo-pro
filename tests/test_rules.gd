extends SceneTree

const RULES = preload("res://scripts/game_rules.gd")

func _initialize() -> void:
	# Three playable modes assign human seats deterministically.
	assert(RULES.human_player_count("human_ai") == 1)
	assert(RULES.human_player_count("multiplayer") == 4)
	assert(RULES.human_player_count("lan") == 0)
	assert(RULES.is_human_seat("human_ai", 0, 0))
	assert(not RULES.is_human_seat("human_ai", 1, 0))
	assert(RULES.is_human_seat("multiplayer", 3, 0))
	assert(RULES.is_human_seat("lan", 2, 2))
	assert(not RULES.is_human_seat("lan", 2, 1))

	# Player-count selection and team-match rules.
	assert(RULES.active_player_indices(2) == [0, 2])
	assert(RULES.active_player_indices(3) == [0, 1, 2])
	assert(RULES.active_player_indices(4) == [0, 1, 2, 3])
	assert(RULES.next_active_player(0, 2) == 2)
	assert(RULES.next_active_player(2, 2) == 0)
	assert(RULES.next_active_player(2, 3) == 0)
	assert(RULES.human_player_count("multiplayer", 2) == 2)
	assert(RULES.is_human_seat("human_ai", 0, -1, 2))
	assert(not RULES.is_human_seat("human_ai", 2, -1, 2))
	assert(RULES.team_colors("red") == ["red", "yellow"])
	assert(RULES.team_colors("blue") == ["green", "blue"])
	var team_board := {
		"red":[57, 57, 57, 57],
		"green":[-1, -1, -1, -1],
		"yellow":[57, 57, 57, 57],
		"blue":[-1, -1, -1, -1]
	}
	assert(RULES.is_team_winner(team_board, "red"))
	var teammate_board := {"red":[4,-1,-1,-1], "green":[-1,-1,-1,-1], "yellow":[31,-1,-1,-1], "blue":[-1,-1,-1,-1]}
	var teammate_capture := RULES.apply_move("red", teammate_board, {"token":0,"from":4,"to":5,"kind":"move"}, true)
	assert(teammate_capture.captured.is_empty())
	assert(teammate_capture.board["yellow"][0] == 31)
	assert(not RULES.is_team_winner(team_board, "green"))
	assert(RULES.team_victory_announcement("red").contains("Ruby & Amber"))

	# Release and exact-finish rules.
	assert(RULES.legal_moves([-1, -1, -1, -1], 5).is_empty())
	assert(RULES.legal_moves([-1, -1, -1, -1], 6).size() == 4)
	assert(RULES.legal_moves([54, -1, -1, -1], 2)[0].to == 56)
	assert(RULES.legal_moves([54, -1, -1, -1], 3).is_empty())
	assert(RULES.legal_moves([57, -1, -1, -1], 6).size() == 3)

	# Track offsets.
	assert(RULES.absolute("red", 0) == 0)
	assert(RULES.absolute("green", 0) == 13)
	assert(RULES.absolute("yellow", 0) == 26)
	assert(RULES.absolute("blue", 0) == 39)

	var board := {
		"red":[-1, -1, -1, -1],
		"green":[-1, -1, -1, -1],
		"yellow":[-1, -1, -1, -1],
		"blue":[-1, -1, -1, -1]
	}

	# Applying a capture changes the copy, never the source board.
	board["red"][0] = 4
	board["green"][0] = 44 # Green absolute square 5, same as red progress 5.
	var capture := {"token":0, "from":4, "to":5, "kind":"move"}
	var outcome: Dictionary = RULES.apply_move("red", board, capture)
	assert(outcome.captured.size() == 1)
	assert(outcome.board["green"][0] == -1)
	assert(outcome.board["red"][0] == 5)
	assert(board["green"][0] == 44)

	# Safe squares are immune to threat calculations.
	assert(RULES.threat_count("red", 5, board) > 0)
	assert(RULES.threat_count("red", 8, board) == 0)

	# Champion AI avoids a square that an opponent can reach next roll.
	var danger_board := {
		"red":[0, 10, -1, -1],
		"green":[40, -1, -1, -1],
		"yellow":[-1, -1, -1, -1],
		"blue":[-1, -1, -1, -1]
	}
	var options: Array[Dictionary] = RULES.legal_moves(danger_board.red, 5)
	assert(options.size() == 2)
	var champion_choice: Dictionary = RULES.choose_ai_move("red", danger_board, options, 5, "champion")
	assert(champion_choice.token == 1)
	assert(champion_choice.to == 15)

	# A winning move is preferred, and bonus-turn planning returns a usable score.
	var home_board := {
		"red":[54, -1, -1, -1],
		"green":[-1, -1, -1, -1],
		"yellow":[-1, -1, -1, -1],
		"blue":[-1, -1, -1, -1]
	}
	var home_moves: Array[Dictionary] = RULES.legal_moves(home_board.red, 2)
	assert(RULES.choose_ai_move("red", home_board, home_moves, 2, "champion") == home_moves[0])
	assert(RULES.extra_turn_lookahead("red", home_board) >= 0.0)

	# Champion reply search and celebration announcement contracts.
	var exposed_board := {
		"red":[20, 10, -1, -1],
		"green":[1, -1, -1, -1],
		"yellow":[-1, -1, -1, -1],
		"blue":[-1, -1, -1, -1]
	}
	var safe_board := {
		"red":[21, 10, -1, -1],
		"green":[1, -1, -1, -1],
		"yellow":[-1, -1, -1, -1],
		"blue":[-1, -1, -1, -1]
	}
	var opponents := ["green", "yellow", "blue"]
	assert(RULES.multi_opponent_reply_risk("red", exposed_board, opponents, 3) >= 0.0)
	assert(RULES.multi_opponent_reply_risk("red", safe_board, opponents, 3) >= 0.0)
	assert(RULES.multi_opponent_reply_risk("red", exposed_board, opponents, 3) > RULES.multi_opponent_reply_risk("red", safe_board, opponents, 3))
	assert(RULES.victory_announcement("red") == "Congratulations, Ruby! You are the Ludo Pro champion!")

	# Home-state scoring and winner detection.
	assert(RULES.is_winner([57, 57, 57, 57]))
	assert(not RULES.is_winner([57, 57, 57, 56]))
	print("LUDO PRO ADVANCED AI TESTS PASSED")
	quit()
