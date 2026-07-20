# GPU-serving module — GPU-served LLM + NVIDIA optimization ($0 proof)

Extends `cloud-deploy-proof` from "I can deploy a container to K8s" to **"I can serve an LLM on a
GPU with NVIDIA optimization (vLLM / TensorRT-LLM), scheduled on Kubernetes with GPU
partitioning (MIG / time-slicing)."** Closes the market gap:

> GPU-served LLM + NVIDIA optimization (vLLM/TGI, CUDA/MIG) — asked in *GTECH AI Platform Engineer*.

## The honest model

The **skill** is proven by artifacts a reviewer reads; the **runtime** is proven by one real call.
We do not fake hardware we don't have.

| Layer | Artifact | Runs where | Cost |
|---|---|---|---|
| Serving stack | `charts/vllm-serving/` Helm chart — vLLM OpenAI server, `nvidia.com/gpu` request, hardened, policy-passing | renders + policy-gates in CI | $0 |
| NVIDIA optimization | `tensorrt/Dockerfile.trtllm` — TensorRT-LLM engine build (FP8/quant) | opt-in GPU host | $0 |
| GPU partitioning | `manifests/` — device-plugin, **time-slicing** (consumer GPU), **MIG** (datacenter) | config + local validate | $0 |
| Runtime smoke | `smoke/nim_smoke.py` — OpenAI wire protocol + throughput, real call | hosted NIM (build.nvidia.com) | $0 |

**Why the smoke hits hosted NIM, not local:** NIM containers, the hosted `build.nvidia.com`
endpoint, and our self-hosted vLLM pod expose the **same OpenAI chat-completions protocol**.
The client is identical; only `base_url` differs. So the smoke proves the runtime path is wired
correctly. Self-hosting is a one-env-var switch — no client change. This box (RTX 5070 Ti, 16GB,
no MIG) can run a tiny model but isn't a serving server; the goal is a working-proof, not a prod
inference host.

## Hardware honesty

- **RTX 5070 Ti** (Blackwell, consumer): can run small models via vLLM; **no MIG** (consumer cards
  lack it). Use **time-slicing** for GPU sharing here.
- **MIG** manifests target A100/H100/H200/B200. Documented, not faked. `mig-partition.sh` on a
  consumer card fails with `Not Supported` — that's expected and left as-is.

## Run the proof

```bash
# 1. Chart renders valid GPU-scheduled manifests
helm template vllm charts/vllm-serving > gpu-serving/docs/evidence/helm-template.txt

# 2. Policy gate passes (same conftest policy as the base repo)
helm template vllm charts/vllm-serving | conftest test --policy policy/ -

# 3. Live runtime smoke (free key from build.nvidia.com -> Get API Key)
export NVIDIA_API_KEY=nvapi-...
python gpu-serving/smoke/nim_smoke.py > gpu-serving/docs/evidence/smoke.local.json

# 4. (opt-in) Self-host the same protocol on a real GPU node
helm install vllm charts/vllm-serving --set model.name=Qwen/Qwen2.5-0.5B-Instruct
OPENAI_BASE_URL=http://localhost:8000/v1 OPENAI_API_KEY=dummy \
  MODEL=Qwen/Qwen2.5-0.5B-Instruct python gpu-serving/smoke/nim_smoke.py
```

See `docs/evidence/README.md` for what each artifact proves + the honesty checklist.
