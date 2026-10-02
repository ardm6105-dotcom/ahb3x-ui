#!/bin/bash
set -u

PANEL_PATH="${PANEL_PATH:-/managepanel}"
PANEL_PORT="${PANEL_PORT:-2053}"
PANEL_USER="${PANEL_USER:-admin}"
PANEL_PASS="${PANEL_PASS:-ChangeMe123!}"
WS_PORT="${WS_PORT:-10001}"
WS_PATH="${WS_PATH:-/wspath}"
REMARK="${INBOUND_REMARK:-ای اچ بی |AHB PANEL}"

STATE_DIR="/etc/x-ui-bootstrap"
mkdir -p "$STATE_DIR"

# ===== UUID و subId ثابت =====
# اگه از قبل ساخته شده (redeploy روی همون کانتینر) همونا رو نگه می‌داریم
# تا سابلینک و کانفیگ کلاینت عوض نشه. برای پایداری کامل بین ری‌دیپلوی‌ها،
# یک Volume روی /etc/x-ui-bootstrap در Railway وصل کنید یا CLIENT_UUID/SUBID
# را در Variables دستی ثابت بدید.
if [ -f "$STATE_DIR/uuid" ]; then
  CLIENT_UUID=$(cat "$STATE_DIR/uuid")
else
  CLIENT_UUID="${CLIENT_UUID:-$(cat /proc/sys/kernel/random/uuid)}"
  echo "$CLIENT_UUID" > "$STATE_DIR/uuid"
fi

if [ -f "$STATE_DIR/subid" ]; then
  SUBID=$(cat "$STATE_DIR/subid")
else
  SUBID="${SUBID:-$(head -c 32 /dev/urandom | md5sum | cut -c1-16)}"
  echo "$SUBID" > "$STATE_DIR/subid"
fi

echo "$CLIENT_UUID" > "$STATE_DIR/uuid.current"
echo "$SUBID" > "$STATE_DIR/subid.current"

BASE="http://127.0.0.1:${PANEL_PORT}${PANEL_PATH}"
COOKIE="$STATE_DIR/cookie.txt"

login() {
  curl -s -c "$COOKIE" -X POST "$BASE/login" \
    --data-urlencode "username=${PANEL_USER}" \
    --data-urlencode "password=${PANEL_PASS}" > /dev/null
}

inbound_exists() {
  curl -s -b "$COOKIE" "$BASE/panel/api/inbounds/list" \
    | jq -e --arg r "$REMARK" '.obj[]? | select(.remark == $r)' > /dev/null 2>&1
}

create_inbound() {
  SETTINGS=$(jq -n --arg id "$CLIENT_UUID" --arg sub "$SUBID" '{
    clients: [{id:$id, flow:"", email:"ahbpanel", limitIp:0, totalGB:0, expiryTime:0, enable:true, tgId:"", subId:$sub, comment:"", reset:0}],
    decryption:"none", fallbacks: []
  }')
  STREAM=$(jq -n --arg path "$WS_PATH" '{
    network:"ws", security:"none", wsSettings:{path:$path, headers:{}}
  }')
  SNIFF='{"enabled":true,"destOverride":["http","tls"]}'

  curl -s -b "$COOKIE" -X POST "$BASE/panel/api/inbounds/add" \
    --data-urlencode "up=0" \
    --data-urlencode "down=0" \
    --data-urlencode "total=0" \
    --data-urlencode "remark=${REMARK}" \
    --data-urlencode "enable=true" \
    --data-urlencode "expiryTime=0" \
    --data-urlencode "listen=127.0.0.1" \
    --data-urlencode "port=${WS_PORT}" \
    --data-urlencode "protocol=vless" \
    --data-urlencode "settings=${SETTINGS}" \
    --data-urlencode "streamSettings=${STREAM}" \
    --data-urlencode "sniffing=${SNIFF}"
}

echo ">> بوت‌استرپ: صبر برای بالا اومدن پنل روی ${BASE} ..."
for i in $(seq 1 60); do
  if curl -s -o /dev/null "${BASE}/login"; then
    break
  fi
  sleep 2
done

echo ">> بوت‌استرپ: لاگین اولیه ..."
login

echo ">> بوت‌استرپ: حلقه‌ی نگهبان اینباند «${REMARK}» شروع شد (هر ۶۰ ثانیه چک می‌کنه) ..."
while true; do
  login
  if ! inbound_exists; then
    echo ">> اینباند «${REMARK}» پیدا نشد یا پاک شده بود؛ در حال ساخت/بازسازی خودکار ..."
    create_inbound > /dev/null
  fi
  sleep 60
done
