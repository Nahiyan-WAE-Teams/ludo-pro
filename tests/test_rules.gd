extends SceneTree
const RULES=preload("res://scripts/game_rules.gd")
func _initialize() -> void:
	assert(RULES.legal_moves([-1,-1,-1,-1],5).is_empty())
	assert(RULES.legal_moves([-1,-1,-1,-1],6).size()==4)
	assert(RULES.absolute("green",0)==13)
	assert(RULES.is_winner([57,57,57,57]))
	assert(not RULES.is_winner([57,57,57,56]))
	print("LUDO PRO RULE TESTS PASSED")
	quit()
