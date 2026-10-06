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

### 3.1 Inventory (D-019)
```json
{
  "rods": ["rod_bamboo"], "equipped_rod": "rod_bamboo",
  "baits": ["bait_bread", "bait_worm"], "equipped_bait": "bait_bread",
  "bait_counts": {"bait_worm": 6},
  "bags": ["bag_basic"], "equipped_bag": "bag_basic",
  "accessories": ["acc_straw_hat"], "equipped_accessory": "acc_straw_hat"
}
```
- `bait_counts`: 개수가 있는 미끼의 재고(정수 0..9999). 끝없는 미끼(`consumable: false`)는 세지 않는다.
- 가방 칸(장착한 가방의 `capacity`)을 넘는 재고는 서비스가 막는다. 세이브 자체는 숫자만 검사한다.
- 이 필드가 없는 예전 세이브(v1)는 불러올 때 시작 가방·모자를 받고, 가진 미끼는 시작 재고를 받는다
  (세이브 v2, 1 → 2 마이그레이션이 표시를 남긴다 — D-019).

## 4. Collection Record
```json
{
  "encounters": 0,
  "releases": 0,
  "largest_cm": 0.0,
  "smallest_cm": 0.0,
  "first_seen_at": 0,
  "last_seen_at": 0,
  "observed_behaviors": [],
  "first_weather": "",
  "journal_seen": false
}
```

- `first_weather`: 처음 만난 날의 날씨 id (도감 "발견한 날의 날씨"). 이 필드 이전의 세이브는 `""`(기록 없음).
- `journal_seen`: 처음 만난 뒤 도감에서 그 종의 페이지를 봤는지 (NEW 표시와 알림 점, D-018).
  새 발견은 `false`로 시작하고, 이 필드가 없는 예전 기록은 `true`로 읽는다(이미 본 것으로 취급).
- 두 필드 모두 로드할 때 기본값으로 채워지는 추가 필드다(D-007).

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

## 5.1 Equipment Content (D-019)
- `rods.json`: `grade` (common | uncommon | rare | event), `line_strength` 0..1(내구도), `desc_key`,
  선택 `price` {currency: ripple | memory, amount}, `unlock` {region, restoration_level}, event는 `granted_by` (가격 없음)
- `baits.json`: `consumable` false = 끝없는 미끼, `desc_key`, 선택 `price`(한 묶음 가격) · `unlock`
- `equipment.json`: `bags` [{id `bag_*`, name_key, desc_key, capacity, color, price?, unlock?}],
  `accessories` [{id `acc_*`, name_key, desc_key, hat, band (색), price?, unlock?}]
- `balance.json`: `starting_inventory`에 bags·accessories·equipped_*·bait_counts, `equipment.bait_pack_size`
- 시작 미끼에는 끝없는 미끼가 하나 이상 있어야 하고, 시작 재고는 시작 가방에 들어가야 한다(검증기가 강제)

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
