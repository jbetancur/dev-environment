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
// The AI gateway controller reads this to wire the extproc HTTP filter into Envoy's
// xDS config. Placing it here (Pulumi-owned namespace) avoids the ArgoCD delete-loop
// that occurs when it's placed in the ArgoCD-managed ai-gateway namespace.
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
