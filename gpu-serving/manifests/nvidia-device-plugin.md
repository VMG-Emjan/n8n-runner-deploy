# NVIDIA GPU scheduling on Kubernetes — install notes

To make `nvidia.com/gpu` (and MIG resources) schedulable, the node needs:

1. **NVIDIA driver** + **NVIDIA Container Toolkit** (`nvidia-ctk runtime configure`), so containers
   can see the GPU.
2. The **NVIDIA device plugin** DaemonSet, which advertises GPU resources to the kubelet.

## Install the device plugin (whole-GPU, no sharing)

```bash
kubectl create namespace nvidia-device-plugin
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm install nvdp nvdp/nvidia-device-plugin \
  --namespace nvidia-device-plugin --version 0.16.2
kubectl get nodes -o json | jq '.items[].status.capacity["nvidia.com/gpu"]'
```

## Enable time-slicing (share one consumer GPU across pods)

Apply `time-slicing-configmap.yaml`, then restart the plugin pointing at it. One physical
RTX 5070 Ti then advertises 4 x `nvidia.com/gpu`. See that file for the exact patch.

## Enable MIG (datacenter GPUs only)

Use the **GPU Operator** (not the bare device plugin) so its MIG Manager can repartition:

```bash
helm install gpu-operator nvidia/gpu-operator -n gpu-operator --create-namespace \
  --set mig.strategy=single
kubectl label node <a100-node> nvidia.com/mig.config=all-1g.5gb --overwrite
```

Then the vllm-serving chart requests slices via `gpu.resourceName=nvidia.com/mig-1g.5gb`.

## kind (local) caveat

Plain `kind` does NOT expose the host GPU by default. Local GPU-in-kind needs the NVIDIA
runtime wired into the kind node + `--gpus all`. For the $0 proof we validate the **manifests
render + schedule** (helm template / conftest / kubectl --dry-run) and run the **runtime smoke**
against the hosted NIM endpoint. Live GPU-in-cluster is opt-in on a real GPU node.
