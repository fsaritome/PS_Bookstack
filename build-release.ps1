# build-release.ps1 - Syncs latest files into the release folder
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$rel  = Join-Path $root "release"

New-Item -ItemType Directory -Force "$rel\web","$rel\scripts" | Out-Null
Copy-Item "$root\server.ps1"                       "$rel\server.ps1"                        -Force
Copy-Item "$root\START.bat"                        "$rel\START.bat"                         -Force
Copy-Item "$root\web\demoscene.html"               "$rel\web\demoscene.html"                -Force
Copy-Item "$root\scripts\installBookstack.ps1"     "$rel\scripts\installBookstack.ps1"      -Force

Write-Host "Release synced to: $rel" -ForegroundColor Green
Get-ChildItem -Recurse $rel | Where-Object { !$_.PSIsContainer } | ForEach-Object {
    Write-Host "  $($_.FullName.Replace($root+'\',''))" -ForegroundColor Cyan
}
