#!/usr/bin/env python3
"""BlazeMP Lua/console error forwarder -> Discord webhook.

Reads `docker logs -f blazed-fivem-1` output from stdin (systemd pipes it),
matches FiveM error patterns, de-duplicates + throttles, collects Lua stack
traces, and posts compact embeds to DISCORD_ERROR_WEBHOOK (env; lives in
/opt/blazed/.env on the VPS — never commit the URL).

Forwarded:
  - SCRIPT ERROR lines + their stack-trace continuation lines ("> fn (@f:N)")
  - Error parsing script (fatal: resource loads but the file is DEAD)
  - Callback error (sunset_core pcall wrapper)
  - lua runtime / native / ERR_ lines

Throttling:
  - same (resource, first 160 chars) -> max 1 post per DEDUP_WINDOW_SEC (300s)
  - repeats counted; every ESCALATE_AFTER (10) repeats posts an orange
    "RECURRING ERROR" summary even while deduped
  - global max RATE_MAX (8) posts/minute (Discord 429)
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
ESCALATE_AFTER = int(os.environ.get("ERROR_FWD_ESCALATE_AFTER", "10"))
TRACE_TTL_SEC = 3.0
TRACE_MAX_LINES = 8
RATE_WINDOW_SEC = 60
RATE_MAX = 8

PATTERNS = [
    re.compile(r"Error parsing script\s+(@?\S+)", re.I),
    re.compile(r"(?:SCRIPT ERROR|script error)[:\s]*(.{0,200})", re.I),
    re.compile(r"Callback error \(([^)]+)\):\s*(.{0,200})"),
    re.compile(r"(?:lua|script) runtime error[:\s]*(.{0,200})", re.I),
    re.compile(r"(Native error|ERR_)[^\r\n]{0,160}", re.I),
]
IGNORE = re.compile(
    r"Script Error: none|testdriver|Error parsing script @(?!sunset)"
    r"|node_modules|citizen:/|forwarder test", re.I
)
ANSI = re.compile(r"\x1b\[[0-9;]*m|\[\s*[0-9;]+m")
RESOURCE = re.compile(r"@?(\w[\w-]*)[/\\](?:client|server|shared)[/\\][\w.-]+\.lua")
# FiveM stack-trace continuation: "> BuyTicket (@sunset_economy/server/lottery.lua:92)"
TRACE_LINE = re.compile(r"^\s*>\s+\S.*\(@?\S+:\d+\)")


def clean(line):
    return ANSI.sub("", line).strip()


def post(embed):
    if not WEBHOOK:
        return
    body = json.dumps({"embeds": [embed]}).encode()
    req = urllib.request.Request(
        WEBHOOK,
        data=body,
        headers={
            "Content-Type": "application/json",
            # Cloudflare (error 1010) blocks the default Python-urllib UA.
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
            ),
        },
    )
    try:
        urllib.request.urlopen(req, timeout=10).read()
    except Exception as exc:  # noqa: BLE001 - never die on webhook issues
        print(f"[errorfwd] webhook post failed: {exc}", file=sys.stderr, flush=True)


def make_embed(title, desc, color):
    return {
        "title": title,
        "description": "```\n" + desc[:1900] + "\n```",
        "color": color,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "footer": {"text": "blazed-fivem-1 error forwarder"},
    }


def main():
    if not WEBHOOK:
        print("[errorfwd] DISCORD_ERROR_WEBHOOK not set; exiting", file=sys.stderr)
        sys.exit(1)
    print("[errorfwd] online (dedup %ss, escalate every %s, rate %s/min)"
          % (DEDUP_WINDOW_SEC, ESCALATE_AFTER, RATE_MAX), flush=True)

    seen = {}            # key -> {count, last}
    rate = deque()       # post timestamps within RATE_WINDOW_SEC
    context = deque(maxlen=4)
    pending = None       # {key, resource, line, repeats, trace[], at}

    def rate_ok(now):
        while rate and now - rate[0] > RATE_WINDOW_SEC:
            rate.popleft()
        if len(rate) >= RATE_MAX:
            return False
        rate.append(now)
        return True

    def flush_pending(now):
        """Post the buffered error (with collected trace)."""
        nonlocal pending
        if not pending:
            return
        p = pending
        pending = None
        if not rate_ok(now):
            print(f"[errorfwd] rate-limited, dropped: {p['line'][:120]}", flush=True)
            return
        desc = p["line"][:1400]
        if p["trace"]:
            desc += "\n\nSTACK:\n" + "\n".join(t[:180] for t in p["trace"])
        if p["repeats"] > 1:
            desc += (f"\n\n*(repeated {p['repeats']}x in the last "
                     f"{DEDUP_WINDOW_SEC}s)*")
        if p["ctx"]:
            desc += "\n\nBEFORE:\n" + "\n".join(f"> {c[:180]}" for c in p["ctx"])
        color = 0xFF3344
        title = f"LUA ERROR — {p['resource']}"
        if "Error parsing script" in p["line"]:
            color = 0x990000
            title = (f"FATAL PARSE ERROR — {p['resource']} "
                     f"(file is DEAD, exports lost)")
        post(make_embed(title, desc, color))

    for raw in sys.stdin:
        now = time.time()
        line = clean(raw)
        if not line:
            continue

        # 1) stack-trace continuation of the buffered error
        if pending and TRACE_LINE.search(line) and (now - pending["at"]) < TRACE_TTL_SEC:
            if len(pending["trace"]) < TRACE_MAX_LINES:
                pending["trace"].append(line)
            continue

        # 2) anything else: flush the buffered error first (trace is done)
        if pending and (now - pending["at"]) >= 0:
            # give traces ~200ms to finish collecting consecutive lines
            flush_pending(now)

        if IGNORE.search(line):
            context.append(line)
            continue

        matched = False
        for pat in PATTERNS:
            if pat.search(line):
                matched = True
                break
        if not matched:
            context.append(line)
            continue

        res = RESOURCE.search(line)
        resource = res.group(1) if res else "unknown"
        key = f"{resource}|{line[:160]}"

        entry = seen.get(key)
        if entry and (now - entry["last"]) < DEDUP_WINDOW_SEC:
            entry["count"] += 1
            if entry["count"] % ESCALATE_AFTER == 0 and rate_ok(now):
                post(make_embed(
                    f"RECURRING ERROR — {resource}",
                    f"{line[:600]}\n\nHit {entry['count']}x in the last "
                    f"{DEDUP_WINDOW_SEC}s (summary every {ESCALATE_AFTER} repeats).",
                    0xFFAA00,
                ))
            context.append(line)
            continue

        repeats = entry["count"] + 1 if entry else 0
        seen[key] = {"count": 0, "last": now}
        pending = {
            "key": key,
            "resource": resource,
            "line": line,
            "repeats": repeats,
            "trace": [],
            "ctx": list(context)[-2:],
            "at": now,
        }
        context.append(line)

    flush_pending(time.time())


if __name__ == "__main__":
    main()
