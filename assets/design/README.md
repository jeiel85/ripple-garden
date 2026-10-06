# Design Mockups & Extracted UI

게임 화면과 시각 언어의 **기준이 되는 생성형 UI 목업**과, 그 목업에서 잘라 낸 래스터 조각입니다.
2026-10-06 오너 결정으로 목업을 그대로 이식하는 것이 목표가 되었습니다(DECISIONS D-018).
게임 런타임은 이 파일을 직접 쓰지 않고, 목업을 따라 다시 만든 테마·아이콘·배치를 씁니다(D-017, D-018).
목업과 같은 그림으로 바꾸는 데 필요한 레이어 분리 에셋은 [`ASSET_REQUESTS.md`](ASSET_REQUESTS.md)에 정리했습니다.

## 출처

| 항목 | 내용 |
|---|---|
| 제작 | 프로젝트 오너가 ChatGPT 이미지 생성으로 제작 (2026-10-06) |
| 원본 해상도 | 941×1672 RGB (세로 9:16) |
| 수정 | 파일명만 정리. `extracted/`는 목업에서 사각형으로 잘라 둥근 모서리 알파만 입힌 것 |
| 라이선스 | 생성형 이미지. 상용 배포 전 사용 조건과 표기 요구사항을 확인한다(`assets/placeholders/README.md`) |

## 구성

```text
assets/design/
├─ mockups/                 화면 목업 8장
│  ├─ 01_main_world.png         메인 월드 (HUD + 하단 내비)
│  ├─ 02_fishing_bite_reel.png  입질 → 장력 미터·릴링
│  ├─ 03_catch_result.png       포획 결과 (새 물고기)
│  ├─ 04_journal.png            도감
│  ├─ 05_equipment.png          장비 (낚싯대·미끼·가방)
│  ├─ 06_camp_edit.png          캠프 꾸미기
│  ├─ 07_region_map.png         지역 선택 지도
│  └─ 08_water_mind.png         물멍 모드
└─ extracted/               목업에서 잘라 낸 조각 82개
   ├─ ui/{common,fishing,catch_result,journal,equipment,camp,regions,water_mode}/
   ├─ items/{rods,baits,bags,decor/camp}/
   ├─ fish/cards/
   ├─ contact_sheet.jpg     전체 조각 한눈에 보기 (라벨은 정리 전 이름: bait_frog → bait_grasshopper)
   └─ manifest.csv          조각별 원본 목업과 잘라 낸 좌표(x0,y0,x1,y1), 모서리 반경
```

`manifest.csv`의 좌표는 `mockups/`의 파일 기준이며, 82개 모두 목업에서 같은 좌표로 다시 잘라 픽셀이 일치함을 확인했다.
더 높은 해상도로 목업을 다시 만들면 같은 좌표 비율로 재추출할 수 있다.

## 그대로 게임에 넣을 수 없는 이유

`extracted/`는 **참고·임시용**이다. 런타임 UI로 쓰려면 다시 만들어야 한다.

- **배경이 구워져 있다** — 알파는 둥근 모서리뿐이고 사각형 안쪽에 목업 배경(물·풀·나무)이 남아 있다. 다른 화면 위에 올리면 티가 난다.
- **글자가 구워져 있다** — 한국어 라벨이 이미지에 박혀 있어 영어 로컬라이제이션, 글자 크기 설정(Text Scale), 수치 갱신(재화·카운터·시간)이 불가능하다.
- **잘림·이웃 침범** — `journal_sort_button`, `journal_counter`, `region_map_title`, `map_back_button`, `button_bgm`/`button_capture`/`button_weather`/`button_time`은 글자가 잘렸고, 여러 탭·아이템 카드에 옆 요소 조각이 들어가 있다.
- **해상도가 낮다** — 원본 폭 941px에서 잘라 버튼 하나가 수십~수백 px다. 1080p 이상 기기에서 확대하면 흐려진다.
- **9-patch가 아니다** — 패널·버튼 프레임은 크기가 고정이라 반응형 레이아웃(UI_UX_SPEC §10)에 늘릴 수 없다.

정식화는 프레임을 StyleBox/9-patch로, 아이콘을 투명 배경 단독 이미지로, 글자를 Label로 분리하는 방향이다.

## 기획 문서·콘텐츠와 달랐던 점

아래는 목업과 기존 스펙이 달랐던 항목이다. D-018로 **목업을 채택**했고 스펙(UI_UX_SPEC, GDD)을 그에 맞게 고쳤다.
예외: 물고기 수는 72종 계획을 유지하고, 도감 탭은 지역 묶음(전체/연못/계곡/강/바다/특수)으로 둔다.
가방·악세서리·낚싯대 등급은 P1-003/004에서 구현한다.

| 목업 | 현재 스펙·데이터 | 근거 |
|---|---|---|
| 내비 `캠프`, 도감 `전체` 탭의 빨간 알림 점 | 빨간 점·카운트 금지 | UI_UX_SPEC §1 |
| 포획 결과에서 `다시 낚시`가 강조, `기록 — 도감에 추가해요` 버튼 | `놓아주기`가 Primary, 포획 즉시 도감 기록 | UI_UX_SPEC §4 Inspect, D-010 |
| 장비 탭 `가방`·`악세서리`, 가방 아이템과 `12/20` 보관 한도 | Gear = Rod / Bait 뿐, 인벤토리 압박 판매 금지 | UI_UX_SPEC §2, MONETIZATION §3 |
| 낚싯대 등급 `이벤트`, 제어력·민감도·내구도 막대 | 이벤트 등급 없음, 장비는 수치 Power Creep이 아니라 플레이 스타일 변화 | GDD §12 |
| 물멍 모드 오버레이 `저장·시간·날씨·BGM` 상시 노출 | 진입 시 HUD 전부 제거, 탭하면 종료·오디오 믹서·사진만 | UI_UX_SPEC §8, GDD §16 |
| 지역명 작은 연못 / 큰 강 / 바닷가 | 고요한 연못 / 갈대강 / 푸른 해안 | `localization.csv` |
| 지역당 12종, 도감 28종 | 72종 (10/10/10/20/22) | `fish_catalog.json` |
| 도감 탭 민물·호수·계곡·특수 | 도감은 Fish / Animals / Moments | UI_UX_SPEC §2 |
| 낚싯대 숲속의 휴식·강가의 산들바람·달빛의 흐름·봄날의 약속 | `rods.json` 12종(대나무·가벼운·…·노장인의 낚싯대) | `rods.json` |
| 미끼 떡밥·메뚜기, 물고기 금붕어·배스 | 빵·곤충·귀뚜라미, 금붕어 없음, 큰입배스 | `baits.json`, `fish_catalog.json` |

일치하는 것: 상단 지역/시간/날씨 + 재화 `물결`(Ripple)·`추억`(Memory)(GDD §11), 하단 도감·장비·낚시 CTA·캠프 배치(UI_UX_SPEC §3),
장력 미터의 색 + 위치 표시와 `약함·강함` 라벨(UI_UX_SPEC §4 Fight), 캠프 슬롯 배치(UI_UX_SPEC §7), 실루엣 `???` 도감 칸.
