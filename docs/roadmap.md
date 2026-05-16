# Roadmap / Improvement Ideas

Tracked improvements and ideas for the xavifortes.com platform.

---

## Security

- **DNS-01 ACME solver** — Replace HTTP-01 with Cloudflare DNS-01 for cert-manager.
  Eliminates the need for port 80 routing through HAProxy, works behind strict
  firewalls, and supports wildcard certs. Requires a Cloudflare API token secret
  in the cluster (`cloudflare-api-token` secret in `cert-manager` namespace).

- **Renovate / Dependabot** — Automated dependency updates for npm packages,
  Docker base images, and Terraform providers. Currently all versions are pinned
  but not automatically bumped.

- **Trivy blocking mode** — Re-enable `exit-code: 1` in the Trivy scan once the
  base image CVEs are resolved or suppressed with a `.trivyignore` file. Currently
  set to report-only.

- **Container signing** — Sign the pushed image with `cosign` and verify the
  signature in ArgoCD before deploying (Sigstore/cosign policy).

- **Network policies** — Add Kubernetes `NetworkPolicy` resources to restrict
  pod-to-pod traffic in the `xavifortes` namespace.

---

## Observability

- **Uptime monitoring** — Add a simple uptime check (Uptime Kuma, Freshping, or
  Cloudflare Health Checks) alerting on `https://xavifortes.com` going down.

- **Prometheus scraping** — Expose nginx metrics via `nginx-prometheus-exporter`
  sidecar and scrape with the existing kube-prometheus-stack (if present on MAD1).

- **ArgoCD notifications** — Configure ArgoCD to send a notification (Discord/email)
  on sync failure or health degradation.

- **Access logs** — Forward nginx access logs from the pod to a central log
  aggregator (Loki, Grafana, or Cloudflare Log Push).

---

## Infrastructure

- **Cloudflare Terraform in shellnet-infrastructure** — Currently the Cloudflare
  module lives in this repo (self-contained portfolio). If other zones are added
  to shellnet-infrastructure in the future, consolidate there to avoid key
  duplication.

- **Cloudflare Origin CA certificate** — Generate a 15-year Cloudflare Origin CA
  cert and install it on HAProxy. This would allow other sites added to GRA8 in
  the future to also use TCP passthrough without needing to manage LE certs at
  the HAProxy level.

- **HAProxy config in git** — The GRA8 HAProxy config is currently edited in-place
  over SSH. Move it to an Ansible playbook or to shellnet-infrastructure with a
  `haproxy.cfg.j2` template so changes are tracked and reproducible.

- **Separate state per environment** — Currently only one Cloudflare environment
  (production). If a staging zone is added, use a separate state key prefix
  (`xavifortes/staging/cloudflare/tofu.tfstate`).

---

## CI/CD

- **GitHub Environments** — Add a `production` environment with a manual approval
  gate in the `deploy` job. Useful once the site has real traffic.

- **Preview deployments** — On PRs, build and push a `pr-<number>` tagged image
  and deploy to a `xavifortes-preview` namespace with a separate IngressRoute on
  a subdomain (e.g. `pr-42.xavifortes.com`).

- **Terrafrom plan in CI** — Add a `terragrunt plan` step to PRs that touch
  `infrastructure/`, posting the plan output as a PR comment.

- **Image provenance (SLSA)** — Add `actions/attest-build-provenance` to the
  push step to generate SLSA provenance attestations for the container image.

---

## Site content

- **Blog / writing section** — MDX is already configured. Add a `blog/` directory
  with a post listing page and RSS feed.

- **Projects page** — A structured list of GitHub projects with live status badges
  pulled from the GitHub API at build time.

- **Dark/light mode toggle** — Currently hardcoded dark. Add a system-preference
  aware toggle using a small amount of vanilla JS and a CSS class on `<html>`.

- **Sitemap** — Re-add `@astrojs/sitemap` once the compatibility issue with
  `astro@4.x` is resolved upstream (currently the integration crashes with
  `Cannot read properties of undefined (reading 'reduce')`).

- **Open Graph / SEO meta tags** — Add per-page OG image, description, and
  canonical URL meta tags in the Base layout.
