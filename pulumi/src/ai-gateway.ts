import * as k8s from "@pulumi/kubernetes";
import * as command from "@pulumi/command";
import * as pulumi from "@pulumi/pulumi";
import { context, aiGatewayVersion, installAiGateway, openAiApiKey } from "./config";
import { provider } from "./cilium";
import { envoyGatewayReady } from "./envoy";


if (!installAiGateway) {
  pulumi.log.info("AI Gateway is disabled (installAiGateway=false). Set installAiGateway=true to enable.");
}

// Everything below is conditional on the feature flag.
// CRDs must be installed before the controller chart.
const aiGatewayCrds = installAiGateway
  ? new k8s.helm.v3.Release(
      "ai-gateway-crds",
      {
        name: "aieg-crd",
        chart: "oci://docker.io/envoyproxy/ai-gateway-crds-helm",
        version: aiGatewayVersion,
        namespace: "envoy-ai-gateway-system",
        createNamespace: true,
      },
      { provider, dependsOn: [envoyGatewayReady] },
    )
  : undefined;

export const aiGateway = aiGatewayCrds
  ? new k8s.helm.v3.Release(
      "ai-gateway",
      {
        name: "aieg",
        chart: "oci://docker.io/envoyproxy/ai-gateway-helm",
        version: aiGatewayVersion,
        namespace: "envoy-ai-gateway-system",
        createNamespace: false,
      },
      { provider, dependsOn: aiGatewayCrds },
    )
  : undefined;

const aiGatewayReady = aiGateway
  ? new command.local.Command(
      "ai-gateway-ready",
      {
        create: `
          kubectl wait --timeout=120s \
            -n envoy-ai-gateway-system \
            --context ${context} \
            deployment/ai-gateway-controller \
            --for=condition=Available
        `,
        delete: `true`,
      },
      { dependsOn: aiGateway },
    )
  : undefined;

export const aiGatewayNs = aiGatewayReady
  ? new k8s.core.v1.Namespace(
      "ai-gateway-ns",
      { metadata: { name: "ai-gateway" } },
      { provider, dependsOn: aiGatewayReady },
    )
  : undefined;

// OpenAI API key secret — value sourced from Pulumi config (openAiApiKey).
export const openAiSecret = aiGatewayNs
  ? new k8s.core.v1.Secret(
      "openai-apikey-secret",
      {
        metadata: { name: "openai-apikey", namespace: "ai-gateway" },
        stringData: { apiKey: openAiApiKey },
      },
      { provider, dependsOn: aiGatewayNs, retainOnDelete: true },
    )
  : undefined;

// GatewayConfig — must be in the same namespace as the Gateway (envoy-gateway-system).
export const aiGatewayConfig = openAiSecret
  ? new k8s.apiextensions.CustomResource(
      "ai-gateway-config",
      {
        apiVersion: "aigateway.envoyproxy.io/v1beta1",
        kind: "GatewayConfig",
        metadata: { name: "ai-gateway-config", namespace: "envoy-gateway-system" },
        spec: {},
      },
      { provider, dependsOn: [openAiSecret] },
    )
  : undefined;

// Patch the Envoy Gateway ConfigMap to register the AI gateway controller as an
// extension server. Without this, Envoy Gateway never calls the AI gateway gRPC
// server during xDS translation, so the ext_proc filter is never injected into
// the listener chain — requests reach OpenAI without the Authorization header.
// Uses a local Command (kubectl patch) since the ConfigMap is owned by the EG Helm chart
// and server-side apply field conflicts prevent Pulumi from managing it directly.
export const envoyGatewayConfigPatch = aiGatewayConfig
  ? new command.local.Command(
      "envoy-gateway-config-patch",
      {
        create: `kubectl patch configmap envoy-gateway-config \
          -n envoy-gateway-system \
          --context ${context} \
          --type merge \
          -p '{"data":{"envoy-gateway.yaml":"apiVersion: gateway.envoyproxy.io/v1alpha1\\nkind: EnvoyGateway\\nextensionApis:\\n  enableBackend: true\\nextensionManager:\\n  hooks:\\n    xdsTranslator:\\n      translation:\\n        listener:\\n          includeAll: true\\n        route:\\n          includeAll: true\\n        cluster:\\n          includeAll: true\\n        secret:\\n          includeAll: true\\n      post:\\n        - Translation\\n        - Cluster\\n        - Route\\n  service:\\n    fqdn:\\n      hostname: ai-gateway-controller.envoy-ai-gateway-system.svc.cluster.local\\n      port: 1063\\ngateway:\\n  controllerName: gateway.envoyproxy.io/gatewayclass-controller\\nlogging:\\n  level:\\n    default: info\\nprovider:\\n  kubernetes:\\n    rateLimitDeployment:\\n      container:\\n        image: docker.io/envoyproxy/ratelimit:ff287602\\n      patch:\\n        type: StrategicMerge\\n        value:\\n          spec:\\n            template:\\n              spec:\\n                containers:\\n                - imagePullPolicy: IfNotPresent\\n                  name: envoy-ratelimit\\n    shutdownManager:\\n      image: docker.io/envoyproxy/gateway:v1.8.0\\n  type: Kubernetes\\n"}}'`,
        delete: `true`,
      },
      { dependsOn: [aiGatewayConfig] },
    )
  : undefined;

// Restart envoy-gateway so it picks up the updated ConfigMap with the extension server.
const envoyGatewayRestart = envoyGatewayConfigPatch
  ? new command.local.Command(
      "envoy-gateway-restart",
      {
        create: `
          kubectl rollout restart deployment/envoy-gateway \
            -n envoy-gateway-system --context ${context} && \
          kubectl rollout status deployment/envoy-gateway \
            -n envoy-gateway-system --context ${context} --timeout=120s
        `,
        delete: `true`,
      },
      { dependsOn: [envoyGatewayConfigPatch] },
    )
  : undefined;

// Restart the envoy proxy pod so the AI gateway extension server injects the
// extproc sidecar. Without this restart the pod comes up without the sidecar
// and /v1/models returns 500 on every fresh cluster.
// No rollout status check — hostPort contention on kind means the old pod
// lingers until it fully terminates, which exceeds any reasonable timeout.
export const envoyProxyRestart = envoyGatewayRestart
  ? new command.local.Command(
      "envoy-proxy-restart",
      {
        create: `
          DEPLOY=$(kubectl get deployment -n envoy-gateway-system \
            --context ${context} \
            -l gateway.envoyproxy.io/owning-gateway-name=local \
            -o jsonpath='{.items[0].metadata.name}') && \
          kubectl rollout restart deployment/$DEPLOY \
            -n envoy-gateway-system --context ${context}
        `,
        delete: `true`,
      },
      { dependsOn: [envoyGatewayRestart] },
    )
  : undefined;
