#!/bin/bash
set -euo pipefail
ENV="/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i/.env"
python3 - <<'PY'
import re
p = "/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i/.env"
with open(p) as f:
    s = f.read()
s2 = re.sub(r"(MARIADB_ROOT_PASSWORD=[^\n]*?)TXADMIN_ENABLE", r"\1\nTXADMIN_ENABLE", s)
with open(p, "w") as f:
    f.write(s2)
print("fixed" if s != s2 else "already_ok")
PY
grep -E 'TXADMIN|MARIADB_ROOT' "$ENV"
cd /data/coolify/services/b0n1oc2fcrzbgdco838ezm1i
docker compose up -d fivem
sleep 10
docker logs --tail 30 b0n1oc2fcrzbgdco838ezm1i-fivem-1 2>&1
