# 08. QA / Test Plan

## 1. Release Blockers
- save corruption / loss
- load softlock
- purchase entitlement loss
- purchase restore failure
- region progression softlock
- frequent crash
- unsupported resolution causing unusable controls
- severe thermal/battery issue
- collection reset

## 2. Automated Tests
### Content
- duplicate IDs
- missing references
- invalid ranges
- invalid rarity
- invalid region
- localization key missing

### Save
- round-trip equality
- migration vN→vN+1
- corrupted primary → backup recovery
- interrupted temporary write

### Encounter
- seeded deterministic result
- no zero-weight candidate crash
- condition filters
- pity cap/reset

## 3. Manual Matrix
| Area | Cases |
|---|---|
| Fishing | every rod/bait/state transition |
| Lifecycle | background/foreground, suspend/resume |
| Save | exit, force-close, low storage |
| Time | midnight, clock rollback, long offline |
| Weather | all transitions |
| UI | phone/tablet/desktop/aspect ratios |
| Audio | route change, mute, headphone reconnect |
| Purchase | success/cancel/offline/restore |
| Localization | KO/EN/JA overflow |
| Accessibility | large text/reduced motion/auto hook |

## 4. Soak
최소 60분 자동 실행:
- node count trend
- memory trend
- audio voice count
- pool size
- FPS
- log error count

## 5. Device Tiers
- low Android
- mid Android
- high Android
- Android tablet
- Windows integrated GPU
- Windows discrete GPU

## 6. Playtest Questions
정량:
- tutorial completion
- fishing attempts before exit
- region restoration progress
- journal opens

분석 SDK가 없는 v1.0에서는 구조화된 외부 테스트 설문으로 수집.

정성:
- 기다리는 시간이 지루했는가?
- 물고기를 방생한 뒤 세계가 달라졌다고 느꼈는가?
- 화면을 3분 정도 그냥 보고 있을 수 있는가?
- 다시 접속하고 싶은 이유가 있는가?
