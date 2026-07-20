# GPU-serving evidence

Fill with REAL artifacts. `*.local.*` files are gitignored (never committed) — copy the
sanitized parts you want public into this README.

## What each artifact proves

| Artifact | Proves | How to produce |
|---|---|---|
| `helm-template.txt` | The chart renders valid GPU-scheduled manifests | `helm template vllm charts/vllm-serving > gpu-serving/docs/evidence/helm-template.txt` |
| `conftest.txt` | Rendered manifests pass the security policy gate | `helm template vllm charts/vllm-serving \| conftest test -` |
| `smoke.local.json` | The OpenAI wire protocol works end-to-end + throughput | `NVIDIA_API_KEY=... python gpu-serving/smoke/nim_smoke.py > gpu-serving/docs/evidence/smoke.local.json` |
| `nvidia-smi.local.txt` (opt-in) | Real GPU + MIG attempt on actual hardware | `nvidia-smi -L` (and `bash manifests/mig-partition.sh` on a datacenter GPU) |

## Proven (2026-07-06)

Live runtime smoke ran against the hosted NIM endpoint — real, committed at `smoke.sample.json`:

| model | base_url | latency | decode throughput |
|---|---|---|---|
| `meta/llama-3.1-8b-instruct` | `integrate.api.nvidia.com/v1` | 0.785 s | **71.29 tok/s** |

Same OpenAI wire protocol as a self-hosted `vllm-serving` pod → self-host is one `base_url` switch.

## Honesty checklist (do NOT skip)

- [ ] The smoke JSON came from a real API call (real `nvapi-...` key), not hand-written.
- [ ] MIG is described as datacenter-only; no faked MIG output from a consumer card.
- [ ] If time-slicing was validated locally, the `nvidia-smi -L` + `kubectl` outputs are real.
- [ ] No API key committed. Check `smoke.local.json` for leaked secrets before copying anything public.

## Claim we can honestly make

> "GPU-served LLM stack: vLLM/TensorRT-LLM Helm chart with NVIDIA device-plugin scheduling,
> time-slicing (consumer GPU) and MIG partitioning (datacenter GPU) manifests, policy-gated.
> Runtime proven against the OpenAI-compatible endpoint; self-host is one `base_url` switch."
