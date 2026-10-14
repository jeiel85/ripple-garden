# 10. AI Coding Agent Guide

이 문서를 Claude Code / Codex / OpenCode 등 구현 에이전트의 최상위 컨텍스트로 사용한다.

## 1. Mission
Godot 4.x 기반 `Ripple Garden`을 상용 품질로 구현한다.
MVP 데모가 아니라 저장 안정성·테스트·성능·접근성을 포함한다.

## 2. Source of Truth Priority
1. `docs/01_GDD.md`
2. `docs/02_TECH_SPEC.md`
3. `docs/04_DATA_SCHEMA.md`
4. `docs/03_UI_UX_SPEC.md`
5. `docs/05_BALANCE_SPEC.md`
6. `TASKS.md`

충돌 시 상위 문서가 우선. 임의로 게임 방향을 바꾸지 않는다.

## 3. Engineering Rules
- Godot 4.x 문법 사용. 엔진 API(클래스·메서드·속성·시그널·기본값)는 기억에 기대지 말고 **설치된 엔진과 같은 버전의 클래스
  레퍼런스**에서 확인한다(학습 데이터의 Godot 3 문법·사라진 API를 막기 위해). 레퍼런스는 저장소 밖에 둔다:
  `git clone --depth 1 --filter=blob:none --sparse --branch <엔진 버전>-stable https://github.com/godotengine/godot.git <경로>` 뒤
  `git sparse-checkout set --no-cone '/doc/classes/' '/modules/*/doc_classes/' '/platform/*/doc_classes/'` (Git Bash에서는 `MSYS_NO_PATHCONV=1`을 붙인다. 약 12MB, 클래스당 XML 하나 —
  예: `doc/classes/Label.xml`을 grep). 엔진 버전을 올리면 새 태그로 다시 받는다. 이 PC의 위치는 `D:\Tools\Godot\godot-4.7.2-docs`.
- static content는 data-driven.
- UI에서 save/state 직접 수정 금지.
- scene tree node를 영속 DB처럼 사용 금지.
- 모든 새 save field는 migration/default 고려.
- public API/데이터 ID rename 시 migration/alias 없이 변경 금지.
- 성능 민감 객체는 pool 고려.
- 프레임마다 전체 fish catalog scan 금지.
- `_process` 남용 금지.

## 4. Feature Completion Rule
기능 하나를 완료할 때:
1. 구현
2. error handling
3. save implications
4. accessibility implications
5. automated test 가능 부분
6. debug hooks
7. documentation update
를 같이 수행한다.

## 5. Vertical Slice First
P0 목표:
- region 01
- fish 10
- rod 2
- bait 4
- weather 3
- restoration 5
- journal
- save
- fishing loop
- ambient population
- water-mind

5개 region을 동시에 만들지 않는다.

## 6. Commit Units
가능하면 한 commit/PR에 하나의 vertical behavior.
예:
`feat(fishing): implement deterministic encounter resolver`

## 7. Do Not Add
- login
- analytics
- ads
- backend
- PvP
- gacha
- battle pass
- daily streak
- arbitrary currencies
요구 문서 변경 없이는 추가 금지.

## 8. Test Before Claiming Done
실행/테스트하지 못했으면 "검증 완료"라고 쓰지 않는다.
Godot CLI가 없으면 코드 리뷰 수준 검증이라고 명시한다.

## 9. Debug Interface
QA build에서:
- set time
- set weather
- spawn fish
- set restoration
- grant currency
- simulate offline
- corrupt save copy
를 지원한다.

## 10. Recommended First Prompt
> README.md와 docs/10_AI_AGENT_GUIDE.md를 먼저 읽고, TASKS.md의 P0-001부터 순서대로 구현하라. 각 작업 전에 관련 설계 문서를 확인하고, 변경 후 테스트 가능한 부분을 실행하라. 기존 데이터 ID와 save 호환성을 깨뜨리지 마라.
