# Decisions

되돌리기 어렵거나 이후 작업 전체에 영향을 주는 기술 결정을 기록합니다.

## D-001 엔진 버전: Godot 4.7.2 (2026-10-06, P0-001)

- 설계 문서는 "Godot 4.x"만 지정. 로컬 개발 환경과 CI를 `4.7.2-stable`로 고정한다.
- 이유: export template·CI 다운로드·`.uid` 파일 형식을 한 버전에 맞춰야 재현 가능한 빌드가 된다.
  4.5+의 `Logger` API를 테스트 러너가 사용한다.
- 업그레이드 시 `project.godot`의 `config/features`, `ci.yml`의 `GODOT_VERSION`, README를 함께 바꾼다.

## D-002 테스트 프레임워크: 자체 최소 러너 (2026-10-06, P0-001)

- 대안: GUT 애드온 vendoring, gdUnit4.
- 선택: `godot/tests/run_tests.gd` (SceneTree 스크립트) + `TestCase` 베이스 클래스.
- 이유: 외부 애드온 수천 개 파일을 들이지 않고 headless CI에서 종료 코드로 판정할 수 있다.
  GDScript 런타임 에러는 예외로 전파되지 않으므로, `OS.add_logger()`로 테스트 중 발생한
  엔진 에러를 수집해 실패로 처리한다(경고는 실패로 보지 않음).
- 재검토 조건: mock/파라미터화/비동기 대기 같은 기능이 반복적으로 필요해지면 GUT/gdUnit4로 이전한다.

## D-003 코드 스타일과 줄바꿈 (2026-10-06, P0-001)

- GDScript 들여쓰기는 탭(Godot 편집기 기본값, 저장 시 자동 변환과 충돌하지 않도록).
- 모든 텍스트 파일은 LF로 정규화(`.gitattributes`). CI가 Linux에서 실행된다.

## D-004 Windows 빌드 설정 (2026-10-06, P0-001)

- PCK를 실행 파일에 내장(`embed_pck=true`)해 단일 exe로 배포한다.
- `application/modify_resources=false`: rcedit 의존을 두지 않는다. 따라서 exe 아이콘·버전 리소스는
  아직 Godot 기본값이다. 정식 아이콘이 생기면 CI에 rcedit을 추가하고 켠다.
- `tests/*`는 export에서 제외한다.

## D-005 콘텐츠 검증 실패 처리: 항목 단위 제외 + 오류 기록 (2026-10-06, P0-002)

- 대안: (a) 하나라도 오류면 전체 로드 실패, (b) 경고만 남기고 그대로 사용.
- 선택: 오류가 있는 항목만 제외하고 나머지는 사용. 모든 오류는 `push_error`(로컬 로그)와
  `ContentDB.errors`에 남긴다. 참조 대상이 제외되면 참조하는 쪽도 연쇄 제외된다(예: 잘못된 지역 → 그 지역 어종).
- 이유: (b)는 잘못된 정의가 런타임 크래시로 이어지고, (a)는 출시 빌드에서 사소한 데이터 실수 하나로
  게임 전체가 막힌다. 출시 전 오류 0건은 CI 테스트(`test_shipped_content_is_valid`)가 강제한다.

## D-006 EventBus 규약: 타입이 있는 사실 이벤트 (2026-10-06, P0-003)

- 대안: Dictionary payload 이벤트(유연), 이벤트별 payload 클래스(`class FishCaught`).
- 선택: 모든 시그널 파라미터에 명시 타입을 강제하고, Dictionary payload와 untyped 파라미터를 금지한다.
  이름은 이미 일어난 사실(`fish_caught`) 또는 `*_changed`이며 명령형은 시그널이 아니라 서비스 메서드다.
  콘텐츠는 문자열 id로만 참조한다. `tests/unit/test_event_bus.gd`가 이를 자동 검사한다.
- 이유: payload 모양이 바뀌면 호출부가 런타임이 아니라 파싱 시점에 깨진다. 클래스형 payload는
  현재 이벤트 수에서는 보일러플레이트가 이득보다 크다. 재검토 조건: 한 이벤트가 파라미터 5개를 넘기면 payload 클래스로 전환.
- 프레임 단위 데이터(장력, 물고기 위치)는 버스를 거치지 않는다. 소유자가 자기 시그널을 그 View에만 노출한다.

## D-007 세이브 v1: JSON + 로드 시 정규화 (2026-10-06, P0-004)

- JSON(디버깅 가능)으로 고정하고 Variant binary와 혼용하지 않는다(TECH_SPEC §4).
- Godot JSON은 모든 숫자를 float로 파싱한다(`1 != 1.0`). 따라서 `SaveSchema.normalize()`가 로드 직후
  정수 필드를 int로 되돌리고, 누락 필드에 기본값을 넣으며, 알 수 없는 필드는 보존한다. 라운드트립 동등성은 이 정규화에 의존한다.
- 저장 형식의 단일 출처는 `save/save_schema.gd`(기본값·정규화·정합성 검사). `GameState`는 그 위의 타입 있는 변경 API다.
- `session.pending_catch`: 낚았지만 아직 방생하지 않은 물고기를 저장해, INSPECT 중 강제 종료돼도 다음 실행에서 이어 처리한다.

## D-008 세이브 트랜잭션·복구·마이그레이션 정책 (2026-10-06, P0-005/006)

- 쓰기: 스냅샷 → 정합성 검사 → `save.tmp` 쓰기 + flush → 파일 길이·재읽기 검증 → 백업 회전 → tmp를 primary로 rename.
  어느 단계가 실패해도 기존 primary·백업은 그대로이며 `save_failed`가 발행된다. 잘못된 상태는 절대 쓰지 않는다.
- 백업은 primary → backup_1 → backup_2 회전. **정합하지 않은 primary는 회전하지 않고 `save_corrupt.json`으로 격리**한다
  (손상본이 정상 백업을 밀어내지 못하게). 로드는 primary → backup_1 → backup_2 순으로 첫 정상 후보를 쓰고 `save_recovered`를 발행한다.
- 더 새로운 버전의 세이브만 남아 있으면 메모리에서 새 게임을 시작하되 **쓰기를 차단**한다(덮어쓰면 복구 불가).
- 마이그레이션은 한 버전씩 순서대로(`SaveMigrator.MIGRATIONS[N]`: vN→vN+1), 단계 누락은 건너뛰지 않고 오류다.
  실제 파일이 마이그레이션되기 전에 `save_pre_migration_v<N>.json`으로 원본을 보관한다. 콘텐츠 id 삭제/변경은 `content_aliases.json`으로 처리한다.
- 저장 시점: 60초 자동 저장(변경이 있을 때만), 앱 일시정지·포커스 아웃·종료 요청.
- 재검토 조건: 세이브가 수 MB를 넘으면 JSON 대신 압축/바이너리를 고려(TECH_SPEC §4는 혼용 금지).

## D-009 시계: 게임 시간은 단조 증가분으로 진행, 벽시계는 오프라인 구간에만 사용 (2026-10-06, P0-007)

- 게임 시계는 `_process` delta 누적(현실 24분 = 하루, `balance.json`의 `time`)으로만 진행하므로 벽시계 조작에 영향받지 않는다.
- 벽시계는 "자리를 비운 시간" 계산에만 쓰며 `[0, 12h]`로 clamp한다(되돌린 시계 → 0, 장기 부재 → 12h 상한). 앱 일시정지→재개와 세이브 로드가 같은 규칙을 쓴다.
- Real-time Mode는 로컬 시각을 그대로 게임 시계로 쓰고 전용 보상은 없다(GDD §13).
- 시간대 경계는 콘텐츠(`band_starts_hour`)다. 시간대 개수(현재 4)는 `TimeService.TIME_BANDS`이며 P1-005에서 5개로 확장한다.

## D-010 낚시 코어: 상태 머신은 뷰를 모르고, 포획은 잡는 즉시 기록 (2026-10-06, P0-011~016)

- `FishingController`는 전이 표(`TRANSITIONS`)에 없는 이동을 오류로 거부하고, 시간은 `advance(delta)`로만 흐른다(테스트 가능, 프레임 한 번에 여러 상태 경계 통과 가능). 애니메이션·소리·햅틱은 EventBus 구독자다.
- 실패는 항상 부드럽다: 훅을 놓치거나 장력 싸움에서 지면 `fish_escaped`로 끝나고 READY로 돌아간다. 희귀(등급 ≥ pity_min_rarity) 종을 놓치면 세션 내 pity 카운터만 오른다(저장 안 함).
- 물고기를 올리는 순간(LAND 진입) 도감에 기록하고 `session.pending_catch`로 저장한다. 방생은 그 뒤의 별도 단계이며, 강제 종료돼도 다음 실행에서 `resume_pending_catch()`로 INSPECT에 복귀한다. **판매/보관 경로는 존재하지 않는다**(UI_UX §4, GDD §11).
- 장력 싸움은 순수 시뮬레이션(`FightSimulation`)이고 어종별 당김 패턴은 `behaviors.json`이다. 테스트가 72종 전부가 꾸준한 플레이어에게 낚이고, 방치·계속 감기는 실패함을 강제한다.
- 모든 타이밍·보상 수치는 `balance.json`(`fishing`, `rewards`)이며 ContentValidator가 범위·상호 관계(예: 풀기 목표가 안전 구간 아래)를 검증한다.
