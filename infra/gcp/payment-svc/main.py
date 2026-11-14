"""payment-svc: tiny demo service for the Stratus live demo (Cloud Run).

GET /authorize  simulates a payment authorization.
Faults are injected per revision through env vars, which is what a bad deploy
looks like to the agent:
  FAULT_DELAY_MS     extra latency per request (e.g. 800)
  FAULT_ERROR_RATE   share of requests answered with HTTP 500 (e.g. 0.08)
  RELEASE            release label shown in responses (e.g. 482)
"""
import json
import os
import random
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DELAY_MS = float(os.getenv("FAULT_DELAY_MS", "0"))
ERROR_RATE = float(os.getenv("FAULT_ERROR_RATE", "0"))
RELEASE = os.getenv("RELEASE", "dev")
REVISION = os.getenv("K_REVISION", "local")


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: dict):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):  # noqa: N802
        if self.path.startswith("/healthz"):
            return self._send(200, {"ok": True, "revision": REVISION})
        started = time.perf_counter()
        # Normal work: 20-40 ms. Injected delay only on the faulty release.
        time.sleep(random.uniform(0.02, 0.04) + DELAY_MS / 1000 * random.uniform(0.85, 1.15))
        took = round((time.perf_counter() - started) * 1000)
        if random.random() < ERROR_RATE:
            return self._send(500, {"error": "upstream timeout", "revision": REVISION, "release": RELEASE, "ms": took})
        return self._send(200, {"authorized": True, "revision": REVISION, "release": RELEASE, "ms": took})

    def log_message(self, *args):  # keep Cloud Run logs quiet
        pass


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    ThreadingHTTPServer(("", port), Handler).serve_forever()
