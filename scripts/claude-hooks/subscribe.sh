#!/usr/bin/env bash
set -euo pipefail

CONFIG="${HOME}/.config/claude-ntfy/config.env"

if [[ ! -f "$CONFIG" ]]; then
  echo "claude-ntfy: config not found at $CONFIG — run install.sh first" >&2
  exit 1
fi

source "$CONFIG"

: "${NTFY_URL:=https://ntfy.sh}"
: "${NTFY_TOPIC:=}"
: "${NTFY_TOKEN:=}"

if [[ -z "$NTFY_TOPIC" ]]; then
  echo "claude-ntfy: NTFY_TOPIC not set in $CONFIG" >&2
  exit 1
fi

AUTH_HEADER=()
if [[ -n "$NTFY_TOKEN" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer $NTFY_TOKEN")
fi

echo "Subscribing to ${NTFY_URL}/${NTFY_TOPIC} ..."
echo "Press Ctrl+C to stop."
echo ""

curl -s --no-buffer \
  ${AUTH_HEADER[@]+"${AUTH_HEADER[@]}"} \
  "${NTFY_URL}/${NTFY_TOPIC}/json" \
  | while IFS= read -r line; do
      EVENT="$(echo "$line" | jq -r '.event // ""')"
      [[ "$EVENT" == "keepalive" || "$EVENT" == "open" ]] && continue
      TITLE="$(echo "$line" | jq -r '.title // ""')"
      MSG="$(echo "$line" | jq -r '.message // ""')"
      TIME="$(date -r "$(echo "$line" | jq -r '.time // 0')" '+%H:%M:%S' 2>/dev/null || date '+%H:%M:%S')"
      echo "[$TIME] ${TITLE}: ${MSG}"
    done
