#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-8080}"

for pid in $(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true); do
  command="$(ps -p "$pid" -o command= 2>/dev/null || true)"

  # หยุดเฉพาะ process ที่เป็น server.js ของ QuakeLink
  if [[ "$command" == *"server.js"* ]]; then
    parent="$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ' || true)"
    echo "หยุด QuakeLink server เก่าที่ PID $pid"
    kill "$pid" 2>/dev/null || true

    if [[ -n "$parent" ]]; then
      parent_command="$(ps -p "$parent" -o command= 2>/dev/null || true)"
      if [[ "$parent_command" == *"nodemon"* && "$parent_command" == *"server.js"* ]]; then
        echo "หยุด nodemon เก่าที่ PID $parent"
        kill "$parent" 2>/dev/null || true
      fi
    fi
  fi
done

exec nodemon server.js
