import * as pulumi from "@pulumi/pulumi";

const cfg = new pulumi.Config();

function mustGet(key: string): string {
  return cfg.require(key);
}

function mustGetSecret(key: string): pulumi.Output<string> {
  return cfg.requireSecret(key);
}

function getOrDefault(key: string, fallback: string): string {
  return cfg.get(key) ?? fallback;
}

// Cluster identity
export const clusterName = mustGet("clusterName");
export const context = `kind-${clusterName}`;

// Domain config
export const domain = mustGet("domain");
export const subdomain = mustGet("subdomain");
export const base = `${subdomain}.${domain}`;
export const wildcard = `*.${subdomain}.${domain}`;

// Let's Encrypt
export const acmeEmail = mustGet("email");

// ArgoCD
export const repoUrl = mustGet("repoUrl");

// Cert mode: "letsencrypt" (default) or "selfsigned"
export const certMode = getOrDefault("certMode", "letsencrypt");

// Cloudflare token — required when certMode=letsencrypt, ignored for selfsigned.
export const cloudflareToken = certMode === "letsencrypt"
  ? mustGetSecret("cloudflareToken")
  : pulumi.output("unused");

// AI Gateway — opt-in feature flag
export const installAiGateway = getOrDefault("installAiGateway", "false") === "true";

// OpenAI API key — only required when installAiGateway=true
export const openAiApiKey: pulumi.Output<string> = installAiGateway
  ? cfg.requireSecret("openAiApiKey")
  : pulumi.output("unused");

// Pinned versions — override per-stack if needed
export const argoCdVersion                = getOrDefault("argoCdVersion",                "9.5.15");
export const aiGatewayVersion             = getOrDefault("aiGatewayVersion",             "v0.6.0");
export const envoyGatewayVersion          = getOrDefault("envoyGatewayVersion",          "v1.8.0");
export const ciliumVersion                = getOrDefault("ciliumVersion",                "1.19.4");
export const certManagerVersion           = getOrDefault("certManagerVersion",           "v1.20.2");
export const kubePrometheusStackVersion   = getOrDefault("kubePrometheusStackVersion",   "85.3.0");
export const lokiVersion                  = getOrDefault("lokiVersion",                  "7.0.0");
export const promtailVersion              = getOrDefault("promtailVersion",              "6.17.1");

// Local registry
export const registryName = getOrDefault("registryName", "kind-registry");
export const registryPort = getOrDefault("registryPort", "5001");
