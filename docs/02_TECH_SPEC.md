# 02. Technical Specification

## 1. Engine / Targets
- Godot 4.x
- GDScript
- Android / Windows 1차
- iOS / Steam 후속
- Portrait-first UI, adaptive landscape/desktop

## 2. Architecture
```text
GameRoot
├─ WorldManager
├─ RegionRuntime
│  ├─ Environment
│  ├─ HabitatZones
│  ├─ FishPopulationPresenter
│  ├─ AmbientAnimalPresenter
│  └─ WeatherPresenter
├─ FishingController
├─ CameraController
└─ UIController

Autoload
├─ EventBus
├─ GameState
├─ ContentDB
├─ SaveService
├─ TimeService
├─ AudioService
└─ EntitlementService
```

## 3. Responsibility Rules
- UI가 GameState를 직접 변경하지 않는다.
- UI → command/request → domain service → state update → EventBus → UI refresh.
- 콘텐츠 ID와 수치는 코드에 하드코딩하지 않는다.
- 시간/난수/저장은 인터페이스 경계를 둬 테스트 가능하게 한다.
- Node 수로 영속 데이터를 표현하지 않는다.

## 4. Persistence Model
Save는 JSON 또는 Godot Variant binary 중 하나로 고정하며 혼용하지 않는다.
초기 구현은 디버깅 가능한 JSON 권장.

필수:
- `save_version`
- atomic temporary write
- 2 rotating backups
- migration pipeline
- schema sanity check
- failed-load recovery

## 5. Save Transaction
```text
serialize
→ validate
→ write save.tmp
→ fsync/close
→ rotate backups
→ rename tmp to primary
```

## 6. Runtime Population
영속 Population과 Visible Agent 분리.

예:
- pop 1~10 → visible cap 1
- 11~30 → 2
- 31~60 → 3
- 61+ → 4

전체 Fish Agent:
- Low: 20
- Medium: 35
- High: 50
설정/실기기 성능 측정으로 조정.

## 7. AI Tick
- Near agents: 10~20 Hz
- Far agents: 2~5 Hz
- Rendering interpolation: every frame
- Pool fish/splash/ripple/ambient animals

## 8. Encounter Service
입력:
- region_id
- habitat_tag
- game_time_band
- weather_id
- bait_id
- ecosystem_level
- temporary modifiers

출력:
- fish_id
- size
- encounter metadata

Seeded RNG 지원으로 QA 재현 가능하게 한다.

## 9. Fishing Controller
FishingController 자체는 View를 모른다.
상태 전환과 타이머만 담당하고 애니메이션/사운드는 이벤트로 분리한다.

## 10. Time Service
- monotonic session clock
- game clock
- optional real-time clock mode
- offline duration clamp
- time-band events

벽시계 변경으로 음수 시간이 생기지 않도록 clamp한다.

## 11. Weather
WeatherDefinition 데이터 기반.
transition duration과 최소 지속시간을 둬 빠른 깜빡임을 방지.

## 12. Audio
Bus:
Master/BGM/Water/Wind/Wildlife/Weather/Fishing/Camp

Ambient는 하나의 긴 파일 대신 layers + randomized one-shots.

## 13. Graphics
모바일 우선:
- low-poly
- simple water shader
- no expensive real-time planar reflections by default
- LOD 또는 visibility range
- particles quality tiers
- shadow quality tiers

## 14. Performance Targets
내부 목표:
- Mid Android: stable 30 FPS
- High: optional 60 FPS
- peak draw calls < 250
- normal draw calls < 180
- runtime memory ideally < 600 MB
- no unbounded node growth
- 60 minute soak with no monotonic memory growth

## 15. Battery Saver
- 30 FPS
- reduced particle emission
- lower AI tick
- reduced reflection/shadow
- lower visible population

## 16. Entitlement
Full Game 여부만 저장.
Store receipt/entitlement가 권위 소스.
오프라인 실행을 고려한 캐시가 필요하지만 영구 unlock 우회 방지보다 사용자 접근성 우선.

## 17. Error Handling
Release:
- 사용자에게 stack trace 노출 금지
- local rotating log
- settings에서 진단 정보 내보내기
- 자동 원격 전송은 v1.0에 없음

## 18. Build Configuration
`debug`, `qa`, `release` 세 프로필.
QA에서만 developer console 활성.
Release는 debug cheat 경로 제거/비활성 확인.

## 19. Definition of Technical Done
- save corruption recovery test
- save migration test
- deterministic encounter test
- pause/resume lifecycle test
- purchase restore path test
- 60 min soak
- supported aspect ratio UI test
- low/mid/high Android profile
