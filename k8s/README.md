# k8s

Local kind cluster with Cilium CNI, Envoy Gateway ingress, Let's Encrypt TLS,
and Prometheus/Grafana monitoring. Everything is provisioned by `scripts/cluster.sh`.

## Quick start

```bash
# Full stack — recommended
./scripts/cluster.sh mycluster --full

# Or pick flags individually
./scripts/cluster.sh mycluster --with-gateway --with-acme --with-monitoring

# Tear down
./scripts/cluster.sh mycluster --delete
```

`--with-acme` requires `user.conf` to be populated (see below).

## Prerequisites

Install required tools — the script will offer to auto-install missing ones via Homebrew:
`kind`, `kubectl`, `helm`, `cilium-cli`

For `--with-acme`, fill in `user.conf` (copy from `user.conf.example`):

```bash
ACME_EMAIL=you@example.com
ACME_DOMAIN=example.com
ACME_SUBDOMAIN=dev
CLOUDFLARE_TOKEN=your_token   # Zone:DNS:Edit — Cloudflare → My Profile → API Tokens
```

## What gets installed

| Flag | Components |
| ------------------- | ---------- |
| _(base)_ | kind cluster, local registry (`localhost:5001`), Cilium, Hubble, metrics-server |
| `--with-gateway` | Gateway API CRDs, Envoy Gateway, GatewayClass `eg`, Gateway `local`, HTTPS redirect, Hubble HTTPRoute |
| `--with-acme` | cert-manager, Cloudflare DNS-01 issuer, wildcard cert `*.dev.example.com` |
| `--with-monitoring` | kube-prometheus-stack (Prometheus + Grafana), ServiceMonitors, dashboards, Grafana HTTPRoute |
| `--with-argocd` | ArgoCD, HTTPRoute, app-of-apps syncing `k8s/apps/` from git |

Grafana: `https://grafana.dev.example.com` — credentials `admin` / `admin`

## DNS

Traffic reaches the cluster via hostPorts 80/443 on the control-plane node → `127.0.0.1`.

**At home** (Technitium on `10.0.10.5`): wildcard `*.dev.example.com → 127.0.0.1` is
already configured in the local DNS zone.

**Away from home**: run the DNS sync script to add entries to `/etc/hosts`:

```bash
sudo ./scripts/dns-sync.sh          # auto-detects home vs away
sudo ./scripts/dns-sync.sh --add    # force add
sudo ./scripts/dns-sync.sh --remove # force remove
```

Add new services to the `SERVICES` array in `scripts/dns-sync.sh`.

## Deploying an app

1. Copy `k8s/apps/example.yaml`, update image/namespace/hostname.
2. Add the hostname to `scripts/dns-sync.sh` `SERVICES`.
3. Build, push, and roll out:

```bash
./scripts/deploy.sh <image-name> <dockerfile-dir> <namespace> <deployment>
```

---

Manifests reference below. Everything here is applied by
`scripts/cluster.sh` — do not `kubectl apply` these directly unless noted.

## Directory structure

```sh
k8s/
├── apps/              # App workloads — copy example.yaml for each new service
├── cert-manager/      # Let's Encrypt ClusterIssuer + wildcard Certificate (envsubst-templated)
├── envoy-gateway/     # GatewayClass, Gateway, EnvoyProxy config, HTTPS redirect
├── hubble/            # Hubble UI HTTPRoute (two variants — see below)
├── monitoring/        # Prometheus RBAC, ServiceMonitors, Grafana dashboards
└── registry/          # LocalRegistryHosting ConfigMap (standard discovery spec)
```

## How the stack fits together

```sh
Internet / localhost
       │
       ▼ :80/:443 (hostPort on control-plane node)
  Envoy Gateway proxy
       │
       ├── GatewayClass "eg"  ──►  EnvoyProxy "kind-hostport"
       │                               schedules on control-plane node
       │                               maps containerPort 10080/10443 → hostPort 80/443
       │
       ├── Gateway "local" (HTTP + HTTPS listeners)
       │
       └── HTTPRoutes  ──►  Services  ──►  Pods
```

TLS is terminated at the Gateway using a Let's Encrypt wildcard cert
(`*.dev.example.com`) issued via Cloudflare DNS-01.

## Directories

### apps/

Copy `example.yaml` for each new service. Pattern:

- Deployment pulling from `localhost:5001/<image>:latest`
- Service on port 80
- HTTPRoute with hostnames `myapp.localhost` and `myapp.dev.example.com`

Use `scripts/deploy.sh` to build, push, and roll out.

### cert-manager/

| File | Description |
|------|-------------|
| `cloudflare-issuer.yaml` | `ClusterIssuer` (Let's Encrypt + Cloudflare DNS-01) and `Certificate` for `*.dev.example.com`. **envsubst-templated** — never apply directly. |

Variables substituted by `cluster.sh`: `$ACME_EMAIL`, `$ACME_DOMAIN`, `$ACME_SUBDOMAIN`.

**Gotcha:** cert-manager must be configured with
`--dns01-recursive-nameservers-only --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53`
or the DNS-01 challenge fails (CoreDNS returns SERVFAIL for external lookups).

### envoy-gateway/

| File | Description |
|------|-------------|
| `envoy-proxy-kind.yaml` | `EnvoyProxy` — pins proxy pods to the control-plane node and maps hostPorts 80/443. |
| `gatewayclass.yaml` | `GatewayClass "eg"` — references `kind-hostport` EnvoyProxy. |
| `gateway.yaml` | Plain HTTP-only Gateway. Used when `--with-acme` is not set. |
| `gateway-https.yaml` | HTTP + HTTPS Gateway with TLS cert ref. **envsubst-templated.** Used with `--with-acme`. |
| `https-redirect.yaml` | HTTPRoute that 301-redirects all HTTP traffic to HTTPS. Applied after the HTTPS gateway. |

**Gotcha:** Envoy proxy pod rollouts deadlock on hostPorts — the new pod can't
schedule until the old one releases ports 80/443. If a rollout hangs, manually
delete the old proxy pod to unblock it.

### hubble/

| File | Description |
|------|-------------|
| `httproute-local.yaml` | HTTP only, `hubble.localhost`. Applied directly (no templating) when `--with-gateway` is used without `--with-acme`. |
| `httproute.yaml` | HTTPS, `hubble.localhost` + `hubble.dev.example.com`. **envsubst-templated.** Applied with `--with-acme`. |

### monitoring/

| File | Description |
|------|-------------|
| `prometheus-rbac.yaml` | `ClusterRoleBinding` giving the kube-prometheus-stack service account cross-namespace scrape access (needed for Cilium, cert-manager, Envoy in other namespaces). |
| `servicemonitors.yaml` | `ServiceMonitor` resources for Cilium agent, cert-manager, and Envoy Gateway proxy. Also creates headless Services for Cilium metrics (port 9962) and Envoy proxy metrics (port 19001) since those components don't create them automatically. |
| `dashboards.yaml` | Grafana dashboard ConfigMaps (Cilium, cert-manager, Envoy Gateway). Auto-discovered by the Grafana sidecar via the `grafana_dashboard=1` label. |
| `grafana-httproute.yaml` | HTTPRoute exposing Grafana at `grafana.dev.example.com`. **envsubst-templated.** |

**Gotcha:** Grafana dashboards sourced from Grafana.com use `${DS_PROMETHEUS}`
string datasource references (Grafana 7.x format). The sidecar provisioner
doesn't resolve `__inputs` — all panel datasources must use the object form
`{"type": "prometheus", "uid": "prometheus"}` instead.

### registry/

| File | Description |
|------|-------------|
| `local-registry-hosting.yaml` | ConfigMap advertising `localhost:5001` as the local registry to tools like Tilt and Skaffold. |

## Adding a new service

1. Copy `apps/example.yaml`, rename, and update image/namespace/hostname.
2. Add the hostname to `scripts/dns-sync.sh` `SERVICES` array so it's added to `/etc/hosts` when away from the home network.
3. Deploy with `scripts/deploy.sh <image> <dockerfile-dir> <namespace> <deployment>`.
