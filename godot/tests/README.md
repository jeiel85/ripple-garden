# Test Strategy

헤드리스 테스트 러너 `res://tests/run_tests.gd`가 `res://tests/unit/test_*.gd`를 찾아
`test_`로 시작하는 메서드를 하나씩 실행합니다. 선택 근거는 `DECISIONS.md` D-002.

```bash
godot --headless --path godot --import
godot --headless --path godot -s res://tests/run_tests.gd
```

## 테스트 작성

```gdscript
extends TestCase

func test_something() -> void:
	var autoload := tree.root.get_node("ContentDB")
	assert_false(autoload.fish.is_empty(), "fish catalog empty")
```

- `tree`로 SceneTree와 autoload에 접근합니다. autoload `_ready()`가 끝난 뒤 실행됩니다.
- 테스트마다 새 인스턴스가 만들어집니다.
- 실패 조건: `assert_*` 실패, 또는 테스트 실행 중 엔진 에러(스크립트 런타임 에러, `push_error`).
  `push_warning`은 실패가 아닙니다.
- 실제 `user://` 세이브를 건드리는 테스트는 만들지 않습니다. 저장 테스트는 경로를 주입할 수 있게
  SaveService를 정리하는 P0-005/P0-027에서 추가합니다.

## 현재 테스트

- `test_bootstrap.gd` — P0-001: autoload 등록·순서, ContentDB 적재, 메인 씬 인스턴스화,
  오디오 버스 레이아웃, 세로 화면 설정

## 추가 예정

- EncounterResolver deterministic seeded tests (P0-010)
- Save roundtrip / backup recovery / migration sequence (P0-005, P0-006, P0-027)
- Fishing state transition legality (P0-011)

정적 콘텐츠 무결성은 `tools/validate_content.py`가 따로 검사합니다.
