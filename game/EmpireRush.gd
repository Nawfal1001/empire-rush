extends Node2D

# Empire Rush — narrative strategy overhaul.
# Original game logic/presentation; inspired by strategy-game conventions.
# No third-party game assets are bundled here.

const W := 10
const H := 7
const TILE := 82
const MX := 34
const MY := 116
const PX := 880
const SAVE := "user://empire_rush_campaign.cfg"
const MAX_TURNS := 60

@onready var monetization = $Monetization

var rng := RandomNumberGenerator.new()
var terrain: Array = []
var territory: Array = []
var buildings: Array = []
var explored: Array = []
var hero_levels: Array = [1, 1, 1]
var techs: Dictionary = {}
var diplomacy: Dictionary = {"Northmen": 0, "Merchants": 0, "Ashen Court": -10}
var quests: Array = []
var story_chapter := 1
var story_step := 0
var screen := "map"
var gold := 60
var food := 35
var wood := 25
var stone := 12
var army := 6
var rival := 6
var turn := 1
var towns := 1
var score := 0
var population := 12
var happiness := 70
var selected := Vector2i(-1, -1)
var selected_hero := 0
var msg := "The old king is dead. Your border is burning."
var over := false
var won := false
var story_popup := true
var popup_title := "THE LAST CROWN"
var popup_body := "King Aldren is dead. Three powers are watching the empty throne.\n\nSecure food, gather allies, and reach the frontier before the Ashen Court does."

var hero_names := ["Seren the Warden", "Mira the Diplomat", "Kael the Builder"]
var hero_roles := ["+combat power", "+diplomacy", "+building economy"]
var faction_names := ["Northmen", "Merchants", "Ashen Court"]

func _ready() -> void:
    rng.randomize()
    if not load_game():
        new_game()
    if not monetization.rewarded_completed.is_connected(_on_rewarded_completed):
        monetization.rewarded_completed.connect(_on_rewarded_completed)
    queue_redraw()

func new_game() -> void:
    terrain.clear()
    territory.clear()
    buildings.clear()
    explored.clear()
    techs.clear()
    quests.clear()
    diplomacy = {"Northmen": 0, "Merchants": 0, "Ashen Court": -10}
    hero_levels = [1, 1, 1]
    gold = 60
    food = 35
    wood = 25
    stone = 12
    army = 6
    rival = 6
    turn = 1
    towns = 1
    score = 0
    population = 12
    happiness = 70
    story_chapter = 1
    story_step = 0
    screen = "map"
    selected = Vector2i(-1, -1)
    selected_hero = 0
    over = false
    won = false
    story_popup = true
    popup_title = "THE LAST CROWN"
    popup_body = "King Aldren is dead. Three powers are watching the empty throne.\n\nSecure food, gather allies, and reach the frontier before the Ashen Court does."
    msg = "Chapter I — A crown without an heir."

    for y in range(H):
        var tr: Array = []
        var own: Array = []
        var bld: Array = []
        var exp: Array = []
        for x in range(W):
            tr.append(rng.randi_range(0, 99) < 20)
            own.append(0)
            bld.append(0)
            exp.append(false)
        terrain.append(tr)
        territory.append(own)
        buildings.append(bld)
        explored.append(exp)

    territory[3][1] = 1
    territory[3][2] = 1
    territory[2][1] = 1
    explored[3][1] = true
    explored[3][2] = true
    explored[2][1] = true
    buildings[3][1] = 1
    quests = [
        {"title":"Feed the Realm", "desc":"Reach 60 food.", "target":60, "kind":"food", "reward":35, "done":false},
        {"title":"Raise the Banner", "desc":"Reach 10 soldiers.", "target":10, "kind":"army", "reward":45, "done":false},
        {"title":"A Growing Kingdom", "desc":"Control 12 tiles.", "target":12, "kind":"land", "reward":60, "done":false}
    ]
    save_game()

func _unhandled_input(e: InputEvent) -> void:
    if not ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
        return
    var p: Vector2 = e.position
    if story_popup:
        if Rect2(720, 590, 420, 62).has_point(p):
            story_popup = false
            queue_redraw()
        return
    if over:
        new_game()
        queue_redraw()
        return
    if Rect2(875, 80, 92, 40).has_point(p): screen = "map"
    elif Rect2(972, 80, 92, 40).has_point(p): screen = "kingdom"
    elif Rect2(1069, 80, 92, 40).has_point(p): screen = "story"
    elif Rect2(1166, 80, 92, 40).has_point(p): screen = "diplomacy"
    if screen == "map": handle_map_input(p)
    elif screen == "kingdom": handle_kingdom_input(p)
    elif screen == "story": handle_story_input(p)
    elif screen == "diplomacy": handle_diplomacy_input(p)
    queue_redraw()

func handle_map_input(p: Vector2) -> void:
    if p.x >= MX and p.x < MX + W * TILE and p.y >= MY and p.y < MY + H * TILE:
        selected = Vector2i(int((p.x - MX) / TILE), int((p.y - MY) / TILE))
        msg = cell_text(selected)
        return
    if Rect2(PX, 150, 360, 50).has_point(p): build_building()
    elif Rect2(PX, 207, 360, 50).has_point(p): train()
    elif Rect2(PX, 264, 360, 50).has_point(p): expand()
    elif Rect2(PX, 321, 360, 50).has_point(p): attack()
    elif Rect2(PX, 378, 360, 50).has_point(p): end_turn()
    elif Rect2(PX, 435, 360, 50).has_point(p): recruit_hero()
    elif Rect2(PX, 492, 360, 50).has_point(p): watch_rewarded()

func handle_kingdom_input(p: Vector2) -> void:
    if Rect2(900, 155, 330, 52).has_point(p): research("agriculture")
    elif Rect2(900, 218, 330, 52).has_point(p): research("military")
    elif Rect2(900, 281, 330, 52).has_point(p): research("commerce")
    elif Rect2(900, 344, 330, 52).has_point(p): upgrade_hero()

func handle_story_input(p: Vector2) -> void:
    if Rect2(900, 530, 330, 55).has_point(p): advance_story()

func handle_diplomacy_input(p: Vector2) -> void:
    if Rect2(900, 170, 330, 52).has_point(p): diplomacy_action("Northmen")
    elif Rect2(900, 235, 330, 52).has_point(p): diplomacy_action("Merchants")
    elif Rect2(900, 300, 330, 52).has_point(p): diplomacy_action("Ashen Court")

func cell_text(c: Vector2i) -> String:
    if territory[c.y][c.x] == 1: return "Your land. Building: %s" % building_name(buildings[c.y][c.x])
    if territory[c.y][c.x] == 2: return "Ashen territory. Dangerous frontier."
    if terrain[c.y][c.x]: return "Forest — rich in wood, expensive to settle."
    if explored[c.y][c.x]: return "Explored plains. A road or farm could stand here."
    return "Unexplored frontier. Scouts report movement."

func build_building() -> void:
    if selected.x < 0 or territory[selected.y][selected.x] != 1:
        msg = "Select one of your tiles first."
        return
    if buildings[selected.y][selected.x] != 0:
        msg = "That tile already has a %s." % building_name(buildings[selected.y][selected.x])
        return
    if gold < 12 or wood < 5:
        msg = "Need 12 gold + 5 wood."
        return
    gold -= 12
    wood -= 5
    var choices := ["farm", "lumberyard", "quarry"]
    var b: String = choices[rng.randi_range(0, choices.size() - 1)]
    buildings[selected.y][selected.x] = building_id(b)
    score += 20
    msg = "%s built. Each turn it improves your economy." % b.capitalize()
    save_game()

func building_id(name: String) -> int:
    if name == "farm": return 2
    if name == "lumberyard": return 3
    if name == "quarry": return 4
    if name == "market": return 5
    if name == "barracks": return 6
    return 0

func building_name(id: int) -> String:
    match id:
        1: return "Capital"
        2: return "Farm"
        3: return "Lumberyard"
        4: return "Quarry"
        5: return "Market"
        6: return "Barracks"
        _: return "Empty"

func train() -> void:
    var barracks := count_building(6)
    var cost_food: int = max(3, 6 - barracks)
    if gold < 12 or food < cost_food:
        msg = "Need 12 gold + %d food." % cost_food
        return
    gold -= 12
    food -= cost_food
    army += 1
    population += 1
    score += 8
    msg = "A new soldier joins the royal guard. Army +1."
    save_game()

func expand() -> void:
    var best := Vector2i(-1, -1)
    var best_distance := 999
    for y in range(H):
        for x in range(W):
            if territory[y][x] != 0: continue
            var adjacent := false
            for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                var nx: int = x + d.x
                var ny: int = y + d.y
                if nx >= 0 and nx < W and ny >= 0 and ny < H and territory[ny][nx] == 1:
                    adjacent = true
                    break
            if not adjacent: continue
            var distance: int = abs(x - 1) + abs(y - 3)
            if distance < best_distance:
                best_distance = distance
                best = Vector2i(x, y)
    if best.x < 0:
        msg = "No connected frontier available."
        return
    var cost: int = 10 if terrain[best.y][best.x] else 8
    if gold < cost:
        msg = "Need %d gold to claim this land." % cost
        return
    territory[best.y][best.x] = 1
    explored[best.y][best.x] = true
    gold -= cost
    score += 15
    msg = "New province joined the crown."
    save_game()

func attack() -> void:
    if rival <= 0:
        win()
        return
    if army < 3:
        msg = "The generals refuse: you need at least 3 soldiers."
        return
    var hero_bonus: int = hero_levels[0] * 2
    var power: int = army + hero_bonus + rng.randi_range(0, 5)
    var defense: int = rival + story_chapter + rng.randi_range(0, 4)
    if techs.has("military"): power += 3
    if power >= defense:
        rival = max(0, rival - 2 - int(hero_levels[0] / 3))
        army = max(1, army - 1)
        food = max(0, food - 5)
        happiness = min(100, happiness + 4)
        score += 55
        msg = "Victory at the frontier! The Ashen banners retreat."
        if rival <= 0: win()
    else:
        army = max(1, army - 2)
        happiness = max(0, happiness - 7)
        score = max(0, score - 15)
        msg = "The assault fails. Survivors retreat behind the walls."
    save_game()

func recruit_hero() -> void:
    if gold < 25:
        msg = "A hero asks for 25 gold to join the crown."
        return
    var next := -1
    for i in range(hero_levels.size()):
        if hero_levels[i] == 1:
            next = i
            break
    if next < 0:
        msg = "All three heroes already serve you."
        return
    gold -= 25
    hero_levels[next] = 2
    selected_hero = next
    score += 30
    popup_title = hero_names[next]
    popup_body = "%s has entered your court.\n\n%s\n\nTheir loyalty will shape the future of your kingdom." % [hero_names[next], hero_roles[next]]
    story_popup = true
    msg = "%s joined the kingdom." % hero_names[next]
    save_game()

func upgrade_hero() -> void:
    if gold < 35:
        msg = "Hero training costs 35 gold."
        return
    gold -= 35
    hero_levels[selected_hero] += 1
    score += 25
    msg = "%s reaches level %d." % [hero_names[selected_hero], hero_levels[selected_hero]]
    save_game()

func research(kind: String) -> void:
    var costs: Dictionary = {"agriculture":30, "military":40, "commerce":45}
    if techs.has(kind):
        msg = "That technology is already researched."
        return
    var cost: int = int(costs[kind])
    if gold < cost:
        msg = "Need %d gold for %s." % [cost, kind.capitalize()]
        return
    gold -= cost
    techs[kind] = true
    score += 50
    msg = "%s researched. Your kingdom evolves." % kind.capitalize()
    save_game()

func diplomacy_action(faction: String) -> void:
    if gold < 15:
        msg = "Diplomatic gifts cost 15 gold."
        return
    gold -= 15
    diplomacy[faction] = int(diplomacy[faction]) + 12
    score += 12
    if faction == "Northmen":
        army += 1
        msg = "The Northmen send a veteran to your army."
    elif faction == "Merchants":
        gold += 25
        msg = "Merchant caravans open a profitable route. +25 gold."
    else:
        rival = max(0, rival - 1)
        msg = "The Ashen Court accepts a tense truce. Rival pressure falls."
    save_game()

func advance_story() -> void:
    story_step += 1
    if story_step == 1:
        popup_title = "THE BROKEN SEAL"
        popup_body = "A letter arrives bearing the royal seal.\nSomeone inside the capital helped assassinate Aldren.\n\nMira urges diplomacy. Seren demands justice. Kael says the kingdom needs walls before revenge."
    elif story_step == 2:
        story_chapter = 2
        popup_title = "CHAPTER II — THREE OATHS"
        popup_body = "The throne is no longer empty. It is contested.\n\nThe Northmen offer swords. The Merchants offer gold. The Ashen Court offers peace — for a price."
        score += 50
    elif story_step == 3:
        story_chapter = 3
        popup_title = "CHAPTER III — THE BLACK ROAD"
        popup_body = "Scouts discover an ancient road beneath the forest.\nIt leads toward the Ashen capital.\n\nControl the road, and the final war can be chosen on your terms."
        score += 75
    else:
        popup_title = "THE LAST DECISION"
        popup_body = "Your people are watching.\n\nBuild a prosperous realm, forge alliances, and decide whether the Ashen Court becomes an enemy or an ally.\n\nYour choices now determine the ending."
        score += 100
    story_popup = true
    msg = "The chronicle advances."
    save_game()

func end_turn() -> void:
    turn += 1
    var land := count_land()
    var farms := count_building(2)
    var lumber := count_building(3)
    var quarries := count_building(4)
    var markets := count_building(5)
    var barracks := count_building(6)
    gold += 6 + land + towns + markets * 3
    food += max(2, int(land / 2)) + farms * 5 + (3 if techs.has("agriculture") else 0)
    wood += 2 + lumber * 4
    stone += 1 + quarries * 3
    population += max(1, int(land / 5))
    if barracks > 0: army += 1
    happiness += 2 if food >= population else -8
    happiness = clamp(happiness, 0, 100)
    if turn % 3 == 0: rival += 1
    if turn >= 4 and rng.randi_range(0, 99) < 22:
        random_event()
    elif turn >= 7 and rng.randi_range(0, 99) < 18:
        army = max(1, army - 1)
        msg = "Border skirmish: one soldier was lost."
    else:
        msg = "Turn %d — harvests gathered and the realm grows." % turn
    reveal_frontier()
    check_quests()
    if turn == 10 and story_step < 1: advance_story()
    if turn == 22 and story_chapter < 3: advance_story()
    if turn >= MAX_TURNS and score < 700:
        over = true
        won = false
        msg = "The kingdom survived, but the throne slipped from your grasp."
    if happiness <= 0:
        over = true
        won = false
        msg = "The people revolt. The crown is lost."
    if turn > 1: monetization.mark_interstitial_session()
    save_game()

func random_event() -> void:
    match rng.randi_range(0, 5):
        0:
            gold += 35
            msg = "EVENT — Merchant caravan: +35 gold."
        1:
            food += 30
            happiness = min(100, happiness + 5)
            msg = "EVENT — A rich harvest: +30 food."
        2:
            army += 2
            happiness = max(0, happiness - 2)
            msg = "EVENT — Veterans arrive from the frontier: +2 army."
        3:
            wood = max(0, wood - 12)
            msg = "EVENT — Forest fire: -12 wood."
        4:
            diplomacy["Merchants"] = int(diplomacy["Merchants"]) + 10
            gold += 15
            msg = "EVENT — Trade festival: merchants improve relations."
        5:
            rival += 2
            happiness = max(0, happiness - 5)
            msg = "EVENT — Ashen mobilisation: the rival grows stronger."

func reveal_frontier() -> void:
    for y in range(H):
        for x in range(W):
            if territory[y][x] != 1: continue
            explored[y][x] = true
            for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                var nx: int = x + d.x
                var ny: int = y + d.y
                if nx >= 0 and nx < W and ny >= 0 and ny < H: explored[ny][nx] = true

func check_quests() -> void:
    for q in quests:
        if q["done"]: continue
        var current := 0
        if q["kind"] == "food": current = food
        elif q["kind"] == "army": current = army
        elif q["kind"] == "land": current = count_land()
        if current >= q["target"]:
            q["done"] = true
            gold += q["reward"]
            score += q["reward"]
            msg = "QUEST COMPLETE — %s. +%d gold." % [q["title"], q["reward"]]

func count_land() -> int:
    var total := 0
    for row in territory:
        for value in row:
            if value == 1: total += 1
    return total

func count_building(id: int) -> int:
    var total := 0
    for row in buildings:
        for value in row:
            if value == id: total += 1
    return total

func watch_rewarded() -> void:
    if monetization.can_reward():
        msg = "Rewarded ad ready: +50 gold."
        monetization.request_rewarded()
    else:
        msg = "Reward ad is loading. Try again shortly."

func _on_rewarded_completed() -> void:
    gold += 50
    score += 25
    msg = "Reward claimed: +50 gold +25 score."
    save_game()

func win() -> void:
    won = true
    over = true
    score += 250
    popup_title = "THE CROWN IS YOURS"
    popup_body = "The Ashen banners fall. But conquest was only the beginning.\n\nYour final legacy will be remembered for war, wealth, diplomacy, or the people."
    save_game()

func save_game() -> void:
    var config := ConfigFile.new()
    var keys := ["gold", "food", "wood", "stone", "army", "rival", "turn", "towns", "score", "population", "happiness", "story_chapter", "story_step"]
    for key in keys: config.set_value("game", key, get(key))
    config.set_value("game", "terrain", terrain)
    config.set_value("game", "territory", territory)
    config.set_value("game", "buildings", buildings)
    config.set_value("game", "explored", explored)
    config.set_value("game", "hero_levels", hero_levels)
    config.set_value("game", "techs", techs)
    config.set_value("game", "diplomacy", diplomacy)
    config.set_value("game", "quests", quests)
    config.save(SAVE)

func load_game() -> bool:
    var config := ConfigFile.new()
    if config.load(SAVE) != OK: return false
    if not config.has_section_key("game", "terrain") or not config.has_section_key("game", "buildings"): return false
    var keys := ["gold", "food", "wood", "stone", "army", "rival", "turn", "towns", "score", "population", "happiness", "story_chapter", "story_step"]
    for key in keys: set(key, int(config.get_value("game", key, get(key))))
    terrain = config.get_value("game", "terrain", [])
    territory = config.get_value("game", "territory", [])
    buildings = config.get_value("game", "buildings", [])
    explored = config.get_value("game", "explored", [])
    hero_levels = config.get_value("game", "hero_levels", [1,1,1])
    techs = config.get_value("game", "techs", {})
    diplomacy = config.get_value("game", "diplomacy", {"Northmen":0,"Merchants":0,"Ashen Court":-10})
    quests = config.get_value("game", "quests", [])
    if terrain.size() != H or territory.size() != H or buildings.size() != H: return false
    msg = "Campaign restored — your choices still matter."
    return true

func _draw() -> void:
    draw_rect(Rect2(0,0,1280,720), Color("080d18"), true)
    draw_rect(Rect2(0,0,1280,70), Color("111a2d"), true)
    draw_string(ThemeDB.fallback_font, Vector2(30,42), "EMPIRE RUSH", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("f5d76e"))
    draw_string(ThemeDB.fallback_font, Vector2(30,61), "A KINGDOM IS BUILT ONE CHOICE AT A TIME", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9da9c2"))
    draw_string(ThemeDB.fallback_font, Vector2(300,35), "TURN %d / %d" % [turn,MAX_TURNS], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e0e7f4"))
    draw_string(ThemeDB.fallback_font, Vector2(300,57), "Gold %d  Food %d  Wood %d  Stone %d" % [gold,food,wood,stone], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aebbd0"))
    draw_string(ThemeDB.fallback_font, Vector2(650,35), "Army %d  People %d  Happiness %d%%" % [army,population,happiness], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e0e7f4"))
    draw_string(ThemeDB.fallback_font, Vector2(650,57), "Chapter %d  Score %d" % [story_chapter,score], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aebbd0"))
    if screen == "map": draw_map()
    elif screen == "kingdom": draw_kingdom()
    elif screen == "story": draw_story()
    elif screen == "diplomacy": draw_diplomacy()
    draw_tabs()
    if story_popup: draw_popup()
    if over and not story_popup: draw_game_over()

func draw_map() -> void:
    for y in range(H):
        for x in range(W):
            var rect := Rect2(MX+x*TILE, MY+y*TILE, TILE-3, TILE-3)
            var c := Color("253550")
            if terrain[y][x]: c = Color("1d4939")
            if not explored[y][x] and territory[y][x] == 0: c = Color("101a2b")
            if territory[y][x] == 1: c = Color("76592f")
            elif territory[y][x] == 2: c = Color("5d303f")
            draw_rect(rect,c,true)
            if Vector2i(x,y) == selected: draw_rect(rect,Color("f5d76e"),false,4)
            var symbol: String = "?" if not explored[y][x] else "."
            if terrain[y][x] and explored[y][x]: symbol = "F"
            if territory[y][x] == 1: symbol = "C"
            elif territory[y][x] == 2: symbol = "R"
            if buildings[y][x] > 1: symbol = str(buildings[y][x])
            draw_string(ThemeDB.fallback_font, rect.position+Vector2(28,48), symbol, HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("eef2f8"))
    draw_rect(Rect2(PX-18,90,380,610),Color("131c2d"),true)
    draw_string(ThemeDB.fallback_font,Vector2(PX,122),"COMMAND",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("f5d76e"))
    draw_string(ThemeDB.fallback_font,Vector2(PX,140),msg,HORIZONTAL_ALIGNMENT_LEFT,350,13,Color("b8c4d8"))
    btn(158,"BUILD","Select owned tile → build 12g + 5w")
    btn(215,"TRAIN","12g + food → raise army")
    btn(272,"EXPAND","Claim the nearest frontier")
    btn(329,"ATTACK","Fight the Ashen Court")
    btn(386,"END TURN","Economy + events + enemy AI")
    btn(443,"RECRUIT HERO","25g → unlock a court hero")
    btn(500,"REWARDED +50g","Optional monetization")
    draw_string(ThemeDB.fallback_font,Vector2(PX,590),"QUESTS",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f5d76e"))
    for i in range(min(2,quests.size())):
        var q: Dictionary = quests[i]
        var state: String = "DONE" if q["done"] else "OPEN"
        draw_string(ThemeDB.fallback_font,Vector2(PX,615+i*25),"[%s] %s" % [state,q["title"]],HORIZONTAL_ALIGNMENT_LEFT,350,13,Color("d8dfeb"))

func draw_kingdom() -> void:
    draw_panel_title("KINGDOM", "Develop technology, heroes and the economy.")
    draw_string(ThemeDB.fallback_font,Vector2(60,155),"TECHNOLOGY",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f5d76e"))
    info_button(900,155,"AGRICULTURE — 30g","+food each turn")
    info_button(900,218,"MILITARY — 40g","+3 battle power")
    info_button(900,281,"COMMERCE — 45g","+trade income")
    info_button(900,344,"TRAIN HERO — 35g","Upgrade selected hero")
    draw_string(ThemeDB.fallback_font,Vector2(60,215),"ROYAL COURT",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f5d76e"))
    for i in range(3):
        var y := 255+i*82
        draw_rect(Rect2(60,y,760,68),Color("151f32"),true)
        draw_string(ThemeDB.fallback_font,Vector2(80,y+25),hero_names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f1f4fa"))
        draw_string(ThemeDB.fallback_font,Vector2(80,y+49),"Level %d • %s" % [hero_levels[i],hero_roles[i]],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbd0"))
    draw_string(ThemeDB.fallback_font,Vector2(60,525),"PROVINCES: %d    FARMS: %d    LUMBER: %d    QUARRIES: %d    BARRACKS: %d" % [count_land(),count_building(2),count_building(3),count_building(4),count_building(6)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("cbd4e4"))
    draw_string(ThemeDB.fallback_font,Vector2(60,570),"Technology changes economy and battle calculations. Heroes unlock stronger choices.",HORIZONTAL_ALIGNMENT_LEFT,760,14,Color("8795ad"))

func draw_story() -> void:
    draw_panel_title("THE CHRONICLE", "Your campaign is a sequence of consequences, not just turns.")
    draw_rect(Rect2(55,145,790,430),Color("121b2c"),true)
    draw_string(ThemeDB.fallback_font,Vector2(85,190),"CHAPTER %d" % story_chapter,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f5d76e"))
    var chapters := ["The Last Crown","Three Oaths","The Black Road","The Final Decision"]
    for i in range(4):
        var c := Color("f5d76e") if i < story_chapter else Color("5d6a82")
        var roman: String = ["I","II","III","IV"][i]
        draw_string(ThemeDB.fallback_font,Vector2(90,235+i*52),"%s  %s" % [roman,chapters[i]],HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)
    draw_string(ThemeDB.fallback_font,Vector2(90,455),"Latest message",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8fa0ba"))
    draw_string(ThemeDB.fallback_font,Vector2(90,485),msg,HORIZONTAL_ALIGNMENT_LEFT,700,18,Color("e8edf5"))
    info_button(900,530,"ADVANCE CHRONICLE","Reveal the next chapter")

func draw_diplomacy() -> void:
    draw_panel_title("DIPLOMACY", "Three factions. Different rewards. No relationship is permanent.")
    for i in range(3):
        var name: String = faction_names[i]
        var y := 165+i*120
        draw_rect(Rect2(60,y,760,95),Color("151f32"),true)
        var rel: int = int(diplomacy[name])
        draw_string(ThemeDB.fallback_font,Vector2(85,y+30),name,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("f1f4fa"))
        draw_string(ThemeDB.fallback_font,Vector2(85,y+58),"Reputation: %d" % rel,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b4c0d4"))
        var desc: String = "Military aid" if name == "Northmen" else ("Gold and trade" if name == "Merchants" else "A dangerous truce")
        draw_string(ThemeDB.fallback_font,Vector2(85,y+80),desc,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("8492aa"))
    info_button(900,170,"GIFT NORTHMEN — 15g","+reputation, +1 army")
    info_button(900,235,"COURT MERCHANTS — 15g","+reputation, +25 gold")
    info_button(900,300,"TREAT WITH ASHEN — 15g","+reputation, -1 rival")

func draw_tabs() -> void:
    var names := ["MAP","KINGDOM","STORY","DIPLOMACY"]
    var screens := ["map","kingdom","story","diplomacy"]
    for i in range(4):
        var x := 875+i*97
        var active: bool = screens[i] == screen
        draw_rect(Rect2(x,76,92,34),Color("5a4728") if active else Color("1b263a"),true)
        draw_string(ThemeDB.fallback_font,Vector2(x+13,99),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f1f4fa"))

func draw_panel_title(title: String, sub: String) -> void:
    draw_string(ThemeDB.fallback_font,Vector2(55,125),title,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("f5d76e"))
    draw_string(ThemeDB.fallback_font,Vector2(260,125),sub,HORIZONTAL_ALIGNMENT_LEFT,580,13,Color("9da9c2"))

func btn(y: float,title: String,sub: String) -> void:
    draw_rect(Rect2(PX,y,360,50),Color("202d46"),true)
    draw_rect(Rect2(PX,y,360,50),Color("425676"),false,2)
    draw_string(ThemeDB.fallback_font,Vector2(PX+14,y+21),title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f1f4fa"))
    draw_string(ThemeDB.fallback_font,Vector2(PX+14,y+40),sub,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9eabc1"))

func info_button(x: float,y: float,title: String,sub: String) -> void:
    draw_rect(Rect2(x,y,330,52),Color("202d46"),true)
    draw_rect(Rect2(x,y,330,52),Color("425676"),false,2)
    draw_string(ThemeDB.fallback_font,Vector2(x+14,y+21),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1f4fa"))
    draw_string(ThemeDB.fallback_font,Vector2(x+14,y+41),sub,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9eabc1"))

func draw_popup() -> void:
    draw_rect(Rect2(0,0,1280,720),Color(0,0,0,0.78),true)
    draw_rect(Rect2(190,105,900,520),Color("131c2d"),true)
    draw_rect(Rect2(190,105,900,520),Color("5a6d8d"),false,3)
    draw_string(ThemeDB.fallback_font,Vector2(240,175),popup_title,HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("f5d76e"))
    draw_string(ThemeDB.fallback_font,Vector2(240,225),popup_body,HORIZONTAL_ALIGNMENT_LEFT,780,20,Color("e4eaf3"))
    draw_rect(Rect2(720,590,420,62),Color("76592f"),true)
    draw_string(ThemeDB.fallback_font,Vector2(760,629),"CONTINUE THE STORY",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff6d0"))

func draw_game_over() -> void:
    draw_rect(Rect2(0,0,1280,720),Color(0,0,0,0.76),true)
    var title: String = "VICTORY" if won else "THE CROWN IS LOST"
    draw_string(ThemeDB.fallback_font,Vector2(350,300),title,HORIZONTAL_ALIGNMENT_LEFT,-1,58,Color("f5d76e"))
    draw_string(ThemeDB.fallback_font,Vector2(350,350),"Final score: %d   Turn: %d" % [score,turn],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
    draw_string(ThemeDB.fallback_font,Vector2(350,390),"Tap anywhere to begin a new campaign.",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("cbd4e4"))
