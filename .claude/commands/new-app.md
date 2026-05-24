Onboard a new application workload to this cluster end-to-end. Ask the user for the following details before doing any work:

1. **App name** (used as namespace, deployment name, and subdomain)
2. **Image** (`localhost:5001/name:latest` for local builds, or a public image)
3. **Container port**
4. **Has `/metrics` endpoint?** (yes/no)
5. **Needs secrets or env vars?** (describe, or none)
6. **Optional component?** (should it be behind a feature flag like `installAiGateway`?)

Once you have the answers, create all of the following:

- `k8s/apps/[name].yaml` — Namespace, Deployment, Service, HTTPRoute (in the manifest, not in Pulumi), and ServiceMonitor if metrics=yes
- Add `[name].yaml` to `k8s/apps/kustomization.yaml`
- Add the subdomain to the `SERVICES` array in `scripts/dns-sync.sh`
- Add `export const [name]Url` to `pulumi/src/index.ts` (gated behind the flag if optional)
- If secrets needed: follow the `openAiApiKey` pattern across `pulumi/src/config.ts`, `pulumi/setup.sh`, and `pulumi/.env.example`

Follow all rules in CLAUDE.md. Do not create a new Gateway, GatewayClass, or Certificate.
