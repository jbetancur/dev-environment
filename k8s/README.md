# k8s

Local kind cluster bootstrapped with Pulumi. After bootstrap, ArgoCD manages everything else — Envoy Gateway, cert-manager, monitoring (Prometheus + Grafana + Loki), and app workloads — by syncing from this repo.

## Quick start

See `pulumi/` for cluster bootstrap. Config lives in `pulumi/.env` (gitignored).

```bash
cp pulumi/.env.example pulumi/.env
# edit .env with your values
./pulumi/setup.sh
cd pulumi && pulumi up
```

To tear down:

```bash
cd pulumi && pulumi destroy
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
| `loki` | Loki log aggregation (SingleBinary, filesystem storage) |
| `promtail` | Promtail DaemonSet — ships pod logs to Loki |
| `monitoring-config` | Prometheus RBAC, ServiceMonitors, Grafana dashboards + datasources |
| `hubble` | Hubble UI HTTPRoute |
| `workloads` | Everything in `k8s/apps/` |
| `reloader` | Stakater Reloader — auto-restarts pods on ConfigMap/Secret changes |

## Deploying an app

1. Copy `k8s/example.yaml`, update image/namespace/hostname, place it in `k8s/apps/`.
2. Push to git — ArgoCD syncs automatically within ~30s (poll interval configured via `application.reconciliation.timeout`).

To trigger an automatic pod restart when a ConfigMap changes, add this annotation to the Deployment's pod template:

```yaml
configmap.reloader.stakater.com/reload: "my-configmap"
```

To build and push the image to the local registry:

```bash
./scripts/deploy.sh <image-name> <dockerfile-dir> <namespace> <deployment>
```

## DNS

Traffic reaches the cluster via hostPorts 80/443 on the control-plane node → `127.0.0.1`.

Add a wildcard record pointing to `127.0.0.1` in your local DNS (e.g. Technitium):

```text
*.k8s.yourdomain.com  A  127.0.0.1
```

Away from home, run the DNS sync script:

```bash
sudo ./scripts/dns-sync.sh
```

## Services

Once the cluster is healthy, these URLs are available:

| Service | URL |
| ------- | --- |
| ArgoCD | `https://argocd.k8s.<domain>` |
| Grafana (metrics + logs) | `https://grafana.k8s.<domain>` |
| Hubble (network flows) | `https://hubble.k8s.<domain>` |
| AI Gateway Demo | `https://ai-demo.k8s.<domain>` |

Grafana credentials: `admin / admin` (set via `grafana.adminPassword` in the monitoring app).

Loki logs are available in Grafana → Explore → select the **Loki** datasource.
The **Logs / App** dashboard is pre-provisioned under Dashboards.

## Directory structure

```text
k8s/
├── example.yaml          # Template for new app manifests — copy to apps/
├── apps/                 # App workloads — synced by ArgoCD automatically
├── argocd/
│   └── apps/             # Child Application CRs (one per infra component)
├── envoy-gateway/        # GatewayClass, EnvoyProxy, HTTPS redirect
├── monitoring/           # Prometheus RBAC, ServiceMonitors, Grafana dashboards + datasources
└── registry/             # LocalRegistryHosting ConfigMap
```

## Known gotchas

- **Envoy proxy rollout deadlock** — proxy pods use hostPorts 80/443. If a rollout
  hangs with a scheduling error, manually delete the old proxy pod.

- **cert-manager DNS-01 + CoreDNS** — cert-manager is configured with
  `--dns01-recursive-nameservers-only` to bypass CoreDNS for ACME challenges.

- **Grafana dashboard datasource** — dashboards must use the object form
  `{"type": "prometheus", "uid": "prometheus"}` (not the old `${DS_PROMETHEUS}` string).
  Loki dashboards use `{"type": "loki", "uid": "loki"}`.

- **ArgoCD `finalizers: []` drift** — omit `finalizers` entirely from Application
  manifests; an explicit empty list causes spurious out-of-sync diffs.

- **Loki cache memory** — the Loki 7.x chart enables memcached chunks/results
  caches by default (~10 GiB requests). Both are disabled in our config for dev.
