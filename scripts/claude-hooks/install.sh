#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
INSTALL_PATH="${BIN_DIR}/claude-ntfy"
CONFIG_DIR="${HOME}/.config/claude-ntfy"
CONFIG_PATH="${CONFIG_DIR}/config.env"
SETTINGS_PATH="${HOME}/.claude/settings.json"

echo "=== Claude Code → ntfy.sh hook installer ==="
echo ""

# Dependency checks
for cmd in curl jq openssl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not found." >&2
    [[ "$cmd" == "jq" ]] && echo "  Install with: brew install jq" >&2
    exit 1
  fi
done

# Install notify script
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/ntfy.sh" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
echo "✓ Installed notify script → $INSTALL_PATH"

# Create config
mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_PATH" ]]; then
  echo "✓ Config already exists at $CONFIG_PATH (skipping generation)"
else
  GENERATED_TOPIC="$(openssl rand -hex 32)"
  echo ""
  echo "Generated a random ntfy topic: $GENERATED_TOPIC"
  echo "Press Enter to use it, or type your own topic and press Enter:"
  read -r USER_TOPIC
  NTFY_TOPIC="${USER_TOPIC:-$GENERATED_TOPIC}"

  echo ""
  echo "ntfy URL (press Enter for https://ntfy.sh, or enter your self-hosted URL):"
  read -r USER_URL
  NTFY_URL="${USER_URL:-https://ntfy.sh}"

  echo ""
  echo "ntfy Bearer token (press Enter to skip — only needed for self-hosted ntfy with auth):"
  read -r -s USER_TOKEN
  NTFY_TOKEN="${USER_TOKEN:-}"

  cat > "$CONFIG_PATH" <<EOF
NTFY_URL=${NTFY_URL}
NTFY_TOPIC=${NTFY_TOPIC}
NTFY_TOKEN=${NTFY_TOKEN}
EOF
  chmod 600 "$CONFIG_PATH"
  echo "✓ Config written → $CONFIG_PATH"
fi

source "$CONFIG_PATH"

# Merge hooks into ~/.claude/settings.json
[[ -f "$SETTINGS_PATH" ]] || echo '{}' > "$SETTINGS_PATH"

jq --arg cmd "$INSTALL_PATH" '
  .hooks.Stop //= [] |
  if (.hooks.Stop | map(.hooks[]?.command) | index($cmd)) then .
  else .hooks.Stop += [{"hooks":[{"type":"command","command":$cmd,"async":true,"timeout":10}]}] end |
  .hooks.Notification //= [] |
  if (.hooks.Notification | map(.hooks[]?.command) | index($cmd)) then .
  else .hooks.Notification += [{"hooks":[{"type":"command","command":$cmd,"async":true,"timeout":10}]}] end
' "$SETTINGS_PATH" > /tmp/_claude_settings.json && mv /tmp/_claude_settings.json "$SETTINGS_PATH"

echo "✓ Hooks merged into $SETTINGS_PATH"

echo ""
echo "=== Done! ==="
echo ""
echo "Subscribe URL for the ntfy app:"
echo "  ${NTFY_URL}/${NTFY_TOPIC}"
echo ""
echo "To test: finish any Claude Code prompt — you should receive a notification."
