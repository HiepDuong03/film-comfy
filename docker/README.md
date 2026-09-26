# Portable Ckey Film Docker images

## Ckey Custom Template probe

Before publishing an all-in-one runtime, deploy the small
`ghcr.io/YOUR_GITHUB_USER/film-ckey-probe:edge` image as a Ckey Custom Template
and expose container port `3000`. Opening `/health` must return `ok: true` and
the allocated GPU name. This verifies custom-registry pulling, the image
entrypoint, port routing, and NVIDIA passthrough without downloading H3.

This builds three **software-only** Linux images:

- `film-comfy`: pinned ComfyUI, CUDA PyTorch, Hugging Face Xet and a resumable H3 downloader.
- `film-studio-backend`: pinned AI Movie Studio 2 backend and its H3 workflow patched to the compatible fp8 Ref2VA file.
- `film-studio-frontend`: pinned AI Movie Studio 2 UI.

The H3 weights are intentionally absent. At runtime `film-comfy` downloads the four required Ref2VA files to a Docker volume and verifies their byte sizes. Publishing model weights in the image would add about 42 GB to every image transfer and may introduce redistribution-license obligations. The GitHub workflow checks out pinned ComfyUI and AI Movie Studio source revisions before each build; Dockerfiles do not clone external repositories themselves.

## Recommended: build on GitHub Actions

This is the recommended route for this laptop: it uses neither local disk nor Ckey GPU time. Create a **private** GitHub repository, put this entire `ckey-h3-film-kit` folder at its repository root, and push it to the `main` branch. GitHub Actions then builds and pushes the three software images to the owner's private GitHub Container Registry namespace.

In the GitHub repository, open **Actions** → **Publish film runtime images** → **Run workflow**, leave the tag as `v1`, and run it. When all three matrix jobs pass, set this on Ckey:

```env
REGISTRY=ghcr.io/YOUR_GITHUB_USER
TAG=v1
```

If GitHub's package visibility defaults to public, change each generated package to private in its Package settings. Ckey will later need a GitHub token with `read:packages` to pull them. The workflow itself uses the automatically supplied `GITHUB_TOKEN`; no registry secret is needed for the build.

## Alternative: build once on Windows

Install Docker Desktop with its WSL 2 backend. Docker Desktop does not need access to your 4 GB laptop GPU: image building is CPU/network work. Reserve at least **35 GB free on the Docker/WSL disk** for the first local build; model weights are not downloaded. Sign in to a **private** registry first. The commands below use GitHub Container Registry; replace `YOUR_GITHUB_USER` once and keep the repository private.

```powershell
cd "C:\Users\Duong Dai Hiep\OneDrive\Documents\ChatGPT\flowKit\ckey-h3-film-kit"
docker login ghcr.io

$r = "ghcr.io/YOUR_GITHUB_USER"
$t = "v1"
docker buildx build --platform linux/amd64 -f docker/comfy/Dockerfile --tag "$r/film-comfy:$t" --push .
docker buildx build --platform linux/amd64 -f docker/studio-backend/Dockerfile --tag "$r/film-studio-backend:$t" --push .
docker buildx build --platform linux/amd64 -f docker/studio-frontend/Dockerfile --tag "$r/film-studio-frontend:$t" --push .
```

`docker login ghcr.io` requires a GitHub personal access token with `write:packages`; Ckey later needs a token with `read:packages`. Never put either token in a Dockerfile or commit it to Git.

## Start on a new Ckey VM

Install Docker Engine and Compose if the VM lacks them. Copy only the `docker/` folder, then:

```bash
cd docker
cp .env.example .env
# edit .env: set REGISTRY and optional HF_TOKEN
docker login ghcr.io
docker compose pull
docker compose up -d
docker compose logs -f comfy
```

The first `comfy` start downloads H3 into `model-data`; later restarts on the same VM reuse it. On a wiped/new Ckey VM, it must download again unless Ckey provides persistent storage or host-side caching.

## Open safely from your PC

On Windows:

```powershell
ssh -N -L 3000:127.0.0.1:3000 -L 8188:127.0.0.1:8188 root@CKEY_IP -p CKEY_PORT
```

Open `http://127.0.0.1:3000`. The `8188` forward is required so generated video
preview links work in your browser. ComfyUI port 8188 is still loopback-only on
the Ckey machine and is not public.

## Before spending a full render hour

Wait until `docker compose logs comfy` says the server is available, then make a 5-second, 512x896, 8-10 step, two-reference test. The RTX 3090 24 GB tier is close to the H3 memory limit, so do not begin with a 15-second high-resolution shot.

## Update safely

Change `TAG` for every tested image set, for example `v2`. Do not use `latest`: it prevents knowing which ComfyUI/Studio revision made a clip. To rebuild only after upstream testing, update the pinned `COMFY_REV` or `STUDIO_REV` Docker build args and publish a new tag.
