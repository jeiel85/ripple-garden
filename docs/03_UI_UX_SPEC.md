# 03. UI / UX Specification

## 1. Principles
- 자연 화면 70~80% 유지
- HUD는 필요할 때만 보이고 유휴 시 자동 숨김
- 중요 행동은 한 손 엄지 범위 우선
- 경쟁 게임식 빨간 점/카운트 폭탄 금지
- 보상 팝업 중첩 금지
- 색상만으로 상태를 전달하지 않음

## 2. Navigation
```text
World
├─ Journal
│  ├─ Fish
│  ├─ Animals
│  └─ Moments
├─ Gear
│  ├─ Rod
│  └─ Bait
├─ Camp
│  ├─ Facilities
│  └─ Decorations
├─ Region Map
└─ Settings
```

## 3. Main World
상단:
- 좌: 지역명 / 시간대 / 날씨
- 우: 설정

하단:
- Journal
- Gear
- Fishing CTA
- Camp/Map

5초 입력 없음 → HUD fade.
화면 터치 → HUD 복귀.

## 4. Fishing UX
### Aim
Drag gesture + landing indicator.
과도한 trajectory UI 없음.

### Wait
최소 UI. 찌와 환경이 주인공.
접근성 설정 시 bite cue를 시각 아이콘으로 추가.

### Hook
짧은 tactile feedback.
실패 시 비난 문구 금지.

### Fight
- 장력 meter는 색 + shape/position 동시 사용
- 한 손 입력
- Reduced Motion 사용 시 camera motion 제거

### Inspect
물고기 모델/이름/크기.
처음 발견이면 새로운 도감 카드.
CTA:
- `놓아주기`가 Primary
- 사진/도감 확인 Secondary

판매 버튼은 없음.

## 5. Journal
정보 공개 수준에 따라 `???` 대신 실루엣/힌트를 사용.
플레이어가 무지함을 벌 받는 느낌이 들지 않도록 함.

## 6. Restoration
업그레이드 버튼을 누르면:
1. 요구 조건 표시
2. 승인
3. 월드 변화 카메라 연출 2~4초
4. 새 생물/오브젝트 Highlight
긴 보상 팝업 금지.

## 7. Camp
Drag-to-place는 선택.
초기 버전은 slot/anchor 방식으로 모바일 조작 복잡도를 낮춘다.

## 8. Water-Mind Mode
진입 시 모든 HUD 제거.
Tap으로 최소 overlay:
- 종료
- audio mixer
- photo

Burn-in/배터리 고려:
- optional dim after N minutes
- battery saver 안내는 1회만

## 9. Settings
### Gameplay
- Relaxed Hook
- Auto Hook
- Real-time Mode
- Tutorial Hints

### Accessibility
- Text Scale
- Large UI
- Reduced Motion
- Camera Shake
- Haptics
- High Contrast Meter

### Graphics
- Quality
- FPS
- Battery Saver

### Audio
각 bus volume.

### Privacy/Support
- Privacy Policy
- Licenses
- Export Diagnostic Info
- Save Backup/Restore UI(가능하면)

## 10. Responsive
Phone portrait = 기준.
Tablet = 월드 가시 영역 확장.
Desktop landscape = 중앙 디오라마 + side utility panels 옵션.

단순 9:16 확대 금지.

## 11. Touch Targets
내부 기준 48dp급 이상.
아이콘 단독 버튼에는 accessibility label.

## 12. Copy Tone
짧고 관찰형.
금지: "실패!", "놓쳤습니다!", "연속 보상 손실!"
권장: "물속으로 돌아갔어요.", "다시 가까이 올지도 몰라요."
