import json
import os
import platform
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def command_output(command):
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return {
            "exit_code": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        }
    except Exception as exc:
        return {"exit_code": -1, "stdout": "", "stderr": repr(exc)}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health"):
            self.send_error(404)
            return

        gpu = command_output(
            [
                "nvidia-smi",
                "--query-gpu=name,memory.total,driver_version",
                "--format=csv,noheader",
            ]
        )
        body = json.dumps(
            {
                "ok": gpu["exit_code"] == 0,
                "message": "Ckey custom image probe",
                "gpu": gpu,
                "cuda_visible_devices": os.getenv("CUDA_VISIBLE_DEVICES"),
                "hostname": platform.node(),
            },
            ensure_ascii=False,
            indent=2,
        ).encode("utf-8")

        self.send_response(200 if gpu["exit_code"] == 0 else 503)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]} {fmt % args}", flush=True)


port = int(os.getenv("PORT", "3000"))
print(f"Ckey probe listening on 0.0.0.0:{port}", flush=True)
ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
