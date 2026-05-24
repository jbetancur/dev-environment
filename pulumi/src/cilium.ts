import * as command from "@pulumi/command";
import * as k8s from "@pulumi/kubernetes";
import { clusterName, context } from "./config";
import { gatewayCrds } from "./crds";

// Resolve the control-plane node's IP — Cilium needs it for kube-proxy replacement.
const apiServerIp = new command.local.Command(
  "api-server-ip",
  {
    create: `
      node=$(kind get nodes --name ${clusterName} | grep control-plane)
      docker inspect "$node" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
    `,
  },
  { dependsOn: gatewayCrds },
);

// Add the Cilium Helm repo.
const ciliumRepo = new command.local.Command(
  "cilium-repo",
  {
    create: `helm repo add cilium https://helm.cilium.io/ --force-update && helm repo update cilium`,
    delete: `true`,
  },
  { dependsOn: gatewayCrds },
);

// Install Cilium with kube-proxy replacement and Gateway API support.
export const cilium = new command.local.Command(
  "cilium",
  {
    create: apiServerIp.stdout.apply((ip) => `
      helm upgrade --install cilium cilium/cilium \
        --namespace kube-system \
        --kube-context ${context} \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost=${ip.trim()} \
        --set k8sServicePort=6443 \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set gatewayAPI.enabled=true \
        --set prometheus.enabled=true \
        --set operator.prometheus.enabled=true
    `),
    delete: `helm uninstall cilium --namespace kube-system --kube-context ${context} 2>/dev/null || true`,
  },
  { dependsOn: [ciliumRepo, apiServerIp] },
);

// Provider scoped to this cluster — used for all subsequent k8s resources.
export const provider = new k8s.Provider(
  "k8s-provider",
  { context },
  { dependsOn: cilium },
);

// Wait for Cilium daemonsets and deployments to be fully rolled out.
const ciliumRollout = new command.local.Command(
  "cilium-rollout",
  {
    create: `
      kubectl rollout status daemonset/cilium --namespace kube-system --context ${context} --timeout=180s
      kubectl rollout status deployment/cilium-operator --namespace kube-system --context ${context} --timeout=120s
      kubectl rollout status daemonset/cilium-envoy --namespace kube-system --context ${context} --timeout=120s
      kubectl rollout status deployment/hubble-relay --namespace kube-system --context ${context} --timeout=120s
      kubectl rollout status deployment/hubble-ui --namespace kube-system --context ${context} --timeout=120s
    `,
    delete: `true`,
  },
  { dependsOn: cilium },
);

// Install metrics-server (needs Cilium CNI to schedule pods).
export const metricsServer = new command.local.Command(
  "metrics-server",
  {
    create: `
      helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
      helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --kube-context ${context} \
        --set args={--kubelet-insecure-tls}
    `,
    delete: `helm uninstall metrics-server --namespace kube-system --kube-context ${context} 2>/dev/null || true`,
  },
  { dependsOn: ciliumRollout },
);
