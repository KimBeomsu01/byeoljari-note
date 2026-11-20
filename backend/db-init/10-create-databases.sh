#!/bin/sh
# DB 볼륨이 비어 있을 때(처음 켤 때) 한 번만 실행된다.
# APP_ACCOUNTS(아이디:DB이름:demo|dev[:doctor], 쉼표로)에 나오는 DB 이름마다 DB를 만든다.
for db in $(printf '%s' "$APP_ACCOUNTS" | tr ',' '\n' | tr -d ' \r' | cut -d: -f2 | sort -u); do
  case "$db" in
    '' | *[!A-Za-z0-9_]*) echo "건너뜀: DB 이름 '$db'"; continue ;;
  esac
  echo "DB 만들기: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -c "CREATE DATABASE \"$db\""
done
