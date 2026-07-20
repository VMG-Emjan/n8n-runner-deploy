#!/usr/bin/env python3
"""Live runtime smoke for the GPU-served LLM stack.

Proves the OpenAI-compatible wire protocol end-to-end and measures decode throughput.
It talks to whatever base_url you give it — the point is that the SAME client code hits:

  * NVIDIA NIM hosted (build.nvidia.com):   https://integrate.api.nvidia.com/v1   [$0, default]
  * a self-hosted vLLM pod (this repo):      http://localhost:8000/v1
  * a self-hosted NIM container:             http://localhost:8000/v1

Switching targets is one env var. That is the honest claim: the serving stack is defined by the
Helm chart + GPU manifests in this repo; this script proves the runtime path works. No fabricated
nvidia-smi output, no faked screenshots.

Usage:
  export NVIDIA_API_KEY=nvapi-...              # free key from build.nvidia.com
  python nim_smoke.py                          # hits hosted NIM
  OPENAI_BASE_URL=http://localhost:8000/v1 \
    OPENAI_API_KEY=dummy MODEL=Qwen/Qwen2.5-0.5B-Instruct \
    python nim_smoke.py                         # hits local vLLM pod

Writes a JSON evidence record to stdout; redirect to docs/evidence/smoke.local.json.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("OPENAI_BASE_URL", "https://integrate.api.nvidia.com/v1")
API_KEY = os.environ.get("OPENAI_API_KEY") or os.environ.get("NVIDIA_API_KEY")
MODEL = os.environ.get("MODEL", "meta/llama-3.1-8b-instruct")
PROMPT = os.environ.get("PROMPT", "In one sentence, what is GPU-served LLM inference?")


def main() -> int:
    if not API_KEY:
        print("ERROR: set NVIDIA_API_KEY (hosted) or OPENAI_API_KEY (self-host).", file=sys.stderr)
        return 2

    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": PROMPT}],
        "max_tokens": 128,
        "temperature": 0.2,
        "stream": False,
    }
    req = urllib.request.Request(
        f"{BASE_URL}/chat/completions",
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"HTTPError {e.code}: {e.read().decode(errors='replace')}", file=sys.stderr)
        return 1
    elapsed = time.perf_counter() - t0

    usage = body.get("usage", {})
    completion_tokens = usage.get("completion_tokens", 0)
    text = body["choices"][0]["message"]["content"]
    tok_per_s = round(completion_tokens / elapsed, 2) if elapsed > 0 else None

    evidence = {
        "base_url": BASE_URL,
        "model": MODEL,
        "latency_s": round(elapsed, 3),
        "completion_tokens": completion_tokens,
        "decode_tokens_per_s": tok_per_s,
        "response_preview": text.strip()[:200],
        "wire_protocol": "openai-chat-completions",
    }
    print(json.dumps(evidence, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
