# 01. Game Design Document

## 1. Product Vision
**잡는 낚시가 아니라, 머무르는 낚시.**

조용한 물가에 낚싯대를 드리우고, 만난 생명을 기록하고 돌려보내며,
황량했던 물가를 살아 있는 작은 생태계로 되돌리는 힐링 낚시 디오라마 게임.

### Core Fantasy
- 내가 발견한 생물이 실제 세계에 남는다.
- 내가 낚시한 결과가 풍경의 변화로 보인다.
- 아무 행동을 하지 않고 바라보는 것도 정상적인 플레이다.
- 실패보다 재시도와 관찰의 기대를 강화한다.

## 2. Design Pillars
1. **Stay, Not Hunt** — 행동 강요보다 체류와 관찰.
2. **Visible Progress** — 숫자 대신 풍경과 생명체 변화.
3. **Gentle Fishing** — 손맛은 있으나 스트레스는 낮음.
4. **Persistent Ecosystem** — 도감과 월드가 연결됨.
5. **No FOMO** — 연속 출석, 기간 한정 강제, 에너지 없음.
6. **Offline by Default** — 핵심 플레이는 네트워크 불필요.

## 3. Core Loop
```text
관찰 → 캐스팅 → 기다림 → 입질 → 릴링 → 발견 → 방생
                                   ↓
                           생태 포인트 획득
                                   ↓
                         지역 복원 / 캠프 성장
                                   ↓
                          새 생물 / 행동 / 풍경
                                   ↓
                                  관찰
```

## 4. Session Design
- 30초: 접속 → 세계 변화 확인 → 종료
- 3~5분: 낚시 2~3회 → 방생 → 복원
- 10~15분: 도감 → 꾸미기 → 지역 탐색
- 30분+: 희귀어 탐색, 사진, 물멍

## 5. Launch Scope
- 5 Regions
- 72 Fish Species
- 18 Rare Variants
- 24 Ambient Animals
- 50 Restoration Milestones
- 12 Rods
- 16 Baits
- 20 Camp Facilities
- 60+ Decorations
- 6 Weather Types
- 5 Time Bands
- 40 Achievements
- 6~8 BGM
- 12+ Ambient Sound Profiles

## 6. Regions
표시 이름은 목업을 따른다(D-018). 데이터 id(`region_01_quiet_pond` 등)는 그대로다.
### R01 작은 연못 (Little Pond)
튜토리얼과 핵심 시스템 학습. 잔잔한 숲속 연못.

### R02 숲속 계곡 (Forest Valley)
유속과 바위/수초 Habitat가 추가된다.

### R03 큰 강 (Big River)
수심과 넓은 캐스팅 영역이 추가된다.

### R04 바닷가 (Seaside)
조수 변화와 해안 어종이 추가된다.

### R05 달빛섬 (Moonlight Isle)
엔드 콘텐츠. 시간/날씨/환경 조합을 활용한 희귀 관찰 중심.

## 7. Fishing State Machine
`READY → AIM → CAST → WAIT → BITE_HINT → HOOK → FIGHT → LAND → INSPECT → RELEASE`

### WAIT
기본 4~14초. 하한 3.5초. 기다림 중 Ambient Event를 발생시켜 빈 시간을 제거한다.

### HOOK
기본 입력 윈도 1.5~2.5초.
접근성 모드 3~4초.
Auto Hook 사용에 불이익 없음.

### FIGHT
화면 누름 = 감기, 놓음 = 장력 완화.
목표 장력 0.30~0.75를 출발점으로 사용한다.

### Failure
영구 손실 없음. 놓친 종은 짧은 시간 재등장 보정.

## 8. Encounter
```text
FinalWeight =
BaseWeight
× HabitatModifier
× TimeModifier
× WeatherModifier
× BaitModifier
× EcosystemModifier
× PityModifier
```
Weighted Random으로 후보군에서 결정한다.

## 9. Ecosystem
실제 Population은 수치로 보관하고 화면에는 대표 Fish Agent만 생성한다.
방생량, 복원도, 시간, 날씨가 대표 Agent 구성에 영향을 준다.

### Restoration Level
지역당 0~10.
모든 단계는 **실제 시각 변화**를 동반해야 한다.

## 10. Collection
도감 정보는 반복 발견으로 단계적으로 해금.
- 1회: 이름/크기
- 3회: 시간대
- 5회: 서식지
- 10회: 특별 행동/설명

## 11. Economy
### Ripple (물결)
일반 진행 재화. 낚시/방생/지역 목표에서 획득.

### Memory (추억)
탐험·관찰 재화. 새 어종/특별 행동/지역 완성에서 획득.
현금 구매하지 않는다.

Premium Currency 없음.

## 12. Equipment
장비는 수치 Power Creep이 아니라 플레이 스타일/접근 영역 변화에 사용.
강화 +1/+99 없음.

목업(D-018)에 따라 장비 화면은 낚싯대 / 미끼 / 가방 / 악세서리 네 갈래다. 세부 규칙은 P1-003/004에서 정하되 원칙은:
- 낚싯대는 등급(일반·고급·희귀·이벤트)과 세 가지 성격(제어력·민감도·내구도)을 보여 준다. 성격은 서로 바꿔 주는
  관계(한쪽이 높으면 다른 쪽이 낮다)로 설계해 "더 센 낚싯대"가 아니라 "다른 낚싯대"가 되게 한다.
- "이벤트" 등급은 기간 한정 판매가 아니라 게임 속 특별한 순간(예: 지역 완전 복원)에 받는 기념 장비다(No FOMO).
- 장비와 가방 칸은 게임 재화로만 얻는다. 현금 판매 없음(MONETIZATION §3).

## 13. Time & Weather
게임 기본 하루 ≈ 현실 24분(초기값).
Real-time Mode는 선택 사항이며 전용 보상 없음.

날씨는 디버프가 아닌 **다른 경험**이어야 한다.

## 14. Offline Progression
보상 캡 12시간.
전체 시뮬레이션이 아니라 Aggregate Simulation 사용.
복귀 팝업의 보상 숫자만 보여주지 말고 실제 월드 변화로 연결.

## 15. Camp
기능 중심이 아니라 정서적 Anchor.
의자/모닥불/텐트/테이블/부두/오두막/정원 등.

## 16. Water-Mind Mode
HUD 전체 숨김.
BGM/Water/Wind/Wildlife/Weather/Camp 믹서를 개별 조절.
배터리 절약 설정과 연동.

## 17. Photo Mode
Zoom / Pan / HUD Off / Frame / Logo Toggle.
실제 저장과 OS Share는 플랫폼 구현 단계에서 추가.

## 18. Narrative
NPC 대화 중심이 아닌 Environmental Storytelling:
낡은 사진, 표지판, 병 속 편지, 오래된 노트.

## 19. First 10 Minutes
- 0:00 로그인 없이 월드 진입
- 1:00 첫 캐스팅
- 2:00 첫 물고기
- 3:00 방생
- 4:00 방생한 종이 실제 연못에 등장 — **First Wow**
- 5:00 도감
- 7:00 첫 복원
- 9:00 첫 환경 동물
- 10:00 튜토리얼 종료

## 20. North Star
기능 추가 전 질문:
> 이 기능이 플레이어와 작은 세계 사이의 애착을 강하게 만드는가?

아니라면 넣지 않는다.
