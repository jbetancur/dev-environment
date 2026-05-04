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
| `helm` | Package manager — used to install Cilium and other components |
| `cilium` (cilium-cli) | Cilium status, connectivity tests, Hubble access |
| `k9s` | TUI dashboard |
| `kubectx` | Quickly switch between clusters/namespaces |

Docker Desktop must be running before creating a cluster.

---

## Creating a cluster

```bash
./scripts/cluster.sh <name>                              # bare cluster
./scripts/cluster.sh <name> --with-gateway               # + Envoy Gateway + Gateway API CRDs
./scripts/cluster.sh <name> --with-certs                 # + cert-manager
./scripts/cluster.sh <name> --with-gateway --with-certs  # all of the above
./scripts/cluster.sh <name> --no-test                    # skip Cilium connectivity tests
```

Every cluster gets the following regardless of flags:
1. kind cluster (1 control-plane + 2 workers), no default CNI, no kube-proxy
2. Local image registry on `localhost:5001` (shared across clusters, removed when last cluster is deleted)
3. Cilium with `kubeProxyReplacement=true`, Hubble relay + UI enabled
4. metrics-server (enables `kubectl top` and HPA)
5. Cilium connectivity tests (skip with `--no-test`)

Once done, switch context:

```bash
kubectl config use-context kind-<name>
```

---

## Tearing down a cluster

```bash
./scripts/cluster.sh <name> --delete
```

The local registry is removed automatically when the last kind cluster is deleted.

---

## Local image registry

Every cluster is wired to a local registry at `localhost:5001`. No `kind load` needed.

```bash
# Build and push
docker build -t localhost:5001/myapp:latest .
docker push localhost:5001/myapp:latest

# Reference in manifests
image: localhost:5001/myapp:latest
```

The registry container (`kind-registry`) is shared — if you spin up a second cluster it reuses the same one.

---

## Envoy Gateway (`--with-gateway`)

Installs Gateway API CRDs and Envoy Gateway via the `envoy-gateway/gateway-crds` and `envoy-gateway/gateway-helm` Helm charts (both pinned to `EG_VERSION` in `cluster.sh`).

Proxy pods are scheduled on the control-plane node via a strategic merge patch ([k8s/envoy-gateway/envoy-proxy-kind.yaml](../k8s/envoy-gateway/envoy-proxy-kind.yaml)) and expose `hostPort` 80/443 — no LoadBalancer or MetalLB needed.

Create a Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
  namespace: default
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      port: 80
      protocol: HTTP
```

Then route to a service with an `HTTPRoute` — traffic arrives at `http://localhost`.

---

## cert-manager (`--with-certs`)

Installs cert-manager (version pinned to `CERT_MANAGER_VERSION` in `cluster.sh`) with CRDs managed by Helm.

Pairs with Envoy Gateway for TLS — create a `Certificate` resource and reference it in a `Gateway` listener's `certificateRefs`.

---

## Hubble (Cilium observability)

```bash
# Open the visual flow map in your browser
cilium hubble ui --context kind-<name>

# Live flow stream in the CLI
cilium hubble port-forward --context kind-<name> &
hubble observe --follow
```

---

## Cluster config

The base cluster config is at [dotfiles/.config/kind/cluster.yaml](../dotfiles/.config/kind/cluster.yaml). Key settings:

```yaml
networking:
  disableDefaultCNI: true   # kindnet disabled — Cilium takes over
  kubeProxyMode: none       # kube-proxy disabled — Cilium eBPF takes over

containerdConfigPatches:
  # Wires all nodes to the local registry container
  - ...

nodes:
  - role: control-plane
    extraPortMappings:      # needed for Envoy Gateway hostPort
      - containerPort: 80 / hostPort: 80
      - containerPort: 443 / hostPort: 443
  - role: worker
  - role: worker
```

To change the number of nodes, edit that file before running the script (requires cluster recreation).

---

## Useful commands

```bash
# Check Cilium status
cilium status --context kind-<name>

# Run full connectivity test
cilium connectivity test --context kind-<name>

# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A

# List all clusters
kind get clusters

# Switch cluster context
kubectx kind-<name>

# Open k9s for a cluster
k9s --context kind-<name>
```

