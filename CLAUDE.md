# 별자리노트 (Flutter)

울산 혜진원 생활관 선생님들이 별님(거주인)의 체온 이상을 빠르게 공유하는 앱. 카카오 테크 포 임팩트 2조 "혜진아왜요쌤".

## 기준 문서
- **`docs/spec/별자리노트_통합명세_v1.md`가 최우선.** 원본 기능 명세(같은 폴더)와 다르면 통합 명세를 따른다.
- 버튼 하나하나의 동작은 원본 기능 명세를 본다 (퀵 체온, 이상 대응, 인수인계, 아카이브, 일정, 사무국 PC 웹).
- `docs/spec/`은 OneDrive `별자리노트_v2` 폴더의 사본이다. 명세가 바뀌면 사본을 다시 복사한다.

## 절대 규칙 (통합 명세 11-4)
- 실제 별님·직원 정보 금지. 시드는 `lib/core/seed.dart`의 가상 명단(6반 36명)만.
- 투약 용량 계산·추천 코드 금지. 투약 지침은 의료진이 쓴 글을 그대로 보여주기만.
- 체온은 정수 ×10 (365 = 36.5℃). 입력 범위 34.0~42.0.
- 판정은 `lib/core/judgment.dart` 하나만 쓴다. 화면마다 따로 계산하지 않는다. 판정은 저장 시점에 측정에 함께 저장한다.
- 기록을 지우는 코드 금지. 잘못 잰 값은 무효 표시 + 새 측정(`correctsId`).
- 체온 입력은 앱 전체에서 퀵 체온 화면 하나뿐. 다른 화면은 `quickTempProvider.notifier.openFor(residentId)`로 연다.
- 화면 이름: 위험이 나온 이상 건 = **"긴급"**, 이상·저온만 = **"이상 대응"** (데이터는 `Case` 하나, `Case.isUrgent`).

## 구조
```
lib/
  core/      models.dart · judgment.dart · baseline.dart · seed.dart · repository.dart · providers.dart · theme.dart
  features/  quick_temp/ · alert_case/ · handover/ · (archive/ · schedule/ · resident_card/ · desk/ 예정)
  app.dart   하단 메뉴 3개 + 가운데 퀵 체온 레이어 + 🔔 + 시연용 역할 바꾸기
test/        core/ (판정·기저치·저장 흐름) · features/ (화면 흐름)
```
- 상태: Riverpod 3 (`flutter_riverpod`). 저장소는 `InMemoryRepository`(가짜, 기기 안). 서버가 정해지면 같은 메서드로 실제 구현을 만든다.
- 모든 체온 저장은 `InMemoryRepository.saveMeasurement` 한 곳에서. 할 일 자동 완료·이상 건 생성·긴급 승격·종료 대기·알림이 여기서 일어난다 (통합 명세 7-1).
- `core/`를 바꿀 때는 팀에 먼저 알린다. 각자 자기 `features/` 폴더를 맡는다.

## 명령
Flutter SDK: `D:\dev\flutter` (PATH에 등록됨).
- **실행:** `run_web.bat` (빌드 후 일반 Chrome에서 열림, 기록이 브라우저에 남음) / `run_chrome.bat` (개발용, `r`로 바로 반영, 실행마다 기록 초기화).
- Claude Code의 Bash는 샌드박스라 거기서 받은 패키지가 실제 PC에 안 보일 수 있다. 패키지를 추가하면 사용자 터미널에서 `flutter pub get`을 한 번 돌린다 (두 bat 파일은 시작할 때 자동으로 한다).
```bash
flutter test                 # 모든 테스트
flutter analyze              # 정적 분석
flutter run -d chrome        # 크롬에서 실행
flutter build web            # build/web 에 웹 빌드
```
- 판정·기저치를 건드리면 반드시 경계값 테스트를 추가한다 (`test/core/judgment_test.dart`).
- 화면 흐름은 위젯 테스트로 확인한다 (`test/features/`). 작은 폰(360×640)에서 넘치지 않는지도 본다.
- `package:flutter/material.dart` 사용 시 Flutter 3.47부터 "material_ui로 옮기라"는 info가 뜬다. 지금은 무시해도 된다.

## 진행 상황
| 화면 | 상태 |
|---|---|
| 공통 (모델·판정·기저치·시드·저장 흐름·일정 시드·근무조) | ✅ 테스트 포함 |
| 기기 안 저장 (`core/storage.dart`) + 시연 초기화·시계 30분 앞으로 (역할 메뉴) | ✅ |
| 퀵 체온 (QT) | ✅ 1차 |
| 인수인계 (HO-1 최신 기록, HO-2 별님별 기록, HO-W 작성 시트) | ✅ 1차 |
| 일정 (SC-1, SC-2, SC-U 고정 예시) | ✅ 1차 |
| 별님 아카이브 (AR) · 별님카드 (PF) | ✅ 1차 |
| 이상 대응 (S1 경고, S2 알림·배너, S3 상세, S4 지침, S5 단계, S7 종료) | ✅ 1차 |
| 사무국 PC 웹 (DESK), 서버·실제 푸시, 로그인 | ⬜ |

남은 공통 부분 할 일: 담당 넘기기·다시 열기·재측정 취소, AppNotice에 actorId, 확인 취소, 오측정 종료 알림 문구 (이상 대응·인수인계 에이전트 보고).

## 에이전트·스킬 (harness-100 17-mobile-app-builder에서 골라 옴)
- `.claude/agents/app-developer.md` — 기능 구현
- `.claude/agents/qa-engineer.md` — 명세 ↔ 코드 대조 검사
- `.claude/skills/mobile-ux-patterns/` — 빈·로딩·오류 상태, 접근성, 제스처 참고 (원본 그대로)
