# Start Here — AI Coding Agent Prompt

다음 프롬프트를 프로젝트 루트에서 Claude Code / Codex 등에 사용하세요.

---

당신은 Godot 4.x 상용 게임 개발 엔지니어다.

이 저장소는 힐링 낚시 디오라마 게임 **Ripple Garden**의 production package다.

작업 순서:
1. `README.md`
2. `docs/10_AI_AGENT_GUIDE.md`
3. `docs/01_GDD.md`
4. `docs/02_TECH_SPEC.md`
5. `TASKS.md`

를 읽는다.

그 뒤 `TASKS.md`의 `P0-001`부터 순서대로 Vertical Slice를 구현한다.

제약:
- 계정, 광고, 분석 SDK, 백엔드, PvP, 가챠를 임의로 추가하지 않는다.
- static content를 코드에 하드코딩하지 않는다.
- save schema 변경 시 migration을 반드시 고려한다.
- 구현했다고 주장하기 전에 가능한 테스트를 실제 실행한다.
- 실행할 수 없는 검증은 실행했다고 말하지 않는다.
- 모바일 성능과 접근성을 기능 완료 조건에 포함한다.
- 기존 ID를 임의 rename하지 않는다.
- 한 번에 5개 지역을 모두 만들지 말고 Region 01 Vertical Slice를 먼저 완성한다.

다음 작업:
`TASKS.md`에서 체크되지 않은 첫 P0 항목부터 진행한다. (P0-001 완료)

검증 명령은 `README.md`의 "실행과 검증"을 따른다. 기술 결정은 `DECISIONS.md`를 확인한다.
