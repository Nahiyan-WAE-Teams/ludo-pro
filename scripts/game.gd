extends Node2D

const R=preload("res://scripts/game_rules.gd")
const BG=Color("#101a23")
const PANEL=Color("#1b2934")
const GOLD=Color("#d8b77a")
const C={"red":Color("#df6267"),"green":Color("#4ca889"),"yellow":Color("#e2bc69"),"blue":Color("#6798d7")}
const N={"red":"RUBY","green":"JADE","yellow":"AMBER","blue":"SAPPHIRE"}
const O=Vector2(36,42)
const CELL=40.0
var pieces={}
var turn=0
var roll=0
var phase="roll"
var mode="solo"
var difficulty="balanced"
var turns=0
var captures=0
var homes=0
var sixes=0
var champion=""
var log:Array[String]=[]
var choices:Array[Dictionary]=[]
var rng=RandomNumberGenerator.new()
var rolling=0.0
var die=1
var wait_ai=0.0
var anim_time=0.0
var anim_length=0.0
var anim_data={}
var rules_open=false
var busy=false

func _ready():
	rng.randomize()
	if not load_match():
		new_match()

func _process(delta):
	if rolling>0:
		rolling-=delta
		if rolling<=0: finish_roll()
		queue_redraw()
	if anim_length>0:
		anim_time+=delta
		if anim_time>=anim_length: finish_animation()
		queue_redraw()
	if wait_ai>0:
		wait_ai-=delta
		if wait_ai<=0: ai_turn()

func _draw():
	draw_rect(Rect2(0,0,1280,720),BG)
	draw_rect(Rect2(0,66,1280,1),Color("#35434d"))
	draw_rect(Rect2(36,17,36,36),Color("#293b46"))
	draw_string(ThemeDB.fallback_font,Vector2(47,43),"L",HORIZONTAL_ALIGNMENT_LEFT,-1,24,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(84,35),"LUDO",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#f4f0e7"))
	draw_string(ThemeDB.fallback_font,Vector2(137,35),"PRO",HORIZONTAL_ALIGNMENT_LEFT,-1,16,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(84,49),"THE ROYAL BOARD",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#91a0aa"))
	draw_string(ThemeDB.fallback_font,Vector2(1000,40),"NATIVE ANDROID  •  OFFLINE",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("#91a0aa"))
	draw_board()
	draw_sidebar()
	if rules_open: draw_rules()
	if champion!="": draw_victory()

func draw_board():
	draw_panel(Rect2(24,30,624,624))
	draw_rect(Rect2(O,Vector2(600,600)),Color("#e8e1d4"))
	var zones={"red":Rect2(O,Vector2(240,240)),"green":Rect2(O+Vector2(360,0),Vector2(240,240)),"yellow":Rect2(O+Vector2(360,360),Vector2(240,240)),"blue":Rect2(O+Vector2(0,360),Vector2(240,240))}
	for color in R.COLORS:
		var z:Rect2=zones[color]
		draw_rect(z,C[color])
		draw_rect(z.grow(-22),Color("#f4efe5"))
		for yard in R.YARDS[color]:
			var p=cell_center(yard)
			draw_circle(p,22,Color("#d8d1c5"))
			draw_arc(p,21,0,TAU,48,C[color],4,true)
	for i in range(R.TRACK.size()):
		var p:Vector2i=R.TRACK[i]
		var rect=Rect2(O+Vector2(p)*CELL+Vector2.ONE,Vector2(38,38))
		draw_rect(rect,Color("#fffdf8"))
		draw_rect(rect,Color("#d7d0c3"),false,1)
		if i in R.SAFE:
			draw_string(ThemeDB.fallback_font,rect.position+Vector2(10,27),"✦",HORIZONTAL_ALIGNMENT_LEFT,-1,20,GOLD)
	for color in R.COLORS:
		for p in R.LANES[color]:
			var rect=Rect2(O+Vector2(p)*CELL+Vector2.ONE,Vector2(38,38))
			draw_rect(rect,C[color].lightened(0.5))
			draw_rect(rect,Color("#d7d0c3"),false,1)
	draw_center()
	draw_tokens()

func draw_center():
	var p=O+Vector2(300,300)
	var tris=[[Vector2(0,0),Vector2(-60,-60),Vector2(60,-60),C.blue],[Vector2(0,0),Vector2(60,-60),Vector2(60,60),C.green],[Vector2(0,0),Vector2(60,60),Vector2(-60,60),C.yellow],[Vector2(0,0),Vector2(-60,60),Vector2(-60,-60),C.red]]
	for t in tris:
		draw_colored_polygon(PackedVector2Array([p+t[0],p+t[1],p+t[2]]),t[3])

func draw_tokens():
	for color in R.COLORS:
		for i in range(4):
			if anim_length>0 and anim_data.color==color and int(anim_data.token)==i: continue
			var p=token_point(color,pieces[color][i],i)
			var can_move=color==R.COLORS[turn] and token_is_legal(i)
			draw_token(p,color,can_move)
	if anim_length>0:
		var t=clampf(anim_time/anim_length,0,1)
		var a=progress_point(anim_data.color,int(anim_data.from),int(anim_data.token))
		var b=progress_point(anim_data.color,int(anim_data.to),int(anim_data.token))
		draw_token(a.lerp(b,1-pow(1-t,3)),anim_data.color,false)

func draw_token(p:Vector2,color:String,highlight:bool):
	if highlight:
		draw_circle(p,20,Color(GOLD,0.3))
		draw_arc(p,20,0,TAU,48,GOLD,2.5,true)
	draw_circle(p+Vector2(0,3),13,Color("#18232b"))
	draw_circle(p,13,C[color])
	draw_arc(p,13,0,TAU,48,Color("#fff9ee"),2,true)
	draw_circle(p+Vector2(-4,-4),3.5,Color.WHITE)

func draw_sidebar():
	draw_panel(Rect2(700,36,544,648))
	draw_string(ThemeDB.fallback_font,Vector2(728,72),"ROYAL ARENA",HORIZONTAL_ALIGNMENT_LEFT,-1,10,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(728,110),"Make your move.",HORIZONTAL_ALIGNMENT_LEFT,-1,31,Color("#f4f0e7"))
	draw_string(ThemeDB.fallback_font,Vector2(728,133),"Four colors. One crown. Strategy decides.",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#9baab3"))
	for i in range(4):
		var color=R.COLORS[i]
		var rect=Rect2(728,158+i*51,488,43)
		draw_round_rect(rect,Color("#33414a") if i==turn else Color("#25343f"),8)
		if i==turn: draw_rect(Rect2(rect.position,Vector2(3,43)),GOLD)
		draw_circle(rect.position+Vector2(17,21),5,C[color])
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(32,25),N[color],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#f0eee8"))
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(126,25),"YOU" if is_human(i) else "AI",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#91a0aa"))
		var count=0
		for p in pieces[color]:
			if p==57: count+=1
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(420,25),"%d / 4 HOME"%count,HORIZONTAL_ALIGNMENT_LEFT,-1,8,GOLD)
	draw_line(Vector2(728,380),Vector2(1216,380),Color("#ffffff18"))
	var color=R.COLORS[turn]
	draw_string(ThemeDB.fallback_font,Vector2(728,411),"CURRENT TURN",HORIZONTAL_ALIGNMENT_LEFT,-1,9,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(728,444),N[color],HORIZONTAL_ALIGNMENT_LEFT,-1,24,C[color])
	var hint="Roll to begin." if phase=="roll" else "Tap a highlighted token."
	if phase=="ai": hint="The strategist is choosing..."
	draw_string(ThemeDB.fallback_font,Vector2(728,465),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#9baab3"))
	draw_round_rect(Rect2(728,488,214,66),GOLD if phase=="roll" and is_human(turn) and not busy else Color("#47545a"),11)
	draw_string(ThemeDB.fallback_font,Vector2(746,530),"⚄" if roll==0 else ["","⚀","⚁","⚂","⚃","⚄","⚅"][roll],HORIZONTAL_ALIGNMENT_LEFT,-1,30,BG)
	draw_string(ThemeDB.fallback_font,Vector2(793,526),"ROLL DICE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,BG)
	draw_round_rect(Rect2(958,488,230,66),Color("#2c3c47"),11)
	draw_string(ThemeDB.fallback_font,Vector2(980,528),"NEW MATCH",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#f1e5cc"))
	draw_line(Vector2(728,572),Vector2(1216,572),Color("#ffffff18"))
	draw_string(ThemeDB.fallback_font,Vector2(728,597),"TURNS %d     CAPTURES %d     HOME %d"%[turns,captures,homes],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#c2cbd0"))
	draw_string(ThemeDB.fallback_font,Vector2(728,638),"MODE  %s  ↻"%mode.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,9,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(930,638),"AI  %s  ↻"%difficulty.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,9,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(728,665),"RULES",HORIZONTAL_ALIGNMENT_LEFT,-1,9,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(1154,665),"AUTO-SAVED",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("#81919b"))

func draw_round_rect(rect:Rect2,color:Color,radius:float):
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style,rect)

func draw_panel(rect:Rect2):
	var style=StyleBoxFlat.new()
	style.bg_color=PANEL
	style.border_color=Color("#34444f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	draw_style_box(style,rect)

func cell_center(p:Vector2i)->Vector2:
	return O+Vector2(p)*CELL+Vector2(20,20)

func progress_point(color:String,pos:int,index:int)->Vector2:
	if pos>=52: return cell_center(R.LANES[color][pos-52])
	return cell_center(R.TRACK[R.absolute(color,pos)])

func token_point(color:String,pos:int,index:int)->Vector2:
	if pos==-1: return cell_center(R.YARDS[color][index])
	if pos==57: return O+Vector2(300+(index%2)*12,300+int(index/2)*12)
	return progress_point(color,pos,index)

func token_is_legal(index:int)->bool:
	for m in choices:
		if int(m.token)==index: return true
	return false

func new_match():
	pieces={"red":[-1,-1,-1,-1],"green":[-1,-1,-1,-1],"yellow":[-1,-1,-1,-1],"blue":[-1,-1,-1,-1]}
	turn=0
	roll=0
	phase="roll"
	turns=0
	captures=0
	homes=0
	sixes=0
	champion=""
	log.clear()
	choices.clear()
	busy=false
	rolling=0
	anim_length=0
	wait_ai=0
	save_match()
	queue_redraw()

func human_count()->int:
	return 4 if mode=="local" else 2 if mode=="duo" else 1

func is_human(i:int)->bool:
	return i<human_count()

func roll_dice():
	if phase!="roll" or not is_human(turn) or busy: return
	busy=true
	die=rng.randi_range(1,6)
	rolling=0.65

func finish_roll():
	busy=false
	roll=die
	if roll==6 and sixes==2:
		add_log("%s forfeits after three sixes."%N[R.COLORS[turn]])
		sixes=0
		next_turn()
		return
	sixes=sixes+1 if roll==6 else 0
	choices=R.legal_moves(pieces[R.COLORS[turn]],roll)
	if choices.is_empty():
		add_log("%s rolled %d. No legal move."%[N[R.COLORS[turn]],roll])
		if roll!=6: next_turn()
	else:
		phase="move"
	queue_redraw()
	if not is_human(turn): wait_ai=0.5

func commit_move(m:Dictionary):
	if busy or phase!="move": return
	var color=R.COLORS[turn]
	anim_data={"color":color,"token":int(m.token),"from":int(m.from),"to":int(m.to)}
	anim_time=0
	anim_length=maxf(0.18,float(int(m.to)-int(m.from))*0.105)
	busy=true
	phase="animating"

func finish_animation():
	anim_length=0
	var color:String=anim_data.color
	var index:int=anim_data.token
	var target:int=anim_data.to
	pieces[color][index]=57 if target==56 else target
	var captured=false
	if target<52:
		var absolute_target=R.absolute(color,target)
		if not absolute_target in R.SAFE:
			for enemy in R.COLORS:
				if enemy==color: continue
				for i in range(4):
					var p:int=pieces[enemy][i]
					if p>=0 and p<52 and R.absolute(enemy,p)==absolute_target:
						pieces[enemy][i]=-1
						captured=true
	if captured: captures+=1
	if target==56: homes+=1
	turns+=1
	add_log("%s moved token %d%s"%[N[color],index+1," · CAPTURE" if captured else ""])
	if R.is_winner(pieces[color]):
		champion=color
		phase="won"
		busy=false
		save_match()
		queue_redraw()
		return
	if roll!=6 and not captured: next_turn()
	else:
		roll=0
		phase="roll"
		choices.clear()
		busy=false
		if not is_human(turn): wait_ai=0.55
	save_match()
	queue_redraw()

func next_turn():
	turn=(turn+1)%4
	roll=0
	phase="roll"
	choices.clear()
	busy=false
	if not is_human(turn): wait_ai=0.6
	queue_redraw()

func ai_turn():
	if champion!="" or is_human(turn) or phase!="roll" or busy: return
	busy=true
	die=rng.randi_range(1,6)
	rolling=0.45
	await get_tree().create_timer(0.48).timeout
	if not is_inside_tree(): return
	rolling=0
	finish_roll()
	if phase=="move":
		var color=R.COLORS[turn]
		var move=R.choose_ai_move(color,pieces,choices,roll,difficulty)
		await get_tree().create_timer(0.38).timeout
		if is_inside_tree() and not move.is_empty():
			busy=false
			commit_move(move)
	queue_redraw()

func add_log(s:String):
	log.push_front(s)
	if log.size()>6: log.pop_back()

func save_match():
	var cfg=ConfigFile.new()
	cfg.set_value("match","pieces",pieces)
	cfg.set_value("match","turn",turn)
	cfg.set_value("match","roll",roll)
	cfg.set_value("match","mode",mode)
	cfg.set_value("match","difficulty",difficulty)
	cfg.set_value("match","turns",turns)
	cfg.set_value("match","captures",captures)
	cfg.set_value("match","homes",homes)
	cfg.set_value("match","sixes",sixes)
	cfg.save("user://ludo_pro_save.cfg")

func load_match():
	var cfg=ConfigFile.new()
	if cfg.load("user://ludo_pro_save.cfg")!=OK: return false
	pieces=cfg.get_value("match","pieces",{})
	if pieces.size()!=4: return false
	turn=cfg.get_value("match","turn",0)
	roll=cfg.get_value("match","roll",0)
	mode=cfg.get_value("match","mode","solo")
	difficulty=cfg.get_value("match","difficulty","balanced")
	turns=cfg.get_value("match","turns",0)
	captures=cfg.get_value("match","captures",0)
	homes=cfg.get_value("match","homes",0)
	sixes=cfg.get_value("match","sixes",0)
	phase="roll"
	choices.clear()
	champion=""
	busy=false
	queue_redraw()
	return true

func draw_rules():
	draw_rect(Rect2(0,0,1280,720),Color(0,0,0,0.8))
	draw_panel(Rect2(300,130,680,460))
	draw_string(ThemeDB.fallback_font,Vector2(350,190),"THE RULEBOOK",HORIZONTAL_ALIGNMENT_LEFT,-1,12,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(350,238),"How to play",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("#f4f0e7"))
	var lines=["Roll a six to release a token.","Move clockwise around the 52-square track.","Capture opponents except on safe squares.","Enter your home lane and reach the center with an exact roll.","A six or capture grants another turn. Three consecutive sixes forfeit the turn.","First player to bring all four tokens home wins."]
	for i in range(lines.size()):
		draw_string(ThemeDB.fallback_font,Vector2(350,286+i*35),"•  "+lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#c3cbd0"))
	draw_round_rect(Rect2(350,520,180,48),GOLD,8)
	draw_string(ThemeDB.fallback_font,Vector2(372,550),"CLOSE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,BG)

func draw_victory():
	draw_rect(Rect2(0,0,1280,720),Color(0,0,0,0.82))
	draw_panel(Rect2(370,185,540,350))
	draw_string(ThemeDB.fallback_font,Vector2(440,260),"THE CROWN IS CLAIMED",HORIZONTAL_ALIGNMENT_LEFT,-1,11,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(440,320),N[champion]+" WINS!",HORIZONTAL_ALIGNMENT_LEFT,-1,38,C[champion])
	draw_string(ThemeDB.fallback_font,Vector2(440,360),"%d turns  ·  %d captures"%[turns,captures],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#c3cbd0"))
	draw_round_rect(Rect2(440,415,230,58),GOLD,10)
	draw_string(ThemeDB.fallback_font,Vector2(462,450),"PLAY AGAIN",HORIZONTAL_ALIGNMENT_LEFT,-1,12,BG)

func _input(event):
	if event is InputEventScreenTouch and event.pressed: handle_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: handle_tap(event.position)

func handle_tap(p:Vector2):
	if rules_open:
		if Rect2(350,520,180,48).has_point(p): rules_open=false; queue_redraw()
		return
	if champion!="":
		if Rect2(440,415,230,58).has_point(p): new_match()
		return
	if Rect2(728,488,214,66).has_point(p): roll_dice(); queue_redraw(); return
	if Rect2(958,488,230,66).has_point(p): new_match(); return
	if Rect2(720,625,180,32).has_point(p):
		var modes=["solo","duo","local"]
		mode=modes[(modes.find(mode)+1)%modes.size()]
		new_match()
		return
	if Rect2(920,625,220,32).has_point(p):
		var levels=["balanced","tactical","champion"]
		difficulty=levels[(levels.find(difficulty)+1)%levels.size()]
		new_match()
		return
	if Rect2(720,650,130,42).has_point(p): rules_open=true; queue_redraw(); return
	if phase!="move" or not is_human(turn) or busy: return
	var color=R.COLORS[turn]
	for m in choices:
		var p_token=token_point(color,pieces[color][int(m.token)],int(m.token))
		if p_token.distance_to(p)<25:
			commit_move(m)
			return
