# 제3자 라이선스 인벤토리 (Third-Party Licenses)

> **초안 (draft v1, 2026-10-19)** — 스토어 제출(P3-004) 전 검토가 필요합니다.
> 게임에 들어간 모든 외부 자산의 출처·라이선스·수정 여부를 한곳에 모은 것입니다.
> 저작권 표시 원본은 `godot/audio/CREDITS.txt`(음악)와 `godot/fonts/OFL.txt`(폰트)이며,
> 둘 다 게임의 **설정 > 오픈소스 라이선스** 화면에 표시됩니다(D-039).

## 요약

| 구분 | 자산 | 라이선스 | 게임 내 사용 |
|---|---|---|---|
| 엔진 | Godot Engine 4.7.2 | MIT | 전체 |
| 폰트 | Gowun Dodum·Jua·M PLUS Rounded 1c | SIL OFL 1.1 | 본문·제목·일본어 (서브셋) |
| 음악 | CC0 곡 5곡 | CC0 1.0 | 지역별 BGM 5개 (D-039) |
| 음향 | CC0 녹음 2종 | CC0 1.0 | 강물 루프·물 튀기는 소리 |
| 음향 | 자체 합성 음원 | 자체 제작 | 나머지 환경음·신호음 (자리 표시) |
| 그림 | AI 생성 그림 다수 | OpenAI/Google 이용 약관 | 풍경·물고기·소품·아이템·순간·지도·모자·낚시꾼·UI 프레임·아이콘 |
| 아이콘 | 자체 제작 도형 | 자체 제작 | 앱 아이콘·SVG 아이콘 |

## 1. 엔진 — Godot Engine

This product uses **Godot Engine**, © 2007-2021 Juan Linietsky, Ariel Manzur and
© 2014-present Godot Engine contributors, licensed under the **MIT License**.
소스 코드와 라이선스 전문: https://github.com/godotengine/godot (LICENSE.txt).
스토어 제출 시 엔진 라이선스 표시 페이지에 Godot MIT 표기를 포함합니다.

## 2. 폰트 — SIL Open Font License 1.1

github.com/google/fonts에서 2026-10-07 수령, `tools/subset_fonts.py`로 게임에 쓰는 글자만 서브셋(수정됨).

| 폰트 | 용도 |
|---|---|
| **Gowun Dodum** (고운돋움) | 한국어 본문 |
| **Jua** (주아) | 제목 |
| **M PLUS Rounded 1c** Regular/Bold | 일본어 |

저작권 표시와 라이선스 전문: `godot/fonts/OFL.txt`. export `include_filter`에 포함되어 배포되며,
설정 > 오픈소스 라이선스 화면에 함께 표시됩니다. **예약된 글꼴 이름(P Reserved Font Name)은 사용하지 않습니다.**

## 3. 음악 — CC0 1.0 (Public Domain)

모두 OpenGameArt CC0 1.0 — 저작자 표시는 의무는 아니나 감사 표시로 게임 라이선스 화면에 표시(D-039).
원본 링크와 변환(ffmpeg Ogg q4, 일부 페이드·이음매 수정) 내역은 `godot/audio/CREDITS.txt`.

| 지역 | 곡명 | 작곡가 | 원본 |
|---|---|---|---|
| Region 01 작은 연못 | Calm3 - Peaceful Days (JRPG Music Pack #4 [Calm]) | Juhani Junkala (SubspaceAudio) | https://opengameart.org/content/jrpg-pack-4-calm |
| Region 02 숲속 계곡 | Champ de tournesol | Komiku (Loyalty Freak Music) | https://opengameart.org/content/champ-de-tournesol |
| Region 03 큰 강 | Just you and me | Alex McCulloch (Pro Sensory) | https://opengameart.org/content/just-you-and-me-guitar |
| Region 04 바닷가 | Good Morning | Cakeflaps @ You're Perfect Studio | https://opengameart.org/content/good-morning |
| Region 05 달빛섬 | Contemplation | Joth | https://opengameart.org/content/contemplation-0 |

## 4. 음향 효과 — CC0 1.0 + 자체 제작

**CC0 녹음** (`godot/audio/CREDITS.txt`):
- 강물 앰비언트: "Sea and river wave sounds" (Vistula) — RandomMind — https://opengameart.org/content/sea-and-river-wave-sounds
- 물 튀기는 소리: "40 CC0 water / splash / slime SFX" — rubberduck — https://opengameart.org/comment/82442

**자체 제작 합성 음원** (저작권 문제 없음): `godot/audio/streams/*.wav`는 `tools/generate_placeholder_audio.py`로
합성한 자리 표시 음원입니다(BACKLOG "오디오: 남은 합성 소리"). 바람·비·계곡·파도·석호 루프, 새·개구리 등
야생 소리, 던지기·입질·챔질·포획 신호음, UI 버튼 소리는 아직 합성 자리 표시이며, 정식 CC0 녹음으로 교체 시
같은 이름으로 바꾸고 이 표에 갱신합니다. UI 버튼 소리로 Kenney Interface Sounds(CC0)를 받아 두었으나
아직 연결하지 않았습니다(BACKLOG).

## 5. 그림 — AI 생성 자산 ⚠ 상용 권리 검토 필요

2026-10-07~13, **Codex CLI**(OpenAI 이미지 생성, 모델 `gpt-5.6-luna`, 추론 `low`)와
**Antigravity CLI**(`agy`, Gemini 이미지 생성)로 제작. `tools/import_art_drop.py`·`import_generated.py`·
`import_icons.py`가 자르고 줄이고 배경을 지워 넣었습니다(수정됨).

- Region 01~05 풍경(복원 전·후 10장)·물고기 72종 옆·위 모습·물가·캠프·지역 전용 소품·장비 아이템·
  낚시꾼 5자세·모자 3·도감 순간 11·지역 지도·UI 프레임 16·UI 아이콘 58·사진 액자
- 디자인 목업(`assets/design/`)도 ChatGPT 이미지 생성 — 런타임 미사용, 화면의 기준 문서(D-017/D-018)

**⚠ 검토 필요 (출시 전):**
1. AI 생성 그림의 상업적 이용 권리는 **OpenAI 이용 약관 / Google 이용 약관**을 따릅니다. 약관은 변경될 수
   있으므로 유료 출시 직전 해당 약관의 상업적 이용 조항을 다시 확인하고, 필요하면 법률 자문을 받습니다.
2. 생성 증빙을 보관합니다: 원본 zip(`ripple_garden_asset_drop_01~10.zip`, 워킹 폴더 `assets/drop/`,
   **저장소에는 커밋하지 않음** — gitignore/untracked), 생성 기록과 원본 대응은
   `assets/placeholders/README.md`에 정리되어 있습니다.
3. 표시가 필요한 attribution 요구사항이 약관에 생기면 게임 라이선스 화면에 추가합니다.

## 6. 자체 제작 아이콘·음원 (외부 라이선스 없음)

- 앱 아이콘(`assets/branding/`, `godot/icon.svg`): `tools/generate_icon.py`로 제작.
- SVG 아이콘(`tools/generate_ui_icons.py`로 그린 도형): 토글·드롭다운 화살표 3개가 현재 도형.
- 합성 음원: `tools/generate_placeholder_audio.py`.

## 7. 제출용 보관 체크리스트 (P3-004)

- [ ] Privacy Policy 3개 언어(`legal/PRIVACY_POLICY*.md`) 검토 후 호스팅, URL 확정
- [ ] 본 인벤토리 검토(특히 §5 AI 그림 약관 재확인)
- [ ] Play Console 데이터 안전 양식 응답 — `store/LISTING.md` 초안 참고
- [ ] Google Play·Steam 제출용 라이선스 표시 페이지에 Godot MIT·OFL·CC0 표기 포함
- [ ] 원본 zip과 생성 기록을 저장소 밖 보관소에 보관(증빙용)
