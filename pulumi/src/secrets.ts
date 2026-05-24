import * as k8s from "@pulumi/kubernetes";
import { certMode, cloudflareToken } from "./config";
import { provider } from "./cilium";
import { argocd } from "./argocd";

// cert-manager namespace — created here so the secret is ready before ArgoCD
// deploys cert-manager (which would also create the namespace).
export const certManagerNs = new k8s.core.v1.Namespace(
  "cert-manager-ns",
  { metadata: { name: "cert-manager" } },
  { provider, dependsOn: argocd },
);

// Cloudflare API token — only needed for letsencrypt mode.
export const cloudflareSecret = certMode === "letsencrypt"
  ? new k8s.core.v1.Secret(
      "cloudflare-api-token",
      {
        metadata: { name: "cloudflare-api-token", namespace: "cert-manager" },
        stringData: { "api-token": cloudflareToken },
      },
      { provider, dependsOn: certManagerNs, retainOnDelete: true },
    )
  : undefined;
