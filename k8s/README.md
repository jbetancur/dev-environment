# k8s

Local kind cluster bootstrapped with Cilium + ArgoCD. After bootstrap, ArgoCD
manages everything else — Envoy Gateway, cert-manager, monitoring, and your app
workloads — by syncing from this repo.

## Quick start

### 1. Fill in your values

Edit `user.conf` (gitignored — your real values, never committed):

```bash
ACME_EMAIL=you@example.com
ACME_DOMAIN=yourdomain.com
ACME_SUBDOMAIN=dev
ARGOCD_REPO_URL=https://github.com/you/dev-environment.git
CLOUDFLARE_TOKEN=your_token   # Zone:DNS:Edit for your domain
```

`k8s/cluster.env` is committed with placeholder defaults. `user.conf` overrides
them at bootstrap — so the repo stays generic and anyone can fork and use it.

### 2. Bootstrap

```bash
./scripts/cluster.sh mycluster
```

That's it. `cluster.sh` installs Cilium and ArgoCD, then ArgoCD syncs everything
else from git automatically.

### 3. Tear down

```bash
./scripts/cluster.sh mycluster --delete
```

## What cluster.sh does

| Step | What |
| ---- | ---- |
| Read config | Sources `k8s/cluster.env` (placeholder defaults) then `user.conf` (your real values) |
| Create ConfigMap | `cluster-values` created imperatively in the `argocd` namespace — Kustomize reads from it at sync time |
| Local registry | `localhost:5001` — push images here, pull from cluster |
| Gateway API CRDs | Installed before Cilium so the operator finds them at startup |
| Cilium | CNI + kube-proxy replacement via eBPF, Hubble enabled |
| metrics-server | Enables `kubectl top` and HPA |
| Secrets | `cloudflare-api-token` in `cert-manager` namespace |
| ArgoCD | Installed via Helm, then root app-of-apps applied |

After the root app is applied ArgoCD takes over and syncs:

| ArgoCD Application | What it manages |
| ------------------ | --------------- |
| `envoy-gateway` | Envoy Gateway Helm release |
| `envoy-gateway-config` | GatewayClass, EnvoyProxy, Gateway, HTTPS redirect |
| `cert-manager` | cert-manager Helm release |
| `cert-manager-config` | ClusterIssuer + wildcard Certificate |
| `monitoring` | kube-prometheus-stack Helm release |
| `monitoring-config` | Prometheus RBAC, ServiceMonitors, Grafana dashboards + HTTPRoute |
| `hubble` | Hubble UI HTTPRoute |
| `workloads` | Everything in `k8s/apps/` |

## DNS

Traffic reaches the cluster via hostPorts 80/443 on the control-plane node → `127.0.0.1`.

**At home** (Technitium on `10.0.10.5`): add `*.dev.example.com A 127.0.0.1` to your local DNS zone.

**Away from home**: run the DNS sync script:

```bash
sudo ./scripts/dns-sync.sh    # auto-detects home vs away
```

Add new services to the `SERVICES` array in `scripts/dns-sync.sh`.

## Deploying an app

1. Copy `k8s/example.yaml`, update image/namespace/hostname, place it in `k8s/apps/`.
2. Add the hostname to `scripts/dns-sync.sh` `SERVICES`.
3. Push to git — ArgoCD syncs automatically.

To build and push the image:

```bash
./scripts/deploy.sh <image-name> <dockerfile-dir> <namespace> <deployment>
```

## Directory structure

```text
k8s/
├── cluster.env           # Placeholder defaults — committed, never has real values
├── example.yaml          # Template for new app manifests — copy to apps/
├── apps/                 # App workloads — synced by ArgoCD automatically
├── argocd/
│   ├── root.yaml         # Root app-of-apps (applied once by cluster.sh)
│   ├── httproute.yaml    # ArgoCD UI HTTPRoute
│   └── apps/             # Child Application CRs (one per infra component)
├── cert-manager/         # ClusterIssuer + Certificate (Kustomize)
├── envoy-gateway/        # GatewayClass, EnvoyProxy, Gateway, HTTPS redirect (Kustomize)
├── hubble/               # Hubble UI HTTPRoute (Kustomize)
├── monitoring/           # Prometheus RBAC, ServiceMonitors, dashboards, Grafana HTTPRoute (Kustomize)
└── registry/             # LocalRegistryHosting ConfigMap
```

## Known gotchas

- **Envoy proxy rollout deadlock** — proxy pods use hostPorts 80/443. If a rollout
  hangs, manually delete the old proxy pod.

- **cert-manager DNS-01 + CoreDNS** — cert-manager is configured with
  `--dns01-recursive-nameservers-only` to bypass CoreDNS for ACME challenges.

- **Grafana dashboard datasource** — dashboards from Grafana.com must use the
  object datasource form `{"type": "prometheus", "uid": "prometheus"}`, not
  the old `${DS_PROMETHEUS}` string format.

- **ArgoCD repo access** — `ARGOCD_REPO_URL` must be an HTTPS URL for public
  repos. Private repos need a deploy key or token configured in ArgoCD.
