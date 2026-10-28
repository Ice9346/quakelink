#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
env_file="$project_root/server/.env"
config_file="$project_root/web/google_maps_config.js"

if [[ ! -f "$env_file" ]]; then
  echo "ไม่พบ $env_file"
  exit 1
fi

maps_key="$(awk -F= '$1 == "GOOGLE_MAPS_API_KEY" { sub(/^[^=]*=/, ""); print; exit }' "$env_file")"
if [[ -z "$maps_key" ]]; then
  echo "กรุณาใส่ GOOGLE_MAPS_API_KEY ใน server/.env ก่อน"
  exit 1
fi

printf "window.__GOOGLE_MAPS_API_KEY__ = '%s';\n" "$maps_key" > "$config_file"
cd "$project_root"

if lsof -nP -iTCP:5173 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "เว็บกำลังรันอยู่แล้วที่ http://127.0.0.1:5173"
  echo "กรุณารีเฟรชหน้าเว็บด้วย Cmd + Shift + R"
  exit 0
fi

exec flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5173
