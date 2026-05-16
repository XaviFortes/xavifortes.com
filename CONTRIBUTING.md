# Contributing / Local Development

## Prerequisites

- Node.js 20+
- npm
- Docker (optional, for container testing)
- OpenTofu + Terragrunt (for infrastructure changes)
- SOPS + Age (for secrets)
- kubectl (for cluster operations)

---

## Running the site locally

```bash
cd apps/web
npm install
npm run dev
# → http://localhost:4321
```

### Build and preview the static output

```bash
cd apps/web
npm run build    # outputs to dist/
npm run preview  # serves dist/ locally
```

---

## Lint and format

```bash
cd apps/web
npm run lint          # ESLint
npm run format        # Prettier (auto-fix)
npm run format:check  # Prettier (check only, used in CI)
```

---

## Infrastructure changes

```bash
cd infrastructure/tofu/live/cloudflare

# Preview changes
terragrunt plan

# Apply changes
terragrunt apply
```

Requires the Age private key:
- Local: `~/.config/sops/age/keys.txt`
- CI: `SOPS_AGE_KEY` GitHub Actions secret

### Formatting

```bash
tofu fmt -recursive infrastructure/tofu/modules/
terragrunt hclfmt infrastructure/
```

---

## Adding a new page

1. Create `apps/web/src/pages/your-page.astro`
2. Add a link in `apps/web/src/components/Nav.astro`
3. Push — CI builds and deploys automatically

---

## Secrets

Secrets are SOPS-encrypted. To edit:

```bash
sops infrastructure/tofu/live/cloudflare/secrets.sops.json
# make changes, save — SOPS re-encrypts on write
git add infrastructure/tofu/live/cloudflare/secrets.sops.json
git commit -m "chore(secrets): ..."
```

To create secrets from scratch on a new machine:

```bash
./scripts/bootstrap-secrets.sh
```

---

## Branching and PR workflow

- `master` is the production branch — every push triggers CI and deploys
- For larger changes, open a PR: CI runs lint/build/scan but does **not** push the image or deploy
- Merge to master to deploy

---

## CI pipeline summary

| Job | Triggers on | What it does |
|---|---|---|
| lint | PR + push | ESLint + Prettier |
| tf-validate | PR + push | tofu fmt + terragrunt hclfmt |
| checkov | PR + push | IaC security scan |
| build-and-scan | PR + push | Docker build, Trivy scan |
| push image | push to master only | Push to ghcr.io |
| deploy | push to master only | Bump image SHA in deployment.yaml, commit, push |
