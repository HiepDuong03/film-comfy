# Ckey H3 Film Kit

Reproducible deployment recipe for a **new, empty Ckey GPU**. Ckey documents SSH and port forwarding and warns that rebuild/expiry can erase data. This recipe stores small setup files in Git and fetches only the **four H3 Ref2VA files needed** from Comfy-Org's Hugging Face repository with Xet. It does not require a private model archive.

## Transfer time floor

The four selected files total **42,458,411,463 bytes (39.54 GiB)** at the pinned revision. Theoretical minimum transfer time:

| Actual throughput | Minimum time |
| --- | ---: |
| 100 Mbit/s | 56.6 min |
| 500 Mbit/s | 11.3 min |
| 1 Gbit/s | 5.7 min |

Actual setup takes longer due to network limits, software setup and model loading. The installer prints timestamps so Ckey hosts can be benchmarked. Network speed matters as much as GPU price.

## Run on Ckey

Choose Linux/NVIDIA with 24 GB+ VRAM and 100 GB+ free disk. SSH in using Ckey's command. Copy this directory to the machine, then:

```bash
cp ckey-film.env.example ckey-film.env
bash bootstrap.sh --doctor ckey-film.env
sudo bash bootstrap.sh ckey-film.env
```

The script fetches ComfyUI, prepares a CUDA Python environment, downloads the four model files through Hugging Face Xet, verifies sizes and starts ComfyUI. If Docker Compose is installed, it starts AI Movie Studio 2 too. Set `SKIP_STUDIO=1` in the config to prepare only ComfyUI/H3.

The default model uses the compatible `fp8_scaled` Ref2VA transformer, `nvfp4_awq` text encoder, fp16 video VAE and fp32 audio VAE. Comfy-Org recommends `int8_convrot` when a suitable CUDA 13/PyTorch stack is available; use that only after validating your host.

The AI Movie Studio Compose file binds its UI to loopback. From your own computer, use an SSH tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 root@<Ckey-IP> -p <Ckey-SSH-port>
```

Then open `http://127.0.0.1:3000`. Keep ComfyUI port 8188 private.

## Important filmmaking limitation

At the pinned AI Movie Studio revision, its bundled H3 Ref2VA workflow exposes only **three image-reference slots**. The backend iterates the slots in that template, so the current kit does **not** provide arbitrary multi-character reference counts or guarantee character consistency across shots. Use it for a two- or three-reference smoke test; extending the workflow/UI and validating each shot is separate work. ComfyUI's native H3 nodes offer more advanced reference workflows, but that is not the same as a polished film editor.

## For multiple creators

Publish the small recipe in Git. A software-only container image can be built once and reused across rentals, while each GPU downloads the selected model files from Hugging Face. Keep projects and outputs in cheap object storage if they must survive a rental. Cloudflare R2 is one option with no egress fees. No creator needs to build or upload a 40 GB bundle.

If a host's link is capped near 100 Mbit/s, no script can eliminate the ~57-minute transfer floor. Choose a host with a faster measured link, or ask Ckey for host-side image/model caching. Mounting object storage can display the UI quickly but still transfers weights during first inference.

## Validation and rights

The script was syntax checked locally; it has not run on a Ckey instance. Run `--doctor` on a specific host and verify one two-character Ref2VA shot after setup.

MiniMax H3 weights carry the MiniMax H3 Community License. ComfyUI's H3 documentation states that commercial use of locally generated outputs requires a separate commercial license. Verify this before monetized TikTok publication.
