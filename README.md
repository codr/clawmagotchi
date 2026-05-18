# Clawmagotchi

A physical pocket device that watches your Claude Code sessions and tells you when one needs input.

It looks like a tamagotchi: a small round screen with a lobster DJ spinning one vinyl record per active session. When a session is waiting for you, that record pulses red and the device buzzes.

---

## Architecture

```
Claude Code (Mac)
  └── hooks
        ├── POST ntfy.sh/{topic}        → phone push notification (instant)
        └── POST /api/session/*         → Next.js API (session state)
                                                  │
                                         Next.js API Routes
                                         (session state, Map → Redis)
                                                  │
                                       ┌──────────┴──────────┐
                                  Vite + React           ESP32-C6
                                  (browser display)     (pocket device)
                                  polls /api/status     polls /api/status
```

**Four parts:**

| Part | What it does |
|---|---|
| **Claude Code hooks** | Shell scripts that fire on session lifecycle events and POST to ntfy.sh + the API |
| **ntfy.sh** | Zero-infrastructure push relay — phone buzzes instantly, no server required |
| **Web app** | Next.js API tracking session state; Vite + React frontend showing the lobster DJ |
| **ESP32-C6** | Polls the API over WiFi, drives the round display and haptic motor |

---

## Project Structure

```
clawmagotchi/
├── scripts/
│   └── claude-hooks/
│       ├── ntfy.sh             # Notification script (installed to ~/.local/bin/claude-ntfy)
│       ├── subscribe.sh        # Stream notifications to terminal for testing
│       ├── install.sh          # Installs hooks + merges ~/.claude/settings.json
│       └── config.env.example  # Template for ntfy credentials
└── src/                        # Next.js app (Phase 3+)
```

Future phases will add `apps/`, `packages/types/`, and `firmware/` directories.

---

## Hook Events

Claude Code fires these events at key session moments. Each pipes JSON to stdin of a shell command.

| Event | When | ntfy priority |
|---|---|---|
| `SessionStart` | Session opens | `min` — suppressed |
| `PermissionRequest` | Claude is blocked waiting for tool approval | `high` — loud + vibrate |
| `Notification` | Claude explicitly signals it needs attention | `high` — loud + vibrate |
| `Stop` | Claude finishes a turn | `default` |
| `SessionEnd` | Session closes | `min` — suppressed |

---

## Getting Started (Phase 1 — ntfy.sh only)

No server or device needed. This gives you instant phone notifications today.

```bash
# 1. Install dependencies
npm install

# 2. Install hook scripts and configure ntfy credentials
npm run hooks:install

# 3. Subscribe to your topic in the ntfy app (iOS / Android, free)
#    The install script prints your subscribe URL.

# Optional: stream notifications to your terminal for testing
npm run hooks:subscribe
```

That's it. The next time Claude Code waits for your input, your phone buzzes.

### `~/.claude/settings.json` hook config

`install.sh` merges this automatically:

```json
{
  "hooks": {
    "SessionStart":       [{ "hooks": [{ "type": "command", "command": "~/.local/bin/claude-ntfy", "async": true, "timeout": 10 }] }],
    "PermissionRequest":  [{ "hooks": [{ "type": "command", "command": "~/.local/bin/claude-ntfy", "async": true, "timeout": 10 }] }],
    "Notification":       [{ "hooks": [{ "type": "command", "command": "~/.local/bin/claude-ntfy", "async": true, "timeout": 10 }] }],
    "Stop":               [{ "hooks": [{ "type": "command", "command": "~/.local/bin/claude-ntfy", "async": true, "timeout": 10 }] }],
    "SessionEnd":         [{ "hooks": [{ "type": "command", "command": "~/.local/bin/claude-ntfy", "async": true, "timeout": 10 }] }]
  }
}
```

---

## Build Phases

| Phase | Goal | Status |
|---|---|---|
| 1 — ntfy.sh hooks | Instant phone notifications, no infrastructure | ✅ Done |
| 2 — Monorepo setup | pnpm workspace, both dev servers running | ⬜ |
| 3 — Next.js API | Session state endpoints, reaper for stale sessions | ⬜ |
| 4 — Vite frontend | Lobster DJ canvas, live-polling status display | ⬜ |
| 5 — Wire hooks to API | Hook scripts POST to ntfy.sh + API simultaneously | ⬜ |
| 6 — Deployment | Vercel + Upstash Redis, live URL | ⬜ |
| 7 — ESP32-C6 firmware | Physical device polls API, drives display + haptic | ⬜ |

---

## API Routes (Phase 3)

| Route | Method | Action |
|---|---|---|
| `/api/session/start` | POST | Register new session |
| `/api/session/notify` | POST | Mark session as waiting (filters `idle_prompt` only) |
| `/api/session/stop` | POST | Mark session as idle |
| `/api/session/end` | POST | Remove session |
| `/api/status` | GET | `{ session_count, waiting_count, sessions }` |
| `/api/health` | GET | `{ ok: true }` |
| `/api/reaper` | GET | Evict sessions silent for > 5 min (called by Vercel Cron) |

---

## Hardware (Phase 7)

| Component | Part |
|---|---|
| MCU | Seeed Studio XIAO ESP32-C6 |
| Display | Seeed Round Display for XIAO — 1.28" circular, 39mm |
| Haptic | Grove Haptic Motor (DRV2605L, I2C) |
| Battery | 100 mAh LiPo, JST connector |

---

## Key Decisions

**ntfy.sh security** — the topic name is the password. `install.sh` generates a 32-byte hex topic (`openssl rand -hex 32`) — 256 bits of entropy, effectively unguessable on the public cloud. Self-hosted ntfy with `auth-default-access: deny-all` is supported via `NTFY_TOKEN`.

**Session state** — in-memory `Map` in development; swapped to Upstash Redis for deployment by changing one file (`lib/sessionStore.ts`).

**Vite + Next.js** — Vite proxies `/api/*` to Next.js in dev. For production, the Vite build outputs into `apps/api/public/` — one Vercel project, one URL, no CORS.

**Auth** — unauthenticated in v1. Before going public: hook scripts send `X-Clawmagotchi-Key`, API routes validate it. One shared env var on both sides.

**Session cap** — max 3 concurrent sessions (matches the 3-record display layout). The API returns `429` beyond that.
