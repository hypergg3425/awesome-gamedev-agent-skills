class_name MapZoom
extends RefCounted
## Zoom-level detail policy of the campaign map. One place decides which layers are visible at which camera zoom so the
## renderer, the overlay and the tests agree. Zoom is the MapView zoom (screen px per world unit).
##   LOW  (strategic):   countries, capitals and major cities, fronts, sea names
##   MID  (operational): provinces, armies, towns, ports, big rivers
##   HIGH (tactical):    terrain relief marks, all rivers, passes, roads / forts / ports, small settlements, tactical info

const LOW := 0
const MID := 1
const HIGH := 2

const MID_ZOOM := 1.25
const HIGH_ZOOM := 3.0
const COUNTRY_LABEL_MAX := 2.3       # country names fade out above this zoom, province names appear
const PROVINCE_LABEL_MIN := 2.3
const SEA_LABEL_MAX := 3.0
const RIVER_BIG_MIN := 1.0           # width-3 rivers
const RIVER_ALL_MIN := 2.6           # every river
const PASS_MIN := 3.0
const RELIEF_MIN := 2.2              # terrain relief marks (mountain / forest glyphs)
const ARMY_MIN := 0.0

static func tier(z: float) -> int:
	if z >= HIGH_ZOOM:
		return HIGH
	if z >= MID_ZOOM:
		return MID
	return LOW

## Minimum city rank drawn at this zoom (rank 3 capital, 2 major city, 1 town, 0 village).
static func min_city_rank(z: float) -> int:
	match tier(z):
		LOW:
			return 2
		MID:
			return 1
		_:
			return 0

static func show_ports(z: float) -> bool:
	return z >= MID_ZOOM

static func show_forts(z: float) -> bool:
	return z >= MID_ZOOM

static func show_roads(z: float) -> bool:
	return z >= HIGH_ZOOM

static func show_rivers(z: float, width: int) -> bool:
	return z >= (RIVER_BIG_MIN if width >= 3 else (RIVER_BIG_MIN * 1.8 if width == 2 else RIVER_ALL_MIN))

static func show_passes(z: float) -> bool:
	return z >= PASS_MIN

static func show_relief(z: float) -> bool:
	return z >= RELIEF_MIN

## Screen-space size multiplier for markers: grows gently with zoom, clamped so touch targets stay readable.
static func marker_scale(z: float) -> float:
	return clampf(0.8 + 0.18 * log(maxf(z, 0.1)) / log(2.0), 0.75, 1.5)
