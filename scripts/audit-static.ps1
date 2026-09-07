# SunsetMP static pre-release checks (section 21)
# Usage: pwsh -File scripts/audit-static.ps1
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$sunset = Join-Path $root 'resources\[sunset]'
$manifests = Get-ChildItem -LiteralPath $sunset -Filter fxmanifest.lua -Recurse
Write-Host "`n[manifests] $($manifests.Count) sunset resources"

# 2. Missing script references in manifests (basic)
foreach ($mf in $manifests) {
    $dir = $mf.DirectoryName
    $text = Get-Content $mf.FullName -Raw
    $patterns = @(
        "client_scripts\s*\{([^}]+)\}",
        "server_scripts\s*\{([^}]+)\}",
        "shared_scripts\s*\{([^}]+)\}",
        "files\s*\{([^}]+)\}"
    )
    foreach ($pat in $patterns) {
        if ($text -match $pat) {
            $block = $Matches[1]
            foreach ($m in [regex]::Matches($block, "'([^']+)'")) {
                $rel = $m.Groups[1].Value
                if ($rel -match '^\@') { continue }
                if ($rel -match '\*') { continue }
                $path = Join-Path $dir ($rel -replace '/', '\')
                if (-not (Test-Path $path)) {
                    Write-Host "  MISSING: $($mf.Directory.Name) -> $rel" -ForegroundColor Red
                    $fail++
                }
            }
        }
    }
}

# 3. Duplicate RegisterCommand names (client vs server)
$cmdMap = @{}
Get-ChildItem -LiteralPath $sunset -Filter *.lua -Recurse | ForEach-Object {
    $side = if ($_.FullName -match '\\client\\') { 'client' } elseif ($_.FullName -match '\\server\\') { 'server' } else { 'other' }
    if ($side -eq 'other') { return }
    $content = Get-Content $_.FullName -Raw
    foreach ($m in [regex]::Matches($content, 'RegisterCommand\(''([^'']+)')) {
        $name = $m.Groups[1].Value.ToLower()
        if (-not $cmdMap[$name]) { $cmdMap[$name] = @() }
        $cmdMap[$name] += "$side@$($_.FullName.Replace($root + '\', ''))"
    }
}
$dual = $cmdMap.GetEnumerator() | Where-Object { ($_.Value | Where-Object { $_ -like 'client@*' }).Count -gt 0 -and ($_.Value | Where-Object { $_ -like 'server@*' }).Count -gt 0 }
Write-Host "`n[dual-side commands] $($dual.Count)"
foreach ($d in $dual) {
    Write-Host "  /$($d.Key): $($d.Value -join '; ')"
}

# 4. Secret scan (lightweight)
$secretHits = Select-String -Path (Join-Path $root 'resources\[sunset]\**\*.lua') -Pattern 'cfxk_|api[_-]?key\s*=\s*["''][^"''\s]+|password\s*=\s*["''][^"''\s]{8,}' -SimpleMatch:$false -ErrorAction SilentlyContinue
if ($secretHits) {
    Write-Host "`n[secrets] possible hits in sunset lua:" -ForegroundColor Yellow
    $secretHits | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber)" }
}

# 5. SQL migrations
$migs = Get-ChildItem (Join-Path $root 'sql\[0-9][0-9]-*.sql') -ErrorAction SilentlyContinue
Write-Host "`n[migrations] $($migs.Count) numbered SQL files (02-23 expected)"

if ($fail -gt 0) {
    Write-Host "`nFAILED: $fail manifest reference issues" -ForegroundColor Red
    exit 1
}
Write-Host "`nStatic checks completed." -ForegroundColor Green
