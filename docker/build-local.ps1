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
    $vendor = Join-Path $root 'vendor'
    New-Item -ItemType Directory -Path $vendor -Force | Out-Null
    function Get-PinnedSource([string]$repo, [string]$commit, [string]$destination) {
        if (-not (Test-Path (Join-Path $destination '.git'))) {
            git clone --filter=blob:none --no-checkout $repo $destination
        }
        git -C $destination fetch --depth 1 origin $commit
        git -C $destination checkout --detach $commit
    }
    Get-PinnedSource 'https://github.com/Comfy-Org/ComfyUI.git' 'b5cc8830279eae909a59de030af1e50761c36751' (Join-Path $vendor 'ComfyUI')
    Get-PinnedSource 'https://github.com/Heroesjouney/AIMovieStudiov2.git' 'eb52643b62429ee1a3f94e94ef06f38fc13dfcbb' (Join-Path $vendor 'AIMovieStudiov2')
    docker buildx build --platform linux/amd64 -f docker/comfy/Dockerfile --tag "$Registry/film-comfy:$Tag" --push .
    docker buildx build --platform linux/amd64 -f docker/studio-backend/Dockerfile --tag "$Registry/film-studio-backend:$Tag" --push .
    docker buildx build --platform linux/amd64 -f docker/studio-frontend/Dockerfile --tag "$Registry/film-studio-frontend:$Tag" --push .
}
finally {
    Pop-Location
}
