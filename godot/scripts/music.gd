extends Node
## Picks the music for the moment (tracks from tools/godot_music.py, plus the web game's own
## day, night and storm loops), and crossfades when it changes:
##   the title screen, making your fisher, a dive, a tough fish on the line;
##   indoors: the tavern and inns, Gran's hut, the lighthouse, the shops;
##   storms; close to whatever the story's after (the keeper's secrets);
##   Gullhaven, Willowford and the estuary, Mirrorlake, the island villages, out sailing;
##   and otherwise the time of day.

const PROCESS_EVERY := 0.5
const ISLAND_TOWNS := ["Tideglass Cay", "Mossbank", "Kelpwood", "Lantern Key", "Wrecker's Cove", "Ember Isle"]

var main: Node
var audio: Node
var track := ""
var _t := 0.0


func setup(m: Node, a: Node) -> void:
	main = m
	audio = a
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = PROCESS_EVERY
	var want := pick()
	if want != track:
		track = want
		audio.set_music(want)


func pick() -> String:
	var menus: Node = main.menus
	if menus and str(menus.mode) == "title":
		return "title"
	var wardrobe: Node = main.wardrobe
	if wardrobe and bool(wardrobe.is_open) and str(wardrobe.mode) == "create":
		return "home"
	var spear: Node = main.spear
	if spear and bool(spear.is_open):
		return "dive"
	var fishing: Node = main.fishing
	if fishing and int(fishing.state) == 5 and (bool(fishing.bar_mode) or int(fishing.difficulty) >= 4):
		return "fight"
	var day_night: Node = main.day_night
	var base := str(day_night.music_base) if day_night else "day"
	var night := base == "night"
	var interiors: Node = main.interiors
	if interiors and bool(interiors.is_inside()):
		var role := str(interiors.inside.get("role", ""))
		if role in ["tavern", "inn", "lodge"]:
			return "tavern"
		if role == "hut":
			return "home"
		if role == "lighthouse":
			return "mystery"
		return "home" if night else "town"
	if base == "storm":
		return "storm"
	if _near_secret():
		return "mystery"
	var player: Node3D = main.player
	var p := player.global_position
	var world: Node = main.harbour
	var place := str(world.area_name(p.x, p.z))
	if place == "Gullhaven":
		return "night" if night else "town"
	if place in ["Willowford", "Mangrove Estuary"]:
		return "night" if night else "river"
	if place in ["Mirrorlake", "Mirrorlake Lodge"]:
		return "lake"
	if place in ISLAND_TOWNS or str(world.island_at(p.x, p.z)) != "":
		return "night" if night else "islands"
	var boats: Node = main.boats
	if boats and bool(boats.aboard):
		return "night" if night else "sailing"
	return base


## Close to one of the keeper's marks the story is sending you to.
func _near_secret() -> bool:
	var story: Node = main.story
	if story == null or bool(story.finished()):
		return false
	var s: Dictionary = story.current()
	if str(s.get("t", "")) != "mystery":
		return false
	var at: Vector3 = story.target()
	if at == Vector3.INF:
		return false
	var player: Node3D = main.player
	var p := player.global_position
	return Vector2(at.x - p.x, at.z - p.z).length() < 40.0
