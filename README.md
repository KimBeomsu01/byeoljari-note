# 별자리노트

울산 혜진원 생활관 선생님들이 별님(거주인)의 체온을 빠르게 기록하고, 이상이 생기면 간호사·촉탁의와 바로 이어지게 돕는 앱이에요.
카카오 테크 포 임팩트 2조 "혜진아왜요쌤" · Flutter 웹 + Dart 서버 + PostgreSQL

## 화면
화면은 Claude Design 시안에 있는 것이 전부예요.

| 어디서 | 화면 | 하는 일 |
|---|---|---|
| 모바일 | 인수인계 | 반별 최신 기록, 근무 교대 서명, 기록 남기기 |
| 모바일 | 체온 측정 (가운데 버튼) | 별님 고르고 길게 눌러 체온 기록, 이상이면 대응 시트, **간호쌤 호출** |
| 모바일 | 별님카드 | 별님 정보·체온 흐름·지난 기록, 프로필 사진 기록(카카오톡처럼, 담당 선생님만 올리기) |
| PC | 현황판 | 반별 측정 현황, 이상 별님, 전체 거주인 명부 |
| PC | 일정 | 월 달력과 오늘 시간표 |
| PC | 의료 호출함 (간호사) | 호출함(앱에서 온 간호사 호출) → 의료진에게 보내기, 의료진별 채팅(아래로 펼침), 비대면 진단·처방 기록(날짜순) |
| 의료진 | 의료진 협진 포털 (`/doctor`) | 호출함(혜진원), 별님별 채팅(아래로 펼침, 안 읽은 수), 진단서·처방 작성·발행 |

## 주소와 계정
서버가 이 PC의 Docker에서 돌아요 (`backend/compose.yaml`).

| | 이 PC | 같은 네트워크 |
|---|---|---|
| 모바일 | http://localhost:8093/ | http://(이 PC IP):8093/ |
| PC 화면 (오피스 웹) | http://localhost:8093/pc | http://(이 PC IP):8093/pc |
| 의료진 협진 포털 | http://localhost:8093/doctor | http://(이 PC IP):8093/doctor |

로그인 계정과 비밀번호는 저장소에 없고 `backend/.env`에 있어요 (공개 저장소라서).
- `APP_ACCOUNTS`: `아이디:DB이름:demo|dev[:doctor]`를 쉼표로 이어 써요. 예: `<아이디>:<DB이름>:demo,<의료진 아이디>:<DB이름>:demo:doctor`
  - `demo` → **시연 DB**: Claude Design의 가상 자료가 모두 들어 있어요.
  - `dev` → **개발 DB**: 가상 자료 없이, 자리마다 "예시" 카드 하나만 보여요. 실제 기록이 생기면 예시는 사라져요.
  - `doctor` → **의료진(의사) 계정**: **`/doctor`에서만** 로그인돼요. 다른 계정은 `/doctor`에 못 들어가요.
- `APP_TEST_PASSWORD`: 모든 계정의 비밀번호.
- 두 DB는 같은 코드로 똑같이 움직여요. 다른 것은 처음 채워지는 자료뿐이에요.
- 패스키 로그인은 `https` 또는 `localhost` 주소에서만 돼요 (`backend/.env`의 `PASSKEY_ORIGIN`과 주소가 같아야 해요).

### 시연 전에
프로필(오른쪽 위) → **"시연 자료 처음 상태로"**. 시연 자료가 지금 시각 기준으로 다시 만들어져요.
의사 화면은 **`/doctor`** 주소로 따로 열어요 (강다혜 촉탁의로 바로 들어가요).

## 실행
### 서버 (평소 쓰는 방법)
1. DB 컨테이너(`byeoljari-note-db`)가 먼저 떠 있어야 해요.
2. 앱 빌드: `build_server_web.bat` (안의 Flutter 경로를 자기 PC에 맞게)
3. 서버 띄우기: `backend` 폴더에서 `docker compose up -d`
4. 위 주소로 접속. 다시 빌드한 뒤에는 브라우저만 새로고침하면 돼요.

### 설치형 앱 (아이폰 · 안드로이드)
설치형 앱은 모바일 화면(인수인계 · 체온 측정 · 별님카드)이에요. 서버 PC와 **같은 와이파이**에서 써요. `<서버 PC IP>`는 서버 PC에서 `ipconfig`로 확인해요.
- **아이폰 (맥북 필요):** Xcode · Flutter · CocoaPods 설치 → 아이폰을 USB로 연결 → `./build_ios.sh http://<서버 PC IP>:8093`
  - 처음 한 번: Xcode에서 `ios/Runner.xcworkspace` → Runner → Signing & Capabilities → Team에 내 Apple ID
  - 아이폰: 설정 → 일반 → VPN 및 기기 관리 → 내 Apple ID 신뢰. 무료 Apple ID는 7일마다 다시 설치해요.
- **안드로이드:** Android Studio가 있는 PC에서 `build_android.bat http://<서버 PC IP>:8093` → `build\app\outputs\flutter-apk\app-release.apk`를 폰에 옮겨 설치
- 로그인은 앱에 남아요 (12시간 뒤나 서버를 다시 켜면 다시 로그인). 패스키는 웹에서만 돼요.
- 앱으로 설치하지 않고 써 보려면: 아이폰 Safari로 서버 주소를 열고 공유 → "홈 화면에 추가".

### 서버 없이 (화면만 볼 때)
- `run_chrome.bat` — 개발용, `r`로 바로 반영. 시연 자료가 브라우저 안에만 저장돼요.
- `run_web.bat` — 빌드 후 일반 Chrome에서 열기.

### 테스트
```bash
flutter test
flutter analyze
```

## 처음 받는 사람
1. Flutter SDK (stable 3.50 이상)
2. `git clone` 후 `flutter pub get`
3. `backend/.env` 만들기: `POSTGRES_PASSWORD`, `APP_TEST_PASSWORD`, 필요하면 `PASSKEY_ORIGIN`

> OneDrive·iCloud처럼 동기화되는 폴더 안에 받지 마세요. 빌드가 느려지거나 깨질 수 있어요.

## 꼭 지킬 것
- 실제 별님·직원 정보는 절대 넣지 않는다. 시연 자료는 가상 명단만.
- 투약 용량 계산·추천 기능은 만들지 않는다. 처방은 의사가 직접 쓴 내용만 저장·표시.

개발 규칙과 구조는 [`CLAUDE.md`](CLAUDE.md)를 보세요.
