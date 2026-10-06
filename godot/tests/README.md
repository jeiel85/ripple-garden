# Test Strategy

Godot CLI가 있는 환경에서는 후속 구현 시 GUT 또는 native unit-test 전략을 결정합니다.
현재 골격 단계에서는 `tools/validate_content.py`가 정적 콘텐츠 무결성을 검사합니다.

추가할 테스트:
- EncounterResolver deterministic seeded tests
- Save roundtrip
- Save backup recovery
- Migration sequence
- Fishing state transition legality
