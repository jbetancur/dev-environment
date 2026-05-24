import * as command from "@pulumi/command";
import * as pulumi from "@pulumi/pulumi";
import * as path from "path";
import { clusterName, context, registryName, registryPort } from "./config";

const repoRoot = path.resolve(__dirname, "../../");
const clusterConfig = path.join(repoRoot, "dotfiles/.config/kind/cluster.yaml");
const k8sDir = path.join(repoRoot, "k8s");

// Start the local registry if it isn't already running.
export const registry = new command.local.Command("registry", {
  create: `
    if docker inspect ${registryName} &>/dev/null; then
      echo "registry already running"
    else
      docker run -d \
        --restart=always \
        -p "127.0.0.1:${registryPort}:5000" \
        --network bridge \
        --name ${registryName} \
        registry:2
    fi
  `,
  delete: `
    # Only remove the registry if no other kind clusters remain.
    if [ -z "$(kind get clusters 2>/dev/null)" ]; then
      docker rm -f ${registryName} 2>/dev/null || true
    fi
  `,
});

// Create the kind cluster (no CNI, no kube-proxy — Cilium takes over).
export const cluster = new command.local.Command(
  "cluster",
  {
    create: `kind create cluster --name ${clusterName} --config ${clusterConfig}`,
    delete: `kind delete cluster --name ${clusterName}`,
  },
  { dependsOn: registry },
);

// Connect the registry container into the kind Docker network so nodes can pull from it.
export const registryNetwork = new command.local.Command(
  "registry-network",
  {
    create: `docker network connect kind ${registryName} 2>/dev/null || true`,
    // No-op on delete — network disappears with the kind cluster.
    delete: `true`,
  },
  { dependsOn: cluster },
);

// Configure each node's containerd to use the local registry via hosts.toml.
export const registryHosts = new command.local.Command(
  "registry-hosts",
  {
    create: pulumi.interpolate`
      for node in $(kind get nodes --name ${clusterName}); do
        docker exec "$node" mkdir -p /etc/containerd/certs.d/localhost:${registryPort}
        printf '[host."http://${registryName}:5000"]\n' \
          | docker exec -i "$node" tee /etc/containerd/certs.d/localhost:${registryPort}/hosts.toml > /dev/null
      done
    `,
    delete: `true`,
  },
  { dependsOn: registryNetwork },
);

// Apply the LocalRegistryHosting ConfigMap so Tilt/Skaffold can discover the registry.
export const registryHostingCm = new command.local.Command(
  "registry-hosting-cm",
  {
    create: `kubectl apply --context ${context} -f ${k8sDir}/registry/local-registry-hosting.yaml`,
    delete: `true`,
  },
  { dependsOn: registryHosts },
);
