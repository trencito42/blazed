# Push to GitHub and sync [sunset] into the live FiveM volume — no Docker restart.
# After sync, run in txAdmin console: refresh  |  ensure sunset_ui  (or restart <resource>)
$ErrorActionPreference = 'Stop'
$Key = Join-Path $env:USERPROFILE '.ssh\sshxodo'
$HostAddr = 'root@193.33.167.216'
$ServicePath = '/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i'
$LiveDst = '/var/lib/docker/volumes/b0n1oc2fcrzbgdco838ezm1i_fivem_config/_data/resources/[sunset]'

if (-not (Test-Path $Key)) {
    Write-Error "SSH key not found: $Key"
}

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push origin main
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Syncing live resources on VPS (no container restart)..." -ForegroundColor Cyan
$remote = @"
set -e
SERVICE='$ServicePath'
LIVE='$LiveDst'
ZIP=/tmp/blazed-main.zip
EXTRACT=/tmp/blazed-extract
rm -rf "$EXTRACT"
wget -q -O "$ZIP" https://github.com/trencito42/blazed/archive/refs/heads/main.zip
unzip -qo "$ZIP" -d /tmp
rm -rf "$EXTRACT"
mv /tmp/blazed-main "$EXTRACT"
cp -rf "$EXTRACT/resources/[sunset]"/* "$SERVICE/resources/[sunset]/"
cp -rf "$SERVICE/resources/[sunset]"/* "$LIVE/"
rm -rf "$ZIP" "$EXTRACT"
echo '[sunsetmp] live resources updated (no restart)'
echo 'txAdmin console:'
echo '  refresh'
echo '  ensure sunset_ui'
"@

ssh -i $Key -o BatchMode=yes $HostAddr $remote
exit $LASTEXITCODE
