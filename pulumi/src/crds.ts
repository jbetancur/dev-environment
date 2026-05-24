import * as command from "@pulumi/command";
import { context, envoyGatewayVersion } from "./config";
import { registryHostingCm } from "./cluster";

// Install Gateway API + Envoy Gateway CRDs before Cilium so the Cilium
// operator finds the GatewayClass CRD on startup.
export const gatewayCrds = new command.local.Command(
  "gateway-crds",
  {
    create: `
      helm template gateway-crds oci://docker.io/envoyproxy/gateway-crds-helm \
        --kube-context ${context} \
        --version "${envoyGatewayVersion}" \
        --set crds.gatewayAPI.enabled=true \
        --set crds.gatewayAPI.channel=experimental \
        --set crds.envoyGateway.enabled=true \
        | kubectl apply --server-side -f - --context ${context}
    `,
    // CRDs are cluster-scoped; let pulumi destroy handle cluster teardown.
    delete: `true`,
  },
  { dependsOn: registryHostingCm },
);
