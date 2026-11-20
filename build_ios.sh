#!/bin/bash
# 맥북에서 아이폰 설치형 앱 설치하기 (아이폰을 USB로 연결하고 실행).
#   ./build_ios.sh http://<서버 PC IP>:8093
# 서버 PC IP는 서버 PC에서 ipconfig 로 확인한다 (아이폰 · 서버 PC가 같은 와이파이).
# 처음 한 번: Xcode에서 ios/Runner.xcworkspace 열기 → Runner → Signing & Capabilities → Team 에 내 Apple ID 선택.
# 아이폰: 설정 → 일반 → VPN 및 기기 관리 → 내 Apple ID 신뢰 (무료 Apple ID는 7일마다 다시 설치).
set -e
cd "$(dirname "$0")"
if [ -z "$1" ]; then
  echo "서버 주소를 붙여 주세요. 예: ./build_ios.sh http://<서버 PC IP>:8093"
  exit 1
fi
SERVER="${1%/}"
echo "서버: $SERVER"
flutter pub get
flutter run --release --dart-define=API_BASE_URL="$SERVER/api/"
