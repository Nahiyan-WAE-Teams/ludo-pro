class_name LudoRules
extends RefCounted
const COLORS := ["red","green","yellow","blue"]
const START := {"red":0,"green":13,"yellow":26,"blue":39}
const SAFE := [0,8,13,21,26,34,39,47]
const TRACK := [Vector2i(6,0),Vector2i(6,1),Vector2i(6,2),Vector2i(6,3),Vector2i(6,4),Vector2i(6,5),Vector2i(5,6),Vector2i(4,6),Vector2i(3,6),Vector2i(2,6),Vector2i(1,6),Vector2i(0,6),Vector2i(0,7),Vector2i(0,8),Vector2i(1,8),Vector2i(2,8),Vector2i(3,8),Vector2i(4,8),Vector2i(5,8),Vector2i(6,9),Vector2i(6,10),Vector2i(6,11),Vector2i(6,12),Vector2i(6,13),Vector2i(6,14),Vector2i(7,14),Vector2i(8,14),Vector2i(8,13),Vector2i(8,12),Vector2i(8,11),Vector2i(8,10),Vector2i(8,9),Vector2i(9,8),Vector2i(10,8),Vector2i(11,8),Vector2i(12,8),Vector2i(13,8),Vector2i(14,8),Vector2i(14,7),Vector2i(14,6),Vector2i(13,6),Vector2i(12,6),Vector2i(11,6),Vector2i(10,6),Vector2i(9,6),Vector2i(8,5),Vector2i(8,4),Vector2i(8,3),Vector2i(8,2),Vector2i(8,1),Vector2i(8,0),Vector2i(7,0)]
const LANES := {"red":[Vector2i(7,1),Vector2i(7,2),Vector2i(7,3),Vector2i(7,4),Vector2i(7,5),Vector2i(7,6)],"green":[Vector2i(1,7),Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7),Vector2i(6,7)],"yellow":[Vector2i(7,13),Vector2i(7,12),Vector2i(7,11),Vector2i(7,10),Vector2i(7,9),Vector2i(7,8)],"blue":[Vector2i(13,7),Vector2i(12,7),Vector2i(11,7),Vector2i(10,7),Vector2i(9,7),Vector2i(8,7)]}
const YARDS := {"red":[Vector2i(2,2),Vector2i(4,2),Vector2i(2,4),Vector2i(4,4)],"green":[Vector2i(2,10),Vector2i(4,10),Vector2i(2,12),Vector2i(4,12)],"yellow":[Vector2i(10,10),Vector2i(12,10),Vector2i(10,12),Vector2i(12,12)],"blue":[Vector2i(10,2),Vector2i(12,2),Vector2i(10,4),Vector2i(12,4)]}
static func absolute(color: String, progress: int) -> int:
	return (int(START[color])+progress)%52
static func legal_moves(tokens: Array, roll: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if roll<1 or roll>6: return result
	for i in range(tokens.size()):
		var pos: int=tokens[i]
		if pos==57: continue
		if pos==-1 and roll==6: result.append({"token":i,"from":-1,"to":0,"kind":"release"})
		elif pos>=0 and pos<57 and pos+roll<=56: result.append({"token":i,"from":pos,"to":pos+roll,"kind":"home" if pos+roll==56 else "move"})
	return result
static func score_move(color: String, all_tokens: Dictionary, move: Dictionary, roll: int) -> int:
	if move.kind=="home": return 1200
	if move.kind=="release": return 38
	var target: int=move.to
	var abs_target:=absolute(color,target)
	var score:=0
	if abs_target in SAFE: score+=28
	if target>=51: score+=45
	elif target>=44: score+=24
	elif target>=32: score+=12
	for enemy_color in COLORS:
		if enemy_color==color: continue
		for enemy_pos in all_tokens[enemy_color]:
			if enemy_pos>=0 and enemy_pos<52:
				if absolute(enemy_color,enemy_pos)==abs_target and not abs_target in SAFE: score+=900
				else:
					var distance: int=(abs_target-absolute(enemy_color,enemy_pos)+52)%52
					if distance>0 and distance<=6: score-=(7-distance)*5
	if roll==6: score+=4
	return score
static func choose_ai_move(color: String, all_tokens: Dictionary, moves: Array[Dictionary], roll: int, difficulty: String) -> Dictionary:
	if moves.is_empty(): return {}
	var ranked: Array[Dictionary]=[]
	for move in moves: ranked.append({"move":move,"score":score_move(color,all_tokens,move,roll)})
	ranked.sort_custom(func(a,b): return int(a.score)>int(b.score))
	if difficulty=="champion": return ranked[0].move
	var margin:=12 if difficulty=="tactical" else 32
	var candidates: Array[Dictionary]=[]
	for item in ranked:
		if int(item.score)>=int(ranked[0].score)-margin: candidates.append(item.move)
	return candidates[randi()%candidates.size()]
static func is_winner(tokens: Array) -> bool:
	for token in tokens:
		if int(token)!=57: return false
	return true
