param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(ghcr\.io|docker\.io)/[a-zA-Z0-9._-]+$')]
    [string]$Registry,
    [string]$Tag = 'v1'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$requiredFreeGb = 35
$freeGb = [math]::Floor((Get-PSDrive -Name C).Free / 1GB)
if ($freeGb -lt $requiredFreeGb) {
    throw "Need at least $requiredFreeGb GB free on C: for the initial Docker build; found $freeGb GB. No build was started."
}

docker version --format '{{.Server.Version}}' | Out-Null
Push-Location $root
try {
    docker buildx build --platform linux/amd64 -f docker/comfy/Dockerfile --tag "$Registry/film-comfy:$Tag" --push .
    docker buildx build --platform linux/amd64 -f docker/studio-backend/Dockerfile --tag "$Registry/film-studio-backend:$Tag" --push .
    docker buildx build --platform linux/amd64 -f docker/studio-frontend/Dockerfile --tag "$Registry/film-studio-frontend:$Tag" --push .
}
finally {
    Pop-Location
}
