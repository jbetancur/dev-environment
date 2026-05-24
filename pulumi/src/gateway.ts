import * as command from "@pulumi/command";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";
import { acmeEmail, base, certMode, context, domain, wildcard } from "./config";
import { provider } from "./cilium";
import { rootApp } from "./argocd";
import { certManagerNs, cloudflareSecret } from "./secrets";
import { envoyGatewayReady } from "./envoy";

// Wait for cert-manager CRDs — ArgoCD-deployed.
const certManagerReady = new command.local.Command(
  "cert-manager-ready",
  {
    create: `
      until kubectl get crd clusterissuers.cert-manager.io --context ${context} &>/dev/null; do sleep 5; done
      kubectl rollout status deployment/cert-manager \
        --namespace cert-manager \
        --context ${context} \
        --timeout=120s
      kubectl rollout status deployment/cert-manager-webhook \
        --namespace cert-manager \
        --context ${context} \
        --timeout=120s
      kubectl rollout status deployment/cert-manager-cainjector \
        --namespace cert-manager \
        --context ${context} \
        --timeout=120s
      until kubectl get validatingwebhookconfigurations cert-manager-webhook --context ${context} \
        -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null | grep -q .; do sleep 3; done
      until kubectl get endpoints cert-manager-webhook -n cert-manager --context ${context} \
        -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q .; do sleep 3; done
      until kubectl apply --dry-run=server --context ${context} -f - <<EOF &>/dev/null
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: webhook-probe
spec:
  selfSigned: {}
EOF
      do sleep 3; done
    `,
    delete: `true`,
  },
  { dependsOn: [rootApp, certManagerNs] },
);

// ── ClusterIssuer + Certificate ───────────────────────────────────────────────
// Both modes produce the same secret name (dev-tls) so the Gateway config
// below never changes regardless of which mode is active.

let devTlsCert: k8s.apiextensions.CustomResource;

if (certMode === "letsencrypt") {
  const issuer = new k8s.apiextensions.CustomResource(
    "letsencrypt-cloudflare",
    {
      apiVersion: "cert-manager.io/v1",
      kind: "ClusterIssuer",
      metadata: { name: "cluster-issuer" },
      spec: {
        acme: {
          server: "https://acme-v02.api.letsencrypt.org/directory",
          email: acmeEmail,
          privateKeySecretRef: { name: "letsencrypt-key" },
          solvers: [
            {
              dns01: {
                cloudflare: {
                  apiTokenSecretRef: {
                    name: "cloudflare-api-token",
                    key: "api-token",
                  },
                },
              },
              selector: { dnsZones: [domain] },
            },
          ],
        },
      },
    },
    { provider, dependsOn: [certManagerReady, cloudflareSecret!], deleteBeforeReplace: true, retainOnDelete: true },
  );

  devTlsCert = new k8s.apiextensions.CustomResource(
    "dev-tls",
    {
      apiVersion: "cert-manager.io/v1",
      kind: "Certificate",
      metadata: { name: "dev-tls", namespace: "envoy-gateway-system" },
      spec: {
        secretName: "dev-tls",
        commonName: wildcard,
        dnsNames: [wildcard, base],
        issuerRef: { name: "cluster-issuer", kind: "ClusterIssuer", group: "cert-manager.io" },
      },
    },
    { provider, dependsOn: issuer, retainOnDelete: true, ignoreChanges: ["spec", "status"] },
  );

} else {
  // Self-signed: CA issuer → CA cert → issuer that signs from the CA → wildcard cert.
  const selfSignedIssuer = new k8s.apiextensions.CustomResource(
    "selfsigned-issuer",
    {
      apiVersion: "cert-manager.io/v1",
      kind: "ClusterIssuer",
      metadata: { name: "selfsigned-issuer" },
      spec: { selfSigned: {} },
    },
    { provider, dependsOn: certManagerReady, retainOnDelete: true },
  );

  const caCert = new k8s.apiextensions.CustomResource(
    "local-ca-cert",
    {
      apiVersion: "cert-manager.io/v1",
      kind: "Certificate",
      metadata: { name: "local-ca", namespace: "cert-manager" },
      spec: {
        isCA: true,
        commonName: "local-ca",
        secretName: "local-ca-secret",
        issuerRef: { name: "selfsigned-issuer", kind: "ClusterIssuer", group: "cert-manager.io" },
      },
    },
    { provider, dependsOn: selfSignedIssuer, retainOnDelete: true },
  );

  const caIssuer = new k8s.apiextensions.CustomResource(
    "local-ca-issuer",
    {
      apiVersion: "cert-manager.io/v1",
      kind: "ClusterIssuer",
      metadata: { name: "cluster-issuer" },
      spec: {
        ca: { secretName: "local-ca-secret" },
      },
    },
    { provider, dependsOn: caCert, deleteBeforeReplace: true, retainOnDelete: true },
  );

  devTlsCert = new k8s.apiextensions.CustomResource(
    "dev-tls",
    {
      apiVersion: "cert-manager.io/v1",
      kind: "Certificate",
      metadata: { name: "dev-tls", namespace: "envoy-gateway-system" },
      spec: {
        secretName: "dev-tls",
        commonName: wildcard,
        dnsNames: [wildcard, base],
        issuerRef: { name: "cluster-issuer", kind: "ClusterIssuer", group: "cert-manager.io" },
      },
    },
    { provider, dependsOn: caIssuer, retainOnDelete: true, ignoreChanges: ["spec", "status"] },
  );
}

// Wait for the dev-tls secret — skip if a valid cert already exists (avoids re-issuing
// on re-runs and burning Let's Encrypt rate limits).
const tlsReady = new command.local.Command(
  "tls-ready",
  {
    create: `
      if kubectl get secret dev-tls -n envoy-gateway-system --context ${context} &>/dev/null; then
        exp=$(kubectl get secret dev-tls -n envoy-gateway-system --context ${context} \
          -o jsonpath='{.data.tls\\.crt}' | base64 -d | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ -n "$exp" ] && [ "$(date -d "$exp" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$exp" +%s 2>/dev/null)" -gt "$(date +%s)" ]; then
          echo "dev-tls cert is valid until $exp, skipping re-issue"
          exit 0
        fi
      fi
      kubectl wait --for=condition=Ready certificate/dev-tls \
        --namespace envoy-gateway-system \
        --context ${context} \
        --timeout=300s
    `,
    delete: `true`,
  },
  { dependsOn: [devTlsCert, envoyGatewayReady] },
);

// Gateway — TLS termination with the wildcard cert.
export const gateway = new k8s.apiextensions.CustomResource(
  "gateway",
  {
    apiVersion: "gateway.networking.k8s.io/v1",
    kind: "Gateway",
    metadata: { name: "local", namespace: "envoy-gateway-system" },
    spec: {
      gatewayClassName: "eg",
      listeners: [
        {
          name: "http",
          protocol: "HTTP",
          port: 80,
          allowedRoutes: { namespaces: { from: "All" } },
        },
        {
          name: "https",
          protocol: "HTTPS",
          port: 443,
          hostname: wildcard,
          allowedRoutes: { namespaces: { from: "All" } },
          tls: {
            mode: "Terminate",
            certificateRefs: [
              { name: "dev-tls", namespace: "envoy-gateway-system" },
            ],
          },
        },
      ],
    },
  },
  { provider, dependsOn: [tlsReady] },
);

// Hubble UI HTTPRoute.
export const hubbleRoute = new k8s.apiextensions.CustomResource(
  "hubble-httproute",
  {
    apiVersion: "gateway.networking.k8s.io/v1",
    kind: "HTTPRoute",
    metadata: { name: "hubble-ui", namespace: "kube-system" },
    spec: {
      parentRefs: [
        { name: "local", namespace: "envoy-gateway-system", sectionName: "https" },
      ],
      hostnames: [pulumi.interpolate`hubble.${base}`],
      rules: [
        {
          matches: [{ path: { type: "PathPrefix", value: "/" } }],
          backendRefs: [{ name: "hubble-ui", port: 80 }],
        },
      ],
    },
  },
  { provider, dependsOn: gateway },
);

// Grafana HTTPRoute.
export const grafanaRoute = new k8s.apiextensions.CustomResource(
  "grafana-httproute",
  {
    apiVersion: "gateway.networking.k8s.io/v1",
    kind: "HTTPRoute",
    metadata: { name: "grafana", namespace: "monitoring" },
    spec: {
      parentRefs: [
        { name: "local", namespace: "envoy-gateway-system", sectionName: "https" },
      ],
      hostnames: [pulumi.interpolate`grafana.${base}`],
      rules: [
        {
          matches: [{ path: { type: "PathPrefix", value: "/" } }],
          backendRefs: [{ name: "monitoring-grafana", port: 80 }],
        },
      ],
    },
  },
  { provider, dependsOn: gateway },
);
