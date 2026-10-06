# 04. Data & Save Schema

## 1. ID Convention
- fish: `fish_<snake_case>`
- region: `region_<nn>_<name>`
- rod: `rod_<snake_case>`
- bait: `bait_<snake_case>`
- animal: `animal_<snake_case>`

ID는 출시 후 변경하지 않는다. 표시명은 localization key로 분리.

## 2. FishDefinition
```json
{
  "id": "fish_crucian_carp",
  "name_key": "fish.crucian_carp.name",
  "regions": ["region_01_quiet_pond"],
  "habitats": ["shallow", "vegetation"],
  "rarity": 1,
  "base_weight": 10.0,
  "size_cm": {"min": 8, "max": 38},
  "time_bands": {"dawn": 1.1, "day": 1.0, "dusk": 1.2, "night": 0.8},
  "weather": {"clear": 1.0, "cloudy": 1.1, "rain": 1.15},
  "bait_tags": ["bread", "worm"],
  "behavior": "steady",
  "fight": {"strength": 0.25, "duration_sec": 5.0},
  "journal_key": "fish.crucian_carp.desc"
}
```

## 3. PlayerSave
```json
{
  "save_version": 1,
  "profile": {
    "created_at": 0,
    "last_session_at": 0
  },
  "economy": {
    "ripple": 0,
    "memory": 0
  },
  "regions": {},
  "collection": {},
  "inventory": {},
  "settings": {},
  "entitlement_cache": {}
}
```

## 4. Collection Record
```json
{
  "encounters": 0,
  "releases": 0,
  "largest_cm": 0.0,
  "smallest_cm": 0.0,
  "first_seen_at": 0,
  "last_seen_at": 0,
  "observed_behaviors": []
}
```

## 5. Region State
```json
{
  "restoration_level": 0,
  "restoration_points": 0,
  "species_population": {},
  "unlocked_spots": [],
  "seen_events": []
}
```

## 6. Migration Rules
- migration은 한 버전씩 순서대로 수행
- migration 전에 backup
- unknown field는 가능한 보존
- missing field는 default 주입
- content ID 삭제가 필요한 경우 alias map 유지

## 7. Content Validation
빌드 전 검사:
- duplicate ID
- region reference
- rarity 1..5
- min/max size
- weight > 0
- referenced rod/bait/behavior
- localization key presence
