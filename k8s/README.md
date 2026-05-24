# k8s

Local kind cluster bootstrapped with Cilium + ArgoCD. After bootstrap, ArgoCD
manages everything else — Envoy Gateway, cert-manager, monitoring, and your app
workloads — by syncing from this repo.

## Quick start

See `pulumi/` for cluster bootstrap. Configuration lives in your Pulumi stack
(`Pulumi.<name>.yaml`) — no files to edit here.

```bash
cd pulumi
pulumi stack select <your-name>
pulumi up
```

To tear down:

```bash
pulumi destroy
```

## What ArgoCD manages

Once Pulumi hands off to ArgoCD, it continuously syncs:

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

## Deploying an app

1. Copy `k8s/example.yaml`, update image/namespace/hostname, place it in `k8s/apps/`.
2. Add the hostname to `scripts/dns-sync.sh` `SERVICES`.
3. Push to git — ArgoCD syncs automatically.

To build and push the image locally:

```bash
./scripts/deploy.sh <image-name> <dockerfile-dir> <namespace> <deployment>
```

## DNS

Traffic reaches the cluster via hostPorts 80/443 on the control-plane node → `127.0.0.1`.

**At home** (Technitium on `10.0.10.5`): add `*.dev.example.com A 127.0.0.1` to your local DNS zone.

**Away from home**: run the DNS sync script:

```bash
sudo ./scripts/dns-sync.sh    # auto-detects home vs away
```

## Directory structure

```text
k8s/
├── example.yaml          # Template for new app manifests — copy to apps/
├── apps/                 # App workloads — synced by ArgoCD automatically
├── argocd/
│   └── apps/             # Child Application CRs (one per infra component)
├── cert-manager/         # (managed by ArgoCD — ClusterIssuer + Certificate applied by Pulumi)
├── envoy-gateway/        # GatewayClass, EnvoyProxy, HTTPS redirect
├── hubble/               # Hubble UI kustomization
├── monitoring/           # Prometheus RBAC, ServiceMonitors, Grafana dashboards
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

- **ArgoCD repo access** — `repoUrl` must be an HTTPS URL for public repos.
  Private repos need a deploy key or token configured in ArgoCD.
