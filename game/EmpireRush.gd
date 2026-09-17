extends Node2D

const W := 10
const H := 7
const TILE := 82
const MX := 34
const MY := 92
const PX := 880
const SAVE := "user://empire_rush.cfg"
var rng := RandomNumberGenerator.new()
var terrain := []
var owner := []
var gold := 35
var food := 20
var army := 4
var rival := 3
var turn := 1
var selected := Vector2i(-1, -1)
var msg := "Expand, build, train and defeat the rival."
var over := false
var won := false

func _ready() -> void:
    rng.randomize()
    new_game()
    queue_redraw()

func new_game() -> void:
    terrain.clear(); owner.clear()
    gold = 35; food = 20; army = 4; rival = 3; turn = 1
    selected = Vector2i(-1, -1); over = false; won = false
    msg = "Build, expand and train before attacking."
    for y in H:
        var tr := []; var ow := []
        for x in W:
            tr.append(1 if rng.randi_range(0,99) < 18 else 0)
            ow.append(0)
        terrain.append(tr); owner.append(ow)
    owner[3][1]=1; owner[3][2]=1; owner[2][1]=1
    owner[3][8]=2; owner[3][7]=2; owner[2][8]=2
    save_game()

func _unhandled_input(e: InputEvent) -> void:
    if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
        var p := e.position
        if over: new_game(); queue_redraw(); return
        if p.x >= MX and p.x < MX+W*TILE and p.y >= MY and p.y < MY+H*TILE:
            selected = Vector2i(int((p.x-MX)/TILE), int((p.y-MY)/TILE))
            msg = cell_text(selected); queue_redraw(); return
        if Rect2(PX,145,330,58).has_point(p): build()
        elif Rect2(PX,215,330,58).has_point(p): train()
        elif Rect2(PX,285,330,58).has_point(p): expand()
        elif Rect2(PX,355,330,58).has_point(p): attack()
        elif Rect2(PX,425,330,58).has_point(p): end_turn()

func cell_text(c: Vector2i) -> String:
    if owner[c.y][c.x] == 1: return "Your land."
    if owner[c.y][c.x] == 2: return "Rival land."
    return "Forest" if terrain[c.y][c.x] == 1 else "Neutral plains."

func build() -> void:
    if gold < 10: msg="Need 10 gold."; queue_redraw(); return
    gold-=10; food+=6; msg="Town built: +6 food."; save_game(); queue_redraw()

func train() -> void:
    if gold < 12 or food < 5: msg="Need 12 gold + 5 food."; queue_redraw(); return
    gold-=12; food-=5; army+=1; msg="Soldier trained."; save_game(); queue_redraw()

func expand() -> void:
    if gold < 8: msg="Need 8 gold."; queue_redraw(); return
    var best := Vector2i(-1,-1); var bd := 999
    for y in H:
        for x in W:
            if owner[y][x] == 0:
                var d := abs(x-1)+abs(y-3)
                if d < bd: bd=d; best=Vector2i(x,y)
    if best.x < 0: msg="No neutral land left."; queue_redraw(); return
    owner[best.y][best.x]=1; gold-=8; msg="Empire expanded."; save_game(); queue_redraw()

func attack() -> void:
    if rival <= 0: win(); return
    if army+2 >= rival+1:
        rival-=1; food=max(0,food-4); msg="Victory in battle. Rival army weakened."
        if rival <= 0: win()
    else:
        army=max(1,army-1); msg="Attack failed. You lost a soldier."
    save_game(); queue_redraw()

func win() -> void:
    won=true; over=true; msg="You conquered the rival."

func end_turn() -> void:
    turn+=1
    var land := 0
    for row in owner:
        for v in row: if v==1: land+=1
    gold += 5+land; food += max(1,int(land/2))
    if rival < 7: rival+=1
    if turn>=4 and rng.randi_range(0,99)<30: food=max(0,food-3); msg="Rival raid: -3 food."
    else: msg="Turn %d: resources collected." % turn
    if turn>=20 and army<=rival: over=true; msg="The rival outgrew you."
    save_game(); queue_redraw()

func save_game() -> void:
    var c:=ConfigFile.new(); c.set_value("g","gold",gold); c.set_value("g","food",food); c.set_value("g","army",army); c.set_value("g","rival",rival); c.set_value("g","turn",turn); c.save(SAVE)

func _draw() -> void:
    draw_rect(Rect2(0,0,1280,720),Color("101522"))
    draw_string(ThemeDB.fallback_font,Vector2(34,44),"EMPIRE RUSH",HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("f5d76e"))
    draw_string(ThemeDB.fallback_font,Vector2(34,70),"Offline strategy • Turn %d" % turn,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b8c1d9"))
    for y in H:
        for x in W:
            var r:=Rect2(MX+x*TILE,MY+y*TILE,TILE-3,TILE-3)
            var c:=Color("263f35") if terrain[y][x]==1 else Color("39475b")
            if owner[y][x]==1: c=Color("765b32")
            elif owner[y][x]==2: c=Color("5b3540")
            draw_rect(r,c,true)
            if Vector2i(x,y)==selected: draw_rect(r,Color("f5d76e"),false,4)
            var s:="F" if terrain[y][x]==1 else "."
            if owner[y][x]==1: s="★"
            elif owner[y][x]==2: s="◆"
            draw_string(ThemeDB.fallback_font,r.position+Vector2(30,48),s,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("eef2f8"))
    draw_rect(Rect2(PX-20,70,360,610),Color("171e2c"),true)
    draw_string(ThemeDB.fallback_font,Vector2(PX,110),"YOUR EMPIRE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f5d76e"))
    draw_string(ThemeDB.fallback_font,Vector2(PX,135),"Gold %d   Food %d   Army %d" % [gold,food,army],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("dbe3f2"))
    btn(145,"BUILD TOWN","10 gold → +6 food"); btn(215,"TRAIN SOLDIER","12 gold + 5 food"); btn(285,"EXPAND","8 gold → claim land"); btn(355,"ATTACK RIVAL","risk / reward"); btn(425,"END TURN","+ resources • enemy AI")
    draw_string(ThemeDB.fallback_font,Vector2(PX,520),msg,HORIZONTAL_ALIGNMENT_LEFT,320,16,Color("c8d0df"))
    draw_string(ThemeDB.fallback_font,Vector2(PX,610),"OFFLINE SAVE: ON",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("83d9a0"))
    draw_string(ThemeDB.fallback_font,Vector2(PX,635),"No server required.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8792a8"))
    if over:
        draw_rect(Rect2(0,0,1280,720),Color(0,0,0,.58),true)
        draw_string(ThemeDB.fallback_font,Vector2(350,320),"VICTORY" if won else "DEFEAT",HORIZONTAL_ALIGNMENT_LEFT,-1,64,Color("f5d76e"))
        draw_string(ThemeDB.fallback_font,Vector2(350,370),"Tap anywhere to restart",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)

func btn(y:float,title:String,sub:String)->void:
    var r:=Rect2(PX,y,330,58); draw_rect(r,Color("263147"),true); draw_rect(r,Color("4b5d7b"),false,2)
    draw_string(ThemeDB.fallback_font,r.position+Vector2(16,24),title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f1f4fa"))
    draw_string(ThemeDB.fallback_font,r.position+Vector2(16,45),sub,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("9eabc1"))
