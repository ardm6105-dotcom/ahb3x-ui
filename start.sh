#!/bin/bash
set -eu

# ===== مقادیر قابل تنظیم از Railway → Variables =====
PANEL_PATH="${PANEL_PATH:-/managepanel}"
WS_PATH="${WS_PATH:-/wspath}"
SUB_PATH="${SUB_PATH:-/subpath}"
PANEL_PORT="${PANEL_PORT:-2053}"
WS_PORT="${WS_PORT:-10001}"
SUB_PORT="${SUB_PORT:-2096}"
PANEL_USER="${PANEL_USER:-admin}"
PANEL_PASS="${PANEL_PASS:-ChangeMe123!}"
PORT="${PORT:-8080}"

export PANEL_PATH WS_PATH SUB_PATH PANEL_PORT WS_PORT SUB_PORT PANEL_USER PANEL_PASS PORT

echo ">> تنظیم یوزر/پسورد/پورت/مسیر پنل به‌صورت ثابت (تا بوت‌استرپ بتونه لاگین کنه) ..."
/app/x-ui setting -username "${PANEL_USER}" -password "${PANEL_PASS}" || true
/app/x-ui setting -port "${PANEL_PORT}" || true
/app/x-ui setting -webBasePath "${PANEL_PATH}" || true

echo ">> ساخت nginx.conf از روی template ..."
envsubst '${PORT} ${PANEL_PATH} ${WS_PATH} ${SUB_PATH} ${PANEL_PORT} ${WS_PORT} ${SUB_PORT}' \
  < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

mkdir -p /var/lib/nginx/tmp /var/log/nginx
nginx -t

echo ">> اجرای 3x-ui در پس‌زمینه ..."
/app/x-ui &
XUI_PID=$!

echo ">> اجرای بوت‌استرپ خودکار اینباند در پس‌زمینه ..."
/bootstrap-inbound.sh &
BOOT_PID=$!

trap "kill $XUI_PID $BOOT_PID 2>/dev/null || true" EXIT

echo ">> اجرای nginx روی پورت ${PORT} (پروسه اصلی کانتینر) ..."
exec nginx -g "daemon off;"
