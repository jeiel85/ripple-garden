# Ripple Garden — Commercial Game Production Package

상용 출시를 목표로 한 힐링 낚시 디오라마 게임의 기획·기술·콘텐츠·QA 패키지입니다.

## 핵심 콘셉트
**Fish → Discover → Release → Restore → Observe**

플레이어가 만난 물고기와 생명들이 단순한 도감 숫자가 아니라 게임 세계에 남아
생태계와 풍경을 변화시키는 것이 핵심 USP입니다.

## 패키지 구성
- `docs/01_GDD.md` — 상용 게임 디자인 문서
- `docs/02_TECH_SPEC.md` — Godot 기술 아키텍처
- `docs/03_UI_UX_SPEC.md` — 화면/인터랙션/접근성
- `docs/04_DATA_SCHEMA.md` — 데이터 구조와 저장 규칙
- `docs/05_BALANCE_SPEC.md` — 출현/진행/경제 밸런스
- `docs/06_CONTENT_PLAN.md` — v1.0 콘텐츠 제작 사양
- `docs/07_MONETIZATION_PRIVACY.md` — 수익모델/개인정보 원칙
- `docs/08_QA_TEST_PLAN.md` — QA 및 자동 검증
- `docs/09_RELEASE_CHECKLIST.md` — 출시 Definition of Done
- `docs/10_AI_AGENT_GUIDE.md` — Claude/Codex 등 코딩 에이전트용 구현 규칙
- `TASKS.md` — 실제 개발 백로그
- `godot/` — Godot 프로젝트 골격과 샘플 코드/데이터
- `tools/validate_content.py` — 콘텐츠 정합성 검사기

## 제품 방향
- Mobile Portrait First, Tablet/PC Adaptive
- Android / Windows 우선, 이후 iOS / Steam
- 기본 오프라인
- 계정/광고/분석 SDK 없음
- 무료 체험 + Full Game 1회 구매
- PvP/가챠/에너지/배틀패스 없음

## 시작 방법
1. `docs/10_AI_AGENT_GUIDE.md`를 코딩 에이전트의 첫 컨텍스트로 제공합니다.
2. `TASKS.md`의 P0 → P1 순서로 구현합니다.
3. 먼저 `Vertical Slice`만 완성해 재미와 감성을 검증합니다.
4. `python tools/validate_content.py`로 콘텐츠 데이터를 검증합니다.
5. Vertical Slice 검증을 통과한 뒤 전체 5개 지역으로 확장합니다.

## 중요
이 패키지의 수치들은 **출발점**입니다. 상용 성공을 보장하는 값이 아니라 플레이테스트와
실기기 프로파일링으로 교정해야 하는 기준값입니다.
