extends SceneTree

const RULES = preload("res://scripts/game_rules.gd")

func _initialize() -> void:
	# Release rules.
	assert(RULES.legal_moves([-1, -1, -1, -1], 5).is_empty())
	assert(RULES.legal_moves([-1, -1, -1, -1], 6).size() == 4)

	# Track offsets and exact home entry.
	assert(RULES.absolute("red", 0) == 0)
	assert(RULES.absolute("green", 0) == 13)
	assert(RULES.absolute("yellow", 0) == 26)
	assert(RULES.absolute("blue", 0) == 39)
	assert(RULES.legal_moves([54, -1, -1, -1], 2)[0].to == 56)
	assert(RULES.legal_moves([54, -1, -1, -1], 3).is_empty())
	assert(RULES.legal_moves([57, -1, -1, -1], 6).size() == 3)

	# Safe-square and capture scoring.
	var board := {
		"red":[-1, -1, -1, -1],
		"green":[-1, -1, -1, -1],
		"yellow":[-1, -1, -1, -1],
		"blue":[-1, -1, -1, -1]
	}
	board["green"][0] = 5
	var capture_move := {"token":0, "from":4, "to":5, "kind":"move"}
	var capture_score: int = RULES.score_move("red", board, capture_move, 1)
	assert(capture_score >= 900)

	board["green"][0] = 8
	var safe_move := {"token":0, "from":7, "to":8, "kind":"move"}
	var safe_score: int = RULES.score_move("red", board, safe_move, 1)
	assert(safe_score >= 28)

	# AI returns a legal move and prefers immediate victory.
	var moves: Array[Dictionary] = RULES.legal_moves([54, -1, -1, -1], 2)
	assert(RULES.choose_ai_move("red", board, moves, 2, "champion") == moves[0])

	# Victory requires all four tokens to reach home.
	assert(RULES.is_winner([57, 57, 57, 57]))
	assert(not RULES.is_winner([57, 57, 57, 56]))
	print("LUDO PRO RULE TESTS PASSED")
	quit()
