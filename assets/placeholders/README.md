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
- **그림 — Asset Drop 02** (`godot/art/fish/fish_common_carp_top*.png` 3프레임, `godot/art/props/cat.png`, `godot/art/props/frog*.png` 4포즈,
  `godot/art/animals/` 4종 × 2프레임): OpenAI 이미지 생성으로 2026-10-07 만든 애니메이션 시트(`ripple_garden_asset_drop_02.zip`, 저장소 밖 보관).
  상업적 이용은 OpenAI 이용 약관을 따른다. `tools/import_art_drop.py`가 시트에서 포즈를 잘라 부스러기 점을 지우고, 몸통을 불투명하게 하고, 같은 그림의 프레임을
  한 캔버스에 맞춰(잉어는 꼬리 튼 프레임을 돌려 머리를 겹침) 축소해 넣는다(수정됨). 시트 칸과 파일 대응은 스크립트의 `SHEETS`에 있다.
  넣지 않은 것: `fish_common_carp_top_anim_sheet`·`fish_minnow_top_anim_sheet`(위에서 본 그림이 아니라 비스듬한 옆모습, 머리 왼쪽),
  고양이 나머지 3포즈(다른 잠자는 자세라 넘기면 순간이동처럼 보임), 폭포 시트(폭포만이 아니라 웅덩이까지 든 바위섬 한 덩어리, 받을 자리 없음) — BACKLOG.
- **그림 — Asset Drop 03** (`godot/art/items/` 28장, `godot/art/props/` 캠프 소품 8장): OpenAI 이미지 생성으로 2026-10-07 만든 아이템 시트
  (`ripple_garden_asset_drop_03.zip`, 저장소 밖 보관). 상업적 이용은 OpenAI 이용 약관을 따른다. `tools/import_art_drop.py`가 시트에서 한 장씩 잘라
  부스러기 점을 지우고, 몸통을 불투명하게 하고, 축소해 넣는다(수정됨). 시트의 이름과 게임 id 대응은 스크립트의 `SHEETS`에 있다.
  낚싯대 12종 모두(`forest_rest`·`river_breeze`·`moonlight_flow`·`spring_promise`는 게임 이름과 같고 나머지는 테마로 맞춤), 미끼 11종, 가방 4종,
  밀짚모자, 캠프 소품 `tent`·`camp_chair`·`wood_table`·`lantern`·`flower_pot`·`birdhouse`·`campfire`·`signboard`.
  넣지 않은 것: 맞는 게임 아이템이 없는 그림(빵 조각·딱정벌레·떡·달 물방울·가재 미끼, 조끼·장갑·장화·수건·보온병, 피크닉 바구니·그루터기 의자·꽃 상자·세면대).
  그림이 오지 않은 게임 아이템은 도형 그대로다(BACKLOG).
- **Asset Drop 04** (`ripple_garden_asset_drop_04.zip`, 지도·아이콘): 넣지 않았다. 아이콘은 지금 아이콘과 같은 수준의 코드 생성 도형인데 뜻이 틀린 것이 많고
  (설정=해, 카메라=가방, 꾸미기=꺾은선, 추억=하트) 색이 박혀 있어 게임의 틴트를 받지 못한다. 지도는 목업 07과 다른 평면 도형이라 지금 지도보다 낫지 않다.
- **Asset Drop 05** (`ripple_garden_asset_drop_05.zip`, 순간 그림·사진 액자·효과): 넣지 않았다. 순간 그림은 목업 01·03을 잘라 스티커를 얹은 같은 장면이라
  순간의 내용이 없고(`rare_encounter`는 한글 UI가 박혀 있음), 나무 액자는 가로줄이 사진 위로 지나가며, 효과는 게임이 이미 그리는 점·원과 같은 수준이다.
  다시 받을 조건은 `assets/design/ASSET_REQUESTS.md`.
- **그림 — Asset Drop 06** (`godot/art/world/r01_foreground.png`, `godot/art/fish/` 위에서 본 9종 + `fish_gudgeon_side`, `godot/art/props/`
  `crate`·`bench`·`junk`·`stump`·`flower_03`, `godot/art/items/` 미끼 5종·모자 3종): OpenAI 이미지 생성으로 2026-10-07 만든 그림
  (`ripple_garden_asset_drop_06.zip`, 저장소 밖 보관). 상업적 이용은 OpenAI 이용 약관을 따른다. 드롭의 낱장 PNG는 참조 시트
  (`source_masters/corrected_core_reference_sheet.png`)를 고정 칸으로 잘라 약 6배 키운 것이라 시트의 체크무늬 배경·옆 그림 조각·파일명 글자가 박혀 있어 쓰지 않았다.
  `tools/import_art_drop.py`가 같은 그림을 참조 시트에서 다시 잘라 체크무늬와 그림자를 지우고(수정됨), 위에서 본 물고기는 머리가 오른쪽이 되게 돌리고
  모래무지 옆모습은 좌우를 뒤집는다. 크기는 시트 그대로(100~200px)다. 앞쪽 수풀은 따로 큰 원본(`r01_foreground_hires_source.png`, 941×1672)을 그대로 넣었다.
  넣지 않은 것: `r01_scene`·`r01_scene_barren`(시트의 330px 그림을 키우고 위아래를 흐린 복사본으로 채움, 체크무늬가 박힘, 목업 01 구도 아님),
  낚시꾼 5장(정면을 보고 앉음 — 목업은 연못을 향한 뒷모습, `cast`에 줄이 그려지고 `bite`·`hold`에 느낌표가 박힘), 텐트(Drop 03 것이 더 크고 다른 캠프 소품과 같은 그림),
  UI 프레임 16장(잘림·흰 테두리, 게임에 9-patch 자리가 아직 없음). 다시 받을 조건은 `assets/design/ASSET_REQUESTS.md`.
- **아이콘**: `assets/branding/`과 `godot/icon.svg`는 `tools/generate_icon.py`로 만든 자체 제작 아이콘이다.
- **디자인 목업**: `assets/design/`은 ChatGPT 이미지 생성으로 만든 UI 목업과 그 조각이다(D-017). 런타임에는 쓰지 않으며 화면의 기준이다(D-018).
- **UI 아이콘**: `godot/ui/icons/*.svg`는 `tools/generate_ui_icons.py`로 그린 자체 제작 단색 아이콘이다. 정식 아이콘으로 교체할 대상.
- **폰트** (`godot/fonts/`, D-031): Gowun Dodum(본문)·Jua(제목)·M PLUS Rounded 1c Regular/Bold(일본어), 모두 SIL Open Font License 1.1.
  github.com/google/fonts에서 2026-10-07 받아 `tools/subset_fonts.py`로 게임에 쓰는 글자만 남겨 woff2로 넣었다(수정됨, 예약 글꼴 이름 없음).
  저작권 표시와 라이선스 전문은 `godot/fonts/OFL.txt`이며 설정 > 오픈소스 라이선스 화면에 함께 나온다(export `include_filter`에 포함).
- **그림 — Asset Drop 07** (`godot/art/moments/moment_rainbow.png`): OpenAI 이미지 생성으로 2026-10-07 만든 그림(`ripple_garden_asset_drop_07.zip`, 저장소 밖 보관),
  512px로 줄여 넣었다(수정됨). 넣지 않은 것: 나머지 순간 그림 10장(목업 01을 잘라 스티커를 얹은 같은 장면), 아이콘 39개(지금 아이콘보다 단순하고 뜻이 틀린 것이 있으며
  일부만 섞으면 일관성이 깨짐), 사진 액자 4장(게임이 그리는 액자와 같은 수준). 다시 받을 조건은 `assets/design/ASSET_REQUESTS.md`.
- **그림 — Asset Drop 08** (`godot/art/world/r01_scene.png`, `r01_scene_barren.png`): OpenAI 이미지 생성으로 2026-10-07 만든 Region 01 풍경 두 장
  (`ripple_garden_asset_drop_08.zip`, 저장소 밖 보관). 상업적 이용은 OpenAI 이용 약관을 따른다. 1024×1536 원본 그대로 넣었다(수정 없음).
  두 장은 같은 구도라 복원 단계 사이에 섞어 보여 준다. `data/region_layouts.json`의 연못 경계·구역·낚시꾼·캠프 자리·소품 위치를 이 그림에 맞췄다.
