import * as pulumi from "@pulumi/pulumi";
import { base, clusterName, subdomain, domain } from "./config";

// Import all modules to trigger resource registration — ordering is expressed
// via dependsOn inside each module, not by import order.
import "./cluster";
import "./crds";
import "./cilium";
import "./envoy";
import "./coredns";
import "./argocd";
import "./secrets";
import "./gateway";
import "./ai-gateway";

import { argocdPassword } from "./argocd";
import { installAiGateway } from "./config";

export const cluster = clusterName;
export const argocdUrl = pulumi.interpolate`https://argocd.${base}`;
export const grafanaUrl = pulumi.interpolate`https://grafana.${base}`;
export const hubbleUrl = pulumi.interpolate`https://hubble.${base}`;
export const registryUrl = pulumi.interpolate`https://registry.${base}`;
export const argocdCredentials = pulumi.interpolate`admin / ${argocdPassword}`;
export const aiGatewayUrl = installAiGateway ? pulumi.interpolate`https://ai.${base}` : undefined;
export const chatUrl = installAiGateway ? pulumi.interpolate`https://chat.${base}` : undefined;
export const note = pulumi.interpolate`Services available once ArgoCD syncs (~2-3 min). Domain: *.${subdomain}.${domain}`;
