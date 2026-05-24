# Prompt: Add a new app workload to the dev cluster

Use this prompt with Claude Code when onboarding a new service. Fill in the bracketed values before sending.

---

I'm adding a new application workload to my local Kubernetes dev cluster. Here's the context and what I need wired up end-to-end.

## Cluster overview

- **Kind** cluster (1 control-plane + 2 workers), ports 80/443 forwarded via hostPort on the control-plane node
- **Cilium** as CNI + kube-proxy replacement
- **Envoy Gateway** (`v1.8.0`) handles all ingress — a single shared `Gateway` named `local` in namespace `envoy-gateway-system`, listeners `http` (port 80) and `https` (port 443, wildcard TLS via `dev-tls` secret)
- **cert-manager** with a wildcard cert covering `*.k8s.<domain>` — TLS is already handled; new apps just reference the existing gateway
- **ArgoCD** app-of-apps pattern: `k8s/apps/` is auto-synced by the `workloads` ArgoCD Application; infra components each have their own ArgoCD app under `k8s/argocd/apps/`
- **Pulumi** (`pulumi/src/`) bootstraps the cluster and owns: controllers (Envoy Gateway, cert-manager, ArgoCD, Cilium), the shared Gateway resource, TLS cert, and all HTTPRoutes
- **DNS**: wildcard `*.k8s.<domain>` → `127.0.0.1` via local Technitium DNS; away from home use `scripts/dns-sync.sh`
- **Local registry**: `localhost:5001` (kind-registry container); use `scripts/deploy.sh` to build + push + rollout
- **Monitoring**: Prometheus + Grafana + Loki already running; add a `ServiceMonitor` if the app exposes `/metrics`

## App details

- **App name**: `[myapp]`
- **Namespace**: `[myapp]`
- **Hostname**: `[myapp].k8s.<domain>` (wildcard cert already covers this)
- **Image source**: `[localhost:5001/myapp:latest | docker.io/org/image:tag]`
- **Container port**: `[8080]`
- **Service port**: `[80]`
- **Has `/metrics` endpoint**: `[yes | no]`
- **Needs env vars or secrets**: `[describe, or "none"]`
- **Needs a Pulumi-managed secret** (e.g. API key from `.env`): `[yes — describe | no]`

## What I need created

### 1. `k8s/apps/[myapp].yaml`

A single manifest file containing:

- `Namespace`
- `Deployment` (with resource requests/limits appropriate for a dev cluster — keep them small)
- `Service` (ClusterIP, port 80 → container port)
- `HTTPRoute` attached to the `local` Gateway in `envoy-gateway-system`, `sectionName: https`, hostname `[myapp].k8s.<domain>`

Do **not** create a separate `Gateway` or `Certificate` — reuse the existing shared ones.

If the app has a `/metrics` endpoint, add a `ServiceMonitor` to the same file.

Follow the pattern in `k8s/example.yaml` and `k8s/apps/registry-ui.yaml`.

### 2. `k8s/apps/kustomization.yaml`

Add `[myapp].yaml` to the `resources` list.

### 3. HTTPRoute placement — manifest vs Pulumi

**Rule**: if the app's namespace is created by ArgoCD (i.e. the manifest lives in `k8s/apps/`), put the `HTTPRoute` in the manifest file itself — not in `pulumi/src/gateway.ts`. Pulumi runs before ArgoCD syncs, so creating an HTTPRoute in Pulumi for an ArgoCD-managed namespace will fail with `namespaces "x" not found`.

**When to put the HTTPRoute in `k8s/apps/[myapp].yaml`** (ArgoCD-managed apps — the common case):

- Add it as the last resource in the manifest, after the `Service`
- Use the literal FQDN for `hostnames` (e.g. `ai-demo.k8s.thebetancurs.net`)
- `parentRefs`: `local` gateway, namespace `envoy-gateway-system`, `sectionName: https`

**When to put the HTTPRoute in `pulumi/src/gateway.ts`** (system components only):

- The namespace is created by Pulumi itself (e.g. `kube-system`, `monitoring`, `registry-ui`)
- Follow the `registryUiRoute` / `hubbleRoute` / `grafanaRoute` export pattern
- Use `` pulumi.interpolate`[myapp].${base}` `` for the hostname

### 4. Pulumi secret (if needed)

If the app requires a secret (e.g. an API key):

- Add the env var to `pulumi/.env.example` with a comment (follow the `OPENAI_API_KEY` pattern)
- Add the var to `pulumi/.env` (actual value)
- Add `cfg.requireSecret(...)` export to `pulumi/src/secrets.ts` or `pulumi/src/config.ts` (follow the `openAiApiKey` / `cloudflareToken` pattern)
- Create a `k8s.core.v1.Secret` in `pulumi/src/[myapp].ts` or inline in `gateway.ts`, with `retainOnDelete: true`
- Add the config set line to `pulumi/setup.sh` under a guard (follow the `INSTALL_AI_GATEWAY` / `CF_TOKEN` pattern if it's optional)
- Import the new module in `pulumi/src/index.ts`

### 5. `pulumi/src/index.ts`

Always add a URL export so the app shows up in `pulumi stack output`:

```ts
export const [myapp]Url = pulumi.interpolate`https://[myapp].${base}`;
```

This applies even for ArgoCD-managed apps whose HTTPRoute lives in the manifest — the URL export is just a convenience output, it doesn't create any resources.

If the app is behind a feature flag, gate it:

```ts
export const [myapp]Url = install[MyApp] ? pulumi.interpolate`https://[myapp].${base}` : undefined;
```

### 6. `scripts/dns-sync.sh`

Add the app's subdomain to the `SERVICES` array so it gets written to `/etc/hosts` when away from home:

```bash
SERVICES=(
  ...
  [myapp]
)
```

This is required for every new HTTPRoute hostname. Without it, DNS won't resolve away from the home network.

### 7. Build step reminder

After any TypeScript changes in `pulumi/src/`, run:

```bash
cd pulumi && npm run build && pulumi up
```

ArgoCD picks up `k8s/apps/` changes automatically on git push — no `pulumi up` needed for manifest-only changes.

## Patterns to follow (read these files first)

| File | Why |
|---|---|
| `k8s/apps/registry-ui.yaml` | Canonical app manifest (Namespace + Deployment + Service + HTTPRoute) |
| `k8s/example.yaml` | Minimal template with comments |
| `pulumi/src/gateway.ts` | All HTTPRoute exports live here |
| `pulumi/src/secrets.ts` | Kubernetes Secret resources |
| `pulumi/src/config.ts` | Feature flags and secret config values |
| `pulumi/src/ai-gateway.ts` | Example of a feature-flagged optional component |
| `pulumi/setup.sh` | How env vars become `pulumi config set` calls |
| `pulumi/.env.example` | Canonical list of all configurable env vars |

## DNS / connectivity checklist

- [ ] Wildcard DNS `*.k8s.<domain>` → `127.0.0.1` is already set in Technitium — no new record needed
- [ ] TLS is handled by the shared `dev-tls` wildcard cert — no new `Certificate` needed
- [ ] HTTPRoute is attached to `sectionName: https` on the `local` Gateway
- [ ] After `pulumi up`, verify: `curl -si https://[myapp].k8s.<domain>/healthz` (or equivalent)
- [ ] App shows up in ArgoCD UI under the `workloads` application

## What NOT to do

- Do not create a new `Gateway`, `GatewayClass`, or `Certificate`
- Do not hardcode the domain — use `pulumi.interpolate\`...\`` in Pulumi and the actual FQDN in the k8s manifest
- Do not add `finalizers: []` to ArgoCD Application manifests (causes spurious drift)
- Do not skip `npm run build` before `pulumi up` when TS source changed
- Do not use `imagePullPolicy: Always` for external registry images; only use it for `localhost:5001/` images that are actively being iterated on
