# TASKS — Production Backlog

## P0 — Vertical Slice Foundation
- [x] P0-001 Godot project bootstrap, folders, autoload registration
  - EntitlementService autoload는 P1-011에서 등록 (TECH_SPEC §2 목록 중 유일한 미등록 항목)
- [x] P0-002 ContentDB JSON loader + validation errors
  - 런타임 검증: `godot/content/content_validator.gd` (DATA_SCHEMA §7). 로컬라이제이션 키 존재는 `tests/unit/test_localization_keys.gd`
  - behavior 값은 정의 목록이 아직 없어 비어 있지 않은 문자열만 검사 → P0-015(fight)에서 behavior 정의 시 참조 검사 추가
- [x] P0-003 EventBus typed event conventions
  - 규약은 D-006, 자동 검사는 `tests/unit/test_event_bus.gd`
- [x] P0-004 GameState domain model
  - 저장 형식 단일 출처 `godot/save/save_schema.gd`, 규칙은 D-007. 시작 인벤토리·슬라이스 범위는 `data/balance.json`
- [x] P0-005 SaveService atomic write + backup + load
  - 정책은 D-008, 테스트 `tests/unit/test_save_service.gd`
- [x] P0-006 Save v1 migration framework
  - `save/save_migrator.gd` (운영 마이그레이션 테이블은 v1만 있어 비어 있음), id alias는 `data/content_aliases.json`
- [x] P0-007 TimeService session/game/offline clock
  - 정책은 D-009, 하루 길이·시간대 경계는 `data/balance.json`의 `time`
- [ ] P0-008 Region 01 base scene
- [ ] P0-009 Habitat zone component
- [ ] P0-010 EncounterResolver seeded weighted random
- [ ] P0-011 Fishing state machine
- [ ] P0-012 cast input
- [ ] P0-013 bite timing + feedback hooks
- [ ] P0-014 hook timing + relaxed/auto hook
- [ ] P0-015 fight tension simulation
- [ ] P0-016 catch inspect/release flow
- [ ] P0-017 collection journal state
- [ ] P0-018 region population state
- [ ] P0-019 visible fish presenter + pool
- [ ] P0-020 restoration levels 0~5
- [ ] P0-021 weather clear/cloudy/rain
- [ ] P0-022 ambient audio layering
- [ ] P0-023 water-mind mode
- [ ] P0-024 settings/accessibility baseline
- [ ] P0-025 debug menu
- [ ] P0-026 automated content validation
  - `tools/validate_content.py`(Python)와 ContentValidator(GDScript) 규칙이 중복됨 → 단일 출처로 정리
- [x] P0-027 save roundtrip/migration tests
  - 라운드트립·3세대 백업·손상/절단 복구·중단된 tmp·정지/종료 저장·신버전 보호·마이그레이션 전 백업: `test_save_service.gd`, `test_save_migrator.gd`, `test_save_schema.gd`
- [ ] P0-028 Android/Windows vertical slice builds

## P1 — Production Systems
- [ ] P1-001 full 10 restoration levels
- [ ] P1-002 camp system
- [ ] P1-003 equipment/rod system
- [ ] P1-004 bait system
- [ ] P1-005 5 time bands
- [ ] P1-006 6 weather types
- [ ] P1-007 offline aggregate simulation
- [ ] P1-008 moment/ambient event journal
- [ ] P1-009 photo mode
- [ ] P1-010 map/region unlock
  - `progression.json`의 `unique_fish`는 "선행 지역에서 발견한 종 수"로 해석 (ContentValidator가 그 지역 서식 종 수 이하를 강제)
- [ ] P1-011 entitlement service abstraction
- [ ] P1-012 full-game unlock UI
- [ ] P1-013 KO/EN/JA localization
- [ ] P1-014 graphics quality profiles
- [ ] P1-015 battery saver

## P2 — Content Expansion
- [ ] P2-001 Region 02 production
- [ ] P2-002 Region 03 production
- [ ] P2-003 Region 04 production
- [ ] P2-004 Region 05 production
- [ ] P2-005 Fish catalog 72
- [ ] P2-006 Rare variants 18
- [ ] P2-007 Ambient animals 24
- [ ] P2-008 Decorations 60+
- [ ] P2-009 Rods 12 / Baits 16
- [ ] P2-010 BGM/Ambience production

## P3 — Productization
- [ ] P3-001 purchase integration Android
- [ ] P3-002 purchase integration Windows/Steam strategy
- [ ] P3-003 purchase restore tests
- [ ] P3-004 privacy/legal pages
- [ ] P3-005 device test pass
- [ ] P3-006 soak/performance pass
- [ ] P3-007 localization QA
- [ ] P3-008 accessibility QA
- [ ] P3-009 store assets/listing
- [ ] P3-010 closed external playtest
- [ ] P3-011 release candidate
