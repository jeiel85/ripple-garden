# Asset Placeholders

실제 상용 배포에서는 이 폴더의 placeholder를 정식 라이선스가 확인된 아트/사운드로 교체합니다.

필수로 보존할 메타데이터:
- 제작자/출처
- 라이선스
- 구매/허가 증빙
- 수정 여부
- attribution 요구사항

## Generated placeholders (현재 상태)

- **음원**: `godot/audio/streams/*.wav`는 `tools/generate_placeholder_audio.py`로 합성한 자체 제작 음원이다(저작권 문제 없음). 정식 음원으로 교체할 대상.
- **그림**: 월드·물고기·UI는 코드로 그리는 절차적 도형이다(DECISIONS D-011). 정식 아트로 교체할 대상.
- **아이콘**: `assets/branding/`과 `godot/icon.svg`는 `tools/generate_icon.py`로 만든 자체 제작 아이콘이다.
- **디자인 목업**: `assets/design/`은 ChatGPT 이미지 생성으로 만든 UI 목업과 그 조각이다(D-017). 런타임에는 쓰지 않으며 화면의 기준이다(D-018).
- **UI 아이콘**: `godot/ui/icons/*.svg`는 `tools/generate_ui_icons.py`로 그린 자체 제작 단색 아이콘이다. 정식 아이콘으로 교체할 대상.
- **폰트**: Godot 기본 폰트 + OS 폰트 폴백. 배포 전에 라이선스가 확인된 CJK 폰트를 번들해야 한다.
