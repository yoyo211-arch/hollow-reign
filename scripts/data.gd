extends RefCounted
## Static game data: weapons, skills, enemies, skins and levels.
## Sprite names refer to files in res://assets/dungeon (0x72 DungeonTileset II, CC0).

const WEAPON_ORDER := ["pistol", "shotgun", "crossbow", "scythe", "hex"]

## "req" is how many gates must be cleared before the weapon can be forged.
## "hold": "point" sprites are drawn pointing up and rotated toward the aim; "bow" faces right.
const WEAPONS := {
	"pistol": {
		"name": "Throwing Knives", "short": "KNIVES", "desc": "A bandolier of rusted blades. Quick and reliable.",
		"sprite": "weapon_knife", "hold": "point", "proj": "knife",
		"cost": 0, "req": 0, "kind": "bullet", "damage": 12.0, "rate": 3.6, "speed": 900.0,
		"spread": 0.04, "count": 1, "pierce": 0, "life": 0.9, "width": 3.0,
		"color": Color(0.85, 0.92, 1.0), "sound": "shoot", "shake": 1.5,
	},
	"shotgun": {
		"name": "Hellfire Staff", "short": "HELLFIRE", "desc": "Spews a cone of cinders. Devastating up close.",
		"sprite": "weapon_red_magic_staff", "hold": "point", "proj": "ember",
		"cost": 60, "req": 1, "kind": "bullet", "damage": 9.0, "rate": 1.3, "speed": 760.0,
		"spread": 0.3, "count": 7, "pierce": 0, "life": 0.42, "width": 4.0,
		"color": Color(1.0, 0.45, 0.15), "sound": "shotgun", "shake": 5.0,
	},
	"crossbow": {
		"name": "Bone Bow", "short": "BOW", "desc": "Heavy arrows that punch through rows of the dead.",
		"sprite": "weapon_bow", "hold": "bow", "proj": "arrow",
		"cost": 130, "req": 2, "kind": "bullet", "damage": 34.0, "rate": 1.5, "speed": 1300.0,
		"spread": 0.0, "count": 1, "pierce": 4, "life": 0.9, "width": 4.0,
		"color": Color(1.0, 0.9, 0.7), "sound": "bow", "shake": 3.0,
	},
	"scythe": {
		"name": "Executioner's Axe", "short": "AXE", "desc": "Wide cleaving swings. Cuts enemy spells out of the air.",
		"sprite": "weapon_waraxe", "hold": "point", "proj": "",
		"cost": 200, "req": 3, "kind": "melee", "damage": 32.0, "rate": 1.7, "range": 125.0,
		"arc": 1.3, "color": Color(1.0, 0.3, 0.25), "sound": "slash", "shake": 4.0,
	},
	"hex": {
		"name": "Wraith Staff", "short": "WRAITH", "desc": "Looses restless spirits that hunt their prey.",
		"sprite": "weapon_green_magic_staff", "hold": "point", "proj": "wisp",
		"cost": 280, "req": 4, "kind": "homing", "damage": 9.0, "rate": 6.5, "speed": 540.0,
		"spread": 0.25, "count": 1, "pierce": 0, "life": 1.6, "width": 5.0,
		"color": Color(0.4, 1.0, 0.65), "sound": "hex", "shake": 0.8,
	},
}

const SKIN_ORDER := ["knight_m", "knight_f", "elf_m", "elf_f", "dwarf_m", "dwarf_f", "wizzard_m", "wizzard_f", "lizard_m", "lizard_f", "doc", "pumpkin_dude", "angel"]

const SKINS := {
	"knight_m": {"name": "Knight", "cost": 0},
	"knight_f": {"name": "Dame", "cost": 0},
	"elf_m": {"name": "Ranger", "cost": 40},
	"elf_f": {"name": "Huntress", "cost": 40},
	"dwarf_m": {"name": "Dwarf", "cost": 60},
	"dwarf_f": {"name": "Shieldmaiden", "cost": 60},
	"wizzard_m": {"name": "Wizard", "cost": 90},
	"wizzard_f": {"name": "Witch", "cost": 90},
	"lizard_m": {"name": "Lizardfolk", "cost": 120},
	"lizard_f": {"name": "Saurian", "cost": 120},
	"doc": {"name": "Plague Doctor", "cost": 180},
	"pumpkin_dude": {"name": "Pumpkin Head", "cost": 220},
	"angel": {"name": "Fallen Angel", "cost": 300},
}

const SKILL_BRANCHES := [
	{"name": "BLOOD", "color": Color(0.85, 0.2, 0.2), "skills": ["thick_blood", "scar_tissue", "ichor", "undying"]},
	{"name": "WRATH", "color": Color(0.95, 0.55, 0.15), "skills": ["hate", "frenzy", "cruel", "spite"]},
	{"name": "SHADE", "color": Color(0.6, 0.5, 1.0), "skills": ["light_step", "phantom", "hunger", "vampiric"]},
]

const SKILLS := {
	"thick_blood": {"name": "Thick Blood", "desc": "+30 max health.", "cost": 20, "req": "", "effect": {"max_hp": 30.0}},
	"scar_tissue": {"name": "Scar Tissue", "desc": "Take 15% less damage.", "cost": 45, "req": "thick_blood", "effect": {"armor": 0.15}},
	"ichor": {"name": "Black Ichor", "desc": "Regenerate 1.5 health per second.", "cost": 80, "req": "scar_tissue", "effect": {"regen": 1.5}},
	"undying": {"name": "Undying Oath", "desc": "Once per gate, rise again at half health.", "cost": 160, "req": "ichor", "effect": {"revive": true}},
	"hate": {"name": "Sharpened Hate", "desc": "+20% damage.", "cost": 20, "req": "", "effect": {"damage_mult": 0.2}},
	"frenzy": {"name": "Frenzy", "desc": "+20% attack speed.", "cost": 45, "req": "hate", "effect": {"fire_rate_mult": 0.2}},
	"cruel": {"name": "Cruel Fate", "desc": "+15% chance to deal double damage.", "cost": 80, "req": "frenzy", "effect": {"crit": 0.15}},
	"spite": {"name": "Piercing Spite", "desc": "Shots pierce 1 more foe and deal +15% damage.", "cost": 160, "req": "cruel", "effect": {"pierce": 1, "damage_mult": 0.15}},
	"light_step": {"name": "Light Step", "desc": "+12% movement speed.", "cost": 20, "req": "", "effect": {"move_speed": 32.0}},
	"phantom": {"name": "Phantom Dash", "desc": "Dash recovers 40% faster.", "cost": 45, "req": "light_step", "effect": {"dash_cd": -0.45}},
	"hunger": {"name": "Soul Hunger", "desc": "+40% souls, and souls drift to you from farther away.", "cost": 80, "req": "phantom", "effect": {"soul_mult": 0.4, "pickup_radius": 90.0}},
	"vampiric": {"name": "Vampiric Shade", "desc": "Every kill restores 2 health.", "cost": 160, "req": "hunger", "effect": {"kill_heal": 2.0}},
}

## "sprites" are picked at random per spawn; "radius" is the hit radius in world pixels.
const ENEMIES := {
	"shambler": {"hp": 30.0, "speed": 80.0, "dmg": 10.0, "radius": 18.0, "souls": 1, "knock": 1.0,
		"sprites": ["skelet", "tiny_zombie"], "scale": 3.0, "blood": Color(0.45, 0.03, 0.03)},
	"runner": {"hp": 16.0, "speed": 175.0, "dmg": 7.0, "radius": 15.0, "souls": 1, "knock": 1.2,
		"sprites": ["imp"], "scale": 3.0, "blood": Color(0.5, 0.05, 0.03)},
	"spitter": {"hp": 26.0, "speed": 75.0, "dmg": 9.0, "radius": 18.0, "souls": 2, "knock": 1.0,
		"sprites": ["necromancer", "orc_shaman"], "scale": 3.0, "blood": Color(0.35, 0.05, 0.4)},
	"brute": {"hp": 150.0, "speed": 58.0, "dmg": 22.0, "radius": 34.0, "souls": 5, "knock": 0.25,
		"sprites": ["big_zombie", "ogre"], "scale": 3.0, "blood": Color(0.35, 0.3, 0.05)},
	"exploder": {"hp": 18.0, "speed": 135.0, "dmg": 28.0, "radius": 17.0, "souls": 1, "knock": 1.0,
		"sprites": ["swampy", "muddy"], "scale": 3.0, "blood": Color(0.3, 0.45, 0.05)},
}

const LEVELS := [
	{"name": "The Ashen Gate", "sub": "Where the dead first stirred", "time": 60.0, "interval": 1.3, "hp": 1.0,
		"pool": {"shambler": 1.0},
		"ambient": Color(0.42, 0.38, 0.4), "floor": Color(1.0, 0.95, 0.92), "banner": "wall_banner_red",
		"torch": Color(1.0, 0.62, 0.32), "ash": Color(0.75, 0.7, 0.65, 0.35)},
	{"name": "Weeping Catacombs", "sub": "The walls remember every scream", "time": 70.0, "interval": 1.15, "hp": 1.15,
		"pool": {"shambler": 3.0, "runner": 2.0},
		"ambient": Color(0.32, 0.36, 0.48), "floor": Color(0.8, 0.88, 1.0), "banner": "wall_banner_blue",
		"torch": Color(0.55, 0.75, 1.0), "ash": Color(0.6, 0.75, 0.9, 0.3)},
	{"name": "The Rotting Chapel", "sub": "Its prayers curdled into plague", "time": 80.0, "interval": 1.0, "hp": 1.3,
		"pool": {"shambler": 3.0, "runner": 2.0, "spitter": 1.5},
		"ambient": Color(0.34, 0.42, 0.32), "floor": Color(0.85, 1.0, 0.8), "banner": "wall_banner_green",
		"torch": Color(0.75, 1.0, 0.45), "ash": Color(0.6, 0.85, 0.4, 0.3)},
	{"name": "Ossuary Depths", "sub": "Bones stacked to the ceiling", "time": 90.0, "interval": 0.9, "hp": 1.5,
		"pool": {"shambler": 3.0, "runner": 2.0, "spitter": 1.5, "brute": 0.8},
		"ambient": Color(0.42, 0.38, 0.3), "floor": Color(1.0, 0.95, 0.8), "banner": "wall_banner_yellow",
		"torch": Color(1.0, 0.75, 0.4), "ash": Color(0.85, 0.8, 0.65, 0.3)},
	{"name": "Blood Moon Ramparts", "sub": "The sky itself bleeds", "time": 100.0, "interval": 0.8, "hp": 1.75,
		"pool": {"shambler": 3.0, "runner": 2.5, "spitter": 1.5, "brute": 1.0, "exploder": 1.5},
		"ambient": Color(0.48, 0.24, 0.24), "floor": Color(1.0, 0.8, 0.78), "banner": "wall_banner_red",
		"torch": Color(1.0, 0.3, 0.2), "ash": Color(1.0, 0.3, 0.2, 0.45)},
	{"name": "Throne of the Hollow King", "sub": "Kneel, or be broken", "time": 0.0, "interval": 3.5, "hp": 1.8,
		"pool": {"shambler": 2.0, "runner": 1.5, "exploder": 0.6}, "boss": true,
		"ambient": Color(0.34, 0.26, 0.44), "floor": Color(0.88, 0.8, 1.0), "banner": "wall_banner_red",
		"torch": Color(0.75, 0.45, 1.0), "ash": Color(0.7, 0.5, 1.0, 0.35)},
]
