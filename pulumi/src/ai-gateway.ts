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

// No HTTPRoute needed here — AIGatewayRoute attaches directly to the Gateway
// via its own parentRefs (managed by ArgoCD via k8s/ai-gateway/ai-gateway-route.yaml).
