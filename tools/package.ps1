$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$windowsBuild = Join-Path $projectRoot 'build/windows/x64/runner/Release'
$androidBuild = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
if (!(Test-Path -LiteralPath (Join-Path $windowsBuild 'terax.exe')) -or !(Test-Path -LiteralPath $androidBuild)) {
    throw 'Compila Windows release y Android release ARM64 antes de empaquetar.'
}
$distPath = Join-Path $projectRoot 'dist'
$portablePath = Join-Path $distPath 'Terax-Windows'
$stagingRoot = Join-Path $distPath ('.package-' + [guid]::NewGuid().ToString('N'))
$stagingPortable = Join-Path $stagingRoot 'Terax-Windows'
$previousPortable = Join-Path $distPath ('Terax-Windows.previous-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
# Verify all directory moves remain inside this project's artifact directory.
$artifactRoot = [IO.Path]::GetFullPath($distPath).TrimEnd('\') + '\'
foreach ($target in @($portablePath, $stagingRoot, $stagingPortable, $previousPortable)) {
    if (![IO.Path]::GetFullPath($target).StartsWith($artifactRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Ruta de empaquetado fuera de dist.'
    }
}
New-Item -ItemType Directory -Path $stagingPortable -Force | Out-Null
Get-ChildItem -LiteralPath $windowsBuild | Copy-Item -Destination $stagingPortable -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination (Join-Path $stagingPortable 'LEEME.md') -Force
if (Test-Path -LiteralPath $portablePath) {
    # Preserve prior/extracted content instead of mixing it into the new ZIP.
    Move-Item -LiteralPath $portablePath -Destination $previousPortable
}
Move-Item -LiteralPath $stagingPortable -Destination $portablePath
Remove-Item -LiteralPath $stagingRoot
Compress-Archive -LiteralPath $portablePath -DestinationPath (Join-Path $distPath 'Terax-Windows.zip') -Force
Copy-Item -LiteralPath $androidBuild -Destination (Join-Path $distPath 'Terax-Android-arm64.apk') -Force
Get-FileHash -LiteralPath (Join-Path $distPath 'Terax-Windows.zip'), (Join-Path $distPath 'Terax-Android-arm64.apk') -Algorithm SHA256 |
    ForEach-Object { '{0}  {1}' -f $_.Hash.ToLowerInvariant(), (Split-Path -Leaf $_.Path) } |
    Set-Content -LiteralPath (Join-Path $distPath 'SHA256SUMS.txt') -Encoding utf8
Get-ChildItem -LiteralPath $distPath -File | Select-Object Name, Length
