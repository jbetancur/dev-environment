import * as command from "@pulumi/command";
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";
import { argoCdVersion, base, context, repoUrl } from "./config";
import { provider, metricsServer } from "./cilium";

const argocdNs = "argocd";

// Install ArgoCD via Helm.
export const argocd = new k8s.helm.v3.Release(
  "argocd",
  {
    name: "argocd",
    chart: "argo-cd",
    version: argoCdVersion,
    namespace: argocdNs,
    createNamespace: true,
    repositoryOpts: { repo: "https://argoproj.github.io/argo-helm" },
    values: {
      configs: {
        params: {
          "server.insecure": true,
          "application.reconciliation.timeout": "30s",
        },
      },
    },
    waitForJobs: true,
  },
  { provider, dependsOn: metricsServer },
);

// Root app-of-apps Application CR — ArgoCD syncs everything else from git.
export const rootApp = new k8s.apiextensions.CustomResource(
  "argocd-root-app",
  {
    apiVersion: "argoproj.io/v1alpha1",
    kind: "Application",
    metadata: {
      name: "infra",
      namespace: argocdNs,
      finalizers: [],
    },
    spec: {
      project: "default",
      source: {
        repoURL: repoUrl,
        targetRevision: "HEAD",
        path: "k8s/argocd/apps",
      },
      destination: {
        server: "https://kubernetes.default.svc",
        namespace: argocdNs,
      },
      syncPolicy: {
        automated: { prune: true, selfHeal: true },
        syncOptions: ["CreateNamespace=true"],
      },
      ignoreDifferences: [
        {
          group: "argoproj.io",
          kind: "Application",
          jsonPointers: ["/status", "/operation", "/metadata/labels", "/metadata/finalizers"],
        },
      ],
    },
  },
  { provider, dependsOn: argocd },
);

// HTTPRoute for ArgoCD UI — routed through the Envoy Gateway.
// Applied here because ArgoCD is available immediately; the Gateway is
// waited on separately in gateway.ts before this route is useful.
export const argocdRoute = new k8s.apiextensions.CustomResource(
  "argocd-httproute",
  {
    apiVersion: "gateway.networking.k8s.io/v1",
    kind: "HTTPRoute",
    metadata: { name: "argocd", namespace: argocdNs },
    spec: {
      parentRefs: [
        { name: "local", namespace: "envoy-gateway-system", sectionName: "https" },
      ],
      hostnames: [pulumi.interpolate`argocd.${base}`],
      rules: [
        {
          matches: [{ path: { type: "PathPrefix", value: "/" } }],
          backendRefs: [{ name: "argocd-server", port: 80 }],
        },
      ],
    },
  },
  { provider, dependsOn: argocd },
);

// Read the initial admin password after ArgoCD is up — kubectl shell-out so
// Pulumi never tries to own or create the secret ArgoCD manages itself.
const adminSecret = new command.local.Command(
  "argocd-admin-password",
  {
    create: `kubectl get secret argocd-initial-admin-secret \
      --namespace ${argocdNs} \
      --context ${context} \
      -o jsonpath="{.data.password}" | base64 -d`,
    delete: `true`,
  },
  { dependsOn: argocd },
);

export const argocdPassword = adminSecret.stdout;
