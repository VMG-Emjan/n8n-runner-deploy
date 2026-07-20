#!/usr/bin/env bash
# Raw nvidia-smi MIG partitioning — the bare-metal equivalent of mig-config.yaml, for a node
# WITHOUT the GPU Operator. DATACENTER GPUs ONLY. Requires root + a MIG-capable GPU.
#
# On an RTX 5070 Ti this fails at `nvidia-smi -mig 1` with:
#   "Unable to enable MIG Mode: Not Supported"
# That is expected and honest — consumer cards have no MIG. Use time-slicing instead.
set -euo pipefail

GPU_ID="${1:-0}"

echo "== GPU inventory =="
nvidia-smi -L

echo "== Enabling MIG mode on GPU ${GPU_ID} =="
nvidia-smi -i "${GPU_ID}" -mig 1

echo "== Available GPU instance profiles =="
nvidia-smi mig -i "${GPU_ID}" -lgip

# Create 7 x 1g.5gb GPU instances (profile 19 on A100), each with a compute instance.
echo "== Creating 1g.5gb GPU instances =="
nvidia-smi mig -i "${GPU_ID}" -cgi 1g.5gb -C

echo "== Resulting MIG devices =="
nvidia-smi -L

echo "Done. Each MIG device now shows as an isolated GPU with dedicated memory + SMs."
