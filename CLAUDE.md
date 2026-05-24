# Dev Environment — Cluster Context

This is a local Kubernetes dev cluster. Use the rules below whenever adding or modifying workloads, infrastructure, or configuration.

## Cluster overview

- **Kind** cluster (1 control-plane + 2 workers), ports 80/443 forwarded via hostPort on the control-plane node
- **Cilium** as CNI + kube-proxy replacement
- **Envoy Gateway** (`v1.8.0`) handles all ingress — a single shared `Gateway` named `local` in namespace `envoy-gateway-system`, listeners `http` (port 80) and `https` (port 443, wildcard TLS via `dev-tls` secret)
- **cert-manager** with a wildcard cert covering `*.k8s.<domain>` — TLS is already handled; new apps just reference the existing gateway
- **ArgoCD** app-of-apps pattern: `k8s/apps/` is auto-synced by the `workloads` ArgoCD Application; infra components each have their own ArgoCD app under `k8s/argocd/apps/`
- **Pulumi** (`pulumi/src/`) bootstraps the cluster and owns: controllers (Envoy Gateway, cert-manager, ArgoCD, Cilium), the shared Gateway resource, TLS cert, and HTTPRoutes for system namespaces
- **DNS**: wildcard `*.k8s.<domain>` → `127.0.0.1` via local Technitium DNS; away from home use `scripts/dns-sync.sh`
- **Local registry**: `localhost:5001` (kind-registry container); use `scripts/deploy.sh` to build + push + rollout
- **Monitoring**: Prometheus + Grafana + Loki already running; add a `ServiceMonitor` if the app exposes `/metrics`

## Adding a new app workload

### 1. `k8s/apps/[myapp].yaml`

A single manifest file containing:

- `Namespace`
- `Deployment` (small resource requests/limits — this is a dev cluster)
- `Service` (ClusterIP, port 80 → container port)
- `HTTPRoute` (see placement rule below)

Do **not** create a separate `Gateway` or `Certificate` — reuse the existing shared ones.

If the app has a `/metrics` endpoint, add a `ServiceMonitor` to the same file.

Follow the pattern in `k8s/example.yaml` and `k8s/apps/registry-ui.yaml`.

### 2. `k8s/apps/kustomization.yaml`

Add `[myapp].yaml` to the `resources` list.

### 3. HTTPRoute placement — manifest vs Pulumi

**For ArgoCD-managed apps** (namespace lives in `k8s/apps/` — the common case), put the `HTTPRoute` in the manifest itself, not in `pulumi/src/gateway.ts`. Pulumi runs before ArgoCD syncs, so a Pulumi HTTPRoute targeting an ArgoCD-managed namespace will fail with `namespaces "x" not found`.

- Add it as the last resource in the manifest, after the `Service`
- Use the literal FQDN for `hostnames` (e.g. `myapp.k8s.thebetancurs.net`)
- `parentRefs`: `local` gateway, namespace `envoy-gateway-system`, `sectionName: https`

**For system components only** (namespace created by Pulumi — e.g. `kube-system`, `monitoring`, `registry-ui`), put the HTTPRoute in `pulumi/src/gateway.ts` following the `registryUiRoute` / `hubbleRoute` / `grafanaRoute` pattern, using `` pulumi.interpolate`[myapp].${base}` `` for the hostname.

### 4. `scripts/dns-sync.sh`

Add the app's subdomain to the `SERVICES` array — required for every new HTTPRoute hostname, otherwise DNS won't resolve away from the home network.

### 5. `pulumi/src/index.ts`

Always add a URL export so the app shows up in `pulumi stack output`, even for ArgoCD-managed apps (the export is a convenience output, it creates no resources):

```ts
export const [myapp]Url = pulumi.interpolate`https://[myapp].${base}`;
```

If the app is behind a feature flag:

```ts
export const [myapp]Url = install[MyApp] ? pulumi.interpolate`https://[myapp].${base}` : undefined;
```

### 6. Pulumi secret (if needed)

- Add the env var to `pulumi/.env.example` (follow the `OPENAI_API_KEY` pattern)
- Add the value to `pulumi/.env`
- Export via `cfg.requireSecret(...)` in `pulumi/src/config.ts` (follow the `openAiApiKey` / `cloudflareToken` pattern)
- Create a `k8s.core.v1.Secret` with `retainOnDelete: true`
- Add a `pulumi config set --secret` call to `pulumi/setup.sh` under a guard (follow the `INSTALL_AI_GATEWAY` / `CF_TOKEN` pattern)
- Import the new module in `pulumi/src/index.ts`

### 7. Build step

After any TypeScript changes in `pulumi/src/`:

```bash
cd pulumi && npm run build && pulumi up
```

ArgoCD picks up `k8s/apps/` changes automatically on git push — no `pulumi up` needed for manifest-only changes.

## Reference files

| File | Purpose |
|---|---|
| `k8s/apps/registry-ui.yaml` | Canonical app manifest (Namespace + Deployment + Service + HTTPRoute) |
| `k8s/example.yaml` | Minimal app template |
| `pulumi/src/gateway.ts` | HTTPRoute exports for system namespaces |
| `pulumi/src/config.ts` | Feature flags and secret config values |
| `pulumi/src/ai-gateway.ts` | Example of a feature-flagged optional component |
| `pulumi/setup.sh` | How `.env` vars become `pulumi config set` calls |
| `pulumi/.env.example` | All configurable env vars with comments |

## Rules — never do these

- Do not create a new `Gateway`, `GatewayClass`, or `Certificate`
- Do not add `finalizers: []` to ArgoCD Application manifests (causes spurious out-of-sync diffs)
- Do not skip `npm run build` before `pulumi up` when TypeScript source changed
- Do not use `imagePullPolicy: Always` for external registry images — only for `localhost:5001/` images being actively iterated on
- Do not hardcode domains in Pulumi — use `pulumi.interpolate\`...\``
- Do not put an HTTPRoute in Pulumi for a namespace that ArgoCD creates
