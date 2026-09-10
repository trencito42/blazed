#!/bin/bash
set -euo pipefail
echo "=== HOST ==="
hostname
uptime
echo "=== FIVEM LOCAL ==="
curl -sS -m 5 http://127.0.0.1:30120/info.json | head -c 200 || echo FAIL
echo
echo "=== FIVEM PUBLIC IP ==="
curl -sS -m 5 http://193.33.167.216:30120/info.json | head -c 200 || echo FAIL
echo
echo "=== DOCKER ==="
docker ps --filter name=blazed-fivem --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "=== UFW ==="
ufw status | head -20
echo "=== IPTABLES DOCKER-USER ==="
iptables -S DOCKER-USER 2>/dev/null || true
echo "=== COMPOSE DIR ==="
ls -la /opt/blazed/
echo "=== SERVER CFG (container) ==="
docker exec blazed-fivem-1 sh -c 'for f in /config/server.cfg /server-data/server.cfg /txData/default/server.cfg; do [ -f "$f" ] && echo FILE:$f && grep -E "endpoint|sv_|license|listing|adhesive" "$f" && break; done' 2>/dev/null || true
