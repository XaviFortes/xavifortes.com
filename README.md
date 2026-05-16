# xavifortes.com

Personal portfolio monorepo for [xavifortes.com](https://xavifortes.com).

The architecture itself is the portfolio. This repo contains:

- **`apps/web/`** — Astro frontend (static, MDX case studies)
- **`infrastructure/tofu/`** — OpenTofu + Terragrunt for Cloudflare DNS, WAF, SSL
- **`kubernetes/apps/xavifortes-web/`** — k8s manifests (Deployment, Service, IngressRoute, Certificate)
- **`.github/workflows/`** — GitHub Actions CI: lint → security scan → build → push → GitOps deploy

## Stack

| Layer | Tool |
|---|---|
| Frontend | Astro 4 + Tailwind CSS |
| Container | nginx:alpine (multi-stage Docker build) |
| Registry | ghcr.io/xavifortes/web |
| Orchestration | k3s v1.33.5 — OVH MAD1 (3-node HA etcd) |
| GitOps | ArgoCD (auto-sync on image tag change) |
| Ingress | Traefik + cert-manager (Let's Encrypt) |
| Edge | Cloudflare WAF, SSL Full Strict |
| Load Balancer | OVH GRA8 HAProxy (SNI routing) |
| IaC | OpenTofu + Terragrunt |
| Secrets | SOPS + Age |
| CI security | Trivy (container CVEs) + Checkov (IaC) |

## Architecture

See [xavifortes.com/architecture](https://xavifortes.com/architecture) for the full breakdown.

## CI/CD flow

```
Push → GitHub Actions
         ├── Lint (ESLint, Prettier, tofu fmt)
         ├── Security (Trivy, Checkov)
         ├── Build Docker image
         ├── Push to ghcr.io:sha-<SHA>
         └── Commit tag bump to deployment.yaml
                  └── ArgoCD detects drift → syncs cluster
```

## Local development

```bash
cd apps/web
npm install
npm run dev        # http://localhost:4321
```

## First-time setup — secrets

Secrets are managed with SOPS + Age (same keys as `shellnet-infrastructure`).

**Templates** (safe to commit — contain only placeholder strings):
- `infrastructure/tofu/live/common.json.tpl` — B2 state backend credentials
- `infrastructure/tofu/live/cloudflare/secrets.json.tpl` — Cloudflare token, zone ID, GRA8 IP

**Bootstrap script** fills in the templates interactively and encrypts them:

```bash
# Requires: sops, age, jq (brew install sops age jq)
# Requires: Age private key in ~/.config/sops/age/keys.txt
./scripts/bootstrap-secrets.sh
```

This produces `*.sops.json` files (encrypted, safe to commit) and never leaves plaintext on disk.

To edit an existing secret later:
```bash
sops infrastructure/tofu/live/cloudflare/secrets.sops.json
```

## Deploying Cloudflare IaC

```bash
# After running bootstrap-secrets.sh:
cd infrastructure/tofu/live/cloudflare
terragrunt plan
terragrunt apply
```

## Required GitHub Secrets

| Secret | Purpose |
|---|---|
| `SOPS_AGE_KEY` | Age private key — value of `AGE-SECRET-KEY-...` line from `keys.txt` |
| `GITHUB_TOKEN` | Auto-provided — used for ghcr.io push and the image tag bump commit |

## Related

- [shellnet-infrastructure](https://github.com/xavifortes/shellnet-infrastructure) — homelab + OVH IaC (Proxmox, k3s, Ansible)
