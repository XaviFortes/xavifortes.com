# Architecture & Deploy Flow

## Overview

`xavifortes.com` is a static Astro site served from a k3s cluster on OVH Madrid (MAD1),
fronted by Cloudflare and routed through an OVH Gravelines (GRA8) HAProxy bastion.
All infrastructure is code — Terraform/OpenTofu for Cloudflare, Kubernetes manifests
for the app, ArgoCD for GitOps delivery.

---

## Repository Layout

```
xavifortes.com/
├── apps/web/                          # Astro frontend source
│   ├── src/pages/                     # index, architecture, cloud, software, hardware
│   ├── src/components/                # Nav, Footer, Base layout
│   ├── Dockerfile                     # multi-stage: node:20-alpine → nginx:mainline-alpine
│   └── nginx.conf                     # hardened nginx config, port 8080
│
├── kubernetes/apps/xavifortes-web/    # k8s manifests (managed by ArgoCD)
│   ├── namespace.yaml
│   ├── deployment.yaml                # image tag auto-bumped by CI
│   ├── service.yaml
│   ├── ingress.yaml                   # Traefik IngressRoute + www-redirect middleware
│   ├── kustomization.yaml
│   └── argocd-app.yaml                # ArgoCD Application (lives in shellnet-infrastructure)
│
├── infrastructure/tofu/
│   ├── modules/cloudflare/            # Reusable Cloudflare module
│   │   ├── main.tf                    # DNS, SSL settings, WAF, rate limiting
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── live/cloudflare/               # Terragrunt live config
│       ├── terragrunt.hcl             # reads secrets.sops.json + common.sops.json
│       └── secrets.sops.json          # CF token, zone ID, GRA8 IP (SOPS-encrypted)
│
├── .github/workflows/ci.yml           # Full CI/CD pipeline
├── .sops.yaml                         # SOPS encryption rules (Age public keys only)
└── docs/                              # This documentation
```

---

## Traffic Flow (Production)

```
User's browser
      │  HTTPS (TLS 1.2+)
      ▼
Cloudflare Edge  (WAF, rate limiting, CDN cache, DDoS protection)
      │  HTTPS — Full Strict mode (validates origin cert)
      │  Cloudflare IP → 51.210.105.255 (GRA8)
      ▼
GRA8 HAProxy  (OVH Gravelines VPS, 51.210.105.255)
      │  TCP passthrough — SNI-based routing, no SSL termination for xavifortes.com
      │  (HAProxy peeks at TLS SNI, routes xavifortes.com directly to MAD1)
      ▼
MAD1 Traefik  (k3s LoadBalancer, any of 141.227.188.178-180 :443)
      │  TLS termination — Let's Encrypt cert via cert-manager
      │  IngressRoute: Host(`xavifortes.com`) || Host(`www.xavifortes.com`)
      │  www-redirect middleware → 308 to apex
      ▼
xavifortes-web pod  (:8080, nginx serving static dist/)
```

### Port 80 (HTTP) flow

```
User / Let's Encrypt ACME validator
      │  HTTP
      ▼
Cloudflare  (passes /.well-known/acme-challenge/ through even with Always HTTPS on)
      ▼
GRA8 HAProxy http_front  (ACL: xavifortes.com → xavifortes_mad1_http backend)
      ▼
MAD1 Traefik :80  → cert-manager ACME HTTP-01 solver pod
```

---

## CI/CD Pipeline

Every `git push` to `master` runs the following jobs in order:

```
push to master
      │
      ├── [parallel] lint          ESLint + Prettier check on src/
      ├── [parallel] tf-validate   tofu fmt + terragrunt hclfmt
      └── [parallel] checkov       IaC security scan (SARIF → GitHub Security tab)
      │
      │   (all three must pass)
      ▼
build-and-scan
      │  1. docker build → load image locally as xavifortes-web:scan
      │  2. trivy scan   → SARIF uploaded to GitHub Security (report-only, no block)
      │  3. docker push  → ghcr.io/xavifortes/web:sha-<full-sha>
      │                    ghcr.io/xavifortes/web:latest
      ▼
deploy  (only on master push, after build-and-scan + checkov pass)
      │  sed replaces image tag in kubernetes/apps/xavifortes-web/deployment.yaml
      │  git commit "chore(deploy): bump web image to sha-<sha> [skip ci]"
      │  git push → master
      ▼
ArgoCD  (polls github.com/XaviFortes/xavifortes.com every ~3 min)
      │  detects diff in kubernetes/apps/xavifortes-web/
      │  server-side apply → Deployment image tag updated
      ▼
k3s rolling update
      │  kubelet pulls ghcr.io/xavifortes/web:sha-<sha> using ghcr-pull-secret
      │  new pod passes readiness probe (/  HTTP 200)
      │  old pod terminated
      ▼
site updated with zero downtime
```

### Key design decisions

| Decision | Reason |
|---|---|
| SHA tag in deployment.yaml | ArgoCD needs a manifest diff to trigger sync; `latest` never changes |
| `[skip ci]` on deploy commit | Prevents infinite loop: push → CI → deploy commit → CI → … |
| TCP passthrough at HAProxy | HAProxy has no cert for xavifortes.com; Traefik holds the LE cert; Cloudflare Full Strict validates it |
| ArgoCD `prune: true, selfHeal: true` | Manual `kubectl apply` changes are reverted; removing a manifest file removes the resource |
| SOPS + Age for secrets | Encrypted secrets committed to git; same Age keys as shellnet-infrastructure; CI decrypts with `SOPS_AGE_KEY` secret |
| Cloudflare Free plan constraints | No `matches` regex operator, no `cf.bot_management.*`, rate limit `period=10` only, no Transform Rules (redirect ruleset) — www redirect handled at Traefik instead |

---

## Infrastructure (Cloudflare via OpenTofu)

Managed in `infrastructure/tofu/live/cloudflare/` with Terragrunt.
State stored in Backblaze B2, key prefix `xavifortes/cloudflare/tofu.tfstate`.

### Resources

| Resource | Description |
|---|---|
| `cloudflare_record.apex` | A record `xavifortes.com` → `51.210.105.255` (GRA8), proxied |
| `cloudflare_record.www` | CNAME `www` → `xavifortes.com`, proxied |
| `cloudflare_zone_settings_override` | SSL strict, TLS 1.2+, HTTP/3, brotli, early hints |
| `cloudflare_ruleset.waf_custom` | Block empty UA, scanners (sqlmap/nikto/etc), path traversal |
| `cloudflare_ruleset.rate_limit` | 20 req/10s per IP per colo, block for 10s (Free plan limits) |

### Applying changes

```bash
cd infrastructure/tofu/live/cloudflare
terragrunt plan    # preview
terragrunt apply   # apply
```

Requires `SOPS_AGE_KEY` in environment or `~/.config/sops/age/keys.txt`.

---

## Secrets Management

Secrets are SOPS-encrypted JSON files committed to the repo.

| File | Contains | Encrypted for |
|---|---|---|
| `infrastructure/tofu/live/cloudflare/secrets.sops.json` | CF API token, zone ID, GRA8 IP | primary + CI Age keys |
| `infrastructure/tofu/live/common.sops.json` | B2 state backend credentials | primary + CI Age keys |

**To re-encrypt / rotate a secret:**
```bash
sops infrastructure/tofu/live/cloudflare/secrets.sops.json
# edit values, save — SOPS re-encrypts on save
```

**GitHub Actions secrets required:**
- `SOPS_AGE_KEY` — Age private key for CI to decrypt SOPS files

---

## Kubernetes Cluster (MAD1)

k3s cluster on OVH Madrid. Three control-plane VPS nodes:

| Node | IP |
|---|---|
| vps-6b58f204 | 141.227.188.178 |
| vps-04483f6e | 141.227.188.179 |
| vps-d147fb4d | 141.227.188.180 |
| k3s-ha-ovh-es | 10.2.1.6 (internal only) |

**Prerequisites on the cluster (one-time setup):**

```bash
# Pull secret for ghcr.io
kubectl create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=XaviFortes \
  --docker-password=<GITHUB_PAT_read:packages> \
  -n xavifortes

# cert-manager ClusterIssuer (if not already present)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: hi@xavifortes.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: traefik
EOF

# ArgoCD Application (from shellnet-infrastructure repo)
kubectl apply -f kubernetes/apps/xavifortes-web/argocd-app.yaml
```

---

## GRA8 HAProxy

The HAProxy on GRA8 (`51.210.105.255`) uses a two-tier `:443` setup:

```
:443  https_sni_router  (TCP mode)
      │  SNI: xavifortes.com / www.xavifortes.com
      ├──→  xavifortes_mad1_tcp backend  (TCP passthrough to MAD1 :443)
      │
      └──→  https_ssl_termination backend  (loopback to 127.0.0.1:4443)
                  │
                  ▼
            https_front  (SSL termination for inovexservices.com etc)
            bound on 127.0.0.1:4443 with accept-proxy
```

The xavifortes.com traffic **never has its TLS terminated at HAProxy** — it passes through as raw TCP to MAD1 Traefik which holds the Let's Encrypt certificate. This satisfies Cloudflare Full Strict mode.

Config lives at `/etc/haproxy/haproxy.cfg` on `vps-f24bf8b4` (SSH alias).
