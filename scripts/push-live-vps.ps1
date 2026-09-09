# Push to GitHub and sync [sunset] into the live FiveM volume — no Docker restart.
# After sync, run in txAdmin console: refresh  |  ensure sunset_ui
$ErrorActionPreference = 'Stop'
$Key = Join-Path $env:USERPROFILE '.ssh\sshxodo'
$HostAddr = 'root@193.33.167.216'
$Script = Join-Path $PSScriptRoot 'push-live-vps.sh'

if (-not (Test-Path $Key)) {
    Write-Error "SSH key not found: $Key"
}

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push origin main
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Syncing live resources on VPS (no container restart)..." -ForegroundColor Cyan
scp -i $Key -o BatchMode=yes $Script "${HostAddr}:/tmp/push-live-vps.sh"
ssh -i $Key -o BatchMode=yes $HostAddr "bash /tmp/push-live-vps.sh"
exit $LASTEXITCODE
