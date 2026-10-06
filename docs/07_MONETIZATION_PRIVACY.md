# 07. Monetization & Privacy

## 1. Commercial Model
권장:
- Region 01 무료 체험
- Full Game 1회 구매
- 강제 광고 없음
- 광고 SDK 없음
- Premium Currency 없음
- Gacha 없음

가격은 출시 직전 시장/스토어 티어를 조사해 확정한다.
내부 초기 검토 범위: KRW 6,900~9,900.

## 2. Purchase UX
- 무료 지역 핵심 재미를 경험하기 전에 결제 요구 금지
- 구매 버튼은 Map/Settings/locked region에서 자연스럽게 제공
- 구매 복원 제공
- 구매 실패 시 진행 데이터 손실 금지

## 3. DLC Policy
허용:
- OST
- cosmetic decoration pack
- 대형 신규 region expansion

금지:
- 진행 속도 판매
- 희귀어 확률 판매
- 강한 낚싯대 현금 전용
- inventory pressure 판매

## 4. Privacy Baseline
v1.0 목표:
- login 없음
- account 없음
- analytics SDK 없음
- ad SDK 없음
- remote config 없음
- gameplay server 없음
- local save
- platform store entitlement only

## 5. Diagnostics
자동 업로드보다 사용자가 직접 내보내는 진단 파일.
가능한 항목:
- app version
- OS
- graphics profile
- save schema version
- recent local error log

개인 식별자와 실제 사용자 파일 경로는 최소화/마스킹.

## 6. Policy Maintenance
스토어 정책은 변경될 수 있으므로 실제 출시 직전:
- target SDK
- data safety/privacy disclosure
- billing library/store rules
- testing eligibility
- age/content rating
을 공식 문서에서 다시 확인한다.
