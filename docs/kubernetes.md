# Local Kubernetes

Local clusters run on [kind](https://kind.sigs.k8s.io/) with [Cilium](https://cilium.io/) as the CNI.
kube-proxy is disabled — Cilium replaces it entirely with eBPF.

This is separate from the main dev-environment bootstrap. Nothing here runs automatically.

---

## Prerequisites

The tools below are installed by the normal `./run.sh install` (they live in the Brewfile):

| Tool | Purpose |
|------|---------|
| `kind` | Creates local Kubernetes clusters in Docker |
| `kubectl` | CLI for interacting with clusters |
| `helm` | Package manager — used to install Cilium |
| `cilium` (cilium-cli) | Cilium status, connectivity tests, Hubble access |
| `k9s` | TUI dashboard |
| `kubectx` | Quickly switch between clusters/namespaces |

Docker Desktop must be running before creating a cluster.

---

## Creating a cluster

```bash
./scripts/cluster.sh <name>
./scripts/cluster.sh <name> --with-gateway   # also installs Gateway API CRDs + Envoy Gateway
```

Example:

```bash
./scripts/cluster.sh dev
./scripts/cluster.sh dev --with-gateway
```

This will:
1. Create a kind cluster (1 control-plane + 2 workers) with no default CNI and no kube-proxy
2. Add the Cilium Helm repo and install Cilium with `kubeProxyReplacement=true`
3. Enable Hubble relay and UI
4. *(with `--with-gateway`)* Install Gateway API CRDs (experimental channel) and Envoy Gateway
5. Wait for Cilium to become healthy
6. Run a quick connectivity test

Once done, switch context:

```bash
kubectl config use-context kind-dev
```

---

## Tearing down a cluster

```bash
./scripts/cluster.sh <name> --delete
```

---

## Hubble (Cilium observability)

Forward the Hubble UI to localhost:

```bash
cilium hubble ui
```

Or use the relay directly from the CLI:

```bash
cilium hubble port-forward &
hubble observe
```

---

## Cluster config

The base cluster config is at `dotfiles/.config/kind/cluster.yaml`.
Key settings:

```yaml
networking:
  disableDefaultCNI: true   # kindnet is disabled — Cilium takes over
  kubeProxyMode: none       # kube-proxy is disabled — Cilium eBPF takes over

nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

To change the number of nodes, edit that file before running the script.

---

## Useful commands

```bash
# Check Cilium status
cilium status --context kind-<name>

# Run full connectivity test
cilium connectivity test --context kind-<name>

# List all clusters
kind get clusters

# Switch cluster context
kubectx kind-<name>

# Open k9s for a cluster
k9s --context kind-<name>
```
