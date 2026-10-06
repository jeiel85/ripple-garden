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
