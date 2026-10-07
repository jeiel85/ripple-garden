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
  그림 파일은 `godot/art/`에 이름 규칙대로 넣으면 그 그림이 쓰인다(D-029). 넣은 그림의 출처·라이선스는 여기에 적는다.
- **그림 — Asset Drop 01** (`godot/art/fish/*_side.png` 9장, `godot/art/props/` 8장): OpenAI 이미지 생성으로 2026-10-07 이 프로젝트용으로
  만든 그림(`ripple_garden_asset_drop_01.zip`, 저장소 밖 보관). 상업적 이용은 OpenAI 이용 약관을 따른다. `tools/import_art_drop.py`가
  이름을 바꾸고 시트 배경 테두리·바늘구멍을 정리해 넣는다(수정됨). 원본 대응: 물고기 옆모습 그대로, `lily_pad`←`prop_lily_pad_01`,
  `lily_pad_02`←`prop_water_lily_01`, `reed`←`prop_reed_01`, `reed_02`←`prop_cattail_01`, `flower`←`prop_flower_white_01`,
  `flower_02`←`prop_flower_pink_01`, `grass_tuft`, `bush`.
  넣지 않은 것: `_top` 물고기(위에서 본 그림이 아니라 비스듬한 옆모습에 머리 왼쪽), `fish_gudgeon_side`(꼬리 잘림),
  월드·낚시꾼·UI·동물과 나머지 소품(해상도·잘림·구조 결정 필요, BACKLOG).
- **그림 — Asset Drop 02** (`godot/art/fish/fish_common_carp_top.png`, `godot/art/props/cat.png`, `godot/art/props/frog.png`): OpenAI 이미지 생성으로
  2026-10-07 만든 애니메이션 시트(`ripple_garden_asset_drop_02.zip`, 저장소 밖 보관). 상업적 이용은 OpenAI 이용 약관을 따른다.
  `tools/import_art_drop.py`가 시트에서 한 포즈를 잘라 부스러기 점을 지우고, 몸통을 불투명하게 하고, 축소해 넣는다(수정됨; 게임에 스프라이트 애니메이션이 아직 없어 한 포즈만).
  원본 대응: `fish_common_carp_top`←`fish_common_carp_top_anim_sheet_alt` 가운데 포즈(머리 위 → 오른쪽으로 돌림), `cat`←`animal_cat_sleeping_01_anim_sheet` 왼쪽 위,
  `frog`←`animal_frog_01_anim_sheet` 왼쪽 위.
  넣지 않은 것: `fish_common_carp_top_anim_sheet`·`fish_minnow_top_anim_sheet`(위에서 본 그림이 아니라 비스듬한 옆모습, 머리 왼쪽),
  새·잠자리·나비·반딧불이(받을 코드 없음), 폭포 시트(폭포만이 아니라 웅덩이까지 든 바위섬 한 덩어리, 받을 자리 없음) — BACKLOG.
- **그림 — Asset Drop 03** (`godot/art/items/` 28장, `godot/art/props/` 캠프 소품 8장): OpenAI 이미지 생성으로 2026-10-07 만든 아이템 시트
  (`ripple_garden_asset_drop_03.zip`, 저장소 밖 보관). 상업적 이용은 OpenAI 이용 약관을 따른다. `tools/import_art_drop.py`가 시트에서 한 장씩 잘라
  부스러기 점을 지우고, 몸통을 불투명하게 하고, 축소해 넣는다(수정됨). 시트의 이름과 게임 id 대응은 스크립트의 `SHEETS`에 있다.
  낚싯대 12종 모두(`forest_rest`·`river_breeze`·`moonlight_flow`·`spring_promise`는 게임 이름과 같고 나머지는 테마로 맞춤), 미끼 11종, 가방 4종,
  밀짚모자, 캠프 소품 `tent`·`camp_chair`·`wood_table`·`lantern`·`flower_pot`·`birdhouse`·`campfire`·`signboard`.
  넣지 않은 것: 맞는 게임 아이템이 없는 그림(빵 조각·딱정벌레·떡·달 물방울·가재 미끼, 조끼·장갑·장화·수건·보온병, 피크닉 바구니·그루터기 의자·꽃 상자·세면대).
  그림이 오지 않은 게임 아이템은 도형 그대로다(BACKLOG).
- **Asset Drop 04** (`ripple_garden_asset_drop_04.zip`, 지도·아이콘): 넣지 않았다. 아이콘은 지금 아이콘과 같은 수준의 코드 생성 도형인데 뜻이 틀린 것이 많고
  (설정=해, 카메라=가방, 꾸미기=꺾은선, 추억=하트) 색이 박혀 있어 게임의 틴트를 받지 못한다. 지도는 목업 07과 다른 평면 도형이라 지금 지도보다 낫지 않다.
- **아이콘**: `assets/branding/`과 `godot/icon.svg`는 `tools/generate_icon.py`로 만든 자체 제작 아이콘이다.
- **디자인 목업**: `assets/design/`은 ChatGPT 이미지 생성으로 만든 UI 목업과 그 조각이다(D-017). 런타임에는 쓰지 않으며 화면의 기준이다(D-018).
- **UI 아이콘**: `godot/ui/icons/*.svg`는 `tools/generate_ui_icons.py`로 그린 자체 제작 단색 아이콘이다. 정식 아이콘으로 교체할 대상.
- **폰트**: Godot 기본 폰트 + OS 폰트 폴백. 배포 전에 라이선스가 확인된 CJK 폰트를 번들해야 한다.
