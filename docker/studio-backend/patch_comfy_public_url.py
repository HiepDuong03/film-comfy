"""Make AI Movie Studio return a browser-reachable ComfyUI output URL.

COMFY_URL remains the Docker service endpoint for uploads and workflow API calls.
COMFY_PUBLIC_URL is used only for the output URL sent to the browser.
"""

from pathlib import Path
import sys


if len(sys.argv) != 2:
    raise SystemExit("usage: patch_comfy_public_url.py PATH")

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")

init_before = 'self.comfy_url = comfy_url or os.getenv("COMFY_URL", "http://127.0.0.1:8188")'
init_after = (
    init_before
    + "\n"
    + "        # Keep Docker API traffic internal; return a browser-reachable output URL.\n"
    + "        self.public_comfy_url = os.getenv(\"COMFY_PUBLIC_URL\", self.comfy_url).rstrip(\"/\")"
)
url_before = 'vid_url = f"{self.comfy_url}/view?filename={filename}&subfolder={subfolder}&type={img_type}"'
url_after = 'vid_url = f"{self.public_comfy_url}/view?filename={filename}&subfolder={subfolder}&type={img_type}"'

if init_before not in source:
    raise RuntimeError("AI Movie Studio changed: cannot locate Comfy URL initialization")
if url_before not in source:
    raise RuntimeError("AI Movie Studio changed: cannot locate output-video URL construction")

source = source.replace(init_before, init_after, 1).replace(url_before, url_after, 1)
path.write_text(source, encoding="utf-8")
