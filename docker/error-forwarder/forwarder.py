#!/usr/bin/env python3
"""BlazeMP Lua/console error forwarder -> Discord webhook.

Reads `docker logs -f blazed-fivem-1` output from stdin (systemd pipes it),
matches known FiveM error patterns, de-duplicates + throttles, and posts
compact embeds to the webhook in DISCORD_ERROR_WEBHOOK (read from env; the
systemd unit loads it from /opt/blazed/.env — never commit the URL).

Patterns forwarded:
  - SCRIPT ERROR / script error lines (runtime Lua errors, client + server)
  - Error parsing script (fatal: resource loads but file is dead)
  - Callback error (sunset_core pcall wrapper)
  - lua runner / native errors

Throttling: same (pattern, resource, first 160 chars of message) is forwarded
at most once per DEDUP_WINDOW_SEC (default 300s), with a hit counter appended
on the next forward. Global rate limit: max 8 messages/minute (Discord 429).
"""
import json
import os
import re
import sys
import time
import urllib.request
from collections import deque

WEBHOOK = os.environ.get("DISCORD_ERROR_WEBHOOK", "").strip()
DEDUP_WINDOW_SEC = int(os.environ.get("ERROR_FWD_DEDUP_SEC", "300"))
RATE_WINDOW_SEC = 60
RATE_MAX = 8

PATTERNS = [
    # fatal parse errors (resource starts but the file is dead)
    re.compile(r"Error parsing script\s+(@?\S+)", re.I),
    # runtime script errors
    re.compile(r"(?:SCRIPT ERROR|script error)[:\s]*(.{0,200})", re.I),
    # callback bus errors from sunset_core
    re.compile(r"Callback error \(([^)]+)\):\s*(.{0,200})"),
    # generic Lua errors
    re.compile(r"(?:lua|script) runtime error[:\s]*(.{0,200})", re.I),
    # native errors
    re.compile(r"(Native error|ERR_)[^\r\n]{0,160}", re.I),
]
# noise to ignore even if matched
IGNORE = re.compile(
    r"Script Error: none|testdriver|Error parsing script @(?!sunset)"
    r"|node_modules|citizen:/", re.I
)
ANSI = re.compile(r"\x1b\[[0-9;]*m|\[\s*[0-9;]+m")
RESOURCE = re.compile(r"@?(\w[\w-]*)[/\\](?:client|server|shared)[/\\][\w.-]+\.lua")


def clean(line: str) -> str:
    return ANSI.sub("", line).strip()


def post(embed):
    if not WEBHOOK:
        return
    body = json.dumps({"embeds": [embed]}).encode()
    req = urllib.request.Request(
        WEBHOOK, data=body, headers={"Content-Type": "application/json"}
    )
    try:
        urllib.request.urlopen(req, timeout=10).read()
    except Exception as exc:  # noqa: BLE001 - never die on webhook issues
        print(f"[errorfwd] webhook post failed: {exc}", file=sys.stderr, flush=True)


def main() -> None:
    if not WEBHOOK:
        print("[errorfwd] DISCORD_ERROR_WEBHOOK not set; exiting", file=sys.stderr)
        sys.exit(1)
    print("[errorfwd] online (dedup %ss, rate %s/min)" % (DEDUP_WINDOW_SEC, RATE_MAX), flush=True)

    seen = {}          # key -> [count, last_forward_ts]
    rate = deque()     # timestamps of posts in the current window
    context = deque(maxlen=3)  # previous cleaned lines for context

    for raw in sys.stdin:
        line = clean(raw)
        if not line:
            continue
        if IGNORE.search(line):
            context.append(line)
            continue

        matched = None
        for pat in PATTERNS:
            m = pat.search(line)
            if m:
                matched = m
                break
        if not matched:
            context.append(line)
            continue

        res = RESOURCE.search(line)
        resource = res.group(1) if res else "unknown"
        key = f"{resource}|{line[:160]}"
        now = time.time()

        entry = seen.get(key)
        if entry and (now - entry[1]) < DEDUP_WINDOW_SEC:
            entry[0] += 1
            continue

        repeats = entry[0] + 1 if entry else 0
        seen[key] = [0, now]

        # global rate limit
        while rate and now - rate[0] > RATE_WINDOW_SEC:
            rate.popleft()
        if len(rate) >= RATE_MAX:
            print(f"[errorfwd] rate-limited, dropped: {line[:120]}", flush=True)
            continue
        rate.append(now)

        desc = line[:1500]
        if repeats > 1:
            desc += f"\n\n*(repeated {repeats}x in the last {DEDUP_WINDOW_SEC}s)*"
        ctx = "\n".join(f"> {c[:200]}" for c in list(context)[-2:])
        if ctx:
            desc += f"\n\n**Context:**\n{ctx}"

        post({
            "title": f"LUA ERROR — {resource}",
            "description": f"```\n{desc}\n```",
            "color": 0xFF3344,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "footer": {"text": "blazed-fivem-1 error forwarder"},
        })
        context.append(line)


if __name__ == "__main__":
    main()
