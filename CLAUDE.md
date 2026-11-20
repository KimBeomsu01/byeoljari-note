# 별자리노트 (Flutter 웹 + Dart 서버)

혜진원 생활관 체온 기록 앱. 모바일 3화면(인수인계·체온 측정·별님카드) + PC 3화면(현황판·일정·의료 호출함) + 의료진 협진 포털(`/doctor`).
사람용 소개·주소·계정은 `README.md`.

## 기준
- **화면은 Claude Design 시안이 기준이다** (https://claude.ai/artifact/2nWMZMroLD5NqHPxckW8Sv). 시안에 없는 화면은 만들지 않는다.
- 모바일 일정 기능은 없앴다. PC 일정 페이지는 시안에 있어서 남겼다.
- `docs/spec/`, `docs/design.md`는 예전 명세다. 판정·기록 규칙의 배경으로만 보고, 화면 모양은 따르지 않는다.
- 백엔드·DB 구조는 되도록 건드리지 않는다. 바꿔야 하면 사용자에게 먼저 묻는다.

## 절대 규칙
- 실제 별님·직원 정보 금지. 시연 자료는 `lib/core/seed.dart`의 가상 명단(6반 36명)만.
- 투약 용량 계산·추천 코드 금지. 처방은 의사가 쓴 내용을 저장·표시만.
- 체온은 정수 ×10 (365 = 36.5℃), 입력 범위 34.0~42.0.
- 판정은 `lib/core/judgment.dart` 하나만 쓴다 (위험 +1.5 또는 39.0 / 이상 +1.0 또는 38.0 / 저온 / 주의 / 평소). 판정은 저장할 때 측정에 함께 저장한다.
- 기록을 지우는 코드 금지. 잘못 잰 값은 `voidMeasurement` + 새 측정(`correctsId`).
- 체온 입력은 퀵 체온 화면 하나뿐. 다른 화면은 `quickTempProvider.notifier.openFor(residentId)`로 연다.
- 모든 체온 저장은 `InMemoryRepository.saveMeasurement` 한 곳. 이상 건 생성·긴급 승격·의료 호출 자동 생성이 여기서 일어난다.

## 구조
```
lib/
  main.dart          API_BASE_URL이 있으면 ServerApp, 없으면 기기 안 저장(시연 자료)으로 실행
  server_app.dart    로그인 화면(패스키 포함) · _ServerStore(서버 저장, 4초마다 동기화, 409 처리)
  app.dart           모바일 틀: 탭 2개 + 가운데 퀵 체온 레이어, 프로필 메뉴(사용자 바꾸기·초기화·로그아웃)
  core/
    models.dart      별님·직원·측정·이상 건·의료 호출·처방·승인·서명 등
    repository.dart  InMemoryRepository: 상태 전체 + 모든 쓰기 동작, JSON 스냅샷 저장/복원
    seed.dart        시연 DB 자료 (Claude Design 시나리오)
    dev_seed.dart    개발 DB 예시 명단 (ex_*)
    judgment.dart · baseline.dart   판정·기저치
    theme.dart · ds.dart            디자인 토큰(Ds, T)과 공통 부품(DsCard, DsButton, DsTag, ExampleWrap …)
    providers.dart   repoProvider, screenKindProvider, currentUserProvider, clockProvider
  features/
    handover/        인수인계
    quick_temp/      체온 측정
    alert_case/      이상 대응 시트·상세
    resident_card/   별님카드
    pc/              PC 틀(pc_shell) · 현황판(pc_dashboard_*) · 일정(pc_schedule_*) · 호출함/의사(pc_calls_*, pc_doctor_page)
backend/             Dart 서버(server.dart, passkey.dart) + passkey-verifier(Node) + compose.yaml
test/core, test/features
```
- 상태: Riverpod 3. 화면은 `ref.watch(repoProvider)`로 읽고, 쓰기는 repository 메서드로만.
- 주소 → 화면: `/pc` 오피스 웹(PC), `/doctor` 의료진 협진 포털(의사만, PC 틀), 그 밖 모바일 (`screenKindOf`). PC는 폭 1280 기준.
- 모바일(체온 측정 · 인수인계 · 별님카드)은 **내 담당 반만** 보인다: `repo.myClasses(me)` (생활관 선생님은 담임 반 + 배치 반, 간호·사무·원장·의사·야간 당직은 전체 반). 반이 없는 전체 공지는 모두에게. 다른 화면에서 특정 별님으로 따로 연 별님카드는 그 반도 보인다.

## 서버와 DB
- 앱 컨테이너 `byeoljari-new2-app-1`이 8093 포트에서 `build/web`을 그대로 서빙하고 `/api/*`를 처리한다. 빌드만 다시 하면 컨테이너는 그대로 둬도 된다.
- DB 컨테이너 `byeoljari-note-db-postgres-1` (네트워크 `byeoljari-note-db_default`).
- 계정은 저장소에 쓰지 않는다 (공개 저장소). `backend/.env`의 `APP_ACCOUNTS` (`아이디:DB이름:demo|dev[:doctor]`, 쉼표로)와 `APP_TEST_PASSWORD`. 서버가 `GET /api/state`로 `dataset`(demo · dev)과 `doctor`를 알려 주고, 앱은 그 값으로 DB 종류와 화면을 정한다.
- 의료진(doctor) 계정은 `/doctor`에서만, `/doctor`는 의료진 계정만 로그인된다 (서버 로그인 + 앱 둘 다 확인).
- 의료 호출 흐름: 앱 간호쌤 호출(`callNurse`, 별님카드에 기록) → 의료 호출함(간호사) 호출함 → 간호사가 의료진에게 보냄(`forwardCall`, `MedicalCall.doctorId`) → 의료진 협진 포털. 간호사 채팅방 = 의료진별(`doc:<의사>`), 의사 채팅방 = 별님별(`res:<별님>`), 안 읽은 수는 `_reads`(스냅샷 `reads`). 채팅은 목록 사이에서 아래로 펼친다 (`pc_medical_rooms.dart`).
- 상태는 계정마다 JSON 한 덩어리: `byeoljari_new2.snapshot` (id=1, version으로 낙관적 잠금, 충돌 시 409).
- 같은 DB의 `public`, `experiment01`, `work_new` 스키마는 다른 프로젝트 것이다. 건드리지 않는다.
- 스냅샷 형식: `{v:1, schema:2, dataset: demo|dev, ...}`. 명단(직원·반·별님·배치·근무조)도 스냅샷 안에 있다. `schema`가 2가 아니면 새로 채운다.
- API: `POST /api/login`, `POST /api/logout`, `POST /api/passkey/*`, `GET/PUT /api/state` (GET은 `login`도 돌려준다), `POST /api/photo` · `GET /api/photo/<id>` (별님 프로필 사진).
- 프로필 사진 파일은 `byeoljari_new2.photo` 표(bytea)에, 누가·언제 올렸는지는 스냅샷 `photos`에 저장한다. 사진은 브라우저에서 긴 쪽 1280px JPEG로 줄여 올린다 (`web/photos.js`). 올리기는 그 반 담당(담임·배치) 선생님만.

## 두 DB
- **시연 DB:** `seed.dart`의 가상 자료 전부. 날짜는 채운 시각 기준(11시 이후면 오늘, 아니면 어제). 프로필 → "시연 자료 처음 상태로"로 다시 만든다.
- **개발 DB:** 가상 자료 없음. 명단 예시(`example: true`)는 실제 항목이 하나라도 생기면 숨겨진다. 목록 예시는 `repo.isDev`이고 목록이 비었을 때만 `ExampleWrap`으로 그린다 (DB에는 저장하지 않음).
- 실제 동작은 두 DB가 같아야 한다. 데이터셋으로 분기하는 코드는 처음 자료와 예시 표시에만 둔다.
- 새 기능에 저장할 자료가 생기면: 모델 JSON → `toSnapshotMap`/`_restore` → 시연 시드 → 개발 DB 예시까지 함께 넣는다.

## 명령
Flutter SDK 3.50 이상. bat 파일은 `D:\dev\flutter` 경로를 쓴다 (자기 PC에 맞게 고친다).
```
flutter test
flutter analyze
flutter build web --release --dart-define=API_BASE_URL=/api/     # 서버용 빌드 (= build_server_web.bat)
```
- **서버용 빌드는 PowerShell이나 bat로만.** Git Bash에서 돌리면 `/api/`가 `C:/Program Files/Git/api/`로 바뀌어 모든 요청이 실패한다 ("서버에 연결하지 못했어요"). 빌드 후 `build\web\main.dart.js`에 `Program Files/Git`이 없어야 한다.
- 서버 다시 띄우기: `backend`에서 `docker compose up -d`.
- 화면 흐름은 위젯 테스트로 확인한다 (`test/features/`). 테스트 시계는 고정(`clockAt`).
- `package:flutter/material.dart`의 "material_ui로 옮기라" info는 무시해도 된다.

## 디자인
- 토큰은 `lib/core/theme.dart`의 `Ds`(색)·`T`(글자 크기). 모바일은 보라(`Ds.violet`), PC는 파랑(`Ds.blue`) 강조.
- 공통 부품은 `lib/core/ds.dart`를 먼저 찾아 쓴다.
- 모바일 화면은 가운데 정렬, 최대 폭 440.
- 글꼴: Pretendard (KS X 1001 한글 2,350자로 줄인 파일, `assets/fonts/Pretendard-*.ttf`, 라이선스 `Pretendard-LICENSE.txt`). 없는 글자는 기기 글꼴로 그려진다.
- 앱 아이콘 원본: `icon/screen.png`. 웹·안드로이드·iOS 아이콘은 여기서 잘라 만들었다.

## 알려진 한계
- 산소포화도·맥박·혈압은 자료가 없어 "기록 없음"으로 보인다.
- 전화·영상통화·인쇄·엑셀은 실제로 하지 않고 안내만 띄운다.
- GitHub Pages 시연판은 쓰지 않는다 (배포 설정 삭제함).
- 설치형 앱(아이폰·안드로이드): `--dart-define=API_BASE_URL=http://<서버 PC IP>:8093/api/` (`build_ios.sh` · `build_android.bat`). 쿠키 대신 Bearer 토큰을 `shared_preferences`에 저장, 사진은 `photoAccessProvider`(서버 주소 + 토큰)로 받고 `image_picker`로 고른다. 패스키는 웹 전용. 이 Windows PC에는 Android SDK가 없어 설치 파일은 여기서 못 만든다.
