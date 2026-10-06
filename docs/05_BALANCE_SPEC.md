# 05. Balance Specification

> 모든 값은 플레이테스트 시작용 기준값이며 고정 진리가 아니다.

## 1. Core Timing
- Cast animation: 0.8~1.2s
- Bite wait: 4~14s
- Hook window: 1.5~2.5s
- Fight common: 4~8s
- Fight rare: 8~18s
- Inspect: user-controlled

일반 낚시 1회 평균 목표: 약 15~30초.

## 2. Encounter Rarity Base Weight
권장 시작 범위:
- Tier 1: 8~15
- Tier 2: 3~8
- Tier 3: 1~3
- Tier 4: 0.2~1
- Tier 5: 조건부 0.05~0.3

Tier 5는 순수 랜덤만으로 막지 않고 조건 힌트를 제공한다.

## 3. Pity
같은 희귀 후보를 놓쳤을 때 임시 multiplier:
`1 + min(1.0, fail_count * 0.15)`

성공 시 reset.
Pity는 UI에 숫자로 노출하지 않는다.

## 4. Restoration
지역당 10단계.
총 필요 포인트 예시:
`[0, 25, 60, 110, 180, 270, 390, 540, 730, 960, 1250]`

새 지역 Unlock은 이전 지역 Level 7~8 전후 + 핵심 도감 목표 조합.
완전 10단계를 강제하지 않는다.

## 5. Economy
초기 일반 낚시 Ripple 보상:
- common: 8~12
- uncommon: 12~18
- rare: 20~35
- special: 35~60

첫 발견/행동 발견은 Memory 중심.

경제 목표:
- 첫 10분 내 첫 의미 있는 복원
- 첫 30분 내 캠프 개선 1회
- 1회 세션에서 최소 하나의 선택 가능한 소목표

## 6. Anti-Grind
같은 종 반복 보상은 완만히 감소시킬 수 있으나 0으로 만들지 않는다.
새 발견/다양한 Habitat/관찰에 자연스럽게 보너스를 준다.

## 7. Offline
12h cap.
목표: 8h 오프라인 보상만으로 진행 단계 1개를 통째로 건너뛰지 못하게 함.
대신 월드 변화/방문객/소규모 자원으로 만족 제공.

시작값(balance.json `offline`, P1-007):
- 10분 미만 부재는 아무것도 바꾸지 않는다.
- 방생된 종마다 약 4시간에 1마리(복원 단계마다 8% 빨라짐), 종당 최대 3마리.
- 물결: 시간당 4 + 복원 단계 × 0.6, 최대 120(8시간·10단계 ≈ 80).
- 복원 포인트·추억은 주지 않는다: 단계는 플레이로만 얻는다.

## 8. Full Game Trial Boundary
무료 Region 01은 Restoration Level 6까지.
핵심 루프와 Wow Moment를 충분히 경험한 이후에만 구매 안내.
첫 세션 중 결제 팝업 자동 노출 금지.
