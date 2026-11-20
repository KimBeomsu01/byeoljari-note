# 개발 환경 설정 (팀원용)

이 문서만 따라 하면 내 컴퓨터에서 별자리노트 서버 + DB를 똑같이 켤 수 있어요.
처음 한 번은 30분쯤 걸려요 (대부분 설치 시간). 그다음부터는 명령 한두 줄이에요.

```
[브라우저 / 폰]  →  [앱 서버 :8093]  →  [DB (PostgreSQL)]
                     build/web 화면        시연 DB · 개발 DB
                     /api 처리
```
- 앱 서버와 DB는 **Docker** 안에서 돌아요. `backend/compose.yaml` 하나에 다 들어 있어요.
- 화면(Flutter 웹)은 내 컴퓨터에서 **빌드**해서 `build/web`에 만들고, 서버가 그 폴더를 그대로 보여 줘요.

---

## 0. 받아야 할 것

| 무엇 | 어디서 | 저장소에 있나 |
|---|---|---|
| 코드 | GitHub 저장소 (`v1.01` 브랜치) | ✅ 있어요 |
| **`.env` 파일** | **팀장에게 비공개로** (카톡 등) | ❌ 없어요. 공개 저장소라 일부러 뺐어요 |

`.env`에는 DB 비밀번호, 로그인 비밀번호, 계정 목록이 들어 있어요. **절대 GitHub에 올리거나 공개된 곳에 붙이지 마세요.**

---

## 1. 프로그램 설치 (처음 한 번)

| 프로그램 | 받는 곳 | 설치 확인 (PowerShell) |
|---|---|---|
| Git | https://git-scm.com | `git --version` |
| Docker Desktop | https://www.docker.com/products/docker-desktop | `docker compose version` |
| Flutter SDK 3.50 이상 (stable) | https://docs.flutter.dev/get-started/install | `flutter --version` |

- Docker Desktop은 설치 후 **실행해 둬야** 해요 (작업 표시줄에 고래 아이콘).
- Flutter는 압축을 푼 폴더의 `bin`을 PATH에 넣어요. `flutter --version`이 나오면 돼요.
- 웹 빌드만 하면 되니 Android Studio·Xcode는 지금은 없어도 돼요.

---

## 2. 코드 받기

PowerShell에서:
```powershell
cd C:\dev                      # 원하는 폴더 (OneDrive·바탕화면처럼 동기화되는 폴더는 피하기)
git clone https://github.com/KimBeomsu01/byeoljari-note.git
cd byeoljari-note
git checkout v1.01
```

---

## 3. `.env` 넣기

팀장에게 받은 `.env` 파일을 **`backend` 폴더 안에** 넣어요.
```
byeoljari-note/
  backend/
    .env            ← 여기
    .env.example
    compose.yaml
```
- 파일 이름이 정확히 `.env`인지 확인 (윈도우가 `.env.txt`로 바꾸는 경우가 있어요).
- 받은 파일이 없다면: `backend/.env.example`을 복사해서 `backend/.env`로 이름을 바꾸고 값을 채워요. 각 값의 뜻은 파일 안에 적혀 있어요.

---

## 4. 화면(웹) 빌드

**PowerShell에서** (또는 탐색기에서 `build_server_web.bat` 더블클릭):
```powershell
.\build_server_web.bat
```
맥이라면 터미널에서:
```bash
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=/api/
```
- 끝나면 `build/web` 폴더가 생겨요. 처음엔 몇 분 걸려요.
- ⚠️ **윈도우에서는 Git Bash로 빌드하지 마세요.** Git Bash가 `/api/`를 `C:/Program Files/Git/api/`로 바꿔 버려서, 접속하면 "서버에 연결하지 못했어요"만 떠요. PowerShell이나 bat 파일로만 빌드해요.

---

## 5. 서버 + DB 켜기

```powershell
cd backend
docker compose up -d
```
- 처음엔 이미지를 받고 만드느라 몇 분 걸려요.
- 처음 켜질 때 자동으로:
  1. DB(`byeoljari_dev`, `byeoljari_demo`)를 만들고 (`backend/db-init/`)
  2. 서버가 표를 만들고
  3. 처음 로그인하면 앱이 **시연 자료**(가상 별님 36명, 호출·채팅 시나리오)를 채워요.
- 잘 켜졌는지 확인:
  ```powershell
  docker compose ps
  ```
  `app`, `postgres`, `passkey-verifier` 세 개가 `Up`이고 postgres는 `(healthy)`면 돼요.

---

## 6. 접속

| 화면 | 주소 | 계정 |
|---|---|---|
| 모바일 (인수인계 · 체온 측정 · 별님카드) | http://localhost:8093/ | `demo` 또는 `dev` 계정 |
| PC (현황판 · 일정 · 의료 호출함) | http://localhost:8093/pc | `demo` 또는 `dev` 계정 |
| 의료진 협진 포털 | http://localhost:8093/doctor | `doctor` 계정만 |

- 계정 아이디는 `.env`의 `APP_ACCOUNTS`에 있어요. 비밀번호는 `APP_TEST_PASSWORD`.
- `demo` 계정 = 시연 DB (가상 자료 전부), `dev` 계정 = 개발 DB (예시 카드만).
- 모바일 화면은 크롬에서 F12 → 휴대폰 모양 아이콘을 누르면 폰 크기로 보여요.

### 같은 와이파이의 폰에서 보기
1. 서버 PC의 IP 찾기: PowerShell에서 `ipconfig` → "IPv4 주소"
2. 폰에서 `http://<서버 PC IP>:8093/`
3. 안 열리면 서버 PC의 방화벽에서 8093을 열어요 (**관리자** PowerShell):
   ```powershell
   New-NetFirewallRule -DisplayName "byeoljari 8093" -Direction Inbound -Protocol TCP -LocalPort 8093 -Action Allow
   ```
   회사·학교 와이파이는 기기끼리 접속을 막아 둔 곳도 있어요. 그때는 폰 핫스팟에 PC를 붙여 보세요.

> IP 주소는 문서·코드에 적어 올리지 마세요 (공개 저장소).

---

## 7. 평소 개발할 때

| 상황 | 할 일 |
|---|---|
| 새 코드 받기 | `git pull` |
| 화면(`lib/`)을 바꿨어요 | `.\build_server_web.bat` → 브라우저 새로고침 (서버는 그대로) |
| 서버 코드(`backend/*.dart`)를 바꿨어요 | `cd backend` → `docker compose up -d --build` |
| `.env`를 바꿨어요 | `cd backend` → `docker compose up -d` |
| 화면만 빠르게 고쳐 보기 (서버 없이) | `run_chrome.bat` (자료는 브라우저 안에만 저장) |
| 테스트 | `flutter test`, `flutter analyze` |

- 서버를 다시 켜면 로그인이 풀려요. 열어 둔 탭은 다시 로그인하면 돼요.
- 시연 자료를 처음 상태로: 앱 오른쪽 위 프로필 → **"시연 자료 처음 상태로"**.

---

## 8. 끄기 · 정리

```powershell
cd backend
docker compose down          # 끄기. 데이터는 남아요
docker compose up -d         # 다시 켜기. 데이터 그대로
```
- 켜고 끄기를 여러 번 해도 DB는 하나예요. 파일이 쌓이지 않아요.
- 서버 코드를 자주 다시 빌드하면 예전 이미지가 쌓여요. 가끔 정리해요:
  ```powershell
  docker image prune
  ```
  (안 쓰는 이미지만 지워요. DB 데이터는 안 지워져요.)
- ⚠️ **`docker compose down -v`** 는 DB 데이터까지 **전부 지워요.** 완전히 처음부터 다시 시작할 때만 써요. 그다음 `up -d` 하면 빈 DB부터 다시 만들어져요.

---

## 9. 자주 나는 문제

| 증상 | 원인 · 해결 |
|---|---|
| "서버에 연결하지 못했어요" | Git Bash로 빌드했어요 → PowerShell로 다시 빌드. `build\web\main.dart.js` 안에 `Program Files/Git`이 있으면 이 문제예요. |
| `Configure backend/.env` 오류 | `.env`가 `backend` 폴더에 없거나 값이 비었어요 (3번). |
| `port is already allocated` / 8093 사용 중 | 다른 프로그램이 8093을 쓰고 있어요. 그 프로그램을 끄거나, `compose.yaml`의 `"8093:8080"` 앞 숫자를 바꿔서 그 포트로 접속해요 (바꾼 건 올리지 않기). |
| `docker` 명령이 안 돼요 | Docker Desktop이 안 켜져 있어요. |
| 화면이 하얗거나 404 | `build/web`이 없어요 → 4번 빌드부터. |
| "로그인이 끝났어요" | 서버를 다시 켰거나 12시간이 지났어요 → 다시 로그인. |
| 비밀번호를 맞게 넣었는데 DB 오류 | `.env`의 `POSTGRES_PASSWORD`를 DB를 만든 뒤에 바꿨어요. DB 비밀번호는 처음 만들 때 정해져요 → 원래 값으로 되돌리거나 `docker compose down -v` 후 다시 켜기 (데이터 지워짐). |
| 로그 보기 | `docker compose logs app` / `docker compose logs postgres` |

---

## 10. 올리면 안 되는 것 (공개 저장소)

| 올라가요 ✅ | 올리지 않아요 ❌ |
|---|---|
| `lib/`, `web/`, `android/`, `ios/`, `test/` | `backend/.env` (비밀번호·계정) |
| `backend/` 서버 코드, `compose.yaml`, `db-init/`, `.env.example` | `backend/backup/` (DB 백업) |
| 빌드 스크립트, `README.md`, `SETUP.md`, `CLAUDE.md` | `backend/compose.override.yaml` (내 PC 전용 설정) |
| | `build/` (빌드 결과, 각자 만들기) |
| | IP 주소, 실제 사람 이름·정보 |

`.gitignore`로 막혀 있는 것도 있지만, `git add` 전에 `git status`로 한 번 확인해요.

---

## 참고
- 구조·규칙은 [`CLAUDE.md`](CLAUDE.md), 화면 소개와 설치형 앱(아이폰·안드로이드)은 [`README.md`](README.md).
- 내 PC에서만 다르게 돌리고 싶을 때는 `backend/compose.override.yaml`을 만들면 `docker compose`가 자동으로 같이 읽어요 (저장소에는 안 올라가요).
