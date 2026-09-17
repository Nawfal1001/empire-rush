extends Node2D

const W := 10
const H := 7
const TILE := 82
const MX := 34
const MY := 92
const PX := 880
const SAVE := "user://empire_rush.cfg"

@onready var monetization = $Monetization

var rng := RandomNumberGenerator.new()
var terrain: Array = []
var territory: Array = []
var gold := 35
var food := 20
var army := 4
var rival := 4
var turn := 1
var towns := 1
var score := 0
var selected := Vector2i(-1, -1)
var msg := "Build your economy, expand smartly, then attack."
var over := false
var won := false

func _ready() -> void:
    rng.randomize()
    if not load_game():
        new_game()
    monetization.rewarded_completed.connect(_on_rewarded_completed)
    queue_redraw()

func new_game() -> void:
    terrain.clear()
    territory.clear()
    gold = 35
    food = 20
    army = 4
    rival = 4
    turn = 1
    towns = 1
    score = 0
    selected = Vector2i(-1, -1)
    over = false
    won = false
    msg = "Build your economy, expand smartly, then attack."

    for y in range(H):
        var tr: Array = []
        var own: Array = []
        for x in range(W):
            tr.append(1 if rng.randi_range(0, 99) < 18 else 0)
            own.append(0)
        terrain.append(tr)
        territory.append(own)

    territory[3][1] = 1
    territory[3][2] = 1
    territory[2][1] = 1
    territory[3][8] = 2
    territory[3][7] = 2
    territory[2][8] = 2
    save_game()

func _unhandled_input(e: InputEvent) -> void:
    if not ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
        return
    var p: Vector2 = e.position

    if over:
        new_game()
        queue_redraw()
        return

    if p.x >= MX and p.x < MX + W * TILE and p.y >= MY and p.y < MY + H * TILE:
        selected = Vector2i(int((p.x - MX) / TILE), int((p.y - MY) / TILE))
        msg = cell_text(selected)
        queue_redraw()
        return

    if Rect2(PX, 145, 330, 58).has_point(p):
        build()
    elif Rect2(PX, 215, 330, 58).has_point(p):
        train()
    elif Rect2(PX, 285, 330, 58).has_point(p):
        expand()
    elif Rect2(PX, 355, 330, 58).has_point(p):
        attack()
    elif Rect2(PX, 425, 330, 58).has_point(p):
        end_turn()
    elif Rect2(PX, 495, 330, 58).has_point(p):
        watch_rewarded()

func cell_text(c: Vector2i) -> String:
    if territory[c.y][c.x] == 1:
        return "Your territory."
    if territory[c.y][c.x] == 2:
        return "Rival territory."
    if terrain[c.y][c.x] == 1:
        return "Forest: expansion costs +2 gold."
    return "Neutral plains."

func build() -> void:
    if gold < 10:
        msg = "Need 10 gold."
        queue_redraw()
        return
    gold -= 10
    towns += 1
    food += 8
    score += 20
    msg = "Town founded: +8 food and +20 score."
    save_game()
    queue_redraw()

func train() -> void:
    if gold < 12 or food < 5:
        msg = "Need 12 gold + 5 food."
        queue_redraw()
        return
    gold -= 12
    food -= 5
    army += 1
    score += 8
    msg = "Soldier trained. Army +1."
    save_game()
    queue_redraw()

func expand() -> void:
    if gold < 8:
        msg = "Need 8 gold."
        queue_redraw()
        return

    var best := Vector2i(-1, -1)
    var best_distance := 999
    for y in range(H):
        for x in range(W):
            if territory[y][x] != 0:
                continue
            var adjacent := false
            for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                var nx := x + d.x
                var ny := y + d.y
                if nx >= 0 and nx < W and ny >= 0 and ny < H and territory[ny][nx] == 1:
                    adjacent = true
                    break
            if not adjacent:
                continue
            var distance: int = abs(x - 1) + abs(y - 3)
            if distance < best_distance:
                best_distance = distance
                best = Vector2i(x, y)

    if best.x < 0:
        msg = "No adjacent neutral land. Build a connected empire."
        queue_redraw()
        return

    var cost := 10 if terrain[best.y][best.x] == 1 else 8
    if gold < cost:
        msg = "Forest land needs 10 gold."
        queue_redraw()
        return
    territory[best.y][best.x] = 1
    gold -= cost
    score += 15
    msg = "Territory claimed."
    save_game()
    queue_redraw()

func attack() -> void:
    if rival <= 0:
        win()
        return
    if army <= 1:
        msg = "Your army is too small to attack."
        queue_redraw()
        return

    var power := army + rng.randi_range(0, 3)
    var defense := rival + rng.randi_range(0, 2)
    if power >= defense:
        rival = max(0, rival - 2)
        army = max(1, army - 1)
        food = max(0, food - 4)
        score += 45
        msg = "Battle won! Rival -2, army -1."
        if rival <= 0:
            win()
    else:
        army = max(1, army - 2)
        food = max(0, food - 3)
        score = max(0, score - 10)
        msg = "Attack failed. Army -2."

    save_game()
    queue_redraw()

func end_turn() -> void:
    turn += 1
    var land := 0
    for row in territory:
        for value in row:
            if value == 1:
                land += 1

    gold += 5 + land + towns
    food += max(1, int(land / 2)) + towns

    # Rival AI grows slowly, then becomes more aggressive.
    if turn % 2 == 0:
        rival += 1
    if turn >= 5 and rng.randi_range(0, 99) < 25:
        food = max(0, food - 3)
        msg = "Rival raid: -3 food."
    elif turn >= 8 and rng.randi_range(0, 99) < 20:
        army = max(1, army - 1)
        msg = "Border skirmish: -1 army."
    else:
        msg = "Turn %d complete: empire income collected." % turn

    if turn >= 20 and army <= rival and score < 250:
        over = true
        msg = "The rival outgrew your empire."

    # Interstitial only at a natural end-of-turn break, every third break.
    if turn > 1:
        monetization.mark_interstitial_session()

    save_game()
    queue_redraw()

func watch_rewarded() -> void:
    if monetization.can_reward():
        msg = "Rewarded ad starting: complete it for +50 gold."
        monetization.request_rewarded()
    else:
        msg = "Reward ad is loading. Try again in a moment."
    queue_redraw()

func _on_rewarded_completed() -> void:
    gold += 50
    score += 25
    msg = "Reward claimed: +50 gold +25 score."
    save_game()
    queue_redraw()

func win() -> void:
    won = true
    over = true
    score += 100
    msg = "Victory! Rival conquered."
    save_game()

func save_game() -> void:
    var config := ConfigFile.new()
    config.set_value("game", "gold", gold)
    config.set_value("game", "food", food)
    config.set_value("game", "army", army)
    config.set_value("game", "rival", rival)
    config.set_value("game", "turn", turn)
    config.set_value("game", "towns", towns)
    config.set_value("game", "score", score)
    config.set_value("game", "terrain", terrain)
    config.set_value("game", "territory", territory)
    config.save(SAVE)

func load_game() -> bool:
    var config := ConfigFile.new()
    if config.load(SAVE) != OK:
        return false
    if not config.has_section_key("game", "terrain") or not config.has_section_key("game", "territory"):
        return false
    gold = int(config.get_value("game", "gold", 35))
    food = int(config.get_value("game", "food", 20))
    army = int(config.get_value("game", "army", 4))
    rival = int(config.get_value("game", "rival", 4))
    turn = int(config.get_value("game", "turn", 1))
    towns = int(config.get_value("game", "towns", 1))
    score = int(config.get_value("game", "score", 0))
    terrain = config.get_value("game", "terrain", [])
    territory = config.get_value("game", "territory", [])
    if terrain.size() != H or territory.size() != H:
        return false
    msg = "Saved empire restored."
    return true

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("0b1020"))
    draw_rect(Rect2(0, 0, 1280, 74), Color("111a2d"), true)
    draw_string(ThemeDB.fallback_font, Vector2(34, 42), "EMPIRE RUSH", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("f5d76e"))
    draw_string(ThemeDB.fallback_font, Vector2(34, 64), "Fast offline empire strategy", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9da9c2"))

    for y in range(H):
        for x in range(W):
            var rect := Rect2(MX + x * TILE, MY + y * TILE, TILE - 3, TILE - 3)
            var cell_color := Color("183d31") if terrain[y][x] == 1 else Color("263650")
            if territory[y][x] == 1:
                cell_color = Color("73562c")
            elif territory[y][x] == 2:
                cell_color = Color("5a303d")
            draw_rect(rect, cell_color, true)
            if Vector2i(x, y) == selected:
                draw_rect(rect, Color("f5d76e"), false, 4)
            var symbol := "F" if terrain[y][x] == 1 else "."
            if territory[y][x] == 1:
                symbol = "★"
            elif territory[y][x] == 2:
                symbol = "◆"
            draw_string(ThemeDB.fallback_font, rect.position + Vector2(29, 49), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("eef2f8"))

    draw_rect(Rect2(PX - 20, 70, 360, 610), Color("131c2d"), true)
    draw_string(ThemeDB.fallback_font, Vector2(PX, 108), "YOUR EMPIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f5d76e"))
    draw_string(ThemeDB.fallback_font, Vector2(PX, 134), "Gold %d   Food %d   Army %d" % [gold, food, army], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e0e7f4"))
    draw_string(ThemeDB.fallback_font, Vector2(PX, 156), "Towns %d   Score %d" % [towns, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9eabc1"))
    btn(175, "BUILD TOWN", "10 gold → +8 food")
    btn(245, "TRAIN SOLDIER", "12 gold + 5 food")
    btn(315, "EXPAND", "8–10 gold → claim land")
    btn(385, "ATTACK RIVAL", "risk / reward")
    btn(455, "END TURN", "+ income • enemy AI")
    btn(525, "WATCH AD  +50 GOLD", "optional rewarded bonus")
    draw_string(ThemeDB.fallback_font, Vector2(PX, 605), msg, HORIZONTAL_ALIGNMENT_LEFT, 330, 15, Color("c8d0df"))
    draw_string(ThemeDB.fallback_font, Vector2(PX, 645), "AUTO-SAVE ON • OFFLINE PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("83d9a0"))

    if over:
        draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.68), true)
        draw_string(ThemeDB.fallback_font, Vector2(350, 310), "VICTORY" if won else "DEFEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color("f5d76e"))
        draw_string(ThemeDB.fallback_font, Vector2(350, 365), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(350, 405), "Tap anywhere to restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("cbd4e4"))

func btn(y: float, title: String, sub: String) -> void:
    var rect := Rect2(PX, y, 330, 58)
    draw_rect(rect, Color("202d46"), true)
    draw_rect(rect, Color("425676"), false, 2)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f1f4fa"))
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(16, 45), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9eabc1"))
