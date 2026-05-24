import * as k8s from "@pulumi/kubernetes";
import * as command from "@pulumi/command";
import { context, envoyGatewayVersion } from "./config";
import { provider, metricsServer } from "./cilium";

// Install Envoy Gateway via Helm directly — same pattern as Cilium/ArgoCD.
// ArgoCD manages the config (GatewayClass, EnvoyProxy, HTTPRoutes) via git;
// Pulumi owns the controller itself.
export const envoyGateway = new k8s.helm.v3.Release(
  "envoy-gateway",
  {
    name: "envoy-gateway",
    chart: "oci://docker.io/envoyproxy/gateway-helm",
    version: envoyGatewayVersion,
    namespace: "envoy-gateway-system",
    createNamespace: true,
  },
  { provider, dependsOn: metricsServer },
);

// Wait for the deployment to be fully ready before gateway resources are applied.
export const envoyGatewayReady = new command.local.Command(
  "envoy-gateway-ready",
  {
    create: `
      kubectl rollout status deployment/envoy-gateway \
        --namespace envoy-gateway-system \
        --context ${context} \
        --timeout=180s
    `,
    delete: `true`,
  },
  { dependsOn: envoyGateway },
);
