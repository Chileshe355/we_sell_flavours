#!/bin/sh
set -eu

response="$({
  SCRIPT_NAME=/ping \
  SCRIPT_FILENAME=/ping \
  REQUEST_METHOD=GET \
  cgi-fcgi -bind -connect 127.0.0.1:9000
} 2>/dev/null)"

printf '%s\n' "$response" | tr -d '\r' | grep -qx 'pong'
