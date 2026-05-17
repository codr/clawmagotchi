#!/usr/bin/env bash
set -euo pipefail

CONFIG="${HOME}/.config/claude-ntfy/config.env"

if [[ ! -f "$CONFIG" ]]; then
  echo "claude-ntfy: config not found at $CONFIG — run install.sh first" >&2
  exit 0
fi

source "$CONFIG"

: "${NTFY_URL:=https://ntfy.sh}"
: "${NTFY_TOPIC:=}"
: "${NTFY_TOKEN:=}"

if [[ -z "$NTFY_TOPIC" ]]; then
  echo "claude-ntfy: NTFY_TOPIC not set in $CONFIG" >&2
  exit 0
fi

INPUT="$(cat)"

EVENT="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))")"
CWD="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))")"
MSG="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',''))")"

PROJECT="$(basename "$CWD")"

case "$EVENT" in
  Stop)
    TITLE="Claude Done"
    BODY="Finished in: $PROJECT"
    PRIORITY="default"
    ;;
  Notification)
    TITLE="Claude Needs Attention"
    BODY="${MSG:-Waiting for input}"
    PRIORITY="high"
    ;;
  *)
    TITLE="Claude: $EVENT"
    BODY="$PROJECT"
    PRIORITY="default"
    ;;
esac

AUTH_HEADER=()
if [[ -n "$NTFY_TOKEN" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer $NTFY_TOKEN")
fi

curl -s --max-time 5 \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -H "Tags: robot" \
  "${AUTH_HEADER[@]}" \
  -d "$BODY" \
  "$NTFY_URL/$NTFY_TOPIC" \
  > /dev/null || true

exit 0
