extends Node
## Static game data: classes, skills, statuses, enemies, floors, loot tables.

const ELEMENTS := ["phys", "fire", "ice", "storm", "nature", "light", "shadow"]
const ELEM_NAME := {"phys": "Physical", "fire": "Fire", "ice": "Ice", "storm": "Storm", "nature": "Nature", "light": "Light", "shadow": "Shadow"}
const ELEM_COLOR := {
	"phys": Color("d8d2c4"), "fire": Color("ff7a3d"), "ice": Color("7fd8ff"), "storm": Color("ffe45c"),
	"nature": Color("7be06a"), "light": Color("fff3b0"), "shadow": Color("b07cff")}

const RARITY := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLOR := [Color("c9c4b8"), Color("6fe08a"), Color("5fb4ff"), Color("c47bff"), Color("ffb347")]

const CLASSES := {
	"runeknight": {"name": "Runeknight", "role": "Tank / Breaker", "weapon": "sword", "elem": "fire",
		"desc": "Armoured warrior who carves fire runes into every swing. Protects allies and shatters guards.",
		"base": {"hp": 125, "mp": 30, "atk": 14, "mag": 7, "def": 13, "res": 8, "spd": 8, "crit": 5},
		"grow": {"hp": 15, "mp": 2, "atk": 2.2, "mag": 0.8, "def": 1.9, "res": 1.0, "spd": 0.4},
		"skills": ["rune_slash", "guard_stance", "runic_cleave", "bulwark"], "names": ["Aldric", "Bryn", "Corvin"]},
	"stormcaller": {"name": "Stormcaller", "role": "Storm Mage", "weapon": "staff", "elem": "storm",
		"desc": "Channels thunderheads through a crystal staff. Devastating area magic, fragile body.",
		"base": {"hp": 80, "mp": 60, "atk": 6, "mag": 16, "def": 6, "res": 12, "spd": 10, "crit": 5},
		"grow": {"hp": 9, "mp": 4, "atk": 0.7, "mag": 2.5, "def": 0.8, "res": 1.6, "spd": 0.5},
		"skills": ["spark", "chain_lightning", "gale_step", "tempest"], "names": ["Vessa", "Ilyra", "Quen"]},
	"thornwarden": {"name": "Thornwarden", "role": "Ranger / Support", "weapon": "bow", "elem": "nature",
		"desc": "Forest guardian with a living bow. Poisons foes and regrows allies.",
		"base": {"hp": 95, "mp": 42, "atk": 12, "mag": 10, "def": 8, "res": 9, "spd": 11, "crit": 8},
		"grow": {"hp": 11, "mp": 3, "atk": 1.9, "mag": 1.4, "def": 1.1, "res": 1.2, "spd": 0.6},
		"skills": ["thorn_shot", "regrowth", "entangle", "bramble_volley"], "names": ["Bramm", "Sylva", "Fenn"]},
	"shadeblade": {"name": "Shadeblade", "role": "Assassin", "weapon": "dagger", "elem": "shadow",
		"desc": "Moves between heartbeats. Highest speed and critical strikes; spots hidden traps.",
		"base": {"hp": 85, "mp": 36, "atk": 15, "mag": 7, "def": 7, "res": 7, "spd": 14, "crit": 18},
		"grow": {"hp": 10, "mp": 2, "atk": 2.3, "mag": 0.8, "def": 0.9, "res": 0.9, "spd": 0.8},
		"skills": ["backstab", "venom_edge", "smoke_veil", "shadow_flurry"], "names": ["Kael", "Nyra", "Vex"]},
	"cleric": {"name": "Lumen Cleric", "role": "Healer", "weapon": "mace", "elem": "light",
		"desc": "Keeper of the dawn lantern. Heals, cleanses and raises the fallen.",
		"base": {"hp": 92, "mp": 56, "atk": 9, "mag": 14, "def": 9, "res": 13, "spd": 9, "crit": 4},
		"grow": {"hp": 11, "mp": 4, "atk": 1.1, "mag": 2.1, "def": 1.1, "res": 1.7, "spd": 0.5},
		"skills": ["mend", "radiant_smite", "sanctuary", "revive"], "names": ["Liora", "Oren", "Seraphe"]},
	"gearsmith": {"name": "Gearsmith", "role": "Engineer", "weapon": "hammer", "elem": "ice",
		"desc": "Inventor with a cryo-powered hammer. Bombs, buffs and repair drones.",
		"base": {"hp": 105, "mp": 40, "atk": 13, "mag": 11, "def": 11, "res": 8, "spd": 8, "crit": 6},
		"grow": {"hp": 13, "mp": 3, "atk": 1.9, "mag": 1.5, "def": 1.5, "res": 1.0, "spd": 0.4},
		"skills": ["cryo_bomb", "overclock", "shrapnel", "repair_drone"], "names": ["Tobin", "Marra", "Gizz"]},
}
const CLASS_ORDER := ["runeknight", "stormcaller", "thornwarden", "shadeblade", "cleric", "gearsmith"]

const WEAPON_TYPES := {
	"sword": {"name": "Sword", "atk": 1.0, "mag": 0.2},
	"staff": {"name": "Staff", "atk": 0.25, "mag": 1.0},
	"bow": {"name": "Longbow", "atk": 0.9, "mag": 0.35},
	"dagger": {"name": "Dirk", "atk": 0.85, "mag": 0.2, "crit": 6},
	"mace": {"name": "Mace", "atk": 0.5, "mag": 0.85},
	"hammer": {"name": "Gearhammer", "atk": 0.9, "mag": 0.5},
}
const TIER_NAMES := ["Bronze", "Iron", "Runesteel", "Starforged", "Voidtempered"]

## target: enemy, all_enemies, random_enemies, ally, all_allies, self, dead_ally
## kind: phys, mag, heal, buff ; power multiplies ATK (phys) or MAG (mag/heal)
const SKILLS := {
	"attack": {"name": "Attack", "mp": 0, "target": "enemy", "kind": "phys", "power": 1.0, "elem": "", "brk": 1, "lvl": 1, "desc": "Strike with your weapon."},
	"rune_slash": {"name": "Rune Slash", "mp": 5, "target": "enemy", "kind": "phys", "power": 1.45, "elem": "fire", "brk": 2, "lvl": 1, "status": ["burn", 30, 3], "desc": "Fiery cut. May Burn."},
	"guard_stance": {"name": "Guard Stance", "mp": 6, "target": "self", "kind": "buff", "lvl": 2, "status": ["taunt", 100, 3], "status2": ["guard", 100, 3], "cost": 0.7, "desc": "Taunt foes and halve damage taken."},
	"runic_cleave": {"name": "Runic Cleave", "mp": 10, "target": "all_enemies", "kind": "phys", "power": 1.05, "elem": "fire", "brk": 2, "lvl": 5, "cost": 1.2, "desc": "Sweeping rune arc that hits every foe."},
	"bulwark": {"name": "Bulwark", "mp": 14, "target": "all_allies", "kind": "buff", "lvl": 9, "status": ["guard", 100, 2], "desc": "Whole party takes half damage."},
	"spark": {"name": "Spark", "mp": 4, "target": "enemy", "kind": "mag", "power": 1.5, "elem": "storm", "brk": 1, "lvl": 1, "status": ["shock", 25, 2], "desc": "Quick bolt. May Shock (slow)."},
	"chain_lightning": {"name": "Chain Lightning", "mp": 11, "target": "all_enemies", "kind": "mag", "power": 1.15, "elem": "storm", "brk": 1, "lvl": 3, "cost": 1.2, "desc": "Lightning arcs through all foes."},
	"gale_step": {"name": "Gale Step", "mp": 8, "target": "ally", "kind": "buff", "lvl": 5, "status": ["haste", 100, 3], "cost": 0.6, "desc": "Grant Haste: act far more often."},
	"tempest": {"name": "Tempest", "mp": 22, "target": "all_enemies", "kind": "mag", "power": 1.9, "elem": "storm", "brk": 3, "lvl": 10, "cost": 1.4, "desc": "A raging storm. Massive area damage."},
	"thorn_shot": {"name": "Thorn Shot", "mp": 4, "target": "enemy", "kind": "phys", "power": 1.3, "elem": "nature", "brk": 1, "lvl": 1, "status": ["poison", 60, 3], "desc": "Barbed arrow. Likely Poisons."},
	"regrowth": {"name": "Regrowth", "mp": 9, "target": "all_allies", "kind": "buff", "lvl": 2, "status": ["regen", 100, 3], "desc": "Party regenerates HP each turn."},
	"entangle": {"name": "Entangle", "mp": 8, "target": "enemy", "kind": "mag", "power": 0.8, "elem": "nature", "brk": 4, "lvl": 5, "status": ["slow", 80, 3], "desc": "Roots bind a foe. Heavy break, Slow."},
	"bramble_volley": {"name": "Bramble Volley", "mp": 15, "target": "all_enemies", "kind": "phys", "power": 1.25, "elem": "nature", "brk": 2, "lvl": 9, "status": ["poison", 35, 3], "cost": 1.2, "desc": "Rain of thorns over every foe."},
	"backstab": {"name": "Backstab", "mp": 5, "target": "enemy", "kind": "phys", "power": 1.6, "elem": "shadow", "brk": 1, "lvl": 1, "crit": 35, "desc": "Strike from shadow. +35% crit."},
	"venom_edge": {"name": "Venom Edge", "mp": 6, "target": "enemy", "kind": "phys", "power": 1.1, "elem": "nature", "brk": 1, "lvl": 2, "status": ["poison", 90, 4], "status2": ["weaken", 50, 3], "desc": "Toxic cut: Poison, may Weaken."},
	"smoke_veil": {"name": "Smoke Veil", "mp": 7, "target": "self", "kind": "buff", "lvl": 5, "status": ["evade", 100, 3], "cost": 0.5, "desc": "Vanish: dodge most attacks."},
	"shadow_flurry": {"name": "Shadow Flurry", "mp": 16, "target": "random_enemies", "hits": 5, "kind": "phys", "power": 0.6, "elem": "shadow", "brk": 1, "lvl": 9, "cost": 1.2, "desc": "Five blinding strikes at random foes."},
	"mend": {"name": "Mend", "mp": 5, "target": "ally", "kind": "heal", "power": 1.9, "lvl": 1, "desc": "Restore one ally's HP."},
	"radiant_smite": {"name": "Radiant Smite", "mp": 6, "target": "enemy", "kind": "mag", "power": 1.55, "elem": "light", "brk": 2, "lvl": 2, "desc": "Holy blow of light."},
	"sanctuary": {"name": "Sanctuary", "mp": 14, "target": "all_allies", "kind": "heal", "power": 1.25, "lvl": 5, "cleanse": true, "cost": 1.2, "desc": "Heal and cleanse the whole party."},
	"revive": {"name": "Dawnrise", "mp": 18, "target": "dead_ally", "kind": "heal", "power": 0.5, "lvl": 8, "revive": true, "desc": "Revive a fallen ally at 50% HP."},
	"cryo_bomb": {"name": "Cryo Bomb", "mp": 7, "target": "all_enemies", "kind": "mag", "power": 0.9, "elem": "ice", "brk": 1, "lvl": 1, "status": ["freeze", 20, 1], "cost": 1.1, "desc": "Frost blast on all foes. May Freeze."},
	"overclock": {"name": "Overclock", "mp": 10, "target": "all_allies", "kind": "buff", "lvl": 2, "status": ["atkup", 100, 3], "desc": "Party ATK and MAG +30%."},
	"shrapnel": {"name": "Shrapnel Burst", "mp": 9, "target": "enemy", "kind": "phys", "power": 1.35, "elem": "phys", "brk": 4, "lvl": 5, "desc": "Exploding scrap. Huge break damage."},
	"repair_drone": {"name": "Repair Drone", "mp": 9, "target": "ally", "kind": "heal", "power": 1.4, "lvl": 9, "status": ["guard", 100, 2], "desc": "Heal an ally and shield them."},
	"burst": {"name": "RUNE BURST", "mp": 0, "target": "all_enemies", "kind": "mag", "power": 2.4, "elem": "", "brk": 4, "lvl": 1, "desc": "Unleash the full combo gauge on every foe."},
	# --- enemy skills ---
	"e_bite": {"name": "Bite", "target": "enemy", "kind": "phys", "power": 1.0, "elem": "phys"},
	"e_slam": {"name": "Slam", "target": "enemy", "kind": "phys", "power": 1.35, "elem": "phys", "cost": 1.3},
	"e_spit": {"name": "Acid Spit", "target": "enemy", "kind": "mag", "power": 0.8, "elem": "nature", "status": ["poison", 60, 3]},
	"e_frost": {"name": "Frost Breath", "target": "all_enemies", "kind": "mag", "power": 0.7, "elem": "ice", "status": ["freeze", 15, 1], "cost": 1.3},
	"e_flame": {"name": "Flame Burst", "target": "enemy", "kind": "mag", "power": 1.3, "elem": "fire", "status": ["burn", 40, 3]},
	"e_inferno": {"name": "Inferno", "target": "all_enemies", "kind": "mag", "power": 0.85, "elem": "fire", "status": ["burn", 30, 3], "cost": 1.4},
	"e_shock": {"name": "Shock Lance", "target": "enemy", "kind": "mag", "power": 1.25, "elem": "storm", "status": ["shock", 40, 2]},
	"e_thunder": {"name": "Thunderclap", "target": "all_enemies", "kind": "mag", "power": 0.8, "elem": "storm", "cost": 1.3},
	"e_quake": {"name": "Quake", "target": "all_enemies", "kind": "phys", "power": 0.75, "elem": "phys", "cost": 1.4},
	"e_drain": {"name": "Soul Drain", "target": "enemy", "kind": "mag", "power": 1.1, "elem": "shadow", "drain": true},
	"e_curse": {"name": "Hex", "target": "enemy", "kind": "mag", "power": 0.6, "elem": "shadow", "status": ["weaken", 80, 3]},
	"e_roar": {"name": "War Cry", "target": "self", "kind": "buff", "status": ["atkup", 100, 3], "cost": 0.8},
	"e_void": {"name": "Void Collapse", "target": "all_enemies", "kind": "mag", "power": 1.05, "elem": "shadow", "status": ["weaken", 40, 2], "cost": 1.5},
	"e_heal": {"name": "Mend Self", "target": "self", "kind": "heal", "power": 2.2},
}

const STATUSES := {
	"poison": {"name": "Poison", "color": Color("8be04e"), "bad": true},
	"burn": {"name": "Burn", "color": Color("ff7a3d"), "bad": true},
	"freeze": {"name": "Freeze", "color": Color("7fd8ff"), "bad": true},
	"shock": {"name": "Shock", "color": Color("ffe45c"), "bad": true},
	"slow": {"name": "Slow", "color": Color("9aa0c0"), "bad": true},
	"weaken": {"name": "Weaken", "color": Color("c06080"), "bad": true},
	"guard": {"name": "Guard", "color": Color("8fb8ff"), "bad": false},
	"taunt": {"name": "Taunt", "color": Color("ff9f6b"), "bad": false},
	"haste": {"name": "Haste", "color": Color("6dffd2"), "bad": false},
	"regen": {"name": "Regen", "color": Color("9cff8f"), "bad": false},
	"evade": {"name": "Evade", "color": Color("c9b0ff"), "bad": false},
	"atkup": {"name": "Power", "color": Color("ffb35c"), "bad": false},
	"broken": {"name": "BREAK", "color": Color("ffffff"), "bad": true},
}

## shape: blob, beast, imp, wisp, golem, eye, bat, crab, knight, drake, engine, harpy, eel, tree, king
const ENEMIES := {
	"gel": {"name": "Moss Gel", "shape": "blob", "pal": ["5fbf5a", "2e6b34", "c7ff9e"], "hp": 52, "atk": 9, "mag": 7, "def": 4, "res": 3, "spd": 7, "weak": ["fire"], "resist": ["nature"], "tough": 3, "skills": ["e_bite", "e_spit"], "xp": 9, "gold": 7, "drops": [["iron_ore", 40], ["beast_hide", 25]]},
	"rat": {"name": "Bone Rat", "shape": "beast", "pal": ["b8a890", "5c4c3c", "ff5a5a"], "hp": 44, "atk": 11, "mag": 3, "def": 3, "res": 2, "spd": 12, "weak": ["light"], "resist": [], "tough": 2, "skills": ["e_bite", "e_bite", "e_slam"], "xp": 8, "gold": 6, "drops": [["beast_hide", 50]]},
	"imp": {"name": "Moss Imp", "shape": "imp", "pal": ["6d9a3c", "34502a", "ffd84a"], "hp": 48, "atk": 8, "mag": 11, "def": 4, "res": 6, "spd": 10, "weak": ["fire", "ice"], "resist": [], "tough": 3, "skills": ["e_bite", "e_flame", "e_curse"], "xp": 11, "gold": 9, "drops": [["runestone", 20], ["iron_ore", 30]]},
	"b_root": {"name": "Rotroot Colossus", "shape": "tree", "boss": true, "pal": ["7a5a3a", "3a2a1a", "9cff6a"], "hp": 420, "atk": 14, "mag": 12, "def": 8, "res": 6, "spd": 8, "weak": ["fire"], "resist": ["nature", "ice"], "tough": 8, "skills": ["e_slam", "e_quake", "e_spit", "e_heal"], "xp": 90, "gold": 120, "drops": [["runestone", 100], ["starsteel", 60]]},
	"wisp": {"name": "Frost Wisp", "shape": "wisp", "pal": ["a8ecff", "3a7aa8", "ffffff"], "hp": 70, "atk": 6, "mag": 18, "def": 5, "res": 14, "spd": 13, "weak": ["fire", "light"], "resist": ["ice"], "tough": 3, "skills": ["e_frost", "e_shock"], "xp": 18, "gold": 14, "drops": [["frost_crystal", 45]]},
	"golem": {"name": "Rime Golem", "shape": "golem", "pal": ["9ac8e0", "4a6a88", "dff6ff"], "hp": 140, "atk": 20, "mag": 6, "def": 16, "res": 6, "spd": 6, "weak": ["storm", "fire"], "resist": ["ice", "phys"], "tough": 5, "skills": ["e_slam", "e_quake"], "xp": 24, "gold": 18, "drops": [["iron_ore", 60], ["frost_crystal", 30]]},
	"wolf": {"name": "Rime Wolf", "shape": "beast", "pal": ["d8e8f0", "6a8098", "6dd8ff"], "hp": 90, "atk": 19, "mag": 5, "def": 7, "res": 6, "spd": 15, "weak": ["fire"], "resist": ["ice"], "tough": 3, "skills": ["e_bite", "e_bite", "e_frost"], "xp": 19, "gold": 13, "drops": [["beast_hide", 60]]},
	"b_glacier": {"name": "Glacial Warden", "shape": "knight", "boss": true, "pal": ["bfe6ff", "3d5f8a", "7fd8ff"], "hp": 820, "atk": 24, "mag": 22, "def": 16, "res": 14, "spd": 10, "weak": ["fire", "storm"], "resist": ["ice"], "tough": 10, "skills": ["e_slam", "e_frost", "e_roar", "e_frost"], "xp": 200, "gold": 260, "drops": [["frost_crystal", 100], ["starsteel", 80]]},
	"bat": {"name": "Cinder Bat", "shape": "bat", "pal": ["d0503a", "5a1e1e", "ffd04a"], "hp": 120, "atk": 26, "mag": 18, "def": 9, "res": 9, "spd": 17, "weak": ["ice"], "resist": ["fire"], "tough": 3, "skills": ["e_bite", "e_flame"], "xp": 30, "gold": 22, "drops": [["ember_core", 40], ["beast_hide", 30]]},
	"crab": {"name": "Magma Crab", "shape": "crab", "pal": ["e06a30", "6a2810", "ffcc5a"], "hp": 220, "atk": 30, "mag": 10, "def": 24, "res": 10, "spd": 7, "weak": ["ice", "storm"], "resist": ["fire", "phys"], "tough": 5, "skills": ["e_slam", "e_bite", "e_inferno"], "xp": 38, "gold": 28, "drops": [["iron_ore", 60], ["ember_core", 40]]},
	"cultist": {"name": "Ash Cultist", "shape": "imp", "pal": ["8a4a6a", "3a1a2a", "ff7a3d"], "hp": 140, "atk": 18, "mag": 30, "def": 10, "res": 18, "spd": 12, "weak": ["light", "ice"], "resist": ["shadow"], "tough": 3, "skills": ["e_flame", "e_inferno", "e_curse", "e_heal"], "xp": 36, "gold": 30, "drops": [["runestone", 40], ["ember_core", 30]]},
	"b_drake": {"name": "Forgeheart Drake", "shape": "drake", "boss": true, "pal": ["d8402a", "5a140e", "ffd04a"], "hp": 1500, "atk": 38, "mag": 36, "def": 22, "res": 18, "spd": 12, "weak": ["ice"], "resist": ["fire"], "tough": 12, "skills": ["e_slam", "e_inferno", "e_flame", "e_roar"], "xp": 380, "gold": 480, "drops": [["ember_core", 100], ["starsteel", 100]]},
	"eel": {"name": "Volt Eel", "shape": "eel", "pal": ["3ac8c0", "1a4a5a", "ffe45c"], "hp": 210, "atk": 30, "mag": 40, "def": 14, "res": 20, "spd": 18, "weak": ["nature"], "resist": ["storm"], "tough": 3, "skills": ["e_shock", "e_thunder", "e_bite"], "xp": 55, "gold": 38, "drops": [["storm_coil", 45]]},
	"sentry": {"name": "Clockwork Sentry", "shape": "golem", "pal": ["c8a050", "5a4420", "6dffd2"], "hp": 330, "atk": 42, "mag": 20, "def": 30, "res": 14, "spd": 9, "weak": ["storm", "nature"], "resist": ["phys"], "tough": 6, "skills": ["e_slam", "e_quake", "e_shock"], "xp": 62, "gold": 45, "drops": [["iron_ore", 60], ["storm_coil", 40]]},
	"harpy": {"name": "Tempest Harpy", "shape": "harpy", "pal": ["8ab0e0", "34446a", "ffe45c"], "hp": 230, "atk": 38, "mag": 32, "def": 14, "res": 16, "spd": 20, "weak": ["ice", "phys"], "resist": ["storm", "nature"], "tough": 3, "skills": ["e_bite", "e_thunder", "e_shock"], "xp": 58, "gold": 40, "drops": [["beast_hide", 50], ["storm_coil", 35]]},
	"b_engine": {"name": "The Thunder Engine", "shape": "engine", "boss": true, "pal": ["c89a40", "4a3418", "6dd8ff"], "hp": 2600, "atk": 52, "mag": 52, "def": 32, "res": 26, "spd": 13, "weak": ["nature", "ice"], "resist": ["storm", "phys"], "tough": 14, "skills": ["e_thunder", "e_shock", "e_quake", "e_roar"], "xp": 620, "gold": 760, "drops": [["storm_coil", 100], ["starsteel", 100]]},
	"shade": {"name": "Shade", "shape": "wisp", "pal": ["7a5ab8", "2a1a4a", "ff5aa8"], "hp": 300, "atk": 30, "mag": 58, "def": 16, "res": 30, "spd": 19, "weak": ["light"], "resist": ["shadow", "phys"], "tough": 3, "skills": ["e_drain", "e_curse", "e_void"], "xp": 85, "gold": 55, "drops": [["void_shard", 45]]},
	"vknight": {"name": "Void Knight", "shape": "knight", "pal": ["4a3a6a", "1a1028", "c47bff"], "hp": 520, "atk": 62, "mag": 30, "def": 38, "res": 22, "spd": 12, "weak": ["light", "storm"], "resist": ["shadow"], "tough": 6, "skills": ["e_slam", "e_slam", "e_drain", "e_roar"], "xp": 100, "gold": 70, "drops": [["iron_ore", 50], ["void_shard", 40]]},
	"eye": {"name": "Eye Stalker", "shape": "eye", "pal": ["d8c8e8", "6a2a6a", "ff3a5a"], "hp": 380, "atk": 36, "mag": 60, "def": 20, "res": 28, "spd": 16, "weak": ["light", "fire"], "resist": [], "tough": 4, "skills": ["e_curse", "e_drain", "e_shock"], "xp": 95, "gold": 64, "drops": [["runestone", 50], ["void_shard", 40]]},
	"b_regent": {"name": "The Umbral Regent", "shape": "king", "boss": true, "pal": ["3a2a5a", "120a20", "ffd36b"], "hp": 4400, "atk": 70, "mag": 74, "def": 38, "res": 36, "spd": 15, "weak": ["light"], "resist": ["shadow"], "tough": 16, "skills": ["e_void", "e_drain", "e_slam", "e_curse", "e_roar"], "xp": 1200, "gold": 1500, "drops": [["void_shard", 100], ["starsteel", 100]]},
}

const FLOORS := [
	{"name": "Mossy Catacombs", "enemies": ["gel", "rat", "imp"], "boss": "b_root", "mat": "beast_hide", "lvl": 1,
		"pal": {"floor": "3a3a2e", "floor2": "424234", "wall": "5c6a3e", "wall2": "2a3020", "accent": "8ad46a"}},
	{"name": "Frostbound Halls", "enemies": ["wisp", "golem", "wolf"], "boss": "b_glacier", "mat": "frost_crystal", "lvl": 2,
		"pal": {"floor": "2e3a48", "floor2": "344456", "wall": "7aa8c8", "wall2": "2a3a52", "accent": "bfe6ff"}},
	{"name": "Ember Forge-Depths", "enemies": ["bat", "crab", "cultist"], "boss": "b_drake", "mat": "ember_core", "lvl": 3,
		"pal": {"floor": "3a2622", "floor2": "442c26", "wall": "8a3a22", "wall2": "3a160e", "accent": "ff9a3a"}},
	{"name": "Storm Spire Vault", "enemies": ["eel", "sentry", "harpy"], "boss": "b_engine", "mat": "storm_coil", "lvl": 4,
		"pal": {"floor": "26303a", "floor2": "2c3844", "wall": "5a6a8a", "wall2": "1e2638", "accent": "ffe45c"}},
	{"name": "Umbral Sanctum", "enemies": ["shade", "vknight", "eye"], "boss": "b_regent", "mat": "void_shard", "lvl": 5,
		"pal": {"floor": "221a30", "floor2": "281e38", "wall": "4a3a6a", "wall2": "140c20", "accent": "c47bff"}},
]

const MATERIALS := {
	"iron_ore": {"name": "Iron Ore", "color": Color("a8a8b8"), "price": 12},
	"beast_hide": {"name": "Beast Hide", "color": Color("b07a4a"), "price": 10},
	"runestone": {"name": "Runestone Shard", "color": Color("8a7aff"), "price": 30},
	"frost_crystal": {"name": "Frost Crystal", "color": Color("7fd8ff"), "price": 25},
	"ember_core": {"name": "Ember Core", "color": Color("ff7a3d"), "price": 35},
	"storm_coil": {"name": "Storm Coil", "color": Color("ffe45c"), "price": 45},
	"void_shard": {"name": "Void Shard", "color": Color("c47bff"), "price": 60},
	"starsteel": {"name": "Starsteel Ingot", "color": Color("fff3b0"), "price": 120},
}
const MAT_ORDER := ["iron_ore", "beast_hide", "runestone", "frost_crystal", "ember_core", "storm_coil", "void_shard", "starsteel"]

const ITEMS := {
	"tonic": {"name": "Tonic", "price": 25, "desc": "Restore 35% HP +30 to one ally.", "target": "ally", "heal_pct": 0.35, "heal": 30},
	"hi_tonic": {"name": "Hi-Tonic", "price": 90, "desc": "Restore 75% HP to one ally.", "target": "ally", "heal_pct": 0.75, "heal": 0},
	"ether": {"name": "Ether", "price": 60, "desc": "Restore 30 MP to one ally.", "target": "ally", "mp": 30},
	"ember_feather": {"name": "Ember Feather", "price": 150, "desc": "Revive a fallen ally at 40% HP.", "target": "dead_ally", "revive": 0.4},
	"clearwater": {"name": "Clearwater", "price": 30, "desc": "Cure all ailments of one ally.", "target": "ally", "cleanse": true},
	"smoke_bomb": {"name": "Smoke Bomb", "price": 40, "desc": "Escape any non-boss battle.", "target": "none", "escape": true},
}
const ITEM_ORDER := ["tonic", "hi_tonic", "ether", "ember_feather", "clearwater", "smoke_bomb"]

const RUNES := {
	"fire_rune": {"name": "Ember Rune", "elem": "fire", "stat": "mag", "val": 4, "desc": "Attacks deal Fire. +4 MAG", "price": 120},
	"frost_rune": {"name": "Frost Rune", "elem": "ice", "stat": "mag", "val": 4, "desc": "Attacks deal Ice. +4 MAG", "price": 120},
	"storm_rune": {"name": "Storm Rune", "elem": "storm", "stat": "mag", "val": 4, "desc": "Attacks deal Storm. +4 MAG", "price": 120},
	"thorn_rune": {"name": "Thorn Rune", "elem": "nature", "stat": "atk", "val": 4, "desc": "Attacks deal Nature. +4 ATK", "price": 120},
	"lumen_rune": {"name": "Lumen Rune", "elem": "light", "stat": "res", "val": 5, "desc": "Attacks deal Light. +5 RES", "price": 160},
	"umbra_rune": {"name": "Umbra Rune", "elem": "shadow", "stat": "crit", "val": 5, "desc": "Attacks deal Shadow. +5% crit", "price": 160},
	"vigor_rune": {"name": "Vigor Rune", "elem": "", "stat": "hp", "val": 40, "desc": "+40 max HP", "price": 100},
	"swift_rune": {"name": "Swift Rune", "elem": "", "stat": "spd", "val": 3, "desc": "+3 SPD", "price": 140},
	"keen_rune": {"name": "Keen Rune", "elem": "", "stat": "crit", "val": 8, "desc": "+8% critical chance", "price": 140},
	"leech_rune": {"name": "Leech Rune", "elem": "", "stat": "leech", "val": 6, "desc": "Heal 6% of damage dealt", "price": 180},
}
const RUNE_ORDER := ["fire_rune", "frost_rune", "storm_rune", "thorn_rune", "lumen_rune", "umbra_rune", "vigor_rune", "swift_rune", "keen_rune", "leech_rune"]

## Weapon affixes. "pre" forms the prefix, "suf" the suffix. val range scales with tier.
const AFFIXES := {
	"atk_pct": {"pre": "Mighty", "suf": "of Might", "fmt": "+%d%% ATK", "min": 5, "max": 12},
	"mag_pct": {"pre": "Arcane", "suf": "of Sorcery", "fmt": "+%d%% MAG", "min": 5, "max": 12},
	"spd": {"pre": "Swift", "suf": "of the Hare", "fmt": "+%d SPD", "min": 1, "max": 3},
	"crit": {"pre": "Keen", "suf": "of Precision", "fmt": "+%d%% crit", "min": 3, "max": 8},
	"hp": {"pre": "Sturdy", "suf": "of the Bear", "fmt": "+%d max HP", "min": 15, "max": 40},
	"leech": {"pre": "Vampiric", "suf": "of Thirst", "fmt": "%d%% lifesteal", "min": 2, "max": 6},
	"breaker": {"pre": "Shattering", "suf": "of Ruin", "fmt": "+%d break power", "min": 1, "max": 1},
	"mp": {"pre": "Sage", "suf": "of Wisdom", "fmt": "+%d max MP", "min": 8, "max": 20},
	"def": {"pre": "Warded", "suf": "of Bastions", "fmt": "+%d DEF", "min": 2, "max": 6},
}
const AFFIX_ORDER := ["atk_pct", "mag_pct", "spd", "crit", "hp", "leech", "breaker", "mp", "def"]

## Forge recipes: materials + gold. "q" shifts rarity odds.
const RECIPES := [
	{"id": "standard", "name": "Standard Forge", "gold": 60, "mats": {"iron_ore": 3, "beast_hide": 1}, "q": 0},
	{"id": "fine", "name": "Fine Forge", "gold": 180, "mats": {"iron_ore": 4, "runestone": 2, "floor_mat": 2}, "q": 1},
	{"id": "master", "name": "Masterwork", "gold": 450, "mats": {"iron_ore": 5, "runestone": 3, "starsteel": 1}, "q": 2},
]
