# byeoljari-note
혜진원 별님들의 체온 이력을 기록하고 생활관·사무국 간 확인을 돕는 팀 프로젝트

카카오 테크 포 임팩트 2조 "혜진아왜요쌤" · Flutter 앱

## 바로 보기 (폰·컴퓨터)
**https://kimbeomsu01.github.io/byeoljari-note/** — `main`에 올리면 몇 분 뒤 자동으로 바뀌어요.
- 아이폰: Safari로 열고 공유 → "홈 화면에 추가"하면 앱처럼 쓸 수 있어요.
- 가상 데이터만 있는 시연판이에요. 기록은 각 기기 브라우저에만 저장돼요.
- 처음 시연 상태로 돌리려면: 오른쪽 위 이름 버튼 → "시연 처음 상태로".

## 처음 받는 사람
1. Flutter SDK 설치 (stable, 3.50 이상) — https://docs.flutter.dev/get-started/install
2. 저장소 받기
   ```bash
   git clone https://github.com/KimBeomsu01/byeoljari-note.git
   cd byeoljari-note
   flutter pub get
   ```
3. 실행: `flutter run -d chrome` (Windows는 `run_web.bat` / `run_chrome.bat`를 더블클릭해도 돼요. 안의 Flutter 경로를 자기 PC에 맞게 고치세요)
4. 테스트: `flutter test`

> OneDrive·iCloud처럼 동기화되는 폴더 안에 받지 마세요. 빌드가 느려지거나 깨질 수 있어요.

## 문서
- 개발 규칙·구조·진행 상황: [`CLAUDE.md`](CLAUDE.md)
- 기준 명세: [`docs/spec/별자리노트_통합명세_v1.md`](docs/spec/별자리노트_통합명세_v1.md) (원본 기능 명세보다 우선)

## 꼭 지킬 것
- 실제 별님·직원 정보는 절대 넣지 않는다. 시드는 가상 명단만.
- 투약 용량 계산·추천 기능은 만들지 않는다.
