param (
    [switch]$Uninstall,
    [string]$Version = $env:NAPI_MBT_VERSION,
    [string]$Repository = $(if ($env:NAPI_MBT_REPO) { $env:NAPI_MBT_REPO } else { "unmbt/napi-mbt" })
)

$InstallRoot = if ($env:NAPI_MBT_HOME) { $env:NAPI_MBT_HOME } else { Join-Path $env:USERPROFILE ".unmbt" }
if ($Uninstall) {
    Remove-Item -LiteralPath $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed $InstallRoot"
    return
}

if (-not $Version) {
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest"
    $Version = $release.tag_name
}
if (-not $Version) { throw "Unable to determine the latest release; set NAPI_MBT_VERSION." }

$asset = "napi-mbt-windows-amd64"
$temp = Join-Path ([IO.Path]::GetTempPath()) ("napi-mbt-" + [guid]::NewGuid().ToString())
$archive = "$temp.tar.gz"
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Invoke-WebRequest "https://github.com/$Repository/releases/download/$Version/$asset.tar.gz" -OutFile $archive
    if (Test-Path $InstallRoot) { Remove-Item $InstallRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $InstallRoot | Out-Null
    tar -xzf $archive -C $InstallRoot
    $binary = Join-Path $InstallRoot "napi-mbt.exe"
    if (-not (Test-Path $binary)) { throw "Release $Version did not contain napi-mbt.exe" }
    Rename-Item $binary "napi-mbt-bin.exe"
    @"
@echo off
set "NAPI_MBT_NODE_RUNTIME=$InstallRoot\runtime\cli\bin\napi-mbt.js"
"$InstallRoot\napi-mbt-bin.exe" %*
"@ | Set-Content (Join-Path $InstallRoot "napi-mbt.cmd") -Encoding ASCII

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (($userPath -split ';') -notcontains $InstallRoot) {
        [Environment]::SetEnvironmentVariable("Path", (($userPath.TrimEnd(';') + ";" + $InstallRoot).Trim(';')), "User")
    }
    Write-Host "Installed napi-mbt $Version in $InstallRoot" -ForegroundColor Green
    Write-Host "Open a new terminal to use the command."
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}