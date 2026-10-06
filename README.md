# Ripple Garden

> **잡는 낚시가 아니라, 머무르는 낚시.**

조용한 물가에 낚싯대를 드리우고, 만난 생명을 기록하고 돌려보내며,
황량했던 물가를 살아 있는 작은 생태계로 되돌리는 힐링 낚시 디오라마 게임입니다.

**Fish → Discover → Release → Restore → Observe** — 플레이어가 만나고 방생한 물고기가
도감 숫자로 끝나지 않고 실제 세계에 남아 생태계와 풍경을 바꾸는 것이 핵심입니다.

[![ci](https://github.com/jeiel85/ripple-garden/actions/workflows/ci.yml/badge.svg)](https://github.com/jeiel85/ripple-garden/actions/workflows/ci.yml)

## 현재 상태

**Vertical Slice(Region 01) 구현 초기 단계**입니다. 아직 플레이 가능한 낚시 루프는 없습니다.

| 단계 | 내용 | 상태 |
|---|---|---|
| P0-001 | Godot 프로젝트 부트스트랩, 폴더, autoload 등록 | ✅ 완료 |
| P0-002 | ContentDB JSON 로더 + 검증 오류 보고 | ✅ 완료 |
| P0-003 | EventBus 타입 이벤트 규약 | ✅ 완료 |
| P0-004 | GameState 도메인 모델 + 세이브 스키마 | ✅ 완료 |
| P0-005 ~ P0-006, P0-027 | 원자적 저장·백업 복구·마이그레이션 프레임워크·세이브 테스트 | ✅ 완료 |
| P0-007 | 세션/게임/오프라인 시계, 시간대 이벤트 | ✅ 완료 |
| P0-008 ~ P0-025 | 월드 씬·서식지·물고기·복원·날씨·도감·앰비언트 오디오·설정·물멍·디버그 | 🚧 PR 검토 중 |
| P0-026, P0-028 | 콘텐츠 검증 단일화·Android/Windows 빌드 | ⏳ 진행 예정 |
| P1 / P2 / P3 | 프로덕션 시스템 → 5개 지역 콘텐츠 → 출시 준비 | 대기 |

전체 백로그는 [`TASKS.md`](TASKS.md)를 봅니다.

## 제품 방향

- Mobile Portrait First, Tablet/PC Adaptive
- Android / Windows 우선, 이후 iOS / Steam
- 기본 오프라인 — 계정·광고·분석 SDK·백엔드 없음
- 무료 체험 + Full Game 1회 구매
- PvP·가챠·에너지·배틀패스·연속 출석 없음

## 요구 사항

- [Godot 4.7.2](https://godotengine.org/download) (GDScript, GL Compatibility 렌더러)
- Python 3.9+ (콘텐츠·버전 검증 도구)
- Windows 빌드 시 Godot 4.7.2 export templates

## 실행과 검증

Godot 프로젝트는 `godot/` 폴더입니다. 편집기에서 `godot/project.godot`을 열면 됩니다.

콘텐츠 데이터 정합성 검사 (게임이 쓰는 `ContentValidator`와 로컬라이제이션 키 검사를 그대로 실행하며, 처음 한 번은 아래 `--import`가 필요합니다):

```bash
godot --headless --path godot -s res://tools/validate_content.gd
```

버전 정합성 검사 (`project.godot` ↔ export preset, 선택적으로 태그):

```bash
python tools/check_version.py
```

Godot 헤드리스 테스트 (처음 한 번은 `--import` 필요):

```bash
godot --headless --path godot --import
```

```bash
godot --headless --path godot -s res://tests/run_tests.gd
```

`tests/unit/test_*.gd`의 `test_*` 메서드를 모두 실행하며, assert 실패뿐 아니라 실행 중
발생한 엔진 에러(스크립트 런타임 에러, `push_error`)도 실패로 판정합니다. 종료 코드 0이 통과입니다.

Windows 빌드 (`build/windows/RippleGarden.exe`로 출력):

```bash
godot --headless --path godot --export-release "Windows Desktop" ../build/windows/RippleGarden.exe
```

## CI / 릴리스

- PR과 `main` 푸시: 콘텐츠 검증 → 버전 검사 → Godot 헤드리스 테스트 (`.github/workflows/ci.yml`)
- `v*` 태그 푸시: 위 검증 통과 후 Windows 빌드를 만들어 GitHub Release에 zip과 SHA256을 올립니다.
  태그는 `godot/project.godot`의 `config/version`과 같아야 합니다.

## 저장소 구조

```text
docs/        기획·기술·데이터·UI·밸런스·QA·출시 문서 (설계 단일 출처)
godot/
  content/   정적 콘텐츠 검증 (ContentValidator)
  save/      세이브 스키마(기본값·정규화·정합성 검사)
  autoload/  전역 서비스 (EventBus, GameState, ContentDB, SaveService, TimeService, AudioService)
  audio/     오디오 버스 레이아웃, 앰비언트 믹스·재생, placeholder 음원(streams/)
  data/      정적 콘텐츠 JSON·로컬라이제이션 CSV — 코드에 하드코딩하지 않음
  fishing/   낚시 상태 머신·조우 판정
  world/     월드 루트 씬
  tests/     헤드리스 테스트 러너와 단위 테스트
tools/       콘텐츠·버전 검증 스크립트
assets/      에셋 (placeholder는 라이선스 확인된 정식 에셋으로 교체)
```

## 문서

| 문서 | 내용 |
|---|---|
| [01 GDD](docs/01_GDD.md) | 게임 디자인 |
| [02 Tech Spec](docs/02_TECH_SPEC.md) | Godot 기술 아키텍처 |
| [03 UI/UX](docs/03_UI_UX_SPEC.md) | 화면·인터랙션·접근성 |
| [04 Data Schema](docs/04_DATA_SCHEMA.md) | 데이터 구조와 저장 규칙 |
| [05 Balance](docs/05_BALANCE_SPEC.md) | 출현·진행·경제 밸런스 |
| [06 Content Plan](docs/06_CONTENT_PLAN.md) | v1.0 콘텐츠 사양 |
| [07 Monetization & Privacy](docs/07_MONETIZATION_PRIVACY.md) | 수익모델·개인정보 원칙 |
| [08 QA Test Plan](docs/08_QA_TEST_PLAN.md) | QA와 자동 검증 |
| [09 Release Checklist](docs/09_RELEASE_CHECKLIST.md) | 출시 Definition of Done |
| [10 AI Agent Guide](docs/10_AI_AGENT_GUIDE.md) | 코딩 에이전트 구현 규칙 |
| [11 Risk Register](docs/11_RISK_REGISTER.md) | 리스크 관리 |
| [DECISIONS](DECISIONS.md) | 되돌리기 어려운 기술 결정 기록 |

AI 코딩 에이전트로 작업할 때는 [`START_HERE_AI_PROMPT.md`](START_HERE_AI_PROMPT.md)부터 시작합니다.

## 참고

설계 문서의 수치는 **출발점**입니다. 상용 성공을 보장하는 값이 아니라 플레이테스트와
실기기 프로파일링으로 교정해야 하는 기준값입니다.
