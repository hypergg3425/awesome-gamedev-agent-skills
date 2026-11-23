class_name Const
extends RefCounted
## Global constants and enumerations for IMPERIUM. No mutable state lives here.

const VERSION := "0.9.0"
const SAVE_VERSION := 3
const MONTHS_PER_TURN := 3
const MAX_PROVINCE_ID_LEN := 48

const RESOURCES: Array[String] = ["gold", "food", "manpower", "iron", "wood", "stone", "coal", "lux"]
const MATERIALS: Array[String] = ["iron", "wood", "stone", "coal", "lux"]
const CLASSES: Array[String] = ["nobility", "merchants", "peasants", "clergy", "artisans", "military"]
const BRANCHES: Array[String] = ["military", "economic", "administration", "society"]
const TERRAINS: Array[String] = ["plains", "hills", "mountains", "forest", "desert", "jungle", "marsh", "steppe", "arctic"]

## movement cost per terrain (entering a province)
const TERRAIN_MOVE := {"plains": 1.0, "steppe": 1.0, "forest": 1.5, "hills": 1.5, "marsh": 2.0, "mountains": 2.0,
	"desert": 2.0, "jungle": 2.0, "arctic": 2.0}
## defender bonus per terrain
const TERRAIN_DEF := {"plains": 0.0, "steppe": 0.0, "forest": 0.10, "hills": 0.15, "marsh": 0.05, "mountains": 0.30,
	"desert": 0.0, "jungle": 0.10, "arctic": 0.05}
## cavalry effectiveness per terrain
const TERRAIN_CAV := {"plains": 1.0, "steppe": 1.15, "forest": 0.7, "hills": 0.8, "marsh": 0.6, "mountains": 0.5,
	"desert": 0.9, "jungle": 0.6, "arctic": 0.75}
## artillery effectiveness per terrain
const TERRAIN_ART := {"plains": 1.0, "steppe": 1.0, "forest": 0.8, "hills": 0.9, "marsh": 0.7, "mountains": 0.6,
	"desert": 0.9, "jungle": 0.7, "arctic": 0.8}
## base food a regiment can forage per turn from this terrain when in enemy land
const TERRAIN_FORAGE := {"plains": 1.2, "steppe": 0.9, "forest": 0.8, "hills": 0.7, "marsh": 0.5, "mountains": 0.4,
	"desert": 0.2, "jungle": 0.5, "arctic": 0.2}

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]

const MAP_MODES: Array[String] = ["political", "terrain", "economic", "diplomatic", "military", "population", "supply", "trade"]

const GOV_IDS: Array[String] = ["absolute_monarchy", "constitutional_monarchy", "republic", "merchant_republic",
	"empire", "tribal_confederation", "theocracy", "feudal_kingdom", "military_government"]

const PERSONALITIES: Array[String] = ["aggressive", "defensive", "expansionist", "diplomatic", "economic",
	"opportunistic", "isolationist", "naval_trade", "coalition_builder"]

const DIFFICULTIES: Array[String] = ["easy", "normal", "hard", "expert"]

const RELIGIONS: Array[String] = ["catholic", "orthodox", "protestant", "sunni", "shia", "jewish", "buddhist",
	"hindu", "eastern_faiths", "pagan", "animist", "tengri", "shinto", "secular"]

## opinion scale
const OPINION_MIN := -200
const OPINION_MAX := 200

const ARMY_SIZE_CAP := 30 ## regiments per army stack cap (soft: combat width)
const BASE_COMBAT_WIDTH := 14.0 ## regiments that fight at full effect per side

## Highest technology level any country may start a scenario with (max level is 4).
const START_TECH_CAP := 3
