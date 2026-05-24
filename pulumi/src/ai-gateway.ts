import * as k8s from "@pulumi/kubernetes";
import * as command from "@pulumi/command";
import * as pulumi from "@pulumi/pulumi";
import { context, base, aiGatewayVersion, installAiGateway, openAiApiKey } from "./config";
import { provider } from "./cilium";
import { envoyGatewayReady } from "./envoy";
import { gateway } from "./gateway";

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

// HTTPRoute — attaches to the existing shared Gateway in envoy-gateway-system.
export const aiGatewayRoute = aiGatewayNs
  ? new k8s.apiextensions.CustomResource(
      "ai-gateway-httproute",
      {
        apiVersion: "gateway.networking.k8s.io/v1",
        kind: "HTTPRoute",
        metadata: { name: "ai-gateway", namespace: "ai-gateway" },
        spec: {
          parentRefs: [
            { name: "local", namespace: "envoy-gateway-system", sectionName: "https" },
          ],
          hostnames: [pulumi.interpolate`ai.${base}`],
          rules: [
            {
              matches: [{ path: { type: "PathPrefix", value: "/" } }],
              backendRefs: [
                {
                  group: "aigateway.envoyproxy.io",
                  kind: "AIGatewayRoute",
                  name: "openai",
                  namespace: "ai-gateway",
                },
              ],
            },
          ],
        },
      },
      { provider, dependsOn: [gateway, aiGatewayNs] },
    )
  : undefined;
