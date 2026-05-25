import * as command from "@pulumi/command";
import * as pulumi from "@pulumi/pulumi";
import { context, base } from "./config";
import { envoyGatewayReady } from "./envoy";

// Patch CoreDNS to rewrite *.{base} → the envoy gateway service so that pods
// can reach cluster-internal services using external hostnames. Without this,
// *.{base} resolves to 127.0.0.1 (local Technitium DNS) inside pods.
// The envoy service name is discovered dynamically so this survives cluster rebuilds.
export const coreDnsRewrite = new command.local.Command(
  "coredns-rewrite",
  {
    create: pulumi.interpolate`
      ENVOY_SVC=$(kubectl get svc -n envoy-gateway-system \
        --context ${context} \
        -l gateway.envoyproxy.io/owning-gateway-name=local \
        -o jsonpath='{.items[0].metadata.name}') && \
      python3 - "$ENVOY_SVC" "${base}" "${context}" <<'PYEOF'
import sys, json, subprocess
envoy_svc, base, ctx = sys.argv[1], sys.argv[2], sys.argv[3]
corefile = f""".:53 {{
    errors
    health {{
       lameduck 5s
    }}
    ready
    rewrite name regex (.*)\\.{base} {envoy_svc}.envoy-gateway-system.svc.cluster.local answer auto
    kubernetes cluster.local in-addr.arpa ip6.arpa {{
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }}
    prometheus :9153
    forward . /etc/resolv.conf {{
       max_concurrent 1000
    }}
    cache 30 {{
       disable success cluster.local
       disable denial cluster.local
    }}
    loop
    reload
    loadbalance
}}
"""
patch = json.dumps({"data": {"Corefile": corefile}})
subprocess.run(["kubectl", "patch", "configmap", "coredns", "-n", "kube-system",
                "--context", ctx, "--type", "merge", "-p", patch], check=True)
PYEOF
      kubectl rollout restart deployment/coredns -n kube-system --context ${context} && \
      kubectl rollout status deployment/coredns -n kube-system --context ${context} --timeout=60s
    `,
    delete: `true`,
  },
  { dependsOn: envoyGatewayReady },
);
